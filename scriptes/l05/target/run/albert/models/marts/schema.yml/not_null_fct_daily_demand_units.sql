
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select units
from `data-engineering-i2`.`l05_fl`.`fct_daily_demand`
where units is null



  
  
      
    ) dbt_internal_test