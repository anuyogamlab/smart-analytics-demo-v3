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


#########################################################################################################
# NOTES:
#########################################################################################################

# Usage: ./main-deploy.sh main-config.sh

# This script is safely re-runnable.  
#   - If you get an error, try again.  Access tokens and such can timeout.
# To save money in GCP
#   - Delete your Data Fusion environment if you will not be using the environment
# To clean up your environment:
#   - Delete your GCP project
#   - Delete your Looker project
#   - Delete your Looker database connection
#   - Delete your Git repo


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
echo "MAIN SCRIPT: Creating GCP Resources"
echo "---------------------------------------------------------------------------------------------------------" 
cd Setup-Files
./deploy.sh $configJSONFilename
cd ..

echo "---------------------------------------------------------------------------------------------------------" 
echo "MAIN SCRIPT: Downloading Sample Test Data to GCP Project"
echo "---------------------------------------------------------------------------------------------------------" 
cd Setup-Files
./download-public-source-data.sh $configJSONFilename
cd ..

echo "---------------------------------------------------------------------------------------------------------" 
echo "MAIN SCRIPT: Deploying Looker"
echo "---------------------------------------------------------------------------------------------------------" 
if [ "$looker_customer_id" = ""  ]; then
    echo "Skipping Looker deployment"
else
    cd Looker
    ./deploy.sh $configJSONFilename
    cd ..
fi

echo "---------------------------------------------------------------------------------------------------------" 
echo "MAIN SCRIPT: Deploying Data Fusion"
echo "---------------------------------------------------------------------------------------------------------" 
cd Datafusion
./deploy.sh $configJSONFilename
cd ..


echo "---------------------------------------------------------------------------------------------------------" 
echo "MAIN SCRIPT: Deploying Data Stream"
echo "---------------------------------------------------------------------------------------------------------" 
if [ "$oracle_install_zip" = ""  ]; then
    echo "Skipping DataStream deployment"
else
    cd DataStream
    ./deploy-oracle.sh $configJSONFilename
    ./deploy-datastream.sh $configJSONFilename
    ./deploy-dataflow.sh $configJSONFilename
    cd ..
fi

echo "---------------------------------------------------------------------------------------------------------" 
echo "MAIN SCRIPT: Running a Mock Customer upload"
echo "---------------------------------------------------------------------------------------------------------" 
# NOTE: You can run this over and over again to keep uploading files
cd Customer-Upload
./upload-files.sh $configJSONFilename
cd ..