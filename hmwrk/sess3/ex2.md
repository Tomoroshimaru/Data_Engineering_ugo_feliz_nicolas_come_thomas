# Session 3 — Exercise 2: an ingestion mode per source

LUBERNE Féliz — a French luxury jewellery and watchmaking house. The analytics
platform runs on Google Cloud: BigQuery, modelled with dbt, read through Looker
(see L01-EX2 and L02-EX2). Systems and flows only; no figure, record or internal
document is quoted.

## 1. Four sources

| Source | What it is | Who produces it | What it is used for downstream |
|--------|-----------|-----------------|--------------------------------|
| **A. Boutique and e-shop sales** | Every sale, return and exchange, from the point-of-sale system and the e-shop. | The retail systems, run by the retail IT teams. | Daily sales dashboards for key users, and monthly reconciliation with finance. |
| **B. Web and app events** | Navigation and technical events from the e-shop and apps. | The web development team, on AWS. | Traffic and conversion dashboards; incident analysis stays with the web team. |
| **C. Business CSV files** | Spreadsheets sent by business teams (targets, mappings, one-off lists). | Business teams, by hand. | Joined to sales in dbt for specific reports. |
| **D. Legacy Azure analytics tables** | Historical tables from the platform being migrated to GCP. | The group's former analytics stack, now frozen. | Year-on-year comparisons until the history is fully migrated. |

## 2. The mode for each, and why

| Source | Mode | How fresh? | Do updates and deletes matter? | Do we control it? | What can it bear? |
|--------|------|-----------|--------------------------------|-------------------|-------------------|
| **A. Sales** | **Change data capture**, landed hourly | Next morning is enough: the dashboards are read daily. Being an hour late costs nothing. | **Yes**: a return or exchange changes a sale days later; a cursor on the sale date never sees it. | Partly: we can read the retail database's log, not change its schema. | A production till system: no heavy queries in opening hours, which CDC avoids. |
| **B. Web events** | **Batch**, daily files | Daily for dashboards. Minute-level freshness only matters for incidents, which the web team handles on its own tools. | No: an event is never corrected, only appended. | No: it belongs to the web team, so we take the export they give us. | The export already exists; we add no load. |
| **C. CSV files** | **Batch**, on arrival, each file replacing its previous version | When the requester drops it; a day late is noticed only by them. | **Yes, by replacement**: a corrected file supersedes the old one. | No: business teams produce them by hand. | Nothing to protect: it is a file. |
| **D. Legacy Azure** | **Batch**, one full extract per table, then verified and switched off | Not at all: the data no longer changes. | No: frozen since the migration started. | Yes, until it is decommissioned. | A one-off read, scheduled outside business hours. |

## 3. Delivery guarantees, and which mistake is cheaper

| Source | Guarantee | Cost of a lost record | Cost of a duplicate | Acceptable? |
|--------|-----------|----------------------|---------------------|-------------|
| **A. Sales** | At least once: the replication slot replays from its last confirmed position. | High and silent: revenue under-reported, found only at monthly reconciliation. | Low: every sale has a transaction identifier, so dbt deduplicates it. | Yes: the duplicate is the cheaper mistake, and we choose it. |
| **B. Web events** | At least once, per daily file. | Low: dashboards show rates and trends, and a few missing events do not move them. | Low, but it inflates traffic counts unless events carry an identifier. | Yes, if the export carries an event identifier; otherwise duplicates must be checked per file. |
| **C. CSV files** | Effectively once per version: loading a file replaces the previous one instead of appending to it. | Medium: a report silently uses last month's targets. | High if appended: the same targets counted twice. That is why each file overwrites. | Yes, because overwrite makes a re-run harmless. |
| **D. Legacy Azure** | Exactly once, checked: row counts and totals compared table by table before switching off. | High and permanent: once Azure is shut down, a missed row is gone. | Low: a full reload can be repeated. | Only with the comparison; without it, nobody would know what was lost. |

## 4. The source where the obvious choice is wrong: sales

In a meeting, everyone would answer **streaming** for sales: it is the company's
most important flow, it happens in real time, and today it is already streamed
into BigQuery.

What that answer misses is that **nobody reads sales in real time, and a sale
is not final when it happens**. The only consumers are daily dashboards and
finance's monthly reconciliation. Meanwhile, in luxury retail a sale is often
modified after the fact: a return, an exchange for another size or model, a
correction of the client or boutique it is attributed to. A stream of "sale
happened" events captures the first state of each sale and nothing after it,
unless the source emits a separate correction event, which ours does not do
reliably. The pipeline then shows gross sales, finance's figures show net
sales, and the gap is reconciled by hand.

Change data capture fixes the right problem: it is no fresher than a nightly
batch would need to be, but it sees every update and delete, in order, at no
extra load on the till systems. Real-time streaming buys a freshness nobody
uses, and pays for it with the corrections nobody sees.
