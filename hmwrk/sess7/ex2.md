# Session 7 — Exercise 2: the back-fill that produced fourteen identical days

LUBERNE Féliz — written as a group. We assume the database is Postgres (the SQL
uses `::date`) and that the scheduler runs in UTC.

## 1. What is in `daily_sales` after the back-fill

The line that decides everything is `today = date.today()`. It reads the clock
of the machine the task runs on, at the moment it runs. The back-fill ran on
20 March, so all fourteen runs computed `today = 2026-03-20`, whatever day they
were supposed to cover.

So the fourteen runs inserted fourteen rows, each with `sales_date =
2026-03-20`, each holding 20 March's orders *from midnight up to the moment
that run executed*. The rows are close but not identical, since orders kept
arriving between the first run and the last. The table gained **no new
`sales_date` at all**: 20 March already had a row, written by that night's
02:00 run. 1 to 14 March are still missing, and any `SUM(revenue)` for 20 March
now counts that day about fifteen times.

There is a worse finding underneath. The nightly run fires at 02:00 UTC, and at
that moment `date.today()` is the day that has just started. Every night for
months, the job has been writing **the first two hours** of the current day
and calling it the day's total. Nobody complained because the numbers looked
like numbers.

## 2. Why nothing failed

Every run did exactly what its code says: it connected, ran valid SQL, inserted
rows and exited 0. Retries and alerts in Airflow react to an exception or a
non-zero exit code, and there was none. No test checks what the rows contain:
nothing compares `sales_date` with the run's date, or the day's revenue with
the orders table.

This is a silent data failure: a run that succeeds and writes the wrong thing.
Its cause is a task that depends on the wall clock instead of on the run it
belongs to, so replaying a past run cannot reproduce the past.

## 3. The fix

**The job.** The date comes from the environment, so the run decides it, and the
filter is a range on the column, not a cast of it:

```python
import os
sales_date = os.environ["SALES_DATE"]          # was: from datetime import date

sql = f"""
INSERT INTO daily_sales
SELECT %(d)s::date AS sales_date, count(*) AS orders, sum(amount) AS revenue
FROM orders
WHERE created_at >= %(d)s::date AND created_at < %(d)s::date + 1
ON CONFLICT (sales_date) DO UPDATE                -- see question 4
  SET orders = EXCLUDED.orders, revenue = EXCLUDED.revenue
"""
run(sql, {"d": sales_date})                        # was: today = date.today()
```

The four lines replaced: `from datetime import date`, `today = date.today()`,
the `WHERE created_at::date = '{today}'` filter, and the plain `INSERT`. The
date is passed as a query parameter rather than pasted into the string.

**The task.**

```python
build = BashOperator(
    task_id="build_daily_sales",
    bash_command="python /jobs/build_sales.py",
    env={"SALES_DATE": "{{ macros.ds_add(data_interval_start | ds, -1) }}"},
    append_env=True,
)
```

We use `data_interval_start` because it is fixed when the run is created and
stays the same on every retry and every back-fill, unlike the clock. We take the
day before it because in Airflow 3 a cron schedule gives a zero-length interval
at the trigger time (we saw `data_interval start = end` in our own runs): the
run of 20 March at 02:00 has `data_interval_start = 2026-03-20`, and the day it
can close completely is 19 March.

One consequence for the engineer: with this rule, the runs that rebuild 1 to 14
March are those of 2 to 15 March, so the back-fill is
`--from-date 2026-03-02 --to-date 2026-03-15`.

## 4. Is the fixed job safe to back-fill twice?

Yes, because of two things we wrote, not because it "should be fine".

First, `sales_date` is the primary key of `daily_sales`
(`ALTER TABLE daily_sales ADD PRIMARY KEY (sales_date)`, after deleting the
fifteen rows of 20 March). Postgres enforces it.

Second, the write is `INSERT … ON CONFLICT (sales_date) DO UPDATE`. On the
second back-fill each run computes the same day again, hits the existing row
for that `sales_date`, and overwrites its `orders` and `revenue` with the values
it has just computed. The table ends with exactly fourteen rows, one per day,
as after the first back-fill. If late orders arrived in between, the second run
writes the corrected totals instead of adding a second copy.

Had the job kept a plain `INSERT`, the second back-fill would have doubled every
day of the first two weeks of March, again with every run green. The primary
key alone would have helped too: it would have turned the original bug into a
loud failure on the second of the fourteen runs.

## 5. The team moves to Paris

**29 March 2026.** Clocks jump from 02:00 to 03:00, so 02:00 Paris time does not
exist. The schedule names a local time that has no instant. In our
understanding, the cron library Airflow uses moves it to the next valid time,
03:00 (01:00 UTC), so the run happens once, an hour late on the wall clock; a
scheduler that skipped it instead would leave a hole for an analyst to find
later. Either way, our job is not hurt, because it takes its date from the
run, not from the clock. We did not test this on a cluster.

**25 October 2026.** Clocks go back from 03:00 to 02:00, so 02:00 happens twice,
at 00:00 and at 01:00 UTC. If the scheduler fires on both, the same day is
built twice. What decides whether it matters is idempotency, question 4: with
the upsert on `sales_date`, the second run rewrites the same row with the same
numbers. With the original `INSERT`, that day would be counted twice.

**Schedule in UTC, present in local time.** We would leave the schedule in UTC,
`0 1 * * *` (01:00 UTC is 02:00 or 03:00 in Paris, after the Paris day has
closed all year round), and move the time zone into the data instead. The job
cuts days on the Paris calendar:
`(created_at AT TIME ZONE 'Europe/Paris')::date = %(d)s`. The analysts would see
figures grouped by Paris trading day: an order at 00:30 in Paris on 1 April
counts on 1 April, where today it lands on 31 March, since it is 22:30 UTC. They should also
know that 29 March has 23 hours and 25 October has 25, so those two days are
slightly smaller and larger by construction.
