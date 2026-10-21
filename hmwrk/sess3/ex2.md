# Session 3 — Exercise 2: an ingestion mode per source

LUBERNE Féliz — written as a group, from the analytics team at Cartier. Our
ingestion is a mix of streaming pipelines into BigQuery and Python scripts we
wrote and schedule with Airflow. Systems and flows only; no figure is given.

## 1. Four sources

**Boutique and e-shop sales.** Every sale, return and exchange, produced by
the retail systems that the retail IT teams run. Downstream it feeds the daily
sales dashboards in Looker and finance's monthly reconciliation.

**Web and app events.** Navigation and technical events, produced by the web
team's platform on AWS. We use them for traffic and conversion dashboards.

**Business CSV files.** Targets, mappings and one-off lists that business
teams send by hand, one subject at a time (HR, marketing, a launch). The
analytics engineer on that subject loads them with a Python script and owns the
table that comes out; the business contact vouches for the content. dbt joins
them to sales for that subject's reports.

**Legacy Azure tables.** The history kept on the analytics stack we are
migrating away from. It is frozen, and we use it for year-on-year comparisons
until the migration is done.

## 2. The mode for each

| Source | Mode | How fresh | Updates and deletes | Do we control it | What it can bear |
|---|---|---|---|---|---|
| Sales | Change data capture, landed every hour; a daily batch if returns turn out to be new transactions (section 4) | Next morning is enough: the dashboards are read once a day | Yes: returns and exchanges come days later. Whether they change the original sale is the open question of section 4 | Partly: we could read its log, not change its schema | It is the tills' database; CDC reads the log and puts no query on it |
| Web events | Daily batch of files | Daily for our dashboards; minute-level only matters to the web team | No: events are only appended | No: we take the export the web team gives us | Nothing to add; the export exists already |
| CSV files | Batch, on arrival; each version replaces the last | Whenever the file is sent | Yes, by replacement: a corrected file supersedes the old one | The table yes (its AE owns it), the content no (the business contact does) | It is a file |
| Legacy Azure | One full extract per table, checked, then switched off | Not at all: the data no longer changes | No | Yes, until we shut it down | One read, run at night |

## 3. Delivery guarantees, and which mistake is cheaper

For sales, CDC gives us at least once: after a crash the replication slot
replays from its last confirmed position. A lost sale is expensive and silent;
revenue comes out short and nobody notices until the monthly reconciliation. A
duplicate costs almost nothing, because every sale has a transaction ID and dbt
removes it. So we accept duplicates and protect against losses.

The web events also arrive at least once, file by file. A few missing events
change nothing on a dashboard that shows trends. Duplicates inflate traffic a
little, which is fine as long as the export carries an event ID. If it does
not, we have to check each file for repeats.

For the CSV files we aim for exactly once per version, and we get it by
overwriting instead of appending. A lost file means a report quietly uses last
month's targets. A file appended twice counts every target twice, which is the
worse mistake, so a rerun must never append.

The Azure extract has to be exactly once, and we only know it is once we have
compared row counts and totals table by table. A missing row is cheap to fix
while Azure is still running and impossible to fix after it is switched off. A
duplicate costs nothing, since we can reload.

## 4. Where the obvious answer is wrong: sales

Ask in a meeting and everyone will say streaming for sales. It is the
company's most important flow, it happens in real time, and it already
streams into BigQuery today.

The first thing that answer misses is freshness. Nobody reads sales in real
time: our only consumers are daily dashboards and a monthly reconciliation. A
stream costs us a pipeline that has to run and be watched all day, for numbers
that are looked at the next morning.

The second thing it misses is that a sale is not final when it happens. In
luxury retail a sale often changes afterwards: a return, an exchange for
another size or model, a client or boutique corrected on the ticket. A stream
of "sale happened" events records each sale as it was at checkout. What
happens next depends on something **we do not know yet**: whether the till
system records a return as a new transaction (a credit note, which the stream
would carry like any other sale) or by changing the original sale (which the
stream would never see).

If it changes the original, change data capture is the right mode: it sees
every update and every delete, in order, and puts no load on the tills, while
a stream would leave us with gross sales on one side, net sales in finance on
the other, and a gap reconciled by hand every month. If it creates a credit
note, a daily batch is enough, and the stream is still more than we need.
Either way, streaming is the one answer the freshness requirement does not
justify. Finding out which case we are in is a single question to the retail
IT team, and it is the first thing we would ask before building anything.
