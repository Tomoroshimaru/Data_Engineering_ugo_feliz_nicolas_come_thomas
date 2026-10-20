-- F. Product sheet: monthly units, and average price paid against list price,
-- for one product over its whole history.
-- Asked by: the product manager. B000X20Y4C is the best seller.
SELECT DATE_TRUNC(i.order_date, MONTH) AS month,
       SUM(i.qty) AS units,
       ROUND(AVG(i.price_at_purchase), 2) AS avg_price_paid,
       ROUND(ANY_VALUE(p.price), 2) AS list_price
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_p` AS i
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.product` AS p USING (p_id)
WHERE i.p_id = 'B000X20Y4C' AND p.p_id = 'B000X20Y4C'
GROUP BY month
ORDER BY month;
