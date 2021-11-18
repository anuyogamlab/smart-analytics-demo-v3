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
echo "Setting Variables for you"
echo "---------------------------------------------------------------------------------------------------------" 
searchString="-"
replaceString="_"
environment_with_underscores=$(echo "${environment//$searchString/$replaceString}")
echo "environment_with_underscores: $environment_with_underscores"

host_url="https://$looker_customer_id.api.looker.com"
project_id="sa-looker-${environment}"

echo "environment_with_underscores: $environment_with_underscores"
echo "Looker host_url: $host_url"
echo "Looker project_id: $project_id"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Getting Looker API credentials"
echo "---------------------------------------------------------------------------------------------------------" 
# The client_id and client_secret are stored in a file not in Git named "looker-username-password.json"
# The file will look like:  { "client_id" : "your-value" , "client_secret" : "your-value"}
lookerCredentials=$(cat $LOOKER_APPLICATION_CREDENTIALS)
client_id=$(echo "$lookerCredentials" | jq .client_id --raw-output)
client_secret=$(echo "$lookerCredentials" | jq .client_secret --raw-output)

if [ "$client_id" = "" ]; then
    echo "ERROR: You need a $LOOKER_APPLICATION_CREDENTIALS (client_id is empty)"
    exit 1
else
    echo "Looker: client_id loaded"
fi

if [ "$client_secret" = "" ]; then
    echo "ERROR: You need a $LOOKER_APPLICATION_CREDENTIALS (client_secret is empty)"
    exit 1
else
    echo "Looker: client_secret loaded"
fi

# Login and extract token
access_token=$(curl --silent "$host_url/api/3.1/login" \
  --data "client_id=$client_id&client_secret=$client_secret" | jq .access_token --raw-output)


echo "---------------------------------------------------------------------------------------------------------" 
echo "Changing to Dev mode"
echo "---------------------------------------------------------------------------------------------------------" 
# Switch into Dev mode (do this everytime)
voidResult=$(curl --silent --request PATCH "$host_url/api/3.1/session" \
    -H "Authorization: token $access_token" \
    -H "Content-Type: application/json" \
    --data "{ \"workspace_id\":\"dev\" }")


echo "---------------------------------------------------------------------------------------------------------" 
echo "Create Project"
echo "---------------------------------------------------------------------------------------------------------" 
# Get the project to test for existance
projectGet=$(curl --silent "$host_url/api/3.1/projects/$project_id" -H "Authorization: token $access_token")

if [[ "$projectGet" == *"Not found"* ]]; then
    echo "Looker: Creating project"
    # Create a new project (if not exists)
    curl --silent -X POST "$host_url/api/3.1/projects" \
        -H "Authorization: token $access_token" \
        -H "Content-Type: application/json" \
        --data "{  \"id\":\"$project_id\", \"name\":\"$project_id\" }"
else
    echo "Looker: Project exists, skipping create"
fi

echo "---------------------------------------------------------------------------------------------------------" 
echo "Login to GCP using service account"
echo "---------------------------------------------------------------------------------------------------------" 
# The username of the service account (e.g.  "smart-analytics-dev-ops@smart-analytics-demo-01.iam.gserviceaccount.com" )
accountName=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email --raw-output)

gcloud auth activate-service-account $accountName --key-file=$GOOGLE_APPLICATION_CREDENTIALS --project=$project



echo "---------------------------------------------------------------------------------------------------------" 
echo "Create Looker GCP Service Account BigQuery"
echo "---------------------------------------------------------------------------------------------------------" 
lookerGCP_ServiceAccountName="sa-looker-connection"
echo "lookerGCP_ServiceAccountName: $lookerGCP_ServiceAccountName"

lookerGCP_ServiceAccountEmail="${lookerGCP_ServiceAccountName}@${project}.iam.gserviceaccount.com"
echo "lookerGCP_ServiceAccountEmail: $lookerGCP_ServiceAccountEmail"

# Export key for servive account
lookerGCP_ServiceAccountFile="looker-sa-key-${environment}.json"
echo "lookerGCP_ServiceAccountFile: $lookerGCP_ServiceAccountFile"

serviceAccountGet=$(gcloud iam service-accounts list --format="json")
searchResult=$(echo "$serviceAccountGet" | jq ".[] | select(.email ==\"${lookerGCP_ServiceAccountEmail}\")")


if [ "$searchResult" = "" ]; then
    echo "Creating service account"

    gcloud iam service-accounts create \
        $lookerGCP_ServiceAccountName \
        --description="Used for Looker to connect to BigQuery" \
        --display-name="Looker Connection"

    gcloud iam service-accounts keys create \
        ${lookerGCP_ServiceAccountFile} \
        --iam-account=${lookerGCP_ServiceAccountEmail} \
        --key-file-type="json"

    # BigQuery Data Editor 
    gcloud projects add-iam-policy-binding \
        $project \
        --member "serviceAccount:$lookerGCP_ServiceAccountEmail" \
        --role "roles/bigquery.dataEditor"

    # BigQuery Job User 
    gcloud projects add-iam-policy-binding \
        $project \
        --member "serviceAccount:$lookerGCP_ServiceAccountEmail" \
        --role "roles/bigquery.jobUser"
else
    echo "Service account exists"
fi



echo "---------------------------------------------------------------------------------------------------------" 
echo "Create Looker Connection to BigQuery"
echo "---------------------------------------------------------------------------------------------------------" 
# Create Looker BigQuery connection
database="sa_bq_dataset_${environment_with_underscores}"
connection_name="${database}_connection"

connectionGet=$(curl --silent "$host_url/api/3.1/connections/$connection_name" \
    -H "Authorization: token $access_token")

if [[ $connectionGet == *"Not found"* ]]; then
    echo "Creating connection"

    # Create a connection (need service account from GCP)
    tmp_db_name="sa_bq_dataset_${environment_with_underscores}_looker"
    pdts_enabled="true"
    uses_oauth="false"
    # Google Project Name
    host=$project 
    dialect_name="bigquery_standard_sql"
    accountName=$(cat $lookerGCP_ServiceAccountFile | jq .client_email --raw-output)
    username=$accountName
    db_timezone="UTC"
    query_timezone="UTC"
    # Not documented, but you need this for your service account
    file_type=".json"

    echo "name: $connection_name"
    echo "host: $host"
    echo "database: $database"
    echo "db_timezone: $db_timezone"
    echo "query_timezone: $query_timezone"
    echo "tmp_db_name: $tmp_db_name"
    echo "dialect_name: $dialect_name"
    echo "pdts_enabled: $pdts_enabled"
    echo "uses_oauth: $uses_oauth"
    echo "username: $username"
    echo "file_type: $file_type"
 
    certificate="$(cat $lookerGCP_ServiceAccountFile | base64)"
    connectionJSON="{ \"name\":\"$connection_name\", \"host\":\"$host\", \"database\":\"$database\", \"db_timezone\":\"$db_timezone\", \"query_timezone\":\"$query_timezone\", \"tmp_db_name\":\"$tmp_db_name\", \"dialect_name\":\"$dialect_name\", \"pdts_enabled\":$pdts_enabled, \"uses_oauth\":$uses_oauth, \"username\":\"$username\", \"certificate\":\"$certificate\", \"file_type\":\"$file_type\" }"
    echo "connectionJSON: $connectionJSON"

    echo "$connectionJSON" > connection.json

    curl --silent -X POST "$host_url/api/3.1/connections" \
        -H "Authorization: token $access_token" \
        -H "Content-Type: application/json" \
        --data @connection.json

    rm connection.json
else
    echo "Looker: Connection exists, skipping create"
fi


echo "---------------------------------------------------------------------------------------------------------" 
echo "Create Looker Model"
echo "---------------------------------------------------------------------------------------------------------" 
# Create a model
model_name="sa-looker-${environment}"

modelGet=$(curl --silent "$host_url/api/3.1/lookml_models/$model_name" \
    -H "Authorization: token $access_token")

if [[ $modelGet == *"Not found"* ]]; then
    echo "Looker: Creating model"

    modelJSON="{ \"name\":\"$model_name\", \"project_name\":\"$project_id\",  \"allowed_db_connection_names\": [\"$connection_name\"] }"
    echo "modelJSON: $modelJSON"

    curl --silent -X POST "$host_url/api/3.0/lookml_models" \
        -H "Authorization: token $access_token" \
        -H "Content-Type: application/json" \
        --data "$modelJSON"
else
    echo "Looker: Model exists, skipping create"
fi


echo "---------------------------------------------------------------------------------------------------------" 
echo "Create Looker source control artifacts"
echo "---------------------------------------------------------------------------------------------------------" 
# Create a new deployment key for source control

deploy_key=$(curl --silent -X POST "$host_url/api/3.1/projects/$project_id/git/deploy_key" \
-H "Authorization: token $access_token")

echo "deploy_key: $deploy_key"
if [[ $deploy_key == *"ssh-rsa"* ]]; then
    echo "Looker: Saving ssh key"
    echo "$deploy_key" > looker-ssh-key-${environment}.txt
else
    deploy_key=$(curl --silent "$host_url/api/3.1/projects/$project_id/git/deploy_key" \
    -H "Authorization: token $access_token")
    echo "deploy_key: $deploy_key"
    echo "$deploy_key" > looker-ssh-key-${environment}.txt
fi


echo "---------------------------------------------------------------------------------------------------------" 
echo "Generating Looker files for your GIT repo"
echo "---------------------------------------------------------------------------------------------------------" 
rm -r sa-looker-git-files
mkdir sa-looker-git-files
mkdir sa-looker-git-files/dashboards
mkdir sa-looker-git-files/models
mkdir sa-looker-git-files/views

sourceString="REPLACE_ENVIRONMENT_UNDERSCORES"
destString=$environment_with_underscores

echo "Creating Git files"
sed "s/$sourceString/$destString/g" \
    ./sa-looker-templates/dashboards/sa-looker-REPLACE_ENVIRONMENT.dashboard.lookml > \
    ./sa-looker-git-files/dashboards/sa-looker-${environment}.dashboard.lookml

sed "s/$sourceString/$destString/g" \
    ./sa-looker-templates/models/sa-looker-REPLACE_ENVIRONMENT.model.lkml > \
    ./sa-looker-git-files/models/sa-looker-${environment}.model.lkml

sed "s/$sourceString/$destString/g" \
    ./sa-looker-templates/views/ga_sessions.view.lkml > \
    ./sa-looker-git-files/views/ga_sessions.view.lkml

sourceString="REPLACE_ENVIRONMENT"
destString=$environment

echo "Setting Git files values"
sed -i "s/$sourceString/$destString/g" \
    ./sa-looker-git-files/dashboards/sa-looker-${environment}.dashboard.lookml 

sed -i "s/$sourceString/$destString/g" \
    ./sa-looker-git-files/models/sa-looker-${environment}.model.lkml

sed -i "s/$sourceString/$destString/g" \
    ./sa-looker-git-files/views/ga_sessions.view.lkml

echo "---------------------------------------------------------------------------------------------------------" 
echo "*** PAUSING!  Manual Steps Required to Continue PAUSING! ***"
echo "1. You need to create a Git repo (GitLab or GitHub)"
echo "   a. Name it: sa-looker-${environment}"
echo "2. You need to add the key in the file ./Looker/looker-ssh-key-${environment}.txt to your Git repo"
echo "3. Add the files in the ./Looker/sa-looker-git-files to your Git repo.  Do NOT add the top level folder."
echo "   a. Add the dashboards folder"
echo "   b. Add the models folder"
echo "   c. Add the views folder"
echo "---------------------------------------------------------------------------------------------------------" 

read -p "Press [Enter] key once you have configured Git (or if Git is already configured)..."


echo "---------------------------------------------------------------------------------------------------------" 
echo "Configuring Looker for your Git Repo"
echo "---------------------------------------------------------------------------------------------------------" 
projectGet=$(curl --silent "$host_url/api/3.1/projects/$project_id" -H "Authorization: token $access_token")
test_git_remote_url=$(echo "$projectGet" | jq .git_remote_url --raw-output)
if [ "$test_git_remote_url" = "null" ]; then
    echo "Looker: Configuring source control"
    
    # Need to set the "Enable Advanced Deploy Mode" in the settings for Looker git_release_mgmt_enabled = true
    sourceControlJSON="{ \"git_remote_url\":\"$looker_git_remote_url\", \"git_release_mgmt_enabled\" : \"true\" }"
    echo "sourceControlJSON: $sourceControlJSON"

    curl --silent -X PATCH "$host_url/api/3.1/projects/$project_id" \
    -H "Authorization: token $access_token" \
    -H "Content-Type: application/json" \
    --data "$sourceControlJSON"

    curl --silent -X PUT "$host_url/api/3.1/projects/$project_id/git_branch" \
    -H "Authorization: token $access_token" \
    -H "Content-Type: application/json" \
    --data "{ \"ref\" : \"$origin\" }" 

else
    echo "Looker: Source control configured, skipping configuration"
fi


echo "---------------------------------------------------------------------------------------------------------" 
echo "Deploying your Git artifacts (Dashboards/Models/Views) to Production"
echo "---------------------------------------------------------------------------------------------------------" 
# Deploy to production
curl --silent -X POST "$host_url/api/3.1/projects/$project_id/deploy_ref_to_production" \
    -H "Authorization: token $access_token"