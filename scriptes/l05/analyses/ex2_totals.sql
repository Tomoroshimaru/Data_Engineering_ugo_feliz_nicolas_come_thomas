-- Rows, units and revenue: generated model, rewrite, and the truth.
SELECT 'generated' AS model, COUNT(*) AS n_rows, SUM(units_sold) AS units, ROUND(SUM(revenue), 2) AS revenue
FROM {{ ref('fct_daily_demand_gen') }}
UNION ALL
SELECT 'fixed', COUNT(*), SUM(units_sold), ROUND(SUM(revenue), 2)
FROM {{ ref('fct_daily_demand_fixed') }}
UNION ALL
SELECT 'truth', NULL, SUM(qty), ROUND(SUM(qty * price_at_purchase), 2)
FROM {{ ref('stg_order_items') }}
