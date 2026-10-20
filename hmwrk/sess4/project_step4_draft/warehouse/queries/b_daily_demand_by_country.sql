-- B. Units sold per product, per country, per day, over the last four weeks.
-- Asked by: the ML team, for demand forecasting. "Today" is 2026-09-14.
-- Country is the customer's default shipping address.
SELECT i.order_date AS day, i.p_id, sd.country, SUM(i.qty) AS units
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_p` AS i
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.orders_p` AS o USING (order_id)
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.customer_shipping` AS cs ON cs.c_id = o.buyer_id AND cs.is_default = 1
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.shipping_details` AS sd USING (address_id)
WHERE i.order_date BETWEEN DATE '2026-08-18' AND DATE '2026-09-14'
  AND o.order_date BETWEEN DATE '2026-08-18' AND DATE '2026-09-14'
GROUP BY day, i.p_id, sd.country;
