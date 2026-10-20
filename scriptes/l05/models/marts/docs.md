{% docs fct_order_items %}
One row per product per order. GRAIN: (order_id, p_id).
{% enddocs %}

{% docs fct_daily_demand %}
One row per product per day, for the ML team. GRAIN: (p_id, order_date).
{% enddocs %}

{% docs fct_daily_demand_gen %}
AI-generated model, kept as generated to study its defects. Do not use.
{% enddocs %}

{% docs fct_daily_demand_fixed %}
Rewrite of the generated model. Incremental, merged on (p_id, order_date).
{% enddocs %}

{% docs line_revenue %}
qty × price_at_purchase.
{% enddocs %}

{% docs units %}
Units sold that day.
{% enddocs %}

{% docs revenue %}
Revenue that day.
{% enddocs %}
