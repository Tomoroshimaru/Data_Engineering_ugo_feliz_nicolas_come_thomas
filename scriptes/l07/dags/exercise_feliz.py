"""Exercise 1, lesson 7: two tables extracted side by side, loaded, staging cleaned up."""

import os

import pendulum
from airflow.sdk import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount

HOST_DIR = os.environ["HOST_DIR"]
GCLOUD_DIR = os.environ["GCLOUD_DIR"]
DATASET = "l07_ex_fl"
DB_URL = "postgresql://postgres:postgres@db:5432/marketplace"

gcloud_mount = Mount(source=GCLOUD_DIR, target="/gcloud-ro", type="bind", read_only=True)
data_mount = Mount(source=f"{HOST_DIR}/out", target="/data", type="bind")

# Neither table has a date column, so no SINCE: every run takes the whole table.
# Step 4 proved that appending doubles the table on a re-run; the load now merges.
LOAD = f"""
set -e
cp -r /gcloud-ro /tmp/gcloud
export CLOUDSDK_CONFIG=/tmp/gcloud

# 1. land each file in its own staging table
bq --location=europe-west1 load --source_format=PARQUET --replace \
  --decimal_target_types=BIGNUMERIC \
  {DATASET}.order_items_stage /data/order_items.parquet
bq --location=europe-west1 load --source_format=PARQUET --replace \
  --decimal_target_types=BIGNUMERIC \
  {DATASET}.product_stage /data/product.parquet

# 2. create bronze on the first run, then merge the staged rows on each table's key,
#    so running the load twice leaves the same rows as running it once
bq --location=europe-west1 query --use_legacy_sql=false --format=none \
"CREATE TABLE IF NOT EXISTS {DATASET}.order_items_raw AS SELECT * FROM {DATASET}.order_items_stage LIMIT 0;
 CREATE TABLE IF NOT EXISTS {DATASET}.product_raw AS SELECT * FROM {DATASET}.product_stage LIMIT 0;
 MERGE {DATASET}.product_raw t
 USING {DATASET}.product_stage s
 ON t.p_id = s.p_id
 WHEN MATCHED THEN UPDATE SET
   p_name = s.p_name, p_desc = s.p_desc, price = s.price,
   qty = s.qty, category_id = s.category_id
 WHEN NOT MATCHED THEN INSERT ROW;
 MERGE {DATASET}.order_items_raw t
 USING {DATASET}.order_items_stage s
 ON t.order_id = s.order_id AND t.p_id = s.p_id
 WHEN MATCHED THEN UPDATE SET
   qty = s.qty, price_at_purchase = s.price_at_purchase
 WHEN NOT MATCHED THEN INSERT ROW;"

# 3. report bronze sizes in the task log
bq --location=europe-west1 query --use_legacy_sql=false --format=csv \
"SELECT 'order_items_raw' AS tbl, COUNT(*) AS n_rows FROM {DATASET}.order_items_raw
 UNION ALL SELECT 'product_raw', COUNT(*) FROM {DATASET}.product_raw"
"""

DROP_STAGING = f"""
set -e
cp -r /gcloud-ro /tmp/gcloud
export CLOUDSDK_CONFIG=/tmp/gcloud
bq --location=europe-west1 query --use_legacy_sql=false --format=none \
"DROP TABLE IF EXISTS {DATASET}.order_items_stage;
 DROP TABLE IF EXISTS {DATASET}.product_stage;"
"""

with DAG(
    dag_id="exercise_feliz",
    schedule="@daily",
    start_date=pendulum.datetime(2026, 9, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": pendulum.duration(seconds=20)},
    tags=["l07", "exercise"],
) as dag:

    extract_order_items = DockerOperator(
        task_id="extract_order_items",
        image="charlestng/albert-extractor:2026-09-25",
        network_mode="albert-marketplace_default",
        environment={"DATABASE_URL": DB_URL, "TABLE": "order_items"},
        mounts=[data_mount],
        auto_remove="success",
        mount_tmp_dir=False,
    )

    extract_product = DockerOperator(
        task_id="extract_product",
        image="charlestng/albert-extractor:2026-09-25",
        network_mode="albert-marketplace_default",
        environment={"DATABASE_URL": DB_URL, "TABLE": "product"},
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

    drop_staging = DockerOperator(
        task_id="drop_staging",
        image="google/cloud-sdk:slim",
        entrypoint="/bin/bash",
        command=["-c", DROP_STAGING],
        # Runs once load has finished, whatever its outcome: scratch tables
        # left behind by a failed run still cost money.
        trigger_rule="all_done",
        mounts=[gcloud_mount],
        auto_remove="success",
        mount_tmp_dir=False,
    )

    # A list on the left means no edge between the two extracts: they run together.
    [extract_order_items, extract_product] >> load >> drop_staging
