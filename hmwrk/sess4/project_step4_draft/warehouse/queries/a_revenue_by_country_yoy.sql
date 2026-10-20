-- A. Revenue by country, summer 2026 against the same period of 2025.
-- Asked by: sales leadership. "Today" is 2026-09-14.
-- Both date filters are repeated on each table so that both are pruned.
SELECT sd.country,
       ROUND(SUM(IF(i.order_date >= DATE '2026-07-01', i.qty * i.price_at_purchase, 0)), 2) AS revenue_2026,
       ROUND(SUM(IF(i.order_date <  DATE '2026-01-01', i.qty * i.price_at_purchase, 0)), 2) AS revenue_2025
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_p` AS i
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.orders_p` AS o USING (order_id)
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.customer_shipping` AS cs ON cs.c_id = o.buyer_id AND cs.is_default = 1
JOIN `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.shipping_details` AS sd USING (address_id)
WHERE (i.order_date BETWEEN DATE '2026-07-01' AND DATE '2026-09-14' OR i.order_date BETWEEN DATE '2025-07-01' AND DATE '2025-09-14')
  AND (o.order_date BETWEEN DATE '2026-07-01' AND DATE '2026-09-14' OR o.order_date BETWEEN DATE '2025-07-01' AND DATE '2025-09-14')
GROUP BY sd.country
ORDER BY revenue_2026 DESC;
