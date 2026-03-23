
WITH source AS (
    SELECT * FROM {{ source('silver', 'order_reviews') }}
)

SELECT
    -- Keys
    order_id,
    review_id,

    -- Order info
    order_status,
    order_purchase_timestamp,

    -- Review details
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp

FROM source
