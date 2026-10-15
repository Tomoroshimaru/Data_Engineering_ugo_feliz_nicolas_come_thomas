# Session 2 — Exercise 2: a retention and access plan

LUBERNE Féliz — a French luxury jewellery and watchmaking house. Its analytics
platform runs on Google Cloud: data lands in BigQuery, is modelled with dbt and
read through Looker (see L01-EX2). This page describes categories of data and
cites only public rules; no internal policy is quoted.

## 1. Three datasets

| Dataset | What it is | How much | How often it is read |
|---------|------------|----------|----------------------|
| **A. Sales transactions** | Every sale from boutiques (point of sale) and the e-shop: order, product, price, store, date, and the client it was sold to. | The largest and fastest-growing dataset in the warehouse. | Daily for the current and previous year (dashboards, year-on-year); older years only for audits. |
| **B. Web and app logs** | Technical and navigation events streamed from the web platform (hosted on AWS). | High volume, mostly short-lived value. | Heavily in the first days (incidents, traffic analysis), rarely after a month. |
| **C. Ad-hoc CSV imports** | Spreadsheets sent by business teams and loaded through Airflow, plus the child tables built from them. | Small, but many files. | By the person who asked for them, within days; almost never afterwards. |

## 2. How long each must be kept, and on whose authority

| Dataset | Retention | Source |
|---------|-----------|--------|
| **A. Sales** | 10 years after the end of the financial year. Client identity in analytics: 3 years after the client's last purchase, then pseudonymised. | **Law:** French Commercial Code, art. L123-22 (accounting documents and supporting evidence kept 10 years). **Regulator guidance:** CNIL, client data for marketing kept 3 years after the last contact (GDPR art. 5(1)(e), storage limitation). |
| **B. Logs** | 12 months, then deleted. | **Regulator guidance:** the CNIL recommendation on logging (6 months to 1 year), under GDPR storage limitation, since logs contain IP addresses. |
| **C. CSV imports** | None defined. | **Nobody knows:** no owner, no rule; they have always been kept because nothing deletes them. I propose 90 days (section 5 explains why I cannot enforce it). |

## 3. Storage-class and lifecycle plan

Raw files are kept in a Cloud Storage bronze bucket; the BigQuery tables
built from them follow the same calendar with partition expiration.

| Dataset | At creation | Transitions | Deleted? | Why, by read frequency |
|---------|-------------|-------------|----------|------------------------|
| **A. Sales** | Standard | Nearline at 1 year, Archive at 3 years | Yes, at 10 years, unless under legal hold | Read daily in year 1, a few times a year in years 2–3 (comparisons), then only by auditors. |
| **B. Logs** | Standard | Nearline at 30 days | Yes, at 12 months | Read daily during the first month, occasionally for investigations afterwards. No Coldline or Archive: their minimum storage duration (90 and 365 days) would cost as much as keeping them to deletion. |
| **C. CSV imports** | Standard | Nearline at 30 days | Yes, at 90 days (proposed) | Read within days of upload, then almost never. |

## 4. Who reads what, with the narrowest access

| Dataset | Who | Narrowest access | Person or service |
|---------|-----|------------------|-------------------|
| **A. Sales** | Key users (business) | Looker dashboards on the aggregated gold tables; no access to BigQuery itself. | Person, through Looker only |
| | Looker and dbt | Read-only on the specific datasets they use (`bigquery.dataViewer` on the gold dataset for Looker, on bronze/silver for dbt). | Service |
| | Data engineers | Read on bronze for maintenance; client identity masked by default. | Person |
| | Auditors | Time-limited read on archived years, granted on request. | Person, temporary |
| **B. Logs** | Ingestion pipeline | Write only (`storage.objectCreator`) on the log prefix. | Service |
| | Web on-call engineer | Read on the log prefix, granted for the incident and then removed. | Person, temporary |
| **C. CSV imports** | Business requester | Upload only to their own landing prefix; cannot read other teams' files. | Person |
| | Airflow | Read on the landing prefix, write to BigQuery. | Service |

## 5. What I cannot do, and why

I cannot apply the 90-day deletion to the CSV imports, because no one owns
them. A file is uploaded by one business team, loaded by the data team, and
turned into child tables used by others, so nobody has the authority to say it
can be deleted, and deleting it without that authority could break a report
someone still relies on. The data team can propose the rule, but the decision
has to come from a named business owner for each source, and that ownership
does not exist yet. Until it does, these files are kept forever by default,
including any personal data they contain.
