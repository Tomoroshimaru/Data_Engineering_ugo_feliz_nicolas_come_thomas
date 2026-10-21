
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select p_id
from `data-engineering-i2`.`l05_fl`.`stg_product_reviews`
where p_id is null



  
  
      
    ) dbt_internal_test