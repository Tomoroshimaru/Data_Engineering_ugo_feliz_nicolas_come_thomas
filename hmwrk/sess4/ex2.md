# Session 4 — Exercise 2: which warehouse, and on what evidence

LUBERNE Féliz — written as a group, from the analytics team at Cartier. Our warehouse is BigQuery; dbt builds the models, Python scripts and Airflow load the data, Terraform holds the setup, and Looker, Tableau and Power BI read it. We use **list prices only**: what Cartier actually pays is confidential.

## 1. The workload

**These are our own estimates, not Cartier's official figures.** We do not have access to the monitoring that records them (section 4 explains why and how we would get it). We built each one with a simple calculation from what we see every day, so that it can be checked and corrected.

| What | Our estimate | How we got it |
|---|---|---|
| Queries a day | about 2,000 | Around 30 key users each open about 5 dashboards a day, and a dashboard sends one query per tile, about 10 tiles: 30 × 5 × 10 = 1,500. Our nightly dbt and Airflow runs and the Tableau extract refreshes add a few hundred more. |
| How concentrated | about 85% between 09:00 and 19:00, Paris time | The 1,500 dashboard queries happen during the working day; the nightly jobs do not. 1,500 out of 2,000 is 75%, and boutiques in other time zones push some morning queries in, so we round to 85%. |
| Data a typical query touches | about 0.5 GB | Dashboards read our aggregated child tables, partitioned by month. A tile usually asks for one month of one table, which is a few hundred MB. |
| People querying at once, at the peak | 20 to 40 | The Monday-morning sales review, when most of the 30 key users open the same dashboards within the same half hour. |

## 2. The crossover

On demand, 2,000 queries × 0.5 GB × 22 working days is about 22,000 GB, or 20 TiB a month. With the nightly jobs, call it **25 TiB** *est.* The first TiB is free, so the bill is (25 − 1) × $7.50 = **$180 a month**.

For capacity we took BigQuery's Standard edition at $0.04 per slot-hour. That is the US list price; we could not find a clear figure for europe-west1, which is usually a little higher. Slots come in blocks of 50.

| Capacity | Hours a month | Cost a month |
|---|---|---|
| 50 slots, working day only (10 h × 22 days) | 220 | $440 |
| 100 slots, working day only | 220 | $880 |
| 100 slots, always on | 730 | $2,920 |

The cheapest useful option, 50 slots during the working day, costs the same as (440 / 7.50) + 1, about **60 TiB a month** on demand. We estimate 25. On demand is less than half the price, and it stays cheaper until our volume more than doubles.

## 3. Our choice: BigQuery, on demand

On demand fits how we work. At 25 TiB we are far below the 60 TiB where capacity would start to pay, and a reservation would also be paid for the long afternoons when nobody opens a dashboard. The Monday peak is short: on demand it runs on Google's shared slots at no extra cost, whereas a reservation would have to be sized for that peak and paid for all week. Snowflake and Databricks SQL bill for the time a warehouse runs. They would win on a dense, continuous workload, which ours is not, and moving would take us off the GCP platform the group is migrating to.

**A feature that is worth less on our meter: BI extracts.** Tableau extracts and Power BI import mode are sold as the way to make dashboards fast and cheap. On BigQuery on demand, each refresh is a full query, billed for every byte it reads. A Tableau extract refreshed every hour on a raw sales table can read more data in a day than the dashboard's live queries ever would, since those filter on a date partition. On a warehouse billed by the hour, the same refresh would run in capacity we have already paid for. So on our meter we refresh extracts when the data changes, from aggregated tables, not on a timer.

**What we give up: a ceiling on the bill.** On demand has no monthly cap. One dashboard tile with no date filter on a raw table, refreshing in a loop, is paid byte by byte, while a reservation would keep the bill flat. We would cap it with a maximum bytes billed per query and a daily quota per user, set in Terraform. Neither exists today.

## 4. What we could not find out

We do not know how many bytes we really scan in a month, and the whole decision rests on it: at 70 TiB instead of 25, capacity wins. Our accounts cannot read `JOBS_BY_PROJECT`, which needs `bigquery.jobs.listAll`. We would ask the platform administrator to run one query on the last 30 days and send back four numbers: queries per day, queries per hour, median bytes per query, and total TiB per month. It takes five minutes and shows the shape of the workload without any data in it. We would run it again every quarter, because each entity that moves from Azure to GCP adds volume and pushes us closer to the line.
