# Session 4 — Exercise 1: three queries, and what each one cost

LUBERNE Féliz — dataset `data-engineering-i2.l04_fl` (europe-west1). Tables
loaded through the fallback (CSV from `legacy_csv/` into
`gs://data-engineering-i2-feliz/fallback/`, then `LOAD DATA`). Query cache
off; every figure below is **bytes processed**, read from BigQuery's job
history. "Today" is 14 September 2026.

## The tables

| Table | Rows | Size |
|-------|------|------|
| `orders` | 222,644 | 13.8 MB |
| `order_items` (joined to `orders` for `order_date`) | 408,560 | 18.0 MB |
| `review` | 111,322 | 28.7 MB |
| `product_reviews` | 111,322 | 3.1 MB |
| `product` | 42,858 | 15.3 MB |
| `customer_shipping` | 200,001 | 10.8 MB |
| `shipping_details` | 200,001 | 18.0 MB |

`review` has no product column (`review_id`, `buyer_id`, `r_desc`, `title`,
`rating`, `seller_product_flag`), so Q3 joins it to `product_reviews`.

## The questions

- **Q1**: revenue by month over the last twelve months (`order_date` from 15 September 2025 to 14 September 2026).
- **Q2**: the ten products with the most units sold last quarter (April to June 2026).
- **Q3**: average rating per product, for products with more than fifty reviews.

## The table

| Query | Variant | Bytes processed | Cost at $7.50/TiB | Which change helped, and why |
|-------|---------|-----------------|-------------------|------------------------------|
| Q1 | untuned | 9,805,440 | $0.000067 | Baseline: three columns of all 408,560 rows. |
| Q1 | partitioned | 3,373,224 | $0.000023 | **Partitioning, 2.9x**: only the 13 monthly partitions in the window are read, out of 37. |
| Q2 | untuned | 11,439,680 | $0.000078 | Baseline. |
| Q2 | partitioned | 888,188 | $0.000006 | **Partitioning, 12.9x**: three months out of 37. The narrower the window, the larger the gain. |
| Q2 | partitioned + clustered | 888,188 | $0.000006 | **Nothing**: Q2 filters on no product, so no block can be skipped. |
| Q3 | untuned | 4,007,592 | $0.000027 | Baseline: only the columns used are read, not the 28.7 MB of review text. |
| Q3 | partitioned | 4,007,592 | $0.000027 | **Nothing, as predicted**: Q3 has no date and reads neither partitioned table. |

For every query, the estimate shown before running matched bytes processed
exactly. The one exception is the clustered table: its estimate is an upper
bound (8,171,200 bytes for the single-product query below), because BigQuery
cannot know in advance how many blocks it will skip.

## One sentence per query

- **Q1**: partitioning by month helped, because the query filters on a date window and BigQuery reads only the partitions inside it.
- **Q2**: partitioning helped most, because a quarter is 3 of 37 partitions; clustering added nothing.
- **Q3**: no change helped, because nothing it filters or joins on is a partitioning or clustering key; its cost is already limited by reading only two narrow columns.

## Why clustering did nothing for Q2

Clustering pays when the filter isolates a few values that sit in a few blocks:
`WHERE p_id = 'B0CHXWTSM6'`, a product sold on 4 lines in 2 of 37 months, fell
from 8,171,200 to 380,220 bytes (21.5x). Q2 asks for the top ten among **all**
products, so every block of the quarter has to be read whatever order the rows
are stored in.

## The cap

With **Maximum bytes billed** set to 1,000,000, Q2 failed with:

```text
Query exceeded limit for bytes billed: 1000000. 10485760 or higher required.
```

**What it cost: nothing.** The job was rejected before running: no bytes
processed, no bytes billed. With the cap raised to 10,485,760 the same query
ran and billed 10,485,760 bytes. That number is 10 MiB (10 × 1,024 × 1,024),
the minimum BigQuery bills for any query, so a cap below it blocks every query.

More precisely, the minimum is 10 MiB **per table read**: a query joining two
tables was refused under the 10,485,760 cap with
`Query exceeded limit for bytes billed: 10485760. 20971520 or higher required.`,
and Q3, which joins two tables, was billed 20,971,520 bytes for 4,007,592
processed.

## The partition grain: month

The table covers about three years. Daily partitions would give about 1,100
partitions of roughly 370 rows each, far too small to be worth managing. Monthly
partitions give 37, holding 5,207 to 18,505 rows each, and match how the
questions are asked: Q1 by month, Q2 by quarter.

## Step 7: what counts as an order

Q1's total over the twelve months, changing only the rule for what counts as
an order:

| Rule | Revenue | Against (b) |
|------|---------|-------------|
| (a) every row in the export | 13,065,805.92 | 2.00x |
| (b) originals only, `order_id <= 111322` (the truth) | 6,523,907.20 | 1.00x |
| (c) one order per buyer and day, keeping the lowest `order_id` | 11,795,512.74 | 1.81x |

**How close did (c) get to (b)? Not close.** It removed only 19% of the excess
(1.27 million out of 6.54 million), and still reports 81% more revenue than was
earned. The gap does not point where I expected: I expected a "buyer and day"
rule to be too aggressive, merging genuine separate orders, and so to
under-count. It under-deduplicates instead. Every twin has the same buyer as its
original, but only 22,106 of the 111,322 twins fall on the same day; the others
are dated a day or more later (order 1 on 2025-12-29, its twin 111323 on
2025-12-30), so the rule never groups them.

That is why the order of events in this exercise is a problem: the tables were
tuned for speed before anyone checked what a row means, and the fastest query
was answering with a figure nearly twice the truth.
