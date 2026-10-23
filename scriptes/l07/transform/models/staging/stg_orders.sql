select
    order_id,
    buyer_id,
    order_date
from {{ source('marketplace', 'orders_raw') }}
