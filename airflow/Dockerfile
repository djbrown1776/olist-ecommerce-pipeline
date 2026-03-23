FROM apache/airflow:2.9.1

USER root
RUN apt-get update && apt-get install -y libpq-dev gcc && rm -rf /var/lib/apt/lists/*
USER airflow

# Step 1: Install Airflow extras (already mostly satisfied by base image)
RUN pip install --no-cache-dir \
    pandas boto3 pyarrow sqlalchemy psycopg2-binary python-dotenv \
    "apache-airflow-providers-amazon==8.20.0"

# Step 2: Install dbt pinned to exact compatible versions
RUN pip install --no-cache-dir \
    "dbt-core==1.8.9" \
    "dbt-postgres==1.8.2" \
    "dbt-redshift==1.8.1" \
    "dbt-adapters>=0.1.0,<2.0" \
    "dbt-common>=0.1.0,<2.0" \
    "protobuf>=4.0,<5.0" \
    "agate<1.10"
