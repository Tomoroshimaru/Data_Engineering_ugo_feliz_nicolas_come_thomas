select
    order_id,
    p_id,
    qty,
    price_at_purchase,
    qty * price_at_purchase as line_revenue
from {{ source('marketplace', 'order_items_raw') }}
