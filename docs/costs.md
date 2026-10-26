# Costs

The monthly cost of what the platform holds, from published list prices. This
file grows every lesson; by lesson 9 it is the input to the FinOps work.

## Prices used

Read on **2026-10-20** from https://cloud.google.com/storage/pricing, for a
regional bucket (europe-west1), in USD.

| Item | Price | Source |
|---|---|---|
| Standard storage | $0.020 per GiB per month | Course material for europe-west1. The pricing page shows regional storage prices only in a region selector; **to confirm by selecting "Belgium (europe-west1)"** |
| Nearline, Coldline, Archive storage | $0.010, $0.004, $0.0012 per GiB per month | **Not read today**; to confirm on the same selector |
| Class A operations (writes, lists), Standard | $0.005 per 1,000 | Pricing page, 2026-10-20 |
| Class B operations (reads), Standard | $0.0004 per 1,000 | Pricing page, 2026-10-20 |
| Retrieval, Nearline / Coldline / Archive | $0.01 / $0.02 / $0.05 per GiB read | Pricing page, 2026-10-20 |
| Minimum storage duration, Nearline / Coldline / Archive | 30 / 90 / 365 days | Pricing page, 2026-10-20 |

## L02: the bronze bucket

| What | Quantity | Cost |
|---|---|---|
| Storage | 54,063,123 bytes = 0.0504 GiB, Standard | 0.0504 × $0.020 = **$0.0010 a month** |
| Writes for one load | 25 objects = 25 Class A operations | 25 / 1,000 × $0.005 = **$0.000125 per load** |
| Reads | Pipelines read bronze when silver is rebuilt: 25 Class B operations per full rebuild | $0.00001 per rebuild |

**Total today: about $0.001 a month**, plus a fraction of a cent per load. The
first landing was done twice (once in snappy, once in zstd), so 50 writes were
billed, about $0.00025.

The lifecycle policy ([infra/lifecycle.json](../infra/lifecycle.json)) moves
bronze to Nearline after 30 days. At this size that saves nothing measurable,
and every rebuild of silver from data older than 30 days pays the Nearline
retrieval fee ($0.01 per GiB read).

## If the data were a hundred times larger

| What | Today | ×100 |
|---|---|---|
| One load | 51.6 MiB | 5.0 GiB |
| Storage of one load | $0.001 a month | $0.10 a month |
| A full export every day for a month | 1.5 GiB, $0.03 a month | 151 GiB, **$3.02 a month**, growing every month |
| Writes per load | 25 | 25: one file per table per load, whatever its size |

At a hundred times the size, **storage of repeated full copies** becomes the
cost, while operations stay flat because the layout writes one file per table
per load. That is the argument for lesson 3 landing changes instead of full
copies, and for the lifecycle policy, which moves the older copies to cheaper
classes.

## L09: the ledger

Every resource we have. BigQuery sizes from each dataset's `__TABLES__`,
bucket sizes from `gcloud storage du`. BigQuery active storage is priced at
about $0.02 per GiB per month (US list price, **to confirm for europe-west1**);
the first 10 GiB a month are free, so today the real bill is zero.

| Resource | Created in | Size | Labels | Monthly, at list price | Measured on |
|---|---|---|---|---|---|
| Bucket `data-engineering-i2-feliz` | L02 | 161.5 MiB, 10,664 objects | yes (Terraform) | $0.0032 | 2026-10-23 |
| Bucket `data-engineering-i2-feliz-tfstate` | L08 | 21 KiB, 10 objects | **none** | ≈ $0 | 2026-10-23 |
| Bucket `data-engineering-i2-toes-futcn` (group) | L02 | 51.6 MiB, 25 objects | **none** | $0.0010 | 2026-10-26 |
| Dataset `l04_fl` | L04 | 116.8 MiB, 8 tables | yes (Terraform) | $0.0023 | 2026-10-26 |
| Dataset `l05_fl` | L05 | 74.1 MiB, 10 tables | **none** | $0.0014 | 2026-10-26 |
| Dataset `l07_ex_fl` | L07 | 38.7 MiB, 2 tables | **none** | $0.0008 | 2026-10-26 |
| Dataset `l07_fl` | L07 | 4.2 MiB, 6 tables | **none** | $0.0001 | 2026-10-26 |
| Dataset `l09_fl` | L09 | 0.2 MiB, 1 table | **none** | ≈ $0 | 2026-10-26 |
| Dataset `l10_fl` | L10 | 15.7 MiB, 1 table | **none** | $0.0003 | 2026-10-26 |
| Dataset `feliz` | L02 | external tables only | **none** | $0 | 2026-10-23 |
| Dataset `toes_ugo_feliz_thomas_warehouse` (group) | L04 | 202.0 MiB stored (12 tables, 2 materialized views), plus 8 external tables | **none** | $0.0039 | 2026-10-26 |
| **Total** | | 0.21 GiB in Cloud Storage, 0.44 GiB in BigQuery | | **≈ $0.013 a month** | |

Only the two resources Terraform manages carry labels; everything created by
hand would land in the unattributed share of a real bill. The group warehouse's
external tables read the CSVs in `gs://data-engineering-i2-feliz/fallback/`, a
personal bucket, so the group warehouse cannot be rebuilt without it.
