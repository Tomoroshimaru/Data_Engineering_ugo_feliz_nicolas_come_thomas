
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select order_date
from `data-engineering-i2`.`l05_fl`.`fct_daily_demand`
where order_date is null



  
  
      
    ) dbt_internal_test