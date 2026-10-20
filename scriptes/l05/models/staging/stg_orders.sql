-- One row per order, without the index column.
SELECT
    order_id,
    buyer_id,
    discount_id,
    payment_id,
    order_date
FROM {{ source('marketplace', 'orders') }}
