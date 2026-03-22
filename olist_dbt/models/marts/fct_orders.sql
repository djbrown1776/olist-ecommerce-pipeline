
WITH order_items AS (
    SELECT
        order_id,
        order_status,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        customer_unique_id,
        delivery_days,
        estimated_vs_actual_days,
        COUNT(*) AS item_count,
        SUM(price) AS total_price,
        SUM(freight_value) AS total_freight,
        SUM(total_item_value) AS order_value
    FROM {{ ref('stg_order_details') }}
    GROUP BY
        order_id,
        order_status,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        customer_unique_id,
        delivery_days,
        estimated_vs_actual_days
),

payments AS (
    SELECT
        order_id,
        COUNT(*) AS payment_count,
        SUM(payment_value) AS total_payment_value
    FROM {{ ref('stg_order_payments') }}
    GROUP BY order_id
),

reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM {{ ref('stg_order_reviews') }}
    GROUP BY order_id
)

SELECT
    oi.order_id,
    oi.order_status,
    oi.order_purchase_timestamp,
    oi.order_delivered_customer_date,
    oi.order_estimated_delivery_date,
    oi.customer_unique_id,
    oi.delivery_days,
    oi.estimated_vs_actual_days,
    oi.item_count,
    oi.total_price,
    oi.total_freight,
    oi.order_value,
    p.payment_count,
    p.total_payment_value,
    r.avg_review_score
FROM order_items oi
LEFT JOIN payments p ON oi.order_id = p.order_id
LEFT JOIN reviews r ON oi.order_id = r.order_id