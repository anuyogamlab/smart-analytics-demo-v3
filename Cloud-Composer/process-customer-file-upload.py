# Copyright 2021 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Reference: https://cloud.google.com/composer/docs/tutorials/hadoop-wordcount-job

# Requires environment variables set in Airflow/Composer
# env_data_lake_bucket="sa-datalake-myid-dev"
# env_ingestion_bucket="sa-ingestion-myid-dev"
# env_zone="us-west2-a"
# env_environment="myid-dev" 

# [START composer_trigger_response_dag]
import os
import datetime
import logging
import airflow
from airflow.operators import bash_operator
from airflow.contrib.operators import dataproc_operator
from airflow.utils import trigger_rule
from airflow.contrib.operators import bigquery_operator

default_args = {
    'owner': 'Smart Anlaytics',
    'depends_on_past': False,
    'email': [''],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': datetime.timedelta(minutes=5),
    'start_date': datetime.datetime(2017, 1, 1)
}

project_id           = os.environ['GCP_PROJECT'] 
env_ingestion_bucket = os.environ['env_ingestion_bucket'] 
env_data_lake_bucket = os.environ['env_data_lake_bucket']
project_environment  = os.environ['env_environment']
env_zone             = os.environ['env_zone']

# It seems like the gs:// get removed sometimes when altering the environment variables via the console
if env_ingestion_bucket.startswith("gs://") == False:
    env_ingestion_bucket = "gs://" + env_ingestion_bucket

if env_data_lake_bucket.startswith("gs://") == False:
    env_data_lake_bucket = "gs://" + env_data_lake_bucket
    
logging.info("project_id:"           + project_id)
logging.info("env_ingestion_bucket:" + env_ingestion_bucket)
logging.info("env_data_lake_bucket:" + env_data_lake_bucket)
logging.info("project_environment:"  + project_environment)
logging.info("env_zone:"             + env_zone)

# For BigQuery table names avoid dashes
environment_underscore=project_environment.replace("-","_")


# Query to load from the parquet staging table to the final table
query="""
INSERT INTO `{project_id}.sa_bq_dataset_{environment_underscore}.ga_sessions` 
      (visitId, visitNumber, visitStartTime, channelGrouping, date, fullVisitorId, socialEngagementType,
       totals, trafficSource, device, geoNetwork, hits)
SELECT *
  FROM (SELECT stagingTable.visitId,
               stagingTable.visitNumber,
               stagingTable.visitStartTime,
               stagingTable.channelGrouping,
               stagingTable.date,
               stagingTable.fullVisitorId,
               stagingTable.socialEngagementType,
               stagingTable.totals,
               stagingTable.trafficSource,
               stagingTable.device,
               stagingTable.geoNetwork,
               HitsNested.hits_array
          FROM (
                SELECT visitId,
                       visitNumber,  
                       visitStartTime,  
                       fullVisitorId,  
                       ARRAY_AGG(hits) AS hits_array
                 FROM (
                        SELECT load_table.visitId,
                              load_table.visitNumber,  
                              load_table.visitStartTime,  
                              load_table.channelGrouping,  
                              load_table.date,  
                              load_table.fullVisitorId,  
                              load_table.socialEngagementType,  
                              load_table.totals,  
                              load_table.trafficSource,  
                              load_table.device,  
                              load_table.geoNetwork,  
                              STRUCT(hits_list.element.type, 
                                     hits_list.element.time,
                                     hits_list.element.hitNumber,
                                     hits_list.element.isEntrance,
                                     hits_list.element.isExit,
                                     hits_list.element.isExit,
                                     hits_list.element.page,
                                     hits_list.element.transaction) AS hits
                         FROM `{project_id}.sa_bq_dataset_{environment_underscore}.{load_table}` AS load_table
                              CROSS JOIN UNNEST(load_table.hits.list) AS hits_list
                      ) AS LoadData
                GROUP BY visitId,
                         visitNumber,  
                         visitStartTime,  
                         fullVisitorId                      
                ) AS  HitsNested
        INNER JOIN `{project_id}.sa_bq_dataset_{environment_underscore}.{load_table}` AS stagingTable
        ON  stagingTable.visitId = HitsNested.visitId
        AND stagingTable.visitNumber = HitsNested.visitNumber
        AND stagingTable.visitStartTime = HitsNested.visitStartTime
        AND stagingTable.fullVisitorId = HitsNested.fullVisitorId)"""


with airflow.DAG('process-customer-file-upload',
                 default_args=default_args,
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # Print the dag_run's configuration
    #print_gcs_info = bash_operator.BashOperator(
    #    task_id='print_gcs_info', bash_command='echo {{ dag_run.conf["filename"] }}')


    # Create a Cloud Dataproc cluster.
    # Add in the BigQuery load connector as an init script
    create_dataproc_cluster = dataproc_operator.DataprocClusterCreateOperator(
        default_args=default_args,
        task_id='create-dataproc-cluster',
        cluster_name='process-customer-file-upload-{{ ts_nodash.lower() }}',
        init_actions_uris=["gs://goog-dataproc-initialization-actions-us-west4/connectors/connectors.sh"],
        metadata={ "gcs-connector-version":"2.1.1", "bigquery-connector-version":"1.1.1", "spark-bigquery-connector-version":"0.13.1-beta"},
        project_id=project_id,
        num_workers=2,
        zone=env_zone,
        master_machine_type='n1-standard-1',
        worker_machine_type='n1-standard-1')


    # Run the Spark code move the data from the ingestion bucket to the bronze -> silver -> gold zones in the data lake
    run_dataproc_spark = dataproc_operator.DataProcPySparkOperator(
        default_args=default_args,
        task_id='task-process-customer-file-upload',
        main=env_data_lake_bucket + "/dataproc/process-ingestion-pyspark.py",
        cluster_name='process-customer-file-upload-{{ ts_nodash.lower() }}',
        arguments=[env_ingestion_bucket, env_data_lake_bucket, '{{ dag_run.conf["filename"] }}', project_environment])


    # Delete Cloud Dataproc cluster
    delete_dataproc_cluster = dataproc_operator.DataprocClusterDeleteOperator(
        default_args=default_args,
        task_id='delete-dataproc-cluster',
        project_id=project_id,
        cluster_name='process-customer-file-upload-{{ ts_nodash.lower() }}',
        # Setting trigger_rule to ALL_DONE causes the cluster to be deleted even if the Dataproc job fails.
        trigger_rule=trigger_rule.TriggerRule.ALL_DONE)


    # Load the data from the staging table to the final table
    # https://cloud.google.com/composer/docs/how-to/using/writing-dags#gcp_operators
    # https://github.com/GoogleCloudPlatform/python-docs-samples/blob/f89ac82ea18a08398cc54762c638c686c6f938fa/composer/workflows/bq_notify.py
    bq_load_ga_sessions = bigquery_operator.BigQueryOperator(
        task_id='process-customer-file-upload-etl',
        bql=query.format(project_id=project_id,environment_underscore=environment_underscore,
        load_table='{{ dag_run.conf["filename"].replace("/end_file.txt","").replace("/","_").replace("-","_")}}'),
        use_legacy_sql=False)


    # Drop the table the parquet file was loaded into (basically a staging table)
    bq_drop_load_table = bigquery_operator.BigQueryOperator(
        task_id='process-customer-file-upload-drop',
        bql="DROP TABLE `{project_id}.sa_bq_dataset_{environment_underscore}.{load_table}`".format(project_id=project_id,environment_underscore=environment_underscore,
        load_table='{{ dag_run.conf["filename"].replace("/end_file.txt","").replace("/","_").replace("-","_")}}'),
        use_legacy_sql=False)


    # print_gcs_info >> create_dataproc_cluster >> run_dataproc_spark >> delete_dataproc_cluster >> bq_load_ga_sessions >> bq_drop_load_table
    create_dataproc_cluster >> run_dataproc_spark >> delete_dataproc_cluster >> bq_load_ga_sessions >> bq_drop_load_table

# [END composer_trigger_response_dag]