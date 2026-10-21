

  create or replace view `data-engineering-i2`.`l05_fl`.`stg_orders`
  OPTIONS()
  as -- One row per order, without the index column.
SELECT
    order_id,
    buyer_id,
    discount_id,
    payment_id,
    order_date
FROM `data-engineering-i2`.`l04_fl`.`orders`;

