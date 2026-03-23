# Olist E-Commerce Analytics Pipeline

End-to-end analytics pipeline for the Brazilian Olist e-commerce dataset. Ingests 9 tables from Kaggle, lands raw Parquet in S3, transforms to a silver layer with PySpark on AWS Glue, loads to Redshift Serverless, then builds dimensional models with dbt — all orchestrated by Airflow.

## Architecture

```
Kaggle (Olist Dataset)
  │
  ▼
Python Ingestion (ECS Fargate)     ← Dockerized, pulls 9 CSVs → Parquet
  │
  ▼
AWS S3 — raw/                      ← 9 tables as date-partitioned Parquet
  │
  ▼
PySpark on AWS Glue                ← Joins, type casting, computed columns
  │
  ▼
AWS S3 — silver/                   ← 3 silver tables: order_details, order_payments, order_reviews
  │
  ▼
Amazon Redshift Serverless         ← COPY from S3 Parquet, truncate-and-load
  │
  ▼
dbt (staging → marts)             ← fct_orders, dim_customers, dim_products
  │
  ▼
Apache Airflow                     ← Full DAG: ingest → Glue → truncate → COPY → dbt run → dbt test

Infrastructure: Terraform (ECS, ECR, S3, Glue, Redshift Serverless, IAM, CloudWatch)
```

## Tech Stack

| Layer | Tool |
|---|---|
| Data Source | Kaggle (Brazilian Olist E-Commerce) |
| Ingestion | Python, KaggleHub, Pandas, Boto3 |
| Compute (Ingestion) | AWS ECS Fargate (Docker) |
| Raw Storage | AWS S3 (Parquet) |
| Transformation | PySpark on AWS Glue |
| Silver Storage | AWS S3 (Parquet) |
| Warehouse | Amazon Redshift Serverless |
| Modeling | dbt (staging views + mart tables) |
| Orchestration | Apache Airflow (Docker Compose, LocalExecutor) |
| Infrastructure | Terraform |
| Container Registry | AWS ECR |
| Secrets | AWS Secrets Manager (Kaggle API token) |

## Project Structure

```
olist-ecommerce-pipeline/
├── ingestion/
│   ├── ingest.py           # Kaggle → S3 ingest script
│   ├── Dockerfile
│   └── requirements.txt
├── spark/
│   └── transform.py        # PySpark Glue job
├── ddl/
│   ├── create_tables.sql   # Redshift schema + silver tables
│   └── copy_silver.sql     # Manual COPY reference (DAG handles this automatically)
├── olist_dbt/
│   ├── dbt_project.yml
│   └── models/
│       ├── staging/        # Views over silver tables
│       └── marts/          # fct_orders, dim_customers, dim_products
├── airflow/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── dags/
│       └── olist_pipeline.py
├── terraform/
│   ├── main.tf             # All AWS resources
│   ├── variables.tf
│   └── outputs.tf
├── .env.example
└── airflow/.env.example
```

## Pipeline Details

### 1. Ingestion
Dockerized Python script uses KaggleHub to download the Olist dataset (9 CSVs), converts each to Parquet with a `loaded_at` timestamp, and uploads to S3 under `raw/{table_name}/`. Runs on ECS Fargate with Kaggle credentials injected from Secrets Manager.

### 2. Transformation (PySpark/Glue)
AWS Glue job runs a PySpark script that reads 8 raw tables, joins them into 3 silver-layer tables designed by grain:
- `order_details` — order-item grain, 7-way join
- `order_payments` — payment-sequential grain
- `order_reviews` — review grain

Adds computed columns: `total_item_value`, `delivery_days`, `estimated_vs_actual_days`. Writes coalesced Parquet to `silver/`.

### 3. Loading (Redshift)
Airflow truncates the silver tables in Redshift, then runs COPY commands to load from S3 Parquet. IAM role ARN is pulled from Airflow Variables for security.

### 4. Modeling (dbt)
Staging layer exposes the three silver tables as views. Mart layer builds:
- `fct_orders` — one row per order, aggregated items/payments/reviews with LEFT JOINs
- `dim_customers` — lifetime value, repeat customer flag, latest address via ROW_NUMBER
- `dim_products` — sales metrics per product

Schema tests enforce uniqueness, not-null, and accepted values.

### 5. Orchestration (Airflow)
DAG chains: ECS ingest → Glue transform → parallel truncate → parallel COPY → dbt run → dbt test.

### 6. Infrastructure (Terraform)
Provisions S3 (versioned, encrypted, public access blocked), ECR, ECS cluster + task definition, Glue job + IAM, Redshift Serverless (namespace + workgroup + security group), and all IAM roles with least-privilege policies.

## How to Run

### Prerequisites
- AWS CLI configured with appropriate permissions
- Docker
- Terraform >= 1.0
- Python >= 3.12

### 1. Provision infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### 2. Build and push ingestion image
```bash
# Get ECR URL from terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)

cd ingestion
docker build -t olist-ingest .
docker tag olist-ingest:latest $ECR_URL:latest

aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL
docker push $ECR_URL:latest
```

### 3. Upload Glue script
```bash
BUCKET=$(terraform -chdir=terraform output -raw bucket_name)
aws s3 cp spark/transform.py s3://$BUCKET/scripts/transform.py
```

### 4. Configure environment variables
```bash
cp .env.example .env
cp airflow/.env.example airflow/.env
# Edit both files with your actual values
```

Set the following Airflow Variables (via the Airflow UI or CLI):
- `s3_bucket` — your S3 bucket name
- `redshift_iam_role_arn` — IAM role ARN from `terraform output redshift_iam_role_arn`

### 5. Start Airflow
```bash
cd airflow
docker compose up
```

Open [http://localhost:8080](http://localhost:8080), configure the `redshift_default` connection, and trigger the `olist_ecs_pipeline` DAG.

## Key Design Decisions

**Medallion architecture (raw → silver → mart):** Clean separation of concerns; raw preserves source fidelity, silver handles denormalization and type casting, marts serve analytics.

**PySpark on AWS Glue:** Managed Spark avoids cluster management while enabling complex multi-table joins at scale. Silver tables designed by grain reduce downstream complexity.

**Redshift Serverless:** Pay-per-query eliminates idle cluster costs for a portfolio project. COPY from Parquet is Redshift's most efficient loading method.

**Truncate-and-load:** Simple idempotency — safe reruns without duplicate data.

**Parallel task groups:** Truncates and COPYs run concurrently within Airflow task groups since they're independent operations on separate tables.

**Secrets Manager:** Kaggle API token injected at container runtime via ECS secrets, never stored in code or environment files.

## Author

Daniel Brown
