-- One row per product per order, with its revenue and the product's rating.
SELECT
    oi.order_id,
    oi.p_id,
    oi.order_date,
    oi.qty,
    oi.price_at_purchase,
    oi.qty * oi.price_at_purchase AS line_revenue,
    pr.avg_rating,
    pr.n_reviews
FROM `data-engineering-i2`.`l05_fl`.`int_order_items` AS oi
LEFT JOIN `data-engineering-i2`.`l05_fl`.`int_product_ratings` AS pr USING (p_id)