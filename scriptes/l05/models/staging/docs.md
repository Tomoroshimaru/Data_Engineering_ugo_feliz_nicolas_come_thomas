{% docs stg_orders %}
One row per order. Each original order (`order_id <= 111322`) has a duplicated twin.
{% enddocs %}

{% docs stg_order_items %}
One row per order line. No date of its own: it comes from the order.
{% enddocs %}

{% docs stg_review %}
One row per review. Blank texts are turned into NULL.
{% enddocs %}

{% docs stg_product_reviews %}
Links each review to the one product it is about.
{% enddocs %}

{% docs order_id %}
Order identifier. Above 111322: duplicated twins.
{% enddocs %}

{% docs p_id %}
Product identifier.
{% enddocs %}

{% docs buyer_id %}
Customer identifier.
{% enddocs %}

{% docs discount_id %}
Discount code. Always empty in the export.
{% enddocs %}

{% docs review_id %}
Review identifier.
{% enddocs %}

{% docs rating %}
Rating from 1 to 5.
{% enddocs %}
