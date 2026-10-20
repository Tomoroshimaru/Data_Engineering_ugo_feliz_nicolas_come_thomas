# Session 5 — Exercise 2: critique a generated dbt model

LUBERNE Féliz. I re-ran the generated SQL on the same bronze (`l04_fl`) and got
its exact figures: 356,981 rows, 29,887,618 units, €700,515,495.02.
B0BM4GX6TT on 2024-10-07: 48 units really sold × 376 reviews = 18,048.

## 1. The defects, ranked by what they would cost

| # | Defect | Line | Wrong today? | Cost if shipped |
|---|--------|------|--------------|-----------------|
| **1** | **`unique_key='p_id'` on an incremental model whose grain is (product, day).** Each incremental run is a `MERGE ... ON p_id`: a product sold on the new day matches **every** historical row of that product, and all of them are overwritten with the new day's date and figures. | `config(... unique_key='p_id')` | **No.** The first run is a full `CREATE TABLE`, so today's numbers are right. | The highest. From the first daily run, history is rewritten in place, product by product, with no error and no failed run. In three weeks the table is wrong for every product that sold since, and nothing says so. The only signal is a test that was already red on day one. |
| **2** | **Fan-out on the reviews.** Order lines are joined to every review of their product before aggregating, so each line is counted once per review. | The two `LEFT JOIN`s on `product_reviews` and `review` | Yes: revenue ×17.9, units ×21.6. | Very high, but **loud**: €700 million against €39 million is caught by the first person who compares with finance. |
| **3** | **`review_count` is multiplied** by the number of order lines of that product that day (wrong on 47,914 rows). `avg_rating` happens to be right, because every review is repeated the same number of times. | `COUNT(r.review_id)`, same joins | Yes. | Medium: a misleading column, and the correct-looking `avg_rating` beside it makes the table look trustworthy. |
| **4** | **Strict `>` on the last loaded date.** If a run happens before a day is complete, or an order arrives late with an earlier date, those rows are never loaded. | `WHERE o.order_date > (SELECT MAX(order_date) FROM {{ this }})` | No. | Medium and silent, but bounded: it loses the late rows of the boundary day, not the history. |
| 5 | **A test that contradicts the declared grain.** The comment says one row per product per day; the test says one row per product. It fails on correct data (39,159 products appear on more than one day), so the team learns to ignore a red test, which is exactly what hides defect 1. | `unique` on `p_id` in `_gen.yml` | n/a | Indirect but real: it trains people to ignore failures. |
| 6 | **`source()` instead of `ref()`.** The model reads bronze directly, skipping the staging models (no lineage through them, and no cleaning). | the four `source()` calls | No. | Low today, a maintenance cost later. |

**Why defect 1 ranks first.** Defects 2 and 3 are wrong today and big enough to
be noticed. Defect 1 is right on the day it is reviewed and approved, then
degrades a little more every run, on a table nobody re-checks once it shipped.
A loud error costs a day; a silent one costs every decision taken on the table
until someone reconciles it.

## 2. The tests

- **`unique` on `p_id` failed (FAIL 39159).** It caught the contradiction between the test and the grain, defect 5: products sell on more than one day. It caught no data problem.
- **`not_null` on `p_id` and on `units_sold` passed**, and could not catch anything relevant: a doubled number is not null.
- **Invisible even with every test green:** the fan-out (2 and 3) and the incremental filter (4). Aggregation collapses the duplicates back to one row per product and day, so even a correct grain test passes on a table 18 times too large.
- **The one test I would add, for defect 1:** the real grain. After the first incremental run, the merge leaves several rows with the same `(p_id, order_date)`, and this fails:

```yaml
models:
  - name: fct_daily_demand
    data_tests:
      - dbt_utils.unique_combination_of_columns:
          arguments:
            combination_of_columns: [p_id, order_date]
```

For defect 2, the second test I would add is a reconciliation (a singular test
that fails if `SUM(units)` in the mart differs from `SUM(qty)` in
`stg_order_items`): no grain test can see a fan-out that has been aggregated
away.

## 3. The rewrite

The reviews are aggregated to one row per product in `int_product_ratings`
before being joined, because the problem is that a review is at a different
grain from an order line; a `WHERE` clause can only keep or drop rows, so it
could keep one arbitrary review per product or lose products, but never turn
many reviews into one attribute of the product.

Staging (`stg_orders`, `stg_order_items`, `stg_review`, `stg_product_reviews`)
is the one from exercise 1.

**`models/intermediate/int_order_items.sql`**

```sql
SELECT i.order_id, i.p_id, i.qty, i.price_at_purchase, o.order_date
FROM {{ ref('stg_order_items') }} AS i
JOIN {{ ref('stg_orders') }} AS o USING (order_id)
```

**`models/intermediate/int_product_ratings.sql`**

```sql
-- One row per product.
SELECT pr.p_id, AVG(r.rating) AS avg_rating, COUNT(*) AS review_count
FROM {{ ref('stg_product_reviews') }} AS pr
JOIN {{ ref('stg_review') }} AS r USING (review_id)
GROUP BY pr.p_id
```

**`models/marts/fct_daily_demand.sql`**

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

## 4. What this tells you about generated code

The model was syntactically perfect and semantically wrong, and every check it
went through checks syntax: it compiled, it built, and its tests ran. Nothing in
that chain knows that this company made €39 million. The assistant wrote the
grain in a comment and a contradicting test because both are plausible text
produced separately; nothing executes the comment against the data, so nothing
can notice that they disagree.

The cheapest check that catches this whole class of error is a
**reconciliation against a number someone outside the code is accountable for**:
total revenue and total units in the mart, compared with the same totals one
layer down and with the figure finance publishes. It is one query, and it
catches every fan-out regardless of how the join was written. On a real project
that number is the finance close (the general ledger), and the person who knows
it is the finance controller, not the data team. The data team's job is to ask
for it before the first model ships.

For a review checklist, two lines:

1. **A model that declares a grain tests that exact grain** with `unique_combination_of_columns` on the columns named in its description, and the reviewer checks that the two match. If it is incremental, its `unique_key` equals that grain.
2. **A model that sums money or units has a reconciliation test** against the layer below, and its total has been compared once, by a person, with a figure from outside the data team.
