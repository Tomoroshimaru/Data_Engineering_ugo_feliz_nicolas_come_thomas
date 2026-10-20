-- Units sold per product per day, for the ML team.
SELECT
    p_id,
    order_date,
    SUM(qty) AS units,
    SUM(line_revenue) AS revenue
FROM {{ ref('fct_order_items') }}
GROUP BY p_id, order_date
