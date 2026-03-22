
CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE silver.order_details (
    order_id                      VARCHAR(50),
    order_item_id                 INTEGER,
    price                         DOUBLE PRECISION,
    freight_value                 DOUBLE PRECISION,
    shipping_limit_date           TIMESTAMP,
    order_status                  VARCHAR(30),
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    customer_unique_id            VARCHAR(50),
    customer_city                 VARCHAR(100),
    customer_state                VARCHAR(5),
    product_id                    VARCHAR(50),
    product_category_name         VARCHAR(100),
    product_weight_g              INTEGER,
    product_length_cm             INTEGER,
    product_height_cm             INTEGER,
    product_width_cm              INTEGER,
    product_category_name_english VARCHAR(100),
    seller_id                     VARCHAR(50),
    seller_city                   VARCHAR(100),
    seller_state                  VARCHAR(5),
    total_item_value              DOUBLE PRECISION,
    delivery_days                 INTEGER,
    estimated_vs_actual_days      INTEGER
);

CREATE TABLE silver.order_payments (
    order_id                 VARCHAR(50),
    order_status             VARCHAR(30),
    order_purchase_timestamp TIMESTAMP,
    payment_sequential       INTEGER,
    payment_type             VARCHAR(30),
    payment_installments     INTEGER,
    payment_value            DOUBLE PRECISION
);

CREATE TABLE silver.order_reviews (
    order_id                 VARCHAR(50),
    order_status             VARCHAR(30),
    order_purchase_timestamp TIMESTAMP,
    review_id                VARCHAR(50),
    review_score             INTEGER,
    review_comment_title     VARCHAR(500),
    review_comment_message   VARCHAR(5000),
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);