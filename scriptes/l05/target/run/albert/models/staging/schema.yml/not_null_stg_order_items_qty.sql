
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select qty
from `data-engineering-i2`.`l05_fl`.`stg_order_items`
where qty is null



  
  
      
    ) dbt_internal_test