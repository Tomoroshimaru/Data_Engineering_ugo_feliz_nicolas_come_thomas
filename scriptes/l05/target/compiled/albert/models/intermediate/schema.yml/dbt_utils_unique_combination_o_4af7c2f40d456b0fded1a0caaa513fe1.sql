





with validation_errors as (

    select
        order_id, p_id
    from `data-engineering-i2`.`l05_fl`.`int_order_items`
    group by order_id, p_id
    having count(*) > 1

)

select *
from validation_errors


