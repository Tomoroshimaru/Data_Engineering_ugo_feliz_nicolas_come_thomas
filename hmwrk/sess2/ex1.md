# Session 3 — Exercise 1: stand up your own bronze bucket

LUBERNE Féliz — project `data-engineering-i2`, bucket `gs://data-engineering-i2-feliz` (europe-west1, Standard), pandas 2.2.3, pyarrow 25.0.1.

## Step 1 — a bucket, twice

The command line is the one I could repeat next month without remembering anything: the whole bucket definition (name, location, access mode) is one line that can be saved, reviewed and re-run, where the console is a sequence of screens to click through again.

## Step 2 — CSV against Parquet

| File | Size |
|------|------|
| `bronze/order_items.csv
` | 10,373,925 bytes (10.4 MB) |
| `bronze/order_items.parquet` (snappy) | 3,546,873 bytes (3.5 MB) |
| **Ratio** | **2.9 times smaller** |

## Step 3 — partitioned by day

The 408,560 order lines became 1,096 `dt=` partitions holding 1,964 Parquet files, 26,418,537 bytes in total. That is about 7 times the single Parquet file of step 2: same rows, but every small file pays for its own footer. The keys look like `bronze/by_day/dt=2026-08-01/part-0.parquet`; `dt=...` is not a folder but a naming convention the query engine reads as a column.

## Step 4 — why no delete action

Bronze promises that nothing which arrived is lost, so the policy only moves objects to cheaper classes (Nearline at 30 days, Coldline at 90, Archive at 365): it makes keeping the data affordable instead of making it optional.

## Step 5 — the refusal

Not completed: the service account could not be created, so the expected `storage.objects.create` refusal was never reached. The error I got instead, on `gcloud iam service-accounts create ml-reader-feliz`:

```text
ERROR: (gcloud.iam.service-accounts.create) [fluberne@albertschool.com] does not
have permission to access projects instance [data-engineering-i2] (or it may not
exist): Permission 'iam.serviceAccounts.create' denied on resource
'//cloudresourcemanager.googleapis.com/projects/data-engineering-i2'
reason: IAM_PERMISSION_DENIED
```

It is the same lesson one level up: my own user account is itself held to least privilege, and can manage storage in the project but not identities.

## Step 6 — querying the files where they lie

External table `feliz.order_items_by_day` over `bronze/by_day/*`, dataset in europe-west1. Units sold, 1 to 7 August 2026:

| dt | units |
|----|-------|
| 2026-08-01 | 1,031 |
| 2026-08-02 | 1,132 |
| 2026-08-03 | 1,114 |
| 2026-08-04 | 973 |
| 2026-08-05 | 1,115 |
| 2026-08-06 | 1,259 |
| 2026-08-07 | 968 |

484 ms, 17,056 bytes processed. Nothing was loaded: the files are the table.

## Step 7 — the four measurements

One month of order lines (August 2026, 9,893 rows), both layouts:

| | `dt=` only | `dt=` and `p_id=` | Ratio |
|---|---|---|---|
| Objects | 31 | 8,649 | 279x |
| Total bytes | 371,338 (0.37 MB) | 32,463,395 (32.5 MB) | 87x |
| Query, elapsed | 391 ms | 1,110 ms | 2.8x |
| Bytes processed | 17,056 | 17,056 | 1x |

Elapsed times are BigQuery's own job durations, from `INFORMATION_SCHEMA.JOBS_BY_USER` (`JOBS_BY_PROJECT` needs a permission I do not have), one run per query. The upload of the over-partitioned layout took 54.9 s for 31 MiB, and `gcloud storage du -s` on it had not finished after 30 minutes.

**The rule.** Another partition is worth adding when queries really filter on that column and each partition stays big enough to be a real file. It starts costing as soon as it crumbles the data: adding `p_id` gave me 8,649 files instead of 31 for the same 17,056 bytes processed, 87 times the storage and a query 2.8 times slower.

## Step 8 — what it costs

| | Quantity | Price | Cost |
|---|---|---|---|
| Storage of both copies | 32,834,733 bytes = 0.0306 GiB | $0.020 per GiB-month | $0.0006 per month |
| Step 7 writes (Class A) | 31 + 8,649 = 8,680 operations | $0.005 per 1,000 | $0.0434 |

The writes are the larger of the two, by about 70 times: one afternoon of writing the data cost roughly 70 months of storing it. With many small files the bill follows the operations meter, not the storage meter.
