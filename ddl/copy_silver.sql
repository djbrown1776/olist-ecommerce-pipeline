-- Manual COPY commands for loading silver parquet from S3 into Redshift
-- The Airflow DAG handles this automatically via SQLExecuteQueryOperator + Airflow Variables
-- Replace <S3_BUCKET> and <REDSHIFT_IAM_ROLE_ARN> with your actual values

COPY silver.order_details
FROM 's3://<S3_BUCKET>/silver/order_details/'
IAM_ROLE '<REDSHIFT_IAM_ROLE_ARN>'
FORMAT AS PARQUET;

COPY silver.order_payments
FROM 's3://<S3_BUCKET>/silver/order_payments/'
IAM_ROLE '<REDSHIFT_IAM_ROLE_ARN>'
FORMAT AS PARQUET;

COPY silver.order_reviews
FROM 's3://<S3_BUCKET>/silver/order_reviews/'
IAM_ROLE '<REDSHIFT_IAM_ROLE_ARN>'
FORMAT AS PARQUET;
