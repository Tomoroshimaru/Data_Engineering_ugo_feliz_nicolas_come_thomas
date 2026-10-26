# Session 10 — Exercise 1: harden it, then erase somebody

LUBERNE Féliz — written as a group. Project `data-engineering-i2`, warehouse dataset `l04_fl`, dbt project in `scriptes/l05/`. Done on 26 October 2026.

## 1. An over-broad grant

We cannot read the project's IAM policy:

```text
ERROR: (gcloud.projects.get-iam-policy) [fluberne@albertschool.com] does not have
permission to access projects instance [data-engineering-i2:getIamPolicy] (or it
may not exist): The caller does not have permission.
```

The over-broad grant is still visible from what it does: our account holds `datacatalog.categories.fineGrainedGet` at project level, most likely through `roles/datacatalog.categoryFineGrainedReader` granted to the whole class. It probably exists so that every student can read the demo tables without being blocked. Its effect is that no policy tag in the project protects anything for anyone (step 3). We would remove it from the project and bind the role on individual policy tags, to a named group that needs the data.

## 2. Tags

Taxonomy `marketplace-pii-fl`, fine-grained access control activated.

- `pii-contact`: data that lets someone reach a person directly, such as a street address or a phone number. Tagged on `street_address` and `phone`.
- `pii-quasi-identifier`: data that is harmless alone but identifies a person in combination, such as zip and city. Tagged on `zip` and `city`.

## 3. Enforcement, and what it would break

There is no error text to copy: the query from the lecture still returned addresses and phone numbers in clear after tagging, because of the grant in step 1. The tags are on the schema (`bq show` lists all four), but they are not enforced for our account. `SELECT * EXCEPT (street_address, phone, zip, city)` returns the four untagged columns: `int64_field_0`, `address_id`, `state`, `country`.

On a Monday morning it would break the group's warehouse load, `warehouse/01_load.sql`, line 33: `CREATE OR REPLACE TABLE shipping_details AS SELECT * FROM ext_shipping_details`. For any account without the reader role the `SELECT *` fails. For an account with it, the load succeeds and silently recreates the table without its tags. We would name the columns there before tagging anything in production.

## 4. Who read it

The Data Access log returned an empty list, with no error, both for reads of `l04_fl` and for `status.code!=0`. BigQuery writes these logs by default, so the entries exist; they are filtered from accounts without `logging.privateLogEntries.list`. An empty answer is not evidence that nobody read the data.

Our own job history, `INFORMATION_SCHEMA.JOBS_BY_USER` (kept 180 days), still answers part of it. The earliest read of `shipping_details` is **2026-10-20 08:56:30 UTC, by fluberne@albertschool.com**, during lesson 4: 6 jobs since. Nobody asked for that history to be kept. It shows our account only, not our teammates'.

Our refusals, from the same history: no refusal from the tags, since step 3 was not refused. The one real access refusal is on 23 October at 07:17 (`accessDenied` on `region-europe-west1.INFORMATION_SCHEMA.TABLES`, missing `bigquery.tables.list`). On 23 October at 08:29, BigQuery also refused to drop the last row access policy of the demo table (`invalid`): it requires `DROP ALL` because that drop opens the table to everyone.

## 5. Erasing buyer `AE224QB4K4PDIZ6FVU6MGVFEYSPQ`

### Where the identifier appears

Traced before deleting anything.

BigQuery, our datasets:

| Table | Rows | How it is linked |
|---|---|---|
| `l04_fl.orders` | 4 | `buyer_id` (2 orders and their duplicated twins) |
| `l04_fl.review` | 2 | `buyer_id` |
| `l04_fl.customer_shipping` | 1 | the same identifier, renamed `c_id` |
| `l04_fl.shipping_details` | 1 | through `address_id`: the street address and phone |
| `l04_fl.order_items`, `order_items_raw` | 4 each | through `order_id` |
| `l04_fl.product_reviews` | 2 | through `review_id` |
| `l05_fl.stg_orders`, `stg_review` (silver) | 4, 2 | `buyer_id` |
| `l05_fl.fct_order_items` (gold) | 4 | through `order_id` |
| `l10_fl.shipping_details` | 1 | the demo's copy, through `address_id` |
| `l07_fl.orders_raw` | 3 | the Airflow pipeline's raw table |
| Group warehouse, `orders` and `review` | 4, 2 | `buyer_id` |

Bronze:

- `gs://data-engineering-i2-feliz/fallback/`: `orders.csv`, `review.csv`, `customer_shipping.csv`, `shipping_details.csv`.
- The group's export, in `bronze/<table>/ingest_date=2026-10-20/part-0.parquet` on disk and in the group bucket: `buyer`, `customer_payment` (their saved payment method), `customer_shipping`, `orders`, `review`.

Anywhere else:

- The source CSVs on our laptops (`legacy_csv/`): `buyer`, `customer`, `customer_payment`, `customer_shipping`, `orders`, `review`. Five members, five copies.
- Our query history: the tracing queries contain the identifier in clear, so it is now in `JOBS_BY_USER` for 180 days and in the audit logs.

### What we erased, and the command

In the tables dbt reads, in one transaction (`scriptes/l10/erase_buyer.sql`): the address and phone (1 row), the customer-address link (1), the reviews (2) and their product links (2) are deleted. The 4 orders stay for the accounts, with `buyer_id` replaced by `'ERASED'`, so revenue in the marts does not change.

```bash
bq query --use_legacy_sql=false < erase_buyer.sql
docker run --rm -v "$PWD:/usr/app" -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" charlestng/dbt-bigquery:1.12.1 build
```

The job statistics show 1, 1, 2, 2 rows deleted and 4 updated. A second run changed 0 rows, so the script is safe to rerun. `dbt build` gave PASS=45 ERROR=1; the error is the deliberately unedited generated test from lesson 5 (`unique_fct_daily_demand_gen_p_id`), unrelated to the erasure. Afterwards, silver (`stg_orders`, `stg_review`) holds 0 rows for the buyer; gold (`fct_order_items`) still holds the 4 order lines, now linked to no one.

### What stops us in bronze

Bronze is written once and never edited, so erasing means rewriting it:

- read the 4 CSVs in `fallback/` (about 67 MB) and the 5 group parquet files;
- drop the buyer's rows;
- write new files and replace the objects.

The compute is seconds and the cost a fraction of a cent. What stops us is the rest:

- No job does this. Someone has to write it, about an hour.
- The group warehouse's external tables read `fallback/` directly, so the rewrite changes their contents under them.
- Bronze would no longer be what the source sent. We would have to record that it was edited, and why.
- The next export from the source, which we do not control, brings the buyer back.

So the real fix is a list of erased identifiers applied at ingestion, not a one-off rewrite.

### What still holds the data after a successful delete

- **BigQuery time travel**: for 7 days (`maxTimeTravelHours: 168`), plus 7 days of fail-safe, the deleted rows can be read back.
- **Cloud Storage soft delete**: after any rewrite of bronze, the old objects stay recoverable for 7 days (`retentionDurationSeconds: 604800`). Versioning is not on.

Neither is a mistake. Both are durability features we chose, to recover from a bad delete; the erasure completes when they expire.

### What we report

We cannot complete this erasure today. Silver and gold are done, in the warehouse dbt reads. Still to do: bronze, the Airflow raw table, the group warehouse, the demo copy, the laptops and the logs. The runbook that would finish it:

1. Add the identifier to an erasure list read by every ingestion job.
2. Run the erasure script on each BigQuery dataset, then `dbt build`.
3. Rewrite the bronze files without the buyer's rows.
4. Delete the local copies.
5. Wait 7 days for time travel and soft delete to expire, then check again with the tracing query.

## 6. Classification policy

[docs/governance.md](../../docs/governance.md)
