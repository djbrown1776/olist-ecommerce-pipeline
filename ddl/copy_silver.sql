-- ddl/copy_silver.sql

COPY silver.order_details
FROM 's3://olist-ecom-dev-33b0/silver/order_details/'
IAM_ROLE '<your-redshift-iam-role-arn>'
FORMAT AS PARQUET;

COPY silver.order_payments
FROM 's3://olist-ecom-dev-33b0/silver/order_payments/'
IAM_ROLE '<your-redshift-iam-role-arn>'
FORMAT AS PARQUET;

COPY silver.order_reviews
FROM 's3://olist-ecom-dev-33b0/silver/order_reviews/'
IAM_ROLE '<your-redshift-iam-role-arn>'
FORMAT AS PARQUET;