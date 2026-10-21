

  create or replace view `data-engineering-i2`.`l05_fl`.`int_product_ratings`
  OPTIONS()
  as -- One row per product: its reviews aggregated.
SELECT
    pr.p_id,
    AVG(r.rating) AS avg_rating,
    COUNT(*) AS n_reviews
FROM `data-engineering-i2`.`l05_fl`.`stg_product_reviews` AS pr
JOIN `data-engineering-i2`.`l05_fl`.`stg_review` AS r USING (review_id)
GROUP BY pr.p_id;

