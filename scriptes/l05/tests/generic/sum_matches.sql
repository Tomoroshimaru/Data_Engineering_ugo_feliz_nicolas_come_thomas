-- Fails if the column's total differs from the same total in another model.
{% test sum_matches(model, column_name, compare_model, compare_expression) %}
WITH a AS (SELECT SUM({{ column_name }}) AS total FROM {{ model }}),
     b AS (SELECT SUM({{ compare_expression }}) AS total FROM {{ compare_model }})
SELECT a.total AS model_total, b.total AS compare_total
FROM a, b
WHERE ABS(a.total - b.total) > 0.01
{% endtest %}
