
WITH customer_orders AS (
    SELECT
        customer_unique_id,
        customer_city,
        customer_state,
        order_purchase_timestamp,
        total_item_value,
        order_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp DESC
        ) AS row_num
    FROM {{ ref('stg_order_details') }}
),

customer_metrics AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(total_item_value) AS lifetime_value,
        MIN(order_purchase_timestamp) AS first_order_at,
        MAX(order_purchase_timestamp) AS last_order_at
    FROM customer_orders
    GROUP BY customer_unique_id
),

latest_address AS (
    SELECT
        customer_unique_id,
        customer_city,
        customer_state
    FROM customer_orders
    WHERE row_num = 1
)

SELECT
    m.customer_unique_id,
    a.customer_city,
    a.customer_state,
    m.total_orders,
    m.lifetime_value,
    m.first_order_at,
    m.last_order_at,
    CASE
        WHEN m.total_orders > 1 THEN TRUE
        ELSE FALSE
    END AS is_repeat_customer
FROM customer_metrics m
JOIN latest_address a ON m.customer_unique_id = a.customer_unique_id
