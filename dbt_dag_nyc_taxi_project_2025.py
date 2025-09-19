import os
from datetime import datetime,timedelta
from airflow import DAG
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping
from cosmos.operators import DbtRunOperationOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.operators.empty import EmptyOperator
from cosmos.config import RenderConfig
from airflow.operators.bash import BashOperator

with DAG(
    's3_to_snowflake_dbt',
    start_date = datetime(2025,9,11),
    schedule= None, ##@'monthly'later
    catchup = False,
    description = 'Copy data from S3 to Snowflake raw tables',
    default_args = {
        'retries': 0,
        'retry_delay': timedelta(minutes=0)
    }
) as dag:
    
    start = EmptyOperator(task_id = 'start')

    copy_green_taxi = SQLExecuteQueryOperator(
        task_id = 'copy_green_taxt_data',
        sql = '''USE DATABASE dbt_db_nyctaxi;
           USE SCHEMA L1_LANDING;
           COPY INTO green_taxi
            FROM @snow_stage_nyctaxi
            FILE_FORMAT = (TYPE = 'PARQUET')
            MATCH_BY_COLUMN_NAME = 'CASE_INSENSITIVE'
            PATTERN = 'green_tripdata_2025-01.parquet' 
        ''',  ##{{ execution_date.strftime("%Y-%m") }}
        conn_id="snowflake_conn"
    )
    copy_yellow_taxi = SQLExecuteQueryOperator(
    task_id = 'copy_yellow_taxt_data',
    sql = '''USE DATABASE dbt_db_nyctaxi;
           USE SCHEMA L1_LANDING;
           COPY INTO yellow_taxi
            FROM @snow_stage_nyctaxi
            FILE_FORMAT = (TYPE = 'PARQUET')
            MATCH_BY_COLUMN_NAME = 'CASE_INSENSITIVE'
            PATTERN = 'yellow_tripdata_2025-01.parquet' 
        ''',  ##{{ execution_date.strftime("%Y-%m") }}
    conn_id="snowflake_conn"
    )

    profile_config = ProfileConfig(
        profile_name="default",
        target_name="dev",
        profile_mapping=SnowflakeUserPasswordProfileMapping(
            conn_id="snowflake_conn",
            profile_args={"database": "dbt_db_nyctaxi", "schema": "L1_LANDING"}
        )
    )

    with DbtTaskGroup(
        group_id = "taxi_data_transformation",
        project_config=ProjectConfig("/usr/local/airflow/dags/nyc_taxi_project2025"),
        profile_config=profile_config,
        operator_args={"install_deps": True},
        render_config=RenderConfig(dbt_deps=True)
    ) as dbt_tg:
        pass

    run_operation_task = DbtRunOperationOperator(
        task_id="insert_processing_log",
        macro_name="metadata_insert_processing_log",
        args={"table_name": "stg_taxi"},
        project_dir="/usr/local/airflow/dags/nyc_taxi_project2025",
        profile_config=profile_config
    )

    end = EmptyOperator(task_id = 'end')

start >> [copy_green_taxi, copy_yellow_taxi] >> dbt_tg >>run_operation_task >> end