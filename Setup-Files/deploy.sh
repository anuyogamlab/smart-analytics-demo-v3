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


# References:
# https://cloud.google.com/deployment-manager/docs/how-to
# https://cloud.google.com/deployment-manager/docs/configuration/supported-resource-types
# https://github.com/GoogleCloudPlatform/deploymentmanager-samples/tree/master/google/resource-snippets
# https://cloud.google.com/resource-manager/reference/rest
#    https://cloud.google.com/data-fusion/docs/reference/rest
#    https://cloud.google.com/composer/docs/reference/rest/v1beta1/projects.locations.environments/create

# Used to deploy the environment
# x Storage         (deployment manager)
# x Dataproc        (deployment manager)
# x Pub/Sub         (deployment manager)
# x Composer        (deployment manager not supported, used REST)
# x Data Fusion     (deployment manager not supported, used REST)
# x Data Catalog    (deployment manager not supported, used gcloud to enable to API)
# x Dataflow        Created as part of Airflow  (what do we want to create? deployment manager not supported)
# x BigQuery        (deployment manager supports dataset / table)
# x Looker          (deployment manager not supported, used REST)
# AI Platform       (what do we want to create? deployment manager not supported)
# Monitoring        (MUST use GCP Console, no automation support)


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
echo "Enabling Google Cloud APIs"
echo "---------------------------------------------------------------------------------------------------------" 
# gcloud services list
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable datafusion.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable datacatalog.googleapis.com 
gcloud services enable composer.googleapis.com 
gcloud services enable cloudfunctions.googleapis.com


echo "---------------------------------------------------------------------------------------------------------" 
echo "Getting access token"
echo "---------------------------------------------------------------------------------------------------------" 
# We need a token for making REST API calls
# Uses: GOOGLE_APPLICATION_CREDENTIALS https://cloud.google.com/docs/authentication/getting-started#setting_the_environment_variable
access_token=$(gcloud auth application-default print-access-token)

# Get the project Number
projects=$(curl --silent "https://cloudresourcemanager.googleapis.com/v1/projects" \
            -H "Authorization: Bearer $access_token")

projectNumber=$(echo "$projects "| jq ".projects[] | select(.projectId == \"$project\") | .projectNumber" --raw-output)

echo "projectNumber:$projectNumber"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Cloud Deployment"
echo "---------------------------------------------------------------------------------------------------------" 
# Run the "today/deployment name" over and over during debugging to generate unique deployment names
today=`date +%Y-%m-%d-%H-%M-%S`
deploymentName="data-analytics-$today"
gcloud deployment-manager deployments create $deploymentName \
    --template deploy.jinja \
    --description $deploymentName \
    --properties project:$project,projectNumber:$projectNumber,region:$region,zone:$zone,environment:$environment

echo "deploymentName: $deploymentName"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Data Fusion"
echo "---------------------------------------------------------------------------------------------------------" 
access_token=$(gcloud auth application-default print-access-token)
voidResult=$(curl --silent -X POST "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances?instanceId=$datafusion_name" \
    -H "Authorization: Bearer $access_token")
 

echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Cloud Composer"
echo "---------------------------------------------------------------------------------------------------------" 
softwareConfigJSON="{ \
  \"imageVersion\": \"composer-1.13.3-airflow-1.10.10\", \
  \"envVariables\": { \
     \"env_data_lake_bucket\":\"gs://sa-datalake-$environment\", \
     \"env_ingestion_bucket\":\"gs://sa-ingestion-$environment\", \
     \"env_environment\":\"$environment\", \
     \"env_zone\":\"$zone\", \
     \"datafusion_location\":\"$datafusion_location\", \
     \"datafusion_name\":\"$datafusion_name\" \
  }, \
  \"pythonVersion\": \"3\"
}"

webServerConfig="{ \
  \"machineType\": \"composer-n1-webserver-2\" \
}"

nodeConfigJSON="{ \
  \"location\": \"projects/$project/zones/$composer_zone\", \
  \"machineType\": \"projects/$project/zones/$composer_zone/machineTypes/n1-standard-1\", \
  \"diskSizeGb\": 20
}"

privateEnvironmentConfigJSON="{
  \"enablePrivateEnvironment\": false \
}"

databaseConfig="{ \
  \"machineType\": \"db-n1-standard-2\" \
}"

environmentConfigJSON="{ \
  \"nodeCount\": 3, \
  \"softwareConfig\": $softwareConfigJSON, \
  \"webServerConfig\": $webServerConfig, \
  \"nodeConfig\": $nodeConfigJSON, \
  \"privateEnvironmentConfig\": $privateEnvironmentConfigJSON, \
  \"databaseConfig\": $databaseConfig \
}"

environmentJSON="{ \
  \"name\": \"projects/$project/locations/$composer_location/environments/$composer_name\", \
  \"config\": $environmentConfigJSON \
}"

echo "environmentJSON: $environmentJSON"

# Get a fresh one since they expire in an hour
access_token=$(gcloud auth application-default print-access-token)

voidResult=$(curl --silent -X POST "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data "$environmentJSON")


echo "---------------------------------------------------------------------------------------------------------" 
echo "Upload PySpark code"
echo "---------------------------------------------------------------------------------------------------------" 
pathToUpload="gs://sa-datalake-$environment/dataproc/" 
gsutil cp ../Cloud-Dataproc/* $pathToUpload


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating BigQuery table"
echo "---------------------------------------------------------------------------------------------------------" 
datasetName="sa-bq-dataset-$environment"
searchString="-"
replaceString="_"
datasetName_with_underscores=$(echo "${datasetName//$searchString/$replaceString}")
bq mk --table \
    --schema ../BigQuery/sa-analytics-schema.json \
    --time_partitioning_field date \
    --time_partitioning_type DAY \
    --description "Google Analytics Data" \
    --label environment:$environment \
    $project:$datasetName_with_underscores.ga_sessions 


echo "---------------------------------------------------------------------------------------------------------" 
echo "Waiting for Cloud Composer and Data Fusion to be created"
echo "---------------------------------------------------------------------------------------------------------"
access_token=$(gcloud auth application-default print-access-token)

stateDataFusion=$(curl --silent "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
    -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

stateCloudComposer=$(curl --silent "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments/$composer_name" \
    -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

echo "stateDataFusion: $stateDataFusion"
echo "stateCloudComposer: $stateCloudComposer"

while [ "$stateDataFusion" == "CREATING" ] ||  [ "$stateCloudComposer" == "CREATING" ]
    do
    sleep 5
    stateDataFusion=$(curl --silent "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
        -H "Authorization: Bearer $access_token" | jq .state --raw-output) 
    echo "stateDataFusion: $stateDataFusion"
    stateCloudComposer=$(curl --silent "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments/$composer_name" \
        -H "Authorization: Bearer $access_token" | jq .state --raw-output) 
    echo "stateCloudComposer: $stateCloudComposer"
    done

# Display Cloud Composer information
# dagGcsPrefix=$(curl --silent "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments/$composer_name" \
#     -H "Authorization: Bearer $access_token" | jq .config.dagGcsPrefix --raw-output) 
# echo "Cloud Composer DAG Bucket: $dagGcsPrefix"

# This is needed for the Cloud Function to be deployed
airflowUri=$(curl --silent "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments/$composer_name" \
    -H "Authorization: Bearer $access_token" | jq .config.airflowUri --raw-output) 
echo "Cloud Composer airflowUri: $airflowUri"
searchString="https://"
replaceString=""
airflowUri=$(echo "${airflowUri/$searchString/$replaceString}")
searchString=".appspot.com"
airflowUri=$(echo "${airflowUri/$searchString/$replaceString}")
echo "Cloud Composer airflowUri: $airflowUri"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Upload Cloud Composer Data Processing Trigger"
echo "---------------------------------------------------------------------------------------------------------" 
# Requires Cloud Composer to be created in order to deploy the DAGs
cd ..
cd Cloud-Composer

find . -type f -name "*.py" -print0 | while IFS= read -r -d '' file; do
    echo "Uploading DAG to Cloud Composer: $file"
    gcloud composer environments storage dags import \
        --environment $composer_name \
        --location $composer_location \
        --source $file
done

cd ..
cd Setup-Files



echo "---------------------------------------------------------------------------------------------------------" 
echo "Deploying Cloud Function"
echo "---------------------------------------------------------------------------------------------------------" 
# Requires Cloud Composer to be created in order to deploy the Cloud Function since it needs the URL to call
cd ..
cd Cloud-Function

env_composer_url=$airflowUri
env_dag_name="process-customer-file-upload"

#functionGet=$(gcloud functions list --format="json")
#searchResult=$(echo "$functionGet" | jq ".[] | select(.name==\"projects/$project/locations/$region/functions/customerUploadTrigger\")")
#echo "searchResult: $searchResult"

#if [ "$searchResult" = "" ]; then
  gcloud functions deploy customerUploadTrigger \
    --runtime python37 \
    --region $region \
    --trigger-resource $cloudFunctionBucket \
    --trigger-event google.storage.object.finalize \
    --set-env-vars env_project_id=$project,env_location=$composer_location,env_composer_environment=$composer_name,env_composer_url=$env_composer_url,env_dag_name=$env_dag_name
#else
#  echo "Cloud Function exists, skipping deployment"
#fi
#gcloud functions deploy customerUploadTrigger --clear-env-vars

cd ..
cd Setup-Files


echo "---------------------------------------------------------------------------------------------------------" 
echo "Configure Cloud Function to call Cloud Composer"
echo "---------------------------------------------------------------------------------------------------------" 
serviceAccount="$project@appspot.gserviceaccount.com"
echo "serviceAccount: $serviceAccount"

gcloud projects add-iam-policy-binding \
    $project \
    --member "serviceAccount:$serviceAccount" \
    --role "roles/iam.serviceAccountTokenCreator"

# May not be required?
#gcloud projects add-iam-policy-binding \
#    $project \
#    --member "serviceAccount:$serviceAccount" \
#    --role "roles/composer.user"


serviceAccountDataFusion=$(curl --silent "https://datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
    -H "Authorization: Bearer $access_token" | jq .serviceAccount --raw-output) 
echo "serviceAccountDataFusion: $serviceAccountDataFusion"

# cloud-datafusion-management-sa@ae7a3d33eca365aa8p-tp.iam.gserviceaccount.com
# Requires: Cloud Data Fusion API Service Agent
gcloud projects add-iam-policy-binding \
    $project \
    --member "serviceAccount:$serviceAccountDataFusion" \
    --role "roles/dataproc.serviceAgent"


serviceAccountCloudComposer=$(curl --silent "https://composer.googleapis.com/v1beta1/projects/$project/locations/$composer_location/environments/$composer_name" \
    -H "Authorization: Bearer $access_token" | jq .config.nodeConfig.serviceAccount --raw-output) 
echo "serviceAccountCloudComposer: $serviceAccountCloudComposer"

# 971334511334-compute@developer.gserviceaccount.com
# Reqiures: Cloud Data Fusion Runner to run Data Fusion Jobs
gcloud projects add-iam-policy-binding \
    $project \
    --member "serviceAccount:$serviceAccountCloudComposer" \
    --role "roles/datafusion.runner"

# This allows data fusion (via airflow) to create dataproc clusters
# The account is added to the compute default account (used by Airflow) and then that account
# can impersonate this account
accountForDataFusion="service-$projectNumber@gcp-sa-datafusion.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding \
    $serviceAccountCloudComposer \
    --member="serviceAccount:$accountForDataFusion" \
    --role="roles/iam.serviceAccountUser"