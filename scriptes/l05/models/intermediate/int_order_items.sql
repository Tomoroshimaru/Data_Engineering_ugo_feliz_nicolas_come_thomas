-- Order lines with the date of their order.
SELECT
    i.order_id,
    i.p_id,
    i.qty,
    i.price_at_purchase,
    o.order_date
FROM {{ ref('stg_order_items') }} AS i
JOIN {{ ref('stg_orders') }} AS o USING (order_id)
