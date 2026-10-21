
    
    

with all_values as (

    select
        rating as value_field,
        count(*) as n_records

    from `data-engineering-i2`.`l05_fl`.`stg_review`
    group by rating

)

select *
from all_values
where value_field not in (
    1,2,3,4,5
)


