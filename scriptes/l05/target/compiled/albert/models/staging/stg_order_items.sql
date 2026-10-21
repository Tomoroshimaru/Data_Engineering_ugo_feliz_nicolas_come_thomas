-- One row per order line, explicit columns only.
SELECT
    order_id,
    p_id,
    qty,
    price_at_purchase
FROM `data-engineering-i2`.`l04_fl`.`order_items_raw`