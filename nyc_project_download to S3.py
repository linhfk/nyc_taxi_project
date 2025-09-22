from airflow import DAG
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import requests  

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def download_and_upload_to_s3(**kwargs):
    execution_date = kwargs['execution_date']
    previous_month = execution_date - timedelta(days=execution_date.day)
    year = previous_month.year
    month = previous_month.month
    #year = 2024
    #month = 8

    base_url = "https://d37ci6vzurychx.cloudfront.net/trip-data"
    s3_hook = S3Hook(aws_conn_id="aws_connection")

    files = [
        f"green_tripdata_{year}-{month:02d}.parquet",
        f"yellow_tripdata_{year}-{month:02d}.parquet"
    ]

    for filename in files:
        url = f"{base_url}/{filename}"
        try:
            print(f"Downloading {url}...")
            response = requests.get(url, stream=True)
            response.raise_for_status()

            # Upload directly to S3
            s3_key = f"{filename}"
            s3_hook.load_bytes(
                response.content,
                key=s3_key,
                bucket_name="nyctaxiproject2025",
                replace=True
            )
            print(f"Successfully uploaded {filename} to S3")

        except Exception as e:
            print(f"Failed to process {filename}: {str(e)}")
            raise


with DAG(
    'nyc_taxi_to_s3', 
    default_args=default_args,
    description='Download NYC taxi data and upload to S3',
    schedule='0 0 1 15 *', 
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['nyc-taxi', 's3'],
) as dag:

    download_to_s3 = PythonOperator(
        task_id='download_direct_to_s3',
        python_callable=download_and_upload_to_s3,
        op_kwargs={'execution_date': "{{ execution_date }}"},
        execution_timeout=timedelta(minutes=10)
    )

    download_to_s3