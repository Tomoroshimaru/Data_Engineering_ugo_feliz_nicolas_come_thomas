-- Order lines with the date of their order.
SELECT
    i.order_id,
    i.p_id,
    i.qty,
    i.price_at_purchase,
    o.order_date
FROM `data-engineering-i2`.`l05_fl`.`stg_order_items` AS i
JOIN `data-engineering-i2`.`l05_fl`.`stg_orders` AS o USING (order_id)