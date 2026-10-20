# ADR-0001: Build a two-tier platform: raw files in Cloud Storage, modelled layers in BigQuery

- **Status:** accepted
- **Date:** 2026-10-20
- **Author:** Féliz Luberne, Thomas Alaph, Ugo Zanchi, Nicolas Gilhodes, Côme Bonneviale
- **Lesson:** L01

## Context

Albert's Marketplace runs its web shop on one PostgreSQL database of about 25
tables. The same database serves the shop and the analysts: analysts query it
directly, and a nightly CSV export feeds their spreadsheets. The facts that
matter, from the brief and the company's repository:

- **The reports disagree on revenue.** Orders are duplicated in the source, and each report handles the duplicates its own way.
- **There is no history.** The database holds the current state only: last March's price is gone.
- **Sensitive data sits beside analytical data.** Saved cards and passwords are in the tables the analysts query.
- **The data is of two kinds.** Structured orders, plus free review text and a clickstream of events published to Kafka.
- **The ML team wants units sold per product, per country, per day**, refreshed daily. Nothing computes it today.
- **The team is five students**, on Google Cloud, with a few hours a week each.

## Options considered

| Option | For | Against |
|---|---|---|
| **Warehouse** (everything in BigQuery) | One system, SQL everywhere, the simplest to run | Raw files (clickstream, exports) are loaded and transformed on arrival: no untouched copy to reprocess from when a rule changes |
| **Lake** (everything as files in Cloud Storage) | Cheap, keeps every raw file, any format | No SQL engine of its own for the analysts; tests, joins and access control would all have to be built by hand |
| **Two-tier** (raw files in Cloud Storage, modelled layers in BigQuery) | Raw data kept as it arrived, so any layer can be rebuilt; BigQuery and dbt for the modelled layers; each tier does what it is good at | Two systems, and a hand-off between them to keep in step |
| **Lakehouse** (open table formats such as Iceberg on Cloud Storage, queried in place) | One copy of the data, open formats, warehouse features on files | More moving parts to set up and secure; hard to justify for a student team and this volume |

## Criteria

| Criterion | What the brief says | Warehouse | Lake | Two-tier | Lakehouse |
|---|---|---|---|---|---|
| **Workload** | Reports for analysts, and a daily table for ML | Good | Poor: no SQL engine | **Good** | Good |
| **Data types** | Structured orders, review text, JSON clickstream | Fair: raw files are reshaped on arrival | Good | **Good**: raw files kept as they are | Good |
| **Freshness** | Daily is enough; nothing needs streaming into the reports | Good | Good | **Good** | Good |
| **Team and skills** | Five students, a few hours a week each, SQL skills | Good | Poor: too much to build | **Good**: managed services, SQL and dbt | Poor: too much to set up |
| **Cost** | Small volumes: tens of MB per table | Good | Good | **Good**: within free tiers at this size | Fair |
| **Governance** | Cards and passwords in the source; personal data | Fair | Poor: file-level access only | **Good**: secrets never extracted; access set per layer | Fair |

## Decision

We build a **two-tier platform**: raw extracts land unchanged in a Cloud Storage
bucket (bronze), and the cleaned and modelled layers (silver and gold) are
built in BigQuery with dbt.

## Consequences

- **Easier:** any rule can be fixed and every layer rebuilt from bronze, because nothing is changed on arrival. The analysts stop querying the shop's database. Revenue gets one definition, in silver, instead of one per report.
- **Harder:** two systems to keep in step. The hand-off from bucket to warehouse (external tables, then loads) is a step that can break, and the bucket's lifecycle and access rules have to be managed alongside BigQuery's.
- **To watch:** that saved cards and passwords are excluded at extraction, not in a later layer; and that the duplicated orders are resolved in silver, once, before any gold table counts revenue.
