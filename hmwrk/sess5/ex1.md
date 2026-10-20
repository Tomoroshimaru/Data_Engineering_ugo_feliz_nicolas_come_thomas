# Session 5 — Exercise 1: give the number one definition

LUBERNE Féliz — dbt 1.12.5 with dbt-bigquery 1.12.1 (course container), models
built into `data-engineering-i2.l05_fl`, sources read from `l04_fl`. The project
is in `scriptes/l05/`.

## 1. Source freshness

```text
1 of 1 PASS freshness of marketplace.orders .......... [PASS in 0.01s]
Done.
```

**Where the timestamp came from:** no `loaded_at_field` is declared, so dbt
reports `Pulling freshness from warehouse metadata tables`: it read the
**last-modified time of the `orders` table** in BigQuery, which is when I loaded
it this morning. It measures when the table was written, not how recent the
data is: the latest `order_date` is 2026-09-14, and the check still passes.

## 2. The grain

**`fct_order_items` has one row per product per order.** It is defended by
`dbt_utils.unique_combination_of_columns` on `(order_id, p_id)`, declared in
`models/marts/_marts.yml`. The first `dbt build` passed:

```text
Done. PASS=29 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=29
```

## 3. Step 5: the FAIL number, and what those rows are

My prediction: the tests would fail. They did, but the model itself built
without error: a join that multiplies rows is valid SQL, so nothing stops the
table being written; only the test catches it afterwards.

```text
OK created sql table model l05_fl.fct_order_items ... [CREATE TABLE (8.9m rows, ...)]
FAIL 315450 dbt_utils_unique_combination_of_columns_fct_order_items_order_id__p_id
Done. PASS=1 WARN=0 ERROR=1 SKIP=4 NO-OP=0 REUSED=0 TOTAL=6
```

**FAIL 315450**: 315,450 `(order_id, p_id)` pairs now appear more than once. A
product has many reviews, and joining reviews onto order lines repeats each
order line once per review of its product: the table went from 408,560 to
8,892,720 rows, about 22 times more. (No order line was lost: every product sold
has at least one review.)

## 4. What was skipped, and why it matters

**Four things were skipped: `fct_daily_demand` and its three tests** (its grain
`(p_id, order_date)`, and `not_null` on `units` and `order_date`).

That is the point of `dbt build`: it tests each model right after building it
and only moves downstream if the tests pass. The inflated rows never reached the
mart, which kept its last good version. Had I run `dbt run` then `dbt test`,
`fct_daily_demand` would have been rebuilt from 8.9 million rows, the ML team's
daily demand would have been multiplied by about twenty, and the test would
have told me only after the wrong figure was published.

## 5. The fix

**I aggregated the reviews to one row per product first**
(`models/intermediate/int_product_ratings.sql`: average rating and number of
reviews per `p_id`), then `LEFT JOIN`ed that onto the order lines. A filter
keeping one review per product would also restore the grain, but the "rating"
would then be one arbitrary review's, not the product's: only aggregation turns
many reviews into one attribute of the product.

```text
OK created sql table model l05_fl.fct_order_items ... [CREATE TABLE (408.6k rows, ...)]
Done. PASS=7 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=7
```

## 6. Lineage: if `orders` gained a column tomorrow

**Downstream in the graph:** four models, `stg_orders` → `int_order_items` →
`fct_order_items` → `fct_daily_demand`, and nine tests: four on `stg_orders`
(`unique` and `not_null` on `order_id`, `not_null` on `buyer_id` and
`order_date`), the `relationships` test from `stg_order_items` to `stg_orders`,
the grain test on `fct_order_items`, and the three tests on `fct_daily_demand`.

**What would actually change: nothing.** `stg_orders` lists its columns
explicitly, so the new column stops there until someone decides to add it. Had
it been `SELECT *`, the column would have entered `stg_orders` without anyone
deciding it.
