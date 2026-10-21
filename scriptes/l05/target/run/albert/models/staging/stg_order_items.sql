

  create or replace view `data-engineering-i2`.`l05_fl`.`stg_order_items`
  OPTIONS()
  as -- One row per order line, explicit columns only.
SELECT
    order_id,
    p_id,
    qty,
    price_at_purchase
FROM `data-engineering-i2`.`l04_fl`.`order_items_raw`;

