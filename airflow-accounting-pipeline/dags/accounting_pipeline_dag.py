from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator
from datetime import datetime
import yaml
import sys
from pathlib import Path


sys.path.append("/opt/airflow/accounting_pipeline")
from loader import run_loader
from loader import ensure_raw_schema

config_path = Path(__file__).with_name("dag_config.yaml")
with open(config_path, "r") as f:
    config = yaml.safe_load(f)

with DAG(
    dag_id='accounting_pipeline',
    start_date=datetime(2024, 1, 1),
    schedule=config["schedule"],
    catchup=config["catchup"],
) as dag:

    """First step"""
    ensure_raw_schema = PythonOperator(
        task_id='ensure_raw_schema',
        python_callable=ensure_raw_schema,
    )

    """Second step"""
    load_raw_data = PythonOperator(
        task_id='run_loader',
        python_callable=run_loader
    )

    """Third step"""
    run_dbt_seed = BashOperator(
       task_id='run_dbt_seed',
       bash_command=("cd /opt/airflow/accounting_pipeline && "
                      "dbt seed --profiles-dir /opt/airflow/accounting_pipeline"),
    )

    """Fourth step"""
    run_dbt_build = BashOperator(
        task_id='run_dbt_build',
        bash_command=(
            "cd /opt/airflow/accounting_pipeline && "
            "dbt build --profiles-dir /opt/airflow/accounting_pipeline"),
    )


    ensure_raw_schema >> load_raw_data >> run_dbt_seed >> run_dbt_build