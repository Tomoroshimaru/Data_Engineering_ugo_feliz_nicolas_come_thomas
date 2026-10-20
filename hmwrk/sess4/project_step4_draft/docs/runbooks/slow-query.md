# Runbook: a query that used to be fast is now slow

**When to use this.** Someone reports "this query took two seconds and now
takes two minutes", on the warehouse dataset
`data-engineering-i2.toes_ugo_feliz_thomas_warehouse`.

**What you need.** The BigQuery console
(https://console.cloud.google.com/bigquery, project `data-engineering-i2`) and
the text of the slow query. You do not need to know how the warehouse was built.

Work through the steps in order: they go from the cheapest and most likely to
the rarest. Each one says what it rules in or out. **Stop at the first step that
explains the slowdown.**

---

## Step 0. Find the two jobs: the slow one and the fast "before" (2 minutes)

1. At the bottom of the BigQuery page, open **Job history**, then **Personal history** (or **Project history** if a teammate ran it).
2. Find the slow run. Click it: the **Job information** tab opens.
3. Find the earlier fast run of the same query the same way. If nobody can point to one, write down "no before" and go to step 2.

Keep both jobs open in two browser tabs: every step below compares them.

## Step 1. Was the "before" served from cache? (1 minute)

In the fast job's **Job information**, look at **Bytes processed** and
**Results cached**.

- **Bytes processed is 0 B, or Results cached is "Yes"**: the fast run never ran the query, it returned a stored result. **Nothing is wrong**: the query was never that fast. Re-run it with the cache off (*More → Query settings →* untick *Use cached results*) to get its real time. **Stop here** and tell the reporter.
- **Bytes processed is above 0**: the comparison is real. Go on.

*Rules out: a false alarm, the most common cause of "it got slower".*

## Step 2. Did bytes processed jump? (2 minutes)

Compare **Bytes processed** in the two jobs. With no "before", compare with the
figures in [warehouse-tuning.md](../warehouse-tuning.md) (for example, query B
should process about 13 MB).

- **Bytes jumped (more than about 2x)**: the query is reading partitions it used to skip. Open the slow query's text and look at the `WHERE` clause on `order_date`:
  - **the date filter is gone** (someone removed it, or moved it into a subquery that is not on the partitioned table);
  - **the column is wrapped in something BigQuery cannot invert**, for example `FORMAT_DATE('%Y-%m', order_date) = '2026-09'` or `CAST(order_date AS STRING) LIKE '2026-09%'`. Rewrite it as a range on the bare column: `order_date BETWEEN DATE '2026-09-01' AND DATE '2026-09-30'`;
  - **the filter is on one table of a join but not the other**: in our queries the date filter must be repeated on `order_items_p` **and** `orders_p`.

  Paste the fixed query in the editor **without running it**: the estimate at the top right ("This query will process N") must fall back to the old figure. **Stop here.**
- **Bytes are about the same**: the query reads the same data and something else changed. Go on.

*Rules in or out: the lost partition filter.*

## Step 3. Did the table outgrow its partition grain? (3 minutes)

Run this (it reads metadata only, a few KB):

```sql
SELECT table_name,
       COUNT(*) AS partitions,
       ROUND(AVG(total_rows)) AS avg_rows_per_partition,
       MAX(last_modified_time) AS last_change
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name IN ('orders_p', 'order_items_p')
GROUP BY table_name;
```

Reference values at build time: 37 partitions; about 6,000 rows on average
for `orders_p` and 11,000 for `order_items_p`.

- **Average rows per partition moved a lot** (several times larger: each month now holds far more data), the monthly grain no longer suits the table. Do not change it at 23:00: write down the figures and **escalate** (step 7).
- **Partitions number in the thousands**: someone rebuilt the table with a daily grain. Check with the person who last changed it (`last_change`).
- **Close to the reference values**: the layout is fine. Go on.

*Rules in or out: the table grew past what the grain suits.*

## Step 4. Does one stage dominate? (3 minutes)

In the slow job, click the **Execution details** tab. It lists the stages
(`S00: Input`, `S01: Join+`, `S02: Aggregate`, ...) with a bar for each, split into
wait, read, compute and write time.

- **One stage's bar is far longer than its neighbours'**: that stage is the problem. Note its name and what it does (join, aggregate, sort). Go to step 5 for that stage.
- **Every stage is longer, in the same proportions**: the query did the same work, only slower; most often the shared slot pool was busy. Look at the **wait** part of the bars: if it dominates, re-run in 15 minutes. If it is fast again, **stop** and note the time it was slow.
- **No stage stands out and wait is small**: go to step 6.

*Rules in or out: one dominant stage; contention for slots.*

## Step 5. Inside that stage, is one worker far slower than the rest? (2 minutes)

Still in **Execution details**, click the dominant stage to expand it. Compare
the **average** and **maximum** time of its workers, for compute and for read.

- **Maximum far above average** (ten times or more): **skew**. One worker got far more rows than the others, nearly always because many rows share one join or group key. In our tables, look for a key value that suddenly became very frequent: a `NULL` `buyer_id`, a placeholder `p_id`, or one country receiving most rows. Find it with a `GROUP BY` on that key, `ORDER BY COUNT(*) DESC LIMIT 5`. **Escalate** with the value you found: the fix is in the data or in the model, not in the query.
- **Maximum close to average**: the stage is uniformly heavy. Go to step 6.

*Rules in or out: skew.*

## Step 6. Did the data change shape? (3 minutes)

In **Execution details**, each stage shows **Records read** and **Records
written**. Compare them with the same stage in the fast job.

- **Records read jumped** while bytes processed did not (step 2): more rows of the same width arrived, usually a reload that appended instead of replacing. Check `SELECT COUNT(*), COUNT(DISTINCT order_id) FROM` the table: if they differ for `orders`, rows were loaded twice.
- **A join stage writes far more records than it reads**: a join became one-to-many. In our model this happens if a customer gets more than one address marked `is_default = 1` in `customer_shipping`, which multiplies every order of that customer.
- **Records are the same as before**: the data did not change. Go to step 7.

*Rules in or out: the data changed shape.*

## Step 7. Stop and escalate

Escalate, rather than continuing, when:

- you reached this step without an explanation;
- step 3, 5 or 6 found a problem whose fix is a rebuild of a table or a change to the data;
- the query now fails with `Query exceeded limit for bytes billed`: the 50 MiB cap is doing its job. Do **not** raise the cap to get it through: go back to step 2.

**How to escalate.** Post in the group channel, addressed to whoever is on call
this week:

- the job IDs of the slow and the fast runs;
- the bytes processed of each;
- the last step you completed and what it showed.

Three lines with two job IDs save the next person the first 15 minutes.
