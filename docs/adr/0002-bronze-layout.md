# ADR-0002: Land bronze as zstd Parquet, all strings, partitioned by ingest date

- **Status:** accepted
- **Date:** 2026-10-20
- **Author:** Féliz Luberne
- **Lesson:** L02

## Context

[ADR-0001](0001-target-architecture.md) puts raw data in a Cloud Storage bucket
and the modelled layers in BigQuery. Bronze's promise is that it holds what
arrived, unchanged, so that any later layer can be rebuilt from it. Lesson 3
will write into it from three directions: a batch export, a stream of events,
and the database's change log.

What we land today: the company export (release v1.0.0), 27 CSV tables, 197 MB.
Two of them hold credentials and card data (`customer.pwd`,
`payment_details.card_no` and `cvv`). Bronze is read by pipelines, not by
analysts: silver is where queries filter by business date.

The bucket is `gs://data-engineering-i2-toes-futcn`, in europe-west1.

**Our own measurements** (exercise 1 of lesson 2, and today's landing):

| Measurement | Result |
|---|---|
| `order_items` as CSV, then as snappy Parquet (typed) | 10,373,925 → 3,546,873 bytes: **2.9x smaller** |
| The 25 landed tables as CSV, then as snappy Parquet (all strings) | 183,556,531 → 93,493,101 bytes: 2.0x |
| Same 25 tables, **zstd** instead of snappy | **54,063,123 bytes: 1.73x smaller than snappy**, write time 1.6 s against 1.4 s |
| Same 25 tables, gzip | 60,477,615 bytes, write time 16.6 s (12x slower) |
| `order_items` partitioned by `order_date`, **daily** | 1,096 partitions, 1,964 files, 26,418,537 bytes: **7.4x the single file** |
| One month of `order_items`, by day then by day **and** product | 31 objects, 371,338 bytes, then 8,649 objects, 32,463,395 bytes (87x); query 391 ms then 1,110 ms; upload 55 s; same 17,056 bytes processed |
| Typed load of `shipping_details` in lesson 4 | `phone` inferred as `INTEGER`: the leading zero of every phone number was lost |

## Options considered

| Option | For | Against |
|---|---|---|
| **Partition by ingest date** (`ingest_date=`, the day the extract landed) | Works the same for every table; each load is a new partition, so nothing already landed is ever rewritten; a bad load is replayed by deleting one prefix | No pruning by business date inside bronze |
| Partition by business date (`order_date=` per day or month) | Prunes queries by order date | Only `orders` has a date: `order_items` would need a join, which changes bronze. A late or corrected order rewrites an old partition. Daily grain measured at 7.4x the size and 1,964 files |
| No partitioning | Simplest | Every new load overwrites the last one: the history of what arrived is lost |
| **CSV** instead of Parquet | Exactly what the export wrote | 3.4x larger than zstd Parquet here, no schema, slow to scan |
| Typed Parquet (types inferred on landing) | Smaller, ready to query | Inference is a change: phone numbers lost their leading zero in lesson 4. Types belong in silver |

## Criteria

- **Fidelity:** bronze must hold what arrived, unchanged. All-string Parquet round-trips to the CSV with 0 differences on all 25 tables; typed Parquet did not.
- **Cost:** zstd stores the same data in 58% of snappy's bytes for the same write time.
- **Uniformity:** the three lesson 3 pipelines can all write by arrival date; only one table has a business date.
- **Object count:** one file per table per load. Our over-partitioning measurement showed object count, not bytes, is what makes small files slow and costly.

## Decision

Bronze is **Parquet, zstd-compressed, every column a string**, at
`bronze/<table>/ingest_date=YYYY-MM-DD/part-N.parquet`, one file per table per
load. The two tables holding credentials and card data (`customer`,
`payment_details`) are **not landed**: per ADR-0001, secrets never leave the
source. Event streams follow the same rule with the event's date
(`dt=YYYY-MM-DD`), as the lesson 3 consumer writes them.

## Consequences

- **Cheap:** appending a new load; replaying or deleting one bad load; rebuilding silver from any past load; reading bronze from BigQuery (checked: an external table over the zstd files returns all 222,644 orders with `ingest_date` as a column).
- **Awkward:** a question by order date cannot prune bronze, so it reads every row of a load. That is silver's job, partitioned by month (measured in lesson 4: 2.3x to 2.8x fewer bytes). Every column needs a cast in silver.
- **Watch:** full daily exports copy whole tables each day, so storage grows by one export per load (51.6 MiB today). Lesson 3's incremental and change-log ingestion should land changes, not copies.
- **What would force a rewrite:** loads frequent enough to make many tiny files per table (we measured the cost of 8,649 small objects), or a need to reprocess bronze by business date across many loads.
