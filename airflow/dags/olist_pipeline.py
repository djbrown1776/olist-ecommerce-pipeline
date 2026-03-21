from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.ecs import EcsRunTaskOperator

default_args = {
    'owner': 'tank',
    'retries': 2,
    'retry_delay': timedelta(minutes=5)
    }

with DAG(
    dag_id='olist_ecs_pipeline',          
    default_args=default_args,
    description='Fetch olist data and load to S3 via ECS Fargate',
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
                'subnets': [
                    'subnet-051ddc87ff8f49aef',
                    'subnet-0ae2456871f5e54c9',
                    'subnet-0fc2ec5bceb602fc2',
                ],
                'securityGroups': ['sg-08a0269ac418cd3db'],   
                'assignPublicIp': 'ENABLED',
            }
        },
        awslogs_group='/ecs/olist-ecommerce-pipeline',
        awslogs_stream_prefix='ecs/olist-ecommerce-pipeline',
    )