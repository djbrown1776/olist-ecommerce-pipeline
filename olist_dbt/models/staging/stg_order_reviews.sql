
WITH source AS (
    SELECT * FROM {{ source('silver', 'order_payments') }}
)

SELECT
    -- Keys
    order_id,

    -- Order info
    order_status,
    order_purchase_timestamp,

    -- Payment details
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value

FROM source