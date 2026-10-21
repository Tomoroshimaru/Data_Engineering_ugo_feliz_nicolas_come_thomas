# Session 5 — Exercise 2: critique a generated dbt model

LUBERNE Féliz — written as a group. We added the generated model to our dbt
project as it was (`scriptes/l05/models/marts/fct_daily_demand_gen.sql`) and
built it on our lesson 4 bronze. We got the brief's output line for line
(`FAIL 39159`, `Done. PASS=3 ERROR=1`) and its exact figures: 356,981 rows,
29,887,618 units, €700,515,495.02. The row the brief quotes checks out: B0BM4GX6TT sold
48 units on 2024-10-07 and has 376 reviews, and 48 × 376 = 18,048.

## 1. The defects, ranked by what they would cost

| # | Defect | Where | Wrong today? |
|---|--------|-------|--------------|
| 1 | `unique_key='p_id'` on an incremental model whose grain is product and day | `config(...)` | No |
| 2 | The reviews are joined before aggregating, so each order line is counted once per review: revenue ×17.9, units ×21.6 | the two `LEFT JOIN`s | Yes |
| 3 | `review_count` is multiplied by the product's order lines that day (wrong on 47,914 rows) | `COUNT(r.review_id)` | Yes |
| 4 | The incremental filter uses a strict `>` on the last loaded date | the `is_incremental()` block | No |
| 5 | The `unique` test on `p_id` contradicts the grain written in the comment | `_gen.yml` | Not a number |
| 6 | It reads `source()` directly instead of the staging models | the four `source()` calls | No |

We put the incremental key first because it is the only defect that is right
on the day someone reviews it. The first build is a plain `CREATE TABLE`, so
every number is correct. From the next run on, dbt runs a `MERGE ... ON p_id`:
a product sold on the new day matches every row of that product's history, and
all of them are overwritten with the new day's figures. No run fails and no
error is raised. Three weeks later, every product sold since has lost its
history, on a table nobody looks at again once it has shipped.

We watched it happen. We deleted 2026-09-14 from the built table, as if that
day had not been loaded yet, and ran dbt again without `--full-refresh`. The
run reported `Done. PASS=2 ERROR=0` and a `MERGE` of 24.6k rows to reload a
single day. Product B0BM4GX6TT had 736 rows over 736 days before; it now had
735 rows, all dated 2026-09-14, totalling 1,105,440 units. That day it really
sold 4 units: multiplied by its 376 reviews (defect 2), then copied onto all
735 rows of its history (defect 1). The reloaded day was not even inserted,
because it matched existing rows. Our rewrite, run the same way, kept its 736
days and its true 4,456 units, and merged only the 1.7k rows of its three-day
look-back.

The fan-out (2) costs more in raw numbers, but it is loud. €700 million against
€39 million gets caught by the first person who compares it with finance.
`review_count` (3) is wrong for the same reason; `avg_rating` happens to be
right, because each review is repeated the same number of times, and that makes
the table look more trustworthy than it is. The strict `>` (4) is silent too,
but it only loses the late rows of the last loaded day. The wrong test (5)
fails on correct data, which teaches the team to ignore a red test, the very
habit that hides defect 1. Reading `source()` (6) costs nothing today and
lineage later.

## 2. The tests

The `unique` test on `p_id` failed with 39,159 rows. It caught defect 5, the
test itself: products sell on more than one day, so `p_id` was never unique. It
caught no problem in the data. The two `not_null` tests passed and could not
have caught anything, since a number multiplied by 18 is still not null.

Even with every test green, the fan-out and the incremental filter would stay
invisible. The `GROUP BY` folds the duplicated lines back into one row per
product and day, so a correct grain test passes on a table 18 times too large.

The test we would add is the real grain. After the first incremental run, the
merge leaves several rows with the same product and day, and this fails:

```yaml
models:
  - name: fct_daily_demand
    data_tests:
      - dbt_utils.unique_combination_of_columns:
          arguments:
            combination_of_columns: [p_id, order_date]
```

For the fan-out we added a second test, `sum_matches` in
`scriptes/l05/tests/generic/`, which fails when the mart's total units or
revenue differ from the order lines underneath. No grain test can see a fan-out
that has already been aggregated away.

## 3. The rewrite

We aggregated the reviews to one row per product in `int_product_ratings`
before joining them. A review and an order line are at different grains, and a
`WHERE` clause can only keep or drop rows: it could keep one arbitrary review
per product, or lose products, but it could never turn many reviews into one
attribute of the product.

The staging models are the ones from exercise 1. The rewrite is in our project
as `fct_daily_demand_fixed`. Built on the same data, it passes its six tests and
lands on the truth to the cent: 356,981 rows, 1,386,640 units, €39,199,900.62.

`models/intermediate/int_order_items.sql`

```sql
SELECT i.order_id, i.p_id, i.qty, i.price_at_purchase, o.order_date
FROM {{ ref('stg_order_items') }} AS i
JOIN {{ ref('stg_orders') }} AS o USING (order_id)
```

`models/intermediate/int_product_ratings.sql`

```sql
-- One row per product.
SELECT pr.p_id, AVG(r.rating) AS avg_rating, COUNT(*) AS review_count
FROM {{ ref('stg_product_reviews') }} AS pr
JOIN {{ ref('stg_review') }} AS r USING (review_id)
GROUP BY pr.p_id
```

`models/marts/fct_daily_demand.sql`

```sql
{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['p_id', 'order_date'],
    partition_by={'field': 'order_date', 'data_type': 'date', 'granularity': 'month'}
  )
}}

-- One row per product per day.
WITH daily AS (
    SELECT
        p_id,
        order_date,
        SUM(qty)                     AS units_sold,
        SUM(qty * price_at_purchase) AS revenue
    FROM {{ ref('int_order_items') }}
    {% if is_incremental() %}
    -- Re-read the last 3 days, so late rows are merged instead of lost.
    WHERE order_date >= (SELECT DATE_SUB(MAX(order_date), INTERVAL 3 DAY) FROM {{ this }})
    {% endif %}
    GROUP BY p_id, order_date
)
SELECT d.*, r.avg_rating, r.review_count
FROM daily AS d
LEFT JOIN {{ ref('int_product_ratings') }} AS r USING (p_id)
```

## 4. What it tells us about generated code

Every check this model went through was a check on syntax. It compiled, it
built and its tests ran, and none of those steps knew the company made €39
million. The assistant wrote the grain in a comment and a test that disagreed
with it, because both were plausible text written separately; nothing ran the
comment against the data.

The cheapest check we know against this kind of error is to reconcile the
total. Compare total revenue and units in the mart with the same totals one
layer down, and once with the figure finance publishes. It is one query, and it
catches every fan-out whatever the join looks like. In a real company that
figure comes from the finance close, and the person who knows it is the
finance controller, not us. Asking them for it before the first model ships is
part of our job.

Two lines we would put in a review checklist:

1. If a model states a grain, it tests that exact grain, and the reviewer checks the two match. If it is incremental, its `unique_key` is that grain.
2. If a model sums money or units, it has a test that reconciles its total with the layer below, and someone has compared that total once with a figure from outside the data team.
