
WITH product_sales AS (
    SELECT
        product_id,
        product_category_name,
        product_category_name_english,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        COUNT(DISTINCT order_id) AS times_ordered,
        SUM(price) AS total_revenue,
        AVG(price) AS avg_price
    FROM {{ ref('stg_order_details') }}
    WHERE product_id IS NOT NULL
    GROUP BY
        product_id,
        product_category_name,
        product_category_name_english,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
)

SELECT
    product_id,
    product_category_name,
    product_category_name_english,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    times_ordered,
    total_revenue,
    avg_price
FROM product_sales
