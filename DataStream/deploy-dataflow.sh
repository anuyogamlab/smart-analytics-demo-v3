#!/bin/bash

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


#########################################################################################################################
# BEGIN: Commom code for ALL deploy / bash scripts.  Any changes must be copied and pasted in all files that use this!
#########################################################################################################################
echo "---------------------------------------------------------------------------------------------------------" 
echo "Parameters (read from a config file, you can have different configs for different environments)"
echo "---------------------------------------------------------------------------------------------------------" 
# Make sure we got a command line arguement
if [ "$1" = ""  ]; then
    echo "ERROR: You need to pass in a main-config.json file"
    exit 1
fi

# Get full path (important when passing to another program)
configJSONFilename=$(echo "$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")")

# Load JSON
configJSON=$(cat $configJSONFilename)

# Parse each value using jq
project=$(echo "$configJSON" | jq .project --raw-output)
GOOGLE_APPLICATION_CREDENTIALS=$(echo "$configJSON" | jq .GOOGLE_APPLICATION_CREDENTIALS --raw-output)
export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS
environment=$(echo "$configJSON" | jq .environment --raw-output)
looker_customer_id=$(echo "$configJSON" | jq .looker_customer_id --raw-output)
LOOKER_APPLICATION_CREDENTIALS=$(echo "$configJSON" | jq .LOOKER_APPLICATION_CREDENTIALS --raw-output)
looker_git_remote_url=$(echo "$configJSON" | jq .looker_git_remote_url --raw-output)
looker_origin=$(echo "$configJSON" | jq .looker_origin --raw-output)
oracle_install_zip=$(echo "$configJSON" | jq .oracle_install_zip --raw-output)

echo "CONFIG ==> configJSONFilename:             $configJSONFilename"
echo "CONFIG ==> project:                        $project"
echo "CONFIG ==> GOOGLE_APPLICATION_CREDENTIALS: $GOOGLE_APPLICATION_CREDENTIALS"
echo "CONFIG ==> environment:                    $environment"
echo "CONFIG ==> looker_customer_id:             $looker_customer_id"
echo "CONFIG ==> LOOKER_APPLICATION_CREDENTIALS: $LOOKER_APPLICATION_CREDENTIALS"
echo "CONFIG ==> looker_git_remote_url:          $looker_git_remote_url"
echo "CONFIG ==> looker_origin:                  $looker_origin"
echo "CONFIG --> oracle_install_zip:             $oracle_install_zip"
#########################################################################################################################
# END:   Commom code for ALL deploy / bash scripts.  Any changes must be copied and pasted in all files that use this!
#########################################################################################################################


echo "---------------------------------------------------------------------------------------------------------" 
echo "Setting names and locations (These could be placed in the config)"
echo "---------------------------------------------------------------------------------------------------------" 
# You can set these, but you need to ensure the location exists for each service
region="us-west2"
zone="us-west2-a"
datafusion_name="sa-datafusion-$environment"
datafusion_location="us-west2"
composer_name="sa-composer-$environment"
composer_location="us-west2"
composer_zone="us-west2-a"
cloudFunctionBucket="sa-ingestion-$environment"

echo "region:$region"
echo "zone:$zone"
echo "datafusion_name:$datafusion_name"
echo "datafusion_location:$datafusion_location"
echo "composer_name:$composer_name"
echo "composer_location:$composer_location"
echo "composer_zone:$composer_zone"
echo "cloudFunctionBucket:$cloudFunctionBucket"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Login using service account"
echo "---------------------------------------------------------------------------------------------------------" 
# The username of the service account (e.g.  "smart-analytics-dev-ops@smart-analytics-demo-01.iam.gserviceaccount.com" )
accountName=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email --raw-output)

gcloud auth activate-service-account $accountName --key-file=$GOOGLE_APPLICATION_CREDENTIALS --project=$project


echo "---------------------------------------------------------------------------------------------------------" 
echo "Getting access token"
echo "---------------------------------------------------------------------------------------------------------" 
# We need a token for making REST API calls
# Uses: GOOGLE_APPLICATION_CREDENTIALS https://cloud.google.com/docs/authentication/getting-started#setting_the_environment_variable
access_token=$(gcloud auth application-default print-access-token)


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating DataFlow"
echo "---------------------------------------------------------------------------------------------------------" 
searchString="-"
replaceString="_"
environment_with_underscores=$(echo "${environment//$searchString/$replaceString}")
echo "environment_with_underscores: $environment_with_underscores"

# Required Vars for deployment
BUCKET_NAME="gs://sa-datalake-${environment}"
TEMPLATE_IMAGE_SPEC=gs://teleport-dataflow-staging/images/datastream-to-bigquery-image-spec.json

GCS_STREAM_PATH=${BUCKET_NAME}/datastream/oracle/hr
GCS_DLQ_PATH=${BUCKET_NAME}/datastream/dlq/

STAGING_DATASET_TEMPLATE="sa_bq_dataset_${environment_with_underscores}_oracle"
STAGING_TABLE_NAME_TEMPLATE={_metadata_table}_log
DATASET_TEMPLATE="sa_bq_dataset_${environment_with_underscores}_oracle"
TABLE_NAME_TEMPLATE={_metadata_table}

MAX_NUM_WORKERS=10
FILE_READ_CONCURRENCY=30
JOB_START_DATETIME=1970-01-01T00:00:00.00Z

# Enable Required APIs
gcloud services enable \
    storage.googleapis.com \
    dataflow.googleapis.com \
    compute.googleapis.com \
    servicenetworking.googleapis.com \
    --project=${project}

# Dataflow Config Vars
#sudo apt-get install uuid-runtime
#NEW_UUID=$(uuidgen | head -c 6 | awk '{print tolower($0)}')
DATAFLOW_JOB_NAME="sa-datastream-$environment"

gcloud config set project ${project}
gcloud beta dataflow flex-template run "${DATAFLOW_JOB_NAME}" \
        --project="${project}" --region="${region}" \
        --template-file-gcs-location="${TEMPLATE_IMAGE_SPEC}" \
        --parameters inputFilePattern="${GCS_STREAM_PATH}",outputProjectId="${project}",outputStagingDatasetTemplate="${STAGING_DATASET_TEMPLATE}",outputStagingTableNameTemplate="${STAGING_TABLE_NAME_TEMPLATE}",outputDatasetTemplate="${DATASET_TEMPLATE}",outputTableNameTemplate="${TABLE_NAME_TEMPLATE}",deadLetterQueueDirectory="${GCS_DLQ_PATH}",maxNumWorkers=${MAX_NUM_WORKERS},autoscalingAlgorithm="THROUGHPUT_BASED",rfcStartDateTime="${JOB_START_DATETIME}",mergeFrequencyMinutes=15,fileReadConcurrency=${FILE_READ_CONCURRENCY}
