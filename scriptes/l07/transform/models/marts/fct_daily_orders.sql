select
    o.order_date,
    count(distinct o.order_id) as orders,
    round(sum(i.line_revenue), 2) as revenue
from {{ ref('stg_orders') }} o
join {{ ref('stg_order_items') }} i using (order_id)
group by o.order_date
