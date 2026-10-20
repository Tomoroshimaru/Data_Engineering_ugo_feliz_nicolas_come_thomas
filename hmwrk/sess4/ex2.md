# Session 4 — Exercise 2: which warehouse, and on what evidence

LUBERNE Féliz — a French luxury jewellery and watchmaking house; analytics on
Google Cloud (BigQuery, dbt, Looker), see L01-EX2. **List prices only**: what
the company actually pays is confidential and is not used here. Every figure
marked *est.* is my estimate, not a measurement.

## 1. The workload, in numbers

| What | Figure | Where it comes from |
|------|--------|---------------------|
| Queries a day | about 2,000 *est.* | Looker dashboards opened by key users (each opening fires one query per tile), plus the nightly dbt and Airflow runs. |
| Concentration in time | about 85% between 09:00 and 19:00 Paris time *est.* | Dashboards are read in the working day; the scheduled jobs run at night. Boutiques in other time zones spread the morning peak. |
| Data touched by a typical query | about 0.5 GB *est.* | Dashboards read aggregated child tables, partitioned by date, not the raw parent tables. |
| People querying at once, at the peak | 20 to 40 *est.* | The Monday-morning sales review, when most key users open the same dashboards. |

How to replace the estimates with measurements: one query on
`INFORMATION_SCHEMA.JOBS_BY_PROJECT` over the last 30 days gives all four
(count per day, count per hour, median `total_bytes_processed`, and overlapping
jobs per minute). It needs the `bigquery.jobs.listAll` permission, which I do
not have; see section 4.

## 2. The crossover arithmetic

**On demand.** 2,000 queries × 0.5 GB × 22 working days = 22,000 GB ≈ 20 TiB
scanned a month, plus the nightly jobs, call it **25 TiB** *est.*

(25 − 1) × $7.50 = **$180 a month**.

**Capacity.** BigQuery Editions, Standard edition, at the list price of
$0.04 per slot-hour (US list price; I could not find a clear figure for
europe-west1, which is usually slightly higher). Slots are bought in steps of
50.

| Capacity | Hours | Cost a month |
|----------|-------|--------------|
| 50 slots, working day only (10 h × 22 days) | 220 | 50 × $0.04 × 220 = **$440** |
| 100 slots, working day only | 220 | **$880** |
| 100 slots, always on | 730 | **$2,920** |

**Where the lines cross.** The smallest useful capacity, 50 slots for the
working day, costs as much as (440 / 7.50) + 1 ≈ **60 TiB a month** on demand.
The estimated workload scans 25. On demand is cheaper by more than half, and
it stays cheaper until the scanned volume more than doubles.

## 3. Which of the three, and why: BigQuery, on demand

- **The meter fits the workload.** About 25 TiB a month is well below the 60 TiB crossover. A rented warehouse would be paid for every working hour, including the long afternoons when dashboards are idle.
- **The peak is short.** On demand, the Monday-morning peak uses the shared slot pool at no extra cost; capacity would have to be sized for that peak and paid for all week.
- **Snowflake and Databricks SQL** both bill time (a warehouse or SQL endpoint running per second, with a one-minute minimum). They would win if the workload were dense and continuous, which it is not; and moving would also mean leaving the GCP platform the group is migrating towards.

**A feature worth less on this meter than the vendor implies: scheduled
pre-aggregation** (Looker persistent derived tables, or dbt models rebuilt
every hour). On a time-billed warehouse that is already running for the day, an
hourly rebuild uses idle capacity and costs almost nothing. On BigQuery on
demand, every rebuild scans its source again: rebuilt 24 times a day, an
aggregate read by a dashboard opened three times a day can cost more bytes than
the queries it replaces. On our meter it should be rebuilt when its source
changes, not on the clock.

**What I am giving up: a ceiling on the bill.** On demand has no monthly cap:
one dashboard tile without a date filter on a raw table, refreshed in a loop,
is paid per byte. A capacity commitment makes the bill flat. The mitigation is
a maximum-bytes-billed limit per query and a daily quota per user, which the
platform does not have today.

## 4. One thing I could not find out

**The real bytes scanned per month.** It decides everything above: if the true
figure is 70 TiB instead of 25, capacity wins. I cannot read it because
`JOBS_BY_PROJECT` needs a permission I do not have. I would ask the platform
administrator to run one query on the last 30 days of job history and give me
four aggregates: queries per day, per hour, median bytes per query, and total
TiB per month. That is a five-minute request, and it reveals no data, only the
shape of the workload. It also matters for the future: as entities move from
Azure to GCP, the volume grows, so the measurement should be repeated each
quarter to see when the line is crossed.
