
WITH source AS (
    SELECT * FROM {{ source('silver', 'order_details') }}
)

SELECT
    -- Keys
    order_id,
    order_item_id,
    customer_unique_id,
    product_id,
    seller_id,

    -- Order info
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    shipping_limit_date,

    -- Financials
    price,
    freight_value,
    total_item_value,

    -- Delivery metrics
    delivery_days,
    estimated_vs_actual_days,

    -- Product attributes
    product_category_name,
    product_category_name_english,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,

    -- Geography
    customer_city,
    customer_state,
    seller_city,
    seller_state

FROM source