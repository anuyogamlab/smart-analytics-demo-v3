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



"""https://cloud.google.com/composer/docs/tutorials/hadoop-wordcount-job"""

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

project_id   = os.environ['GCP_PROJECT'] 
input_path   = os.environ['env_ingestion_bucket'] 
output_path  = os.environ['env_data_lake_bucket']
project_environment  = os.environ['env_environment']

logging.info("project_id:" + project_id)
logging.info("input_path:" + input_path)
logging.info("output_path:" + output_path)
logging.info("project_environment:" + project_environment)

environment_underscore=project_environment.replace("-","_")
hard_code_TEST="customer01/ga_sessions/2017-06-03/end_file.txt"
load_table=hard_code_TEST.replace("/end_file.txt","").replace("/","_").replace("-","_")

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

with airflow.DAG('bq-dag',
                 default_args=default_args,
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    # https://cloud.google.com/composer/docs/how-to/using/writing-dags#gcp_operators
    # https://github.com/GoogleCloudPlatform/python-docs-samples/blob/f89ac82ea18a08398cc54762c638c686c6f938fa/composer/workflows/bq_notify.py
    bq_load_ga_sessions = bigquery_operator.BigQueryOperator(
        task_id='process-customer-file-upload',
        bql=query.format(project_id=project_id,environment_underscore=environment_underscore,load_table=load_table),
        use_legacy_sql=False)

    bq_drop_load_table = bigquery_operator.BigQueryOperator(
        task_id='process-customer-file-upload',
        bql="DROP TABLE `{project_id}.sa_bq_dataset_{environment_underscore}.{load_table}`".format(project_id=project_id,environment_underscore=environment_underscore,load_table=load_table),
        use_legacy_sql=False)

    bq_load_ga_sessions

# [END composer_trigger_response_dag]