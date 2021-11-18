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

# Requires environment variables set in Airflow/Composer
# env_data_lake_bucket="sa-datalake-myid-dev"
# env_ingestion_bucket="sa-ingestion-myid-dev"
# env_zone="us-west2-a"
# env_environment="myid-dev" 

# [START composer_dag]
import os
import datetime
import logging
import airflow
from airflow.operators import bash_operator
from airflow.utils import trigger_rule
from airflow.providers.google.cloud.operators.datafusion import (
    CloudDataFusionCreateInstanceOperator,
    CloudDataFusionCreatePipelineOperator,
    CloudDataFusionDeleteInstanceOperator,
    CloudDataFusionDeletePipelineOperator,
    CloudDataFusionGetInstanceOperator,
    CloudDataFusionListPipelinesOperator,
    CloudDataFusionRestartInstanceOperator,
    CloudDataFusionStartPipelineOperator,
    CloudDataFusionStopPipelineOperator,
    CloudDataFusionUpdateInstanceOperator,
)

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
datafusion_location  = os.environ['datafusion_location']
datafusion_name      = os.environ['datafusion_name']

if env_ingestion_bucket.startswith("gs://") == False:
    env_ingestion_bucket = "gs://" + env_ingestion_bucket

if env_data_lake_bucket.startswith("gs://") == False:
    env_data_lake_bucket = "gs://" + env_data_lake_bucket

logging.info("project_id:"           + project_id)
logging.info("env_ingestion_bucket:" + env_ingestion_bucket)
logging.info("env_data_lake_bucket:" + env_data_lake_bucket)
logging.info("project_environment:"  + project_environment)
logging.info("env_zone:"             + env_zone)
logging.info("datafusion_location:"  + datafusion_location)
logging.info("datafusion_name:"      + datafusion_name)

environment_underscore=project_environment.replace("-","_")

targetTable = "df_ga_sessions"
bqDataset = "sa_bq_dataset_" + environment_underscore
projectId = project_id
latestDate=""
stagingBucketPath=env_ingestion_bucket + "/datafusion/ga_sessions"
if stagingBucketPath.startswith("gs://"):
    stagingBucketPath = stagingBucketPath.replace("gs://","")

runtime_args= {
    "targetTable" : targetTable,
    "bqDataset" : bqDataset,
    "projectId" : projectId,
    "latestDate" : latestDate,
    "stagingBucketPath" : stagingBucketPath
}
logging.info("targetTable:"       + targetTable)
logging.info("bqDataset:"         + bqDataset)
logging.info("projectId:"         + projectId)
logging.info("latestDate:"        + latestDate)
logging.info("stagingBucketPath:" + stagingBucketPath)


with airflow.DAG('process-datafusion-etl-ml-modeling',
                 default_args=default_args,
                 # Not scheduled, trigger only
                 schedule_interval=None) as dag:

    start_pipeline = CloudDataFusionStartPipelineOperator(
        location=datafusion_location,
        pipeline_name="sa-datafusion-etl-ml-modeling",
        instance_name=datafusion_name,
        task_id="start_pipeline",
        runtime_args=runtime_args
    )
    
    start_pipeline

# [END composer_dag]