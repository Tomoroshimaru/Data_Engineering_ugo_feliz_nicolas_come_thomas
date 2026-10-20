-- Which product each review is about.
SELECT
    p_id,
    review_id
FROM {{ source('marketplace', 'product_reviews') }}
