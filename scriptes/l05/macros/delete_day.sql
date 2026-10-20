-- Deletes one day from a model's table, to simulate a day not loaded yet.
-- dbt run-operation delete_day --args '{model: fct_daily_demand_gen, day: "2026-09-14"}'
{% macro delete_day(model, day) %}
  {% set sql %}
    DELETE FROM `{{ target.database }}.{{ target.schema }}.{{ model }}`
    WHERE order_date = DATE '{{ day }}'
  {% endset %}
  {% set result = run_query(sql) %}
  {{ log("Deleted " ~ day ~ " from " ~ model, info=True) }}
{% endmacro %}
