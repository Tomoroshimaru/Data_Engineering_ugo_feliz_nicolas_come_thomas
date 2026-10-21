
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select rating
from `data-engineering-i2`.`l05_fl`.`stg_review`
where rating is null



  
  
      
    ) dbt_internal_test