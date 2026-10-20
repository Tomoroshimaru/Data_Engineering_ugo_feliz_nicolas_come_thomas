{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['p_id', 'order_date'],
    partition_by={'field': 'order_date', 'data_type': 'date', 'granularity': 'month'}
  )
}}

-- Rewrite of fct_daily_demand_gen. One row per product per day.
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
SELECT
    d.p_id,
    d.order_date,
    d.units_sold,
    d.revenue,
    r.avg_rating,
    r.n_reviews AS review_count
FROM daily AS d
LEFT JOIN {{ ref('int_product_ratings') }} AS r USING (p_id)
