





with validation_errors as (

    select
        p_id, order_date
    from `data-engineering-i2`.`l05_fl`.`fct_daily_demand`
    group by p_id, order_date
    having count(*) > 1

)

select *
from validation_errors


