-- Daily demand for the ML team, and a weekly variant to test a coarser grain.
-- Collapse ratios and what each view saves: docs/warehouse-tuning.md, section 3.

-- Kept: the grain the ML team asked for. Collapse ratio 1.14.
CREATE MATERIALIZED VIEW `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.mv_daily_demand`
PARTITION BY DATE_TRUNC(order_date, MONTH)
AS
SELECT order_date, p_id, SUM(qty) AS units, COUNT(*) AS order_lines
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_p`
GROUP BY order_date, p_id;

-- Built to show the ratio moving (1.81). Unpartitioned, so any query bounded in
-- time reads all of it: it must be partitioned before anyone relies on it.
CREATE MATERIALIZED VIEW `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.mv_weekly_demand`
AS
SELECT DATE_TRUNC(order_date, WEEK) AS week, p_id, SUM(qty) AS units, COUNT(*) AS order_lines
FROM `data-engineering-i2.toes_ugo_feliz_thomas_warehouse.order_items_p`
GROUP BY week, p_id;
