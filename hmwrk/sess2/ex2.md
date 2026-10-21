# Session 2 — Exercise 2: a retention and access plan

LUBERNE Féliz — written as a group, from the analytics team at Cartier. Our
platform is on Google Cloud: data lands in BigQuery, dbt models it, and Looker,
Tableau and Power BI read it. We describe categories of data and cite only
public rules; no internal policy is quoted and no volume is given.

## 1. Three datasets

**Sales transactions.** Every sale from the boutiques' point of sale and from
the e-shop: product, price, boutique, date, and the client. It is the largest
dataset we hold. The current and previous year are read every day by the
dashboards; older years are read for audits and long comparisons.

**Web and app events.** Navigation and technical events sent by the web team's
platform on AWS. A lot of it, worth a lot for a few days and very little after
a month. Our dashboards read it daily; incidents are investigated by the web
team.

**Business CSV imports.** Spreadsheets sent by business teams (targets,
mappings, one-off lists) for a given subject: HR, marketing, a product launch.
The analytics engineer (AE) working on that subject loads the file with a
Python script, turns it into a table and owns that table in BigQuery; the
business contact who sent it vouches for its content. Small files, but many of
them. The subject's dashboards read them while the subject is active, then
almost nobody does.

## 2. How long each must be kept, and who says so

Sales must be kept **10 years** after the end of the financial year. That
comes from the French Commercial Code, article L123-22, which applies to
accounting documents and the records behind them. The client's identity is a
different matter: for marketing use, the CNIL's guidance is 3 years after the
client's last purchase (GDPR, article 5(1)(e), storage limitation). After that
we would keep the sale but pseudonymise the client in the analytics tables.

Web and app events: **12 months**, then deleted. Logs hold IP addresses, so
they are personal data, and the CNIL's recommendation on logging is between 6
months and a year.

CSV imports: **nobody has decided**. Each file has an owner, but no written rule
says how long it should live; files and tables are kept because nothing
deletes them. HR files may also fall under the retention periods of the Labour
Code, which would make them longer, not shorter. We would set 90 days for the
raw files once the subject's table is built, and section 5 explains why that is
hard to apply.

## 3. Storage class and lifecycle

Raw files sit in a Cloud Storage bucket and follow the calendar below; the
BigQuery tables built from them follow it through partition expiry. Each step
follows how often the data is read.

| Dataset | At creation | Then | Deleted |
|---|---|---|---|
| Sales | Standard: read every day | Nearline at 1 year (a few reads a year), Archive at 3 years (audits only) | At 10 years, unless under legal hold |
| Web and app events | Standard: read daily for a month | Nearline at 30 days | At 12 months |
| CSV imports | Standard: read while the subject is active | Nearline at 30 days | Raw file at 90 days (proposed); the table follows its subject |

We left Coldline and Archive out for the events on purpose. Their minimum
storage durations (90 and 365 days) mean an object moved there and deleted at
12 months would cost about as much as if it had stayed where it was.

## 4. Who reads what

Key users never touch BigQuery. They read sales through Looker, or Tableau and
Power BI for the teams still on them, and only on aggregated tables with the
client masked. The BI tools, dbt and our ingestion scripts each run as their
own service account with read access to the datasets they need, nothing wider,
and the bindings are written in Terraform. We, the data engineers, can read
bronze for maintenance, with client identity masked by default. Auditors get
time-limited read access to archived years when they ask.

The web events are written by an ingestion service account that can only
create objects, not read or delete them. The web on-call engineer gets read
access for the length of an incident.

For the CSV imports, access follows the subject. The business contact uploads
to that subject's folder and cannot see other subjects' files. The AE who owns
the subject reads the folder and writes the table, and the dashboards of that
subject read the table, nothing else. An HR file should never be readable by
the marketing AE.

So people reach data through a BI tool or a temporary grant; services reach it
directly.

## 5. What we cannot do

We cannot easily apply a retention rule to the CSV imports, because their
ownership is split in two and it follows subjects, not data. The AE on a
subject owns the table; the business contact vouches for what is in it. A
retention period is a decision about the content, so it belongs to the business
contact, who is not a data person and has no reason to think about it. And
subjects end: the AE moves to the next topic, or leaves at the end of an
apprenticeship, while the table stays in BigQuery with an owner who no longer
looks at it. Deleting it then means finding out who still reads it, which
nobody has time to do.

So these files and tables are kept for as long as nothing deletes them,
including whatever personal data they hold. The fix is not technical: when a
subject starts, the AE and the business contact should agree a retention
period and write it on the table as a label, so that an expiry can be set the
day the table is created.
