-- History of one product in both models: number of days, date range, units.
SELECT 'generated' AS model, COUNT(*) AS n_rows, COUNT(DISTINCT order_date) AS n_days,
       MIN(order_date) AS first_day, MAX(order_date) AS last_day, SUM(units_sold) AS units
FROM {{ ref('fct_daily_demand_gen') }}
WHERE p_id = 'B0BM4GX6TT'
UNION ALL
SELECT 'fixed', COUNT(*), COUNT(DISTINCT order_date), MIN(order_date), MAX(order_date), SUM(units_sold)
FROM {{ ref('fct_daily_demand_fixed') }}
WHERE p_id = 'B0BM4GX6TT'
