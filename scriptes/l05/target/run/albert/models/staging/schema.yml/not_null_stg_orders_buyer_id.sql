
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select buyer_id
from `data-engineering-i2`.`l05_fl`.`stg_orders`
where buyer_id is null



  
  
      
    ) dbt_internal_test