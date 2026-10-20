{{
  config(
    materialized='incremental',
    unique_key='p_id'
  )
}}

-- Daily product demand with average customer rating.
-- Grain: one row per product per day.

SELECT
    oi.p_id,
    o.order_date,
    SUM(oi.qty)                        AS units_sold,
    SUM(oi.qty * oi.price_at_purchase) AS revenue,
    AVG(r.rating)                      AS avg_rating,
    COUNT(r.review_id)                 AS review_count
FROM {{ source('marketplace', 'order_items') }} AS oi
JOIN {{ source('marketplace', 'orders') }}      AS o  ON oi.order_id = o.order_id
LEFT JOIN {{ source('marketplace', 'product_reviews') }} AS pr ON oi.p_id = pr.p_id
LEFT JOIN {{ source('marketplace', 'review') }}          AS r  ON pr.review_id = r.review_id

{% if is_incremental() %}
  WHERE o.order_date > (SELECT MAX(order_date) FROM {{ this }})
{% endif %}

GROUP BY 1, 2
