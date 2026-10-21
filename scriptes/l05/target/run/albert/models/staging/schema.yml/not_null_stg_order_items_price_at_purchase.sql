
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select price_at_purchase
from `data-engineering-i2`.`l05_fl`.`stg_order_items`
where price_at_purchase is null



  
  
      
    ) dbt_internal_test