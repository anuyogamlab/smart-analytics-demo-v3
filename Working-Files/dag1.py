# Used to show DAG level security (NOTE: You need to upgrade Cloud Composer/Airflow to 1.13.4)
# https://cloud.google.com/composer/docs/airflow-rbac
import os
import datetime
import logging
import airflow
from airflow.operators import bash_operator

default_args = {
    'owner': 'Dag 1',
    'depends_on_past': False,
    'email': [''],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': datetime.timedelta(minutes=5),
    'start_date': datetime.datetime(2017, 1, 1)
}

with airflow.DAG('dag_01',
                 default_args=default_args,
                 schedule_interval=None) as dag:

    # Print the dag_run's configuration
    task_01 = bash_operator.BashOperator(
        task_id='print_gcs_info', bash_command='echo {{ dag_run.conf["filename"] }}')

    task_01