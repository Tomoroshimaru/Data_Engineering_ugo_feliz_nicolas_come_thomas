-- One row per review, blank texts as NULL.
SELECT
    review_id,
    buyer_id,
    NULLIF(TRIM(r_desc), '') AS r_desc,
    title,
    rating,
    seller_product_flag
FROM `data-engineering-i2`.`l04_fl`.`review`