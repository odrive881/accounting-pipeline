from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator
from datetime import datetime

import sys
sys.path.append("/opt/airflow")             #?????
from accounting_pipeline.loader import run_loader


with DAG(
    dag_id='accounting_pipeline',
    start_date=datetime(2024, 1, 1),
    schedule="@daily",
    catchup=False,
) as dag:


    """First step"""
    load_raw_data = PythonOperator(
        task_id='run_loader',
        python_callable=run_loader,
    )

    """Second step"""
    run_dbt_build = BashOperator(
        task_id='run_dbt_build',
        bash_command=("cd /opt/airflow/accounting_pipeline && "
                      "dbt build --profiles-dir /opt/airflow/accounting_pipeline")        #this is a directory-command-directory chain that instructs dbt to find it's installation ()
    ),

    load_raw_data >> run_dbt_build