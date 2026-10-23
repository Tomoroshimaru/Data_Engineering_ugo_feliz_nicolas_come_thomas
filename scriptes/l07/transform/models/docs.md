{% docs stg_orders %}
One row per order, read from bronze `orders_raw`.
{% enddocs %}

{% docs stg_order_items %}
One row per order line, with its revenue.
{% enddocs %}

{% docs fct_daily_orders %}
One row per day: number of orders and revenue.
{% enddocs %}
