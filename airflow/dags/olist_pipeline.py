import os
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.ecs import EcsRunTaskOperator
from airflow.providers.amazon.aws.operators.glue import GlueJobOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.operators.bash import BashOperator
from airflow.utils.task_group import TaskGroup

# Set these in Airflow Variables or environment
ECS_SUBNETS = os.environ.get('ECS_SUBNETS', '').split(',')
ECS_SECURITY_GROUP = os.environ.get('ECS_SECURITY_GROUP', '')

default_args = {
    'owner': 'airflow',
    'retries': 2,
    'retry_delay': timedelta(minutes=5)
    }

with DAG(
    dag_id='olist_ecs_pipeline',
    default_args=default_args,
    description='End to end Olist pipeline: ingest, transform, load, model',
    start_date=datetime(2026, 3, 14),
    schedule_interval='@daily',
    catchup=False,
    tags=['olist', 'ecs', 'pipeline'],
) as dag:

    fetch_olist = EcsRunTaskOperator(
        task_id='fetch_olist_to_s3',
        cluster='olist-ecommerce-pipeline-cluster',
        task_definition='olist-ecommerce-pipeline',
        launch_type='FARGATE',
        overrides={},
        network_configuration={
            'awsvpcConfiguration': {
                'subnets': ECS_SUBNETS,
                'securityGroups': [ECS_SECURITY_GROUP],
                'assignPublicIp': 'ENABLED',
            }
        },
        awslogs_group='/ecs/olist-ecommerce-pipeline',
        awslogs_stream_prefix='ecs/olist-ecommerce-pipeline',
    )

    run_glue_transform = GlueJobOperator(
        task_id='run_glue_transform',
        job_name='olist-ecommerce-pipeline-transform',
        wait_for_completion=True,
        verbose=True,
    )

    truncate_order_details = SQLExecuteQueryOperator(
        task_id='truncate_order_details',
        conn_id='redshift_default',
        sql="TRUNCATE silver.order_details;",
    )

    truncate_order_payments = SQLExecuteQueryOperator(
        task_id='truncate_order_payments',
        conn_id='redshift_default',
        sql="TRUNCATE silver.order_payments;",
    )

    truncate_order_reviews = SQLExecuteQueryOperator(
        task_id='truncate_order_reviews',
        conn_id='redshift_default',
        sql="TRUNCATE silver.order_reviews;",
    )

    copy_order_details = SQLExecuteQueryOperator(
        task_id='copy_order_details',
        conn_id='redshift_default',
        sql="""
            COPY silver.order_details
            FROM 's3://{{ var.value.s3_bucket }}/silver/order_details/'
            IAM_ROLE '{{ var.value.redshift_iam_role_arn }}'
            FORMAT AS PARQUET;
        """,
    )

    copy_order_payments = SQLExecuteQueryOperator(
        task_id='copy_order_payments',
        conn_id='redshift_default',
        sql="""
            COPY silver.order_payments
            FROM 's3://{{ var.value.s3_bucket }}/silver/order_payments/'
            IAM_ROLE '{{ var.value.redshift_iam_role_arn }}'
            FORMAT AS PARQUET;
        """,
    )

    copy_order_reviews = SQLExecuteQueryOperator(
        task_id='copy_order_reviews',
        conn_id='redshift_default',
        sql="""
            COPY silver.order_reviews
            FROM 's3://{{ var.value.s3_bucket }}/silver/order_reviews/'
            IAM_ROLE '{{ var.value.redshift_iam_role_arn }}'
            FORMAT AS PARQUET;
        """,
    )

    dbt_run = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/airflow/dbt && dbt run --profiles-dir /home/airflow/.dbt',
    )

    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/airflow/dbt && dbt test --profiles-dir /home/airflow/.dbt',
    )

    with TaskGroup("truncate_silver") as truncate_group:
        truncate_order_details
        truncate_order_payments
        truncate_order_reviews

    with TaskGroup("copy_silver") as copy_group:
        copy_order_details
        copy_order_payments
        copy_order_reviews

    fetch_olist >> run_glue_transform >> truncate_group >> copy_group >> dbt_run >> dbt_test
