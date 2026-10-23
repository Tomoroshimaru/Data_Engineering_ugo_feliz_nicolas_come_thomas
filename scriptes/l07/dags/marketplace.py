"""Albert's Marketplace: one day of orders, extracted, loaded, transformed, tested.

Four tasks, four containers. The DAG file says *what* runs and *in what order*;
none of the work happens here.
"""

import os

import pendulum
from airflow.sdk import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount

# The paths below are the HOST's, not this container's. A DockerOperator task
# asks the host's Docker daemon to start a container, so every mount it names
# is resolved by the host. This is the one genuinely confusing thing about
# running Docker from inside Docker.
HOST_DIR = os.environ["HOST_DIR"]
GCLOUD_DIR = os.environ["GCLOUD_DIR"]

DATASET = "l07_fl"
DB_URL = "postgresql://postgres:postgres@db:5432/marketplace"

# Read-only on purpose: a task has no business editing your gcloud config.
gcloud_mount = Mount(source=GCLOUD_DIR, target="/gcloud-ro", type="bind", read_only=True)
data_mount = Mount(source=f"{HOST_DIR}/out", target="/data", type="bind")
transform_mount = Mount(source=f"{HOST_DIR}/transform", target="/usr/app", type="bind")

# The casts are not decoration. pandas stores a nullable integer as float64,
# Parquet carries that through, and payment_id arrives in BigQuery as FLOAT.
#
# `bq` insists on writing to its config directory, so it gets a writable copy.
# dbt does not: its BigQuery adapter only reads the credentials.
LOAD = f"""
set -e
cp -r /gcloud-ro /tmp/gcloud
export CLOUDSDK_CONFIG=/tmp/gcloud
bq --location=europe-west1 load --source_format=PARQUET --replace \
  {DATASET}.orders_stage /data/orders.parquet

bq --location=europe-west1 query --use_legacy_sql=false --format=none \
"CREATE TABLE IF NOT EXISTS {DATASET}.orders_raw (
   order_id INT64, buyer_id STRING, discount_id INT64,
   payment_id INT64, order_date DATE);
 MERGE {DATASET}.orders_raw t
 USING (
   SELECT order_id, buyer_id,
          SAFE_CAST(discount_id AS INT64) AS discount_id,
          SAFE_CAST(payment_id AS INT64)  AS payment_id,
          order_date
   FROM {DATASET}.orders_stage
 ) s
 ON t.order_id = s.order_id
 WHEN MATCHED THEN UPDATE SET
   buyer_id = s.buyer_id, discount_id = s.discount_id,
   payment_id = s.payment_id, order_date = s.order_date
 WHEN NOT MATCHED THEN INSERT ROW;"

bq --location=europe-west1 query --use_legacy_sql=false --format=csv \
"SELECT COUNT(*) AS rows_in_bronze FROM {DATASET}.orders_raw"
"""


def alert(context):
    """Runs only when a task has failed for the last time."""
    ti = context["task_instance"]
    print(
        f"ALERT  {ti.dag_id}.{ti.task_id} failed for "
        f"{context['data_interval_start']} after {ti.try_number} tries",
        flush=True,
    )


with DAG(
    dag_id="marketplace_daily",
    schedule="@daily",
    start_date=pendulum.datetime(2026, 3, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={
        "retries": 2,
        "retry_delay": pendulum.duration(seconds=20),
        "on_failure_callback": alert,
    },
    tags=["albert", "l07"],
) as dag:

    extract = DockerOperator(
        task_id="extract",
        image="charlestng/albert-extractor:2026-09-25",
        network_mode="albert-marketplace_default",
        environment={
            "DATABASE_URL": DB_URL,
            "TABLE": "orders",
            "CURSOR_COL": "order_date",
            "SINCE": "{{ data_interval_start | ds }}",
        },
        mounts=[data_mount],
        auto_remove="success",
        mount_tmp_dir=False,
    )

    load = DockerOperator(
        task_id="load",
        image="google/cloud-sdk:slim",
        entrypoint="/bin/bash",
        command=["-c", LOAD],
        mounts=[gcloud_mount, data_mount],
        auto_remove="success",
        mount_tmp_dir=False,
    )

    dbt_run = DockerOperator(
        task_id="dbt_run",
        image="charlestng/dbt-bigquery:1.12.1",
        command="run",
        working_dir="/usr/app",
        environment={"DBT_PROFILES_DIR": "/usr/app",
                     "CLOUDSDK_CONFIG": "/gcloud-ro"},
        mounts=[gcloud_mount, transform_mount],
        auto_remove="success",
        mount_tmp_dir=False,
    )

    dbt_test = DockerOperator(
        task_id="dbt_test",
        image="charlestng/dbt-bigquery:1.12.1",
        command="test",
        working_dir="/usr/app",
        environment={"DBT_PROFILES_DIR": "/usr/app",
                     "CLOUDSDK_CONFIG": "/gcloud-ro"},
        mounts=[gcloud_mount, transform_mount],
        auto_remove="success",
        mount_tmp_dir=False,
    )

    extract >> load >> dbt_run >> dbt_test
