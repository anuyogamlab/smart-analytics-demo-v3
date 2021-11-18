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
echo "Obtaining Oracle VM IP address"
echo "---------------------------------------------------------------------------------------------------------" 
oracleVM="oracle-vm-${environment}"
oracleMachine=$(gcloud compute instances describe ${oracleVM} --project ${project} --zone ${zone} --format json)
oracleMachineIPAddress=$(echo $oracleMachine | jq .networkInterfaces[0].accessConfigs[0].natIP --raw-output)

echo "oracleMachineIPAddress: $oracleMachineIPAddress"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Datastream Connection Profiles"
echo "---------------------------------------------------------------------------------------------------------" 
# Docs: https://cloud.google.com/datastream/docs/reference/rest

datastream_location="us-central1"
datastream_rest_api="https://datastream.clients6.google.com/v1alpha1"

datastream_oracle_connection="oracle-vm-conn-${environment}"
datastream_datalake_connection="data-lake-conn-${environment}"
datastream_stream="oracle-stream-${environment}"

echo "datastream_oracle_connection: $datastream_oracle_connection"
echo "datastream_datalake_connection: $datastream_datalake_connection"
echo "datastream_stream: $datastream_stream"
echo "datastream_location: $datastream_location"
echo "datastream_rest_api :$datastream_rest_api"


datastreamStorageConnectionJSON=" \
{ \
  \"displayName\": \"${datastream_datalake_connection}\", \
  \"gcsProfile\": { \
    \"bucketName\": \"sa-datalake-${environment}\", \
    \"rootPath\": \"/datastream/oracle/hr\" \
  }, \
  \"noConnectivity\": {} \
}"

curl -X POST "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/connectionProfiles?connectionProfileId=${datastream_datalake_connection}" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data "$datastreamStorageConnectionJSON"


datastreamOracleConnectionJSON=" \
{ \
  \"displayName\": \"${datastream_oracle_connection}\", \
  \"oracleProfile\": { \
    \"hostname\": \"${oracleMachineIPAddress}\", \
    \"port\": 1521, \
    \"username\": \"datacdc\", \
    \"password\": \"MyPassword\", \
    \"databaseService\": \"ORADB01\" \
  }, \
  \"staticServiceIpConnectivity\" : {} \
}"

curl -X POST "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/connectionProfiles?connectionProfileId=${datastream_oracle_connection}" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data "$datastreamOracleConnectionJSON"


datastreamJSON="{ \
    \"displayName\": \"${datastream_stream}\", \
    \"sourceConfig\": { \
        \"sourceConnectionProfileName\": \"projects/${project}/locations/${datastream_location}/connectionProfiles/${datastream_oracle_connection}\", \
        \"oracleSourceConfig\": { \
            \"allowlist\": { \
                \"oracleSchemas\": [ \
                    { \
                        \"schemaName\": \"hr\" \
                    } \
                ] \
            }, \
            \"rejectlist\": { \
                \"oracleSchemas\": [] \
            } \
        } \
    }, \
    \"destinationConfig\": { \
        \"destinationConnectionProfileName\": \"projects/${project}/locations/${datastream_location}/connectionProfiles/${datastream_datalake_connection}\", \
        \"gcsDestinationConfig\": { \
            \"path\": \"\", \
            \"fileRotationMb\": 50, \
            \"fileRotationInterval\": \"60s\", \
            \"avroFileFormat\": {} \
        } \
    }, \
    \"backfillAll\": { \
        \"oracleExcludedObjects\": {} \
    } \
}"

echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Datastream IP Whitelisting Firewall rules"
echo "---------------------------------------------------------------------------------------------------------" 
# Per https://cloud.google.com/datastream/docs/ip-allowlists-and-regions
tag="oracle-datastream"

gcloud compute firewall-rules create "oracle-datastream-ingress" \
  --description="Allow Datastream to Oracle" \
  --direction=INGRESS \
  --allow=tcp:1521 \
  --source-ranges="34.72.28.29,34.67.234.134,34.67.6.157,34.72.239.218,34.71.242.81" \
  --target-tags=${tag}


echo "---------------------------------------------------------------------------------------------------------" 
echo "Creating Datastream"
echo "---------------------------------------------------------------------------------------------------------" 
#echo "datastreamJSON: $datastreamJSON"
# force skips the validation process
curl -X POST "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/streams?streamId=${datastream_stream}&validateOnly=false&force=true" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data "$datastreamJSON"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Waiting for Datastream to be Created"
echo "---------------------------------------------------------------------------------------------------------" 

stateDataStream=$(curl --silent "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/streams/${datastream_stream}" \
    -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

echo "stateDataStream: $stateDataStream"

while [ "$stateDataStream" != "CREATED" ]
    do
    sleep 5
    stateDataStream=$(curl --silent "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/streams/${datastream_stream}" \
        -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

    echo "stateDataStream: $stateDataStream"
    done


echo "---------------------------------------------------------------------------------------------------------" 
echo "Starting Datastream"
echo "---------------------------------------------------------------------------------------------------------" 
curl -X POST "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/streams/${datastream_stream}:start" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data ""

echo "---------------------------------------------------------------------------------------------------------" 
echo "Waiting for Datastream to Start"
echo "---------------------------------------------------------------------------------------------------------" 

stateDataStream=$(curl --silent "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/streams/${datastream_stream}" \
    -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

echo "stateDataStream: $stateDataStream"

while [ "$stateDataStream" != "RUNNING" ]
    do
    sleep 5
    stateDataStream=$(curl --silent "${datastream_rest_api}/projects/${project}/locations/${datastream_location}/streams/${datastream_stream}" \
        -H "Authorization: Bearer $access_token" | jq .state --raw-output) 

    echo "stateDataStream: $stateDataStream"
    done    