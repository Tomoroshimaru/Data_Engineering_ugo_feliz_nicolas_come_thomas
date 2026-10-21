

  create or replace view `data-engineering-i2`.`l05_fl`.`stg_product_reviews`
  OPTIONS()
  as -- Which product each review is about.
SELECT
    p_id,
    review_id
FROM `data-engineering-i2`.`l04_fl`.`product_reviews`;

