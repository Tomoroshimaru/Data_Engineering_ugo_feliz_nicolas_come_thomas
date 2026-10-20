# Warehouse tuning

Project step 4. Dataset `data-engineering-i2.toes_ugo_feliz_thomas_warehouse`
(europe-west1). The SQL is in [`warehouse/`](../warehouse/).

**How every figure on this page was measured.** Query cache off (console:
*More → Query settings → Use cached results* unticked; CLI: `--nouse_cache`),
and every figure is **bytes processed**, read from
`INFORMATION_SCHEMA.JOBS_BY_USER` for jobs labelled `step4:*`. Bytes billed is
not used: BigQuery bills at least 10 MiB per table read, so on tables this size
every billed figure is a multiple of 10 MiB and says nothing about the query.
"Today" is 2026-09-14. Cost is bytes / 2^40 × $7.50.

**Where bronze comes from.** The group had not built an ingestion into a group
bucket by this step, so bronze is the company's published CSV export, copied to
`gs://data-engineering-i2-feliz/fallback/`, plus the clickstream Parquet written
by the lesson 3 consumer to `gs://data-engineering-i2-feliz/bronze/clickstream/`.

## 1. What is loaded, and what is left external

| Data | Native or external | Why |
|------|--------------------|-----|
| `orders`, `order_items` | Native | Every revenue and demand question filters them by date; they are what gets partitioned. `order_items` takes `order_date` from its order, because it records no date of its own. |
| `product`, `review`, `product_reviews` | Native | Joined by every product and rating question. |
| `customer_shipping`, `shipping_details` | Native | They carry the customer's country, which the ML team's demand question needs, and they are lesson 5's dimensions. |
| `clickstream` | **External** (`ext_clickstream`) | Appended continuously and read rarely. Its `dt=` layout already lets BigQuery read only the days asked for; reloading it on every arrival would cost more than it saves. |
| Lesson 2 experiment layouts (`by_day`, `month_by_day`, `month_by_day_product`) | **Not loaded** | They are copies made to measure over-partitioning, not project data. |

Every native table also has an `ext_` external table over its bronze file, so
the source stays readable in place.

| Table | Rows | Size |
|-------|------|------|
| `orders` | 222,644 | 13.8 MB |
| `order_items` | 408,560 | 18.0 MB |
| `product` | 42,858 | 15.3 MB |
| `review` | 111,322 | 28.7 MB |
| `product_reviews` | 111,322 | 3.1 MB |
| `customer_shipping` | 200,001 | 10.8 MB |
| `shipping_details` | 200,001 | 18.0 MB |

## 2. What each change was worth

The three questions are in section 4. Each row compares a variant with the
untuned tables, or with the previous variant where stated.

| Table | Change | Query | Bytes before | Bytes after | Ratio |
|-------|--------|-------|--------------|-------------|-------|
| `order_items`, `orders` | Partition by month | A | 35,770,705 | 15,718,911 | **2.28x** |
| `order_items`, `orders` | Partition by month | B | 37,404,945 | 13,377,983 | **2.80x** |
| `order_items` | Partition by month | F | 15,565,320 | 15,565,320 | 1.00x |
| `order_items` | Partition by **day** instead of month | A | 15,718,911 | 15,488,959 | 1.01x |
| `order_items` | Partition by **day** instead of month | B | 13,377,983 | 13,193,807 | 1.01x |
| `order_items` | Cluster by `p_id`, on top of monthly partitions | A | 15,718,911 | 15,718,911 | 1.00x |
| `order_items` | Cluster by `p_id`, on top of monthly partitions | B | 13,377,983 | 13,377,983 | 1.00x |
| `order_items`, `product` | Cluster both by `p_id` | F | 15,565,320 | 15,565,248 | 1.00x |

**Kept: monthly partitions** on `orders` and `order_items`. A and B filter on a
date window, so BigQuery reads only the months inside it: 37 partitions of
about 6,000 and 11,000 rows. F has no date filter, so partitioning does nothing
for it.

**Tried and not kept: daily partitions.** 1,096 partitions of 373 rows on
average, for 1.5% fewer bytes. The grain is far too fine for three years of
this volume.

**Tried and not kept: clustering by product.** A and B ask about all products,
so no block can be skipped. F filters on one product and still gained nothing,
and the reason is the table's size: each monthly partition is small enough to
be a single storage block, so clustering can only skip a partition whose
min–max range of `p_id` excludes the value. `B000X20Y4C` sells in all 37
months and sits in the middle of the range, so nothing is skipped. The same
query on `B0CHXWTSM6` fell from 8,171,160 to 380,220 bytes (21x), but only
because it is the **highest `p_id` in the table** and sold in 2 months. That
21x is an edge case of the block statistics, not evidence that clustering pays
here.

**What is left in B.** After partitioning, 12.5 MB of B's 13.4 MB (93%, from
a dry run of the address join alone) is `customer_shipping` and
`shipping_details`, read in full on every run to find the customer's country. Partitioning cannot help them; a precomputed
customer-to-country dimension (lesson 5) would.

## 3. The materialised view, and whether it earns its place

Collapse ratio, order lines / distinct (product, period):

| Grain | Rows in the view | Ratio |
|-------|------------------|-------|
| Product × day | 356,981 | **1.14** |
| Product × week | 225,345 | 1.81 |
| Product × month | 165,141 | 2.47 |

The daily ratio is close to 1: the catalogue is a long tail (41,323 products
sold over three years), so a product rarely sells twice on the same day, and the
stored result is nearly the size of the table it summarises.

What the views saved, measured:

| Question | Without view | With view | Ratio |
|----------|--------------|-----------|-------|
| Units per product and day, last 4 weeks | 422,800 | 366,940 (`mv_daily_demand`) | 1.15x |
| Units per product, whole history | 8,171,200 | 7,139,620 (`mv_daily_demand`) | 1.14x |
| Units per product, whole history | 8,171,200 | 4,506,900 (`mv_weekly_demand`) | 1.81x |
| Units per product and week, last 12 weeks | 876,204 (served by the daily view) | 6,309,660 (`mv_weekly_demand`) | **0.14x** |

**The ratio predicted the saving exactly**: 1.14 computed, 1.14–1.15 measured
for the daily view; 1.81 and 1.81 for the weekly one.

**`mv_daily_demand` is kept anyway, for a stated reason.** It saves almost
nothing in bytes, but it is the grain the ML team asked for, it is partitioned
like its base table, and it costs about 12.9 MB of storage. We keep it as the
agreed definition of daily demand rather than as an optimisation.

**BigQuery rewrites queries onto it on its own.** A query written against
`order_items_p` was served from `mv_daily_demand`: the job's referenced tables
list the view. The 876,204 bytes for the weekly question came from that
rewrite.

**`mv_weekly_demand` is not to be relied on as it stands.** Its grain is
coarser and its ratio better, but it is not partitioned, so any question bounded
in time reads all of it. It must be partitioned by `week` before anyone uses it.

## 4. Three analytical queries, costed

| Query | Question | Untuned | Tuned | Ratio | Cost untuned | Cost tuned |
|-------|----------|---------|-------|-------|--------------|------------|
| [A](../warehouse/queries/a_revenue_by_country_yoy.sql) | Revenue by country, July to 14 September 2026 against the same period of 2025 | 35,770,705 | 15,718,911 | 2.28x | $0.00024 | $0.00011 |
| [B](../warehouse/queries/b_daily_demand_by_country.sql) | Units per product, per country, per day, last four weeks (ML team) | 37,404,945 | 13,377,983 | 2.80x | $0.00026 | $0.00009 |
| [F](../warehouse/queries/f_product_sheet.sql) | Monthly units and price paid against list price, for one product | 15,565,320 | 15,565,320 | 1.00x | $0.00011 | $0.00011 |

The costs round to nothing; the ratios are what carry to a table a thousand
times bigger.

**The figures themselves are still wrong.** Every order in the export has a
duplicate (lesson 4, exercise 1: revenue is counted about twice), and nothing
in this warehouse says what an order is. These tables are fast, not correct;
correctness is the next step.

## 7. The cap

**Value: 50 MiB (52,428,800 bytes).** BigQuery bills at least 10 MiB per table
read, and our largest legitimate queries (A and B) read four tables, so they
are billed 40 MiB however small they are. 50 MiB lets them run and stops a
query that reads several whole tables.

**Where it is set:**

- **On every query run from the CLI**: `bq query --maximum_bytes_billed=52428800`.
- **In the console**: *More → Query settings → Advanced options → Maximum bytes billed*. The setting belongs to the editor tab, so it has to be set again in every new tab.
- **Not set as a project default.** That would be a custom quota on the project, which needs an administrator role we do not have. dbt will carry the same value in its profile from lesson 5 (`maximum_bytes_billed`).

**Seen to trip.** A careless join of four whole tables, with no date filter,
under the 50 MiB cap:

```text
Query exceeded limit for bytes billed: 52428800. 60817408 or higher required.
```

It was rejected before running: 0 bytes processed, nothing billed. Query B ran
under the same cap and was billed 41,943,040 bytes.
