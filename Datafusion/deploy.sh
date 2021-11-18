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
echo "Setting names and locations"
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
echo "Deploy Cloud Data Fusion"
echo "---------------------------------------------------------------------------------------------------------" 
# https://cloud.google.com/data-fusion/docs/reference/cdap-reference

access_token=$(gcloud auth application-default print-access-token)

datafusion_get=$(curl --silent "https://content-datafusion.googleapis.com/v1beta1/projects/$project/locations/$datafusion_location/instances/$datafusion_name" \
    -H "Authorization: Bearer $access_token")


datafusion_version=$(echo "$datafusion_get" | jq .version --raw-output)

datafusion_api_endpoint=$(echo "$datafusion_get" | jq .apiEndpoint --raw-output)

echo "datafusion_api_endpoint: $datafusion_api_endpoint"

pipelineFilename="sa-datafusion-etl-ml-modeling.json"
pipelineJSON=$(cat $pipelineFilename)
pipelineName=$(echo "$pipelineJSON" | jq .name --raw-output)
pipelineArtifact=$(echo "$pipelineJSON" | jq .artifact.name --raw-output)
echo "pipelineName: $pipelineName"
echo "pipelineArtifact: $pipelineArtifact"

# This is for Basic edition; otherwise, you need one for Enterprise
namespace_id="default"

# Download a pipeline
# You need to download versus using the export button
# This will encode the "configuration element" (we could do this via hand after a manual export, but we should automate the export process)
# Also the UI exports a "configuration element" and the REST export exports a "config element"
#curl -X GET "$datafusion_api_endpoint/v3/namespaces/$namespace_id/apps/sa-datafusion-etl-ml-modeling" \
#    -H "Authorization: Bearer $access_token" > sa-datafusion-etl-ml-modeling.json


echo "---------------------------------------------------------------------------------------------------------" 
echo "Updating Cloud Data Fusion Artifact Versions"
echo "---------------------------------------------------------------------------------------------------------" 
installedPlugins=$(curl "$datafusion_api_endpoint/v3/namespaces/$namespace_id/artifacts" \
   -H "Authorization: Bearer $access_token")
echo "installedPlugins: $installedPlugins"

pipelinePlugins=$(echo "$pipelineJSON" | jq .config.stages[].plugin.artifact | jq -s '.')
echo "pipelinePlugins: $pipelinePlugins"

newJson=$(echo "$pipelineJSON" | jq  "def walkJson(f): . as \$in | if type == \"object\" then reduce keys[] as \$key ( {}; . + { (\$key):  (\$in[\$key] | walkJson(f)) } ) | f elif type == \"array\" then map( walkJson(f) ) | f else f end; walkJson(if type == \"object\" and .name == \"$pipelineArtifact\" then .version=\"$datafusion_version\" else . end)")  


for row in $(echo "${pipelinePlugins}" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1} 
    }

   artifactName=$(echo $(_jq '.name'))
   echo "artifactName: $artifactName"

   searchResult=$(echo "$installedPlugins "| jq ".[] | select(.name ==\"${artifactName}\")")
   echo "searchResult (artifact) = $searchResult"

   newVersion=$(echo "$searchResult" | jq .version)
   echo "newVersion (version) = $newVersion"

    newJson=$(echo "$newJson" | jq  "def walkJson(f): . as \$in | if type == \"object\" then reduce keys[] as \$key ( {}; . + { (\$key):  (\$in[\$key] | walkJson(f)) } ) | f elif type == \"array\" then map( walkJson(f) ) | f else f end; walkJson(if type == \"object\" and .name == \"$artifactName\" then .version=$newVersion else . end)")  
done

echo "$newJson" > deploy_pipeline.json

echo "---------------------------------------------------------------------------------------------------------" 
echo "Uploading Cloud Data Fusion"
echo "---------------------------------------------------------------------------------------------------------" 
# Upload an app/pipeline
# https://cloud.google.com/data-fusion/docs/reference/cdap-reference#deploy_a_pipeline
# https://cdap.atlassian.net/wiki/spaces/DOCS/pages/477692148/Artifact+Microservices
curl --silent -X PUT "$datafusion_api_endpoint/v3/namespaces/$namespace_id/apps/$pipelineName" \
    -H "Authorization: Bearer $access_token" \
    -d @deploy_pipeline.json

# List the apps in data fusion
# curl -X GET "$datafusion_api_endpoint/v3/namespaces/$namespace_id/apps" \
#   -H "Authorization: Bearer $access_token"


