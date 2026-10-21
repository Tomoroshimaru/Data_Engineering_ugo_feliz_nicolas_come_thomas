
  
    

    create or replace table `data-engineering-i2`.`l05_fl`.`fct_daily_demand`
      
    
    

    
    OPTIONS()
    as (
      -- Units sold per product per day, for the ML team.
SELECT
    p_id,
    order_date,
    SUM(qty) AS units,
    SUM(line_revenue) AS revenue
FROM `data-engineering-i2`.`l05_fl`.`fct_order_items`
GROUP BY p_id, order_date
    );
  