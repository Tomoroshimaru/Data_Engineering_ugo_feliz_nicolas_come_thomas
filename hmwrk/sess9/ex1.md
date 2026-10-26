# Session 9 — Exercise 1: label it, budget it, find it, fix it

LUBERNE Féliz — written as a group. Project `data-engineering-i2`, Terraform in
`scriptes/l08/terraform/`. Measured on 23 October 2026. Everything we run fits
in the free tier, so we measure units, not money.

## 1. Labels

```text
Plan: 0 to add, 2 to change, 0 to destroy.
```

Applied, then `No changes` on the next plan. Our convention, agreed before
typing:

| Key | Value | Why |
|---|---|---|
| `team` | `feliz` | who to ask about the line on the bill |
| `environment` | `dev` | an exercise resource must never be mistaken for production |
| `pipeline` | `bronze`, `warehouse` | which data flow the cost belongs to |
| `lesson` | `l02`, `l04` | what created it, so nobody has to guess in a month |

Both Terraform resources (the lesson 2 bucket and the dataset `l04_fl`) now
carry it. The label `owner=feliz` we had added by hand in lesson 8 survived:
Terraform only manages the labels written in the code.

## 2. The budget

We could not add a threshold: the billing console lists no billing account for
our accounts ("No items to display"), so the budget is invisible to us. From the
lab's Terraform (`budget_thresholds = [0.5, 0.9, 1.0]`), crossing 50 %, 90 % or
100 % of the group's budget sends an email to the budget's recipients.

It stops nothing, and we could exceed it by any amount. If we needed a real cap,
we would set `maximum_bytes_billed` on our scheduled queries, because it refuses
a query instead of reporting it, and accept that the pipeline breaks rather
than the bill.

## 3. Our biggest consumer, and its shape

`INFORMATION_SCHEMA.JOBS` covers the whole project and needs
`bigquery.jobs.listAll`, which we do not have, so we read
`INFORMATION_SCHEMA.JOBS_BY_USER` instead, zero-filled against a 30-day date
range with `GENERATE_DATE_ARRAY`.

| Day | Jobs | GiB processed |
|---|---|---|
| 24 Sep – 12 Oct | 0 | 0 |
| 13 Oct | 10 | 0.000 |
| 14 – 19 Oct | 0 | 0 |
| **20 Oct** | 200 | **1.490** |
| 21 Oct | 16 | 0.215 |
| **22 Oct** | **296** | 1.117 |
| 23 Oct | 12 | 0.001 |

**Shape: spikes.** Nothing for 25 days out of 30, then two sharp spikes: 20
October (the most data, lesson 4's tuning measurements) and 22 October (the most
jobs, lesson 7's Airflow demo and exercise). Our usage follows our sessions; no
pipeline runs on its own.

**Busiest day:** 20 October by data processed (1.49 GiB), 22 October by number
of jobs (296).

**Missing days:** without zero-filling, the query returns 5 rows out of 30.
Read one after the other, they look like five busy days in a row, when they
spread over ten days with a six-day gap between 13 and 20 October.

Over those days we processed about 2.8 GiB but were billed about 6 GiB: the
10 MiB minimum per table and per query dominates our bill, not the data we read.

We could not run the cost query for comparison: no billing export view is
visible to our accounts, for the same reason as the budget in step 2.

## 4. The before figure

We picked data nobody reads any more: three copies made in lesson 4 to measure
partitioning and clustering. Our job history shows `order_items_p` last read on
20 October at 07:16, `order_items_pc` at 07:11, and `orders_p` never read at all.

| What we measure | Storage held by `order_items_p`, `order_items_pc` and `orders_p` in `l04_fl` |
|---|---|
| Before | **47.45 MiB** (17.14 + 17.14 + 13.17), 29 % of the dataset's 164.28 MiB |
| Measured on | 23 October 2026, from `l04_fl.__TABLES__` |
| At the published price | about $0.02 per GiB-month of active BigQuery storage (US list price, not confirmed for europe-west1): 0.046 GiB, about $0.001 a month |

We deleted the three tables with `bq rm`. Right after, the same query read
**8 tables, 116.83 MiB**: exactly 164.28 − 47.45, and no other table changed.

## 5. How we will know it worked

We will look at the total `size_bytes` of `l04_fl`, from `__TABLES__`, the same
query as the before figure. It is trustworthy immediately, because it reads the
dataset's own metadata; the billing export, which we cannot read, would only
show the storage line a day or two later. We expected 116.83 MiB and got it,
with no other table changing size. We were wrong if, in the next 30 days, any
query fails with `Not found: Table l04_fl.order_items_p` (or `order_items_pc`,
`orders_p`): somebody still used them, and our job history only shows our own
queries, not a teammate's. In that case we restore the table within the
seven-day time-travel window.

## 6. Our ledger

What exists, measured on 23 October 2026. Prices: Cloud Storage Standard,
$0.020 per GiB-month (course figure for europe-west1); BigQuery active storage,
about $0.02 per GiB-month (US list price, to confirm).

| Resource | Size | Labels | Monthly, at list price |
|---|---|---|---|
| Bucket `data-engineering-i2-feliz` (L02) | 161.5 MiB, 10,664 objects | yes (Terraform) | $0.0032 |
| Bucket `data-engineering-i2-feliz-tfstate` (L08) | 21 KiB, 10 objects | **none** | ≈ $0 |
| Bucket `data-engineering-i2-toes-futcn` (group, project step 2) | 51.6 MiB, 25 objects | **none** | $0.0010 |
| Dataset `l04_fl` (L04) | 116.8 MiB, 8 tables | yes (Terraform) | $0.0023 |
| Dataset `l05_fl` (L05) | 74.1 MiB, 10 tables | **none** | $0.0014 |
| Dataset `l07_ex_fl` (L07) | 38.7 MiB, 2 tables | **none** | $0.0008 |
| Dataset `l07_fl` (L07) | 4.2 MiB, 6 tables | **none** | $0.0001 |
| Dataset `l09_fl` (L09) | 0.2 MiB, 1 table | **none** | ≈ $0 |
| Dataset `feliz` (L02) | external tables only | **none** | $0 |
| Dataset `toes_ugo_feliz_thomas_warehouse` (group, project step 4 draft) | 202.0 MiB, 22 tables | **none** | $0.0039 |
| **Total** | 0.21 GiB in Cloud Storage, 0.43 GiB in BigQuery | | **≈ $0.013 a month** |

Only the two resources Terraform manages are labelled: everything created by
hand still belongs to nobody on the bill. The state bucket also holds 10 objects
for one state file, because versioning keeps every old version and no rule
deletes them; small, but it grows with every apply.

The group's `docs/costs.md` belongs to the project and lives on the group
branch; this ledger covers our own resources.
