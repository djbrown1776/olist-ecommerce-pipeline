
WITH customer_orders AS (
    SELECT
        customer_unique_id,
        customer_city,
        customer_state,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(total_item_value) AS lifetime_value,
        MIN(order_purchase_timestamp) AS first_order_at,
        MAX(order_purchase_timestamp) AS last_order_at
    FROM {{ ref('stg_order_details') }}
    GROUP BY
        customer_unique_id,
        customer_city,
        customer_state
)

SELECT
    customer_unique_id,
    customer_city,
    customer_state,
    total_orders,
    lifetime_value,
    first_order_at,
    last_order_at,
    CASE
        WHEN total_orders > 1 THEN TRUE
        ELSE FALSE
    END AS is_repeat_customer
FROM customer_orders