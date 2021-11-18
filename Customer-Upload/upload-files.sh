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


# This will download a file from the source sa-source-data-myid-dev bucket
# This will upload the file to a customer folder in the ingestion bucket sa-ingestion-myid-dev in a folder named "customer01" and in a folder for the date
# This will then upload the marker file "end_file.txt"
# NOTE: When running this for customers we would have a signed url for customers to upload so they would only see their "folder".  The customer would call a Cloud Function with a "secret" and received a token for uploading.


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
echo "Login using service account"
echo "---------------------------------------------------------------------------------------------------------" 
# The username of the service account (e.g.  "smart-analytics-dev-ops@smart-analytics-demo-01.iam.gserviceaccount.com" )
accountName=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email --raw-output)

gcloud auth activate-service-account $accountName --key-file=$GOOGLE_APPLICATION_CREDENTIALS --project=$project


echo "---------------------------------------------------------------------------------------------------------" 
echo "Uploading a sample JSON file to start the Batch Processing Process"
echo "---------------------------------------------------------------------------------------------------------" 
# Variables
sourceDataBucket="sa-source-data-$environment"
ingestionBucket="sa-ingestion-$environment"

uploadTrackingFile=dates-uploaded.txt
if test -f "$uploadTrackingFile"; then
   echo "$uploadTrackingFile exists."
   dayToUpload=$(cat $uploadTrackingFile)
   dayToUpload=$(echo $(( dayToUpload + 1 )))
else
   dayToUpload=1
fi

if (( $dayToUpload < 10 )); then
   formattedDay="0${dayToUpload}"
else
   formattedDay="${dayToUpload}"
fi
dateToUpload="2017-06-${formattedDay}"
echo "Uploading date: $dateToUpload"

if (( $dayToUpload > 30 )); then
   echo "ERROR: You need to RESET your dates back to June 1st."
   echo "ERROR: Delete the file dates-uploaded.txt"
   exit 1
fi

# NOTE: The customer would have these files on their system.  This is just emulating data for processing
fileToDownload="gs://$sourceDataBucket/source-data-json/ga_sessions/$dateToUpload/" 
echo "Source File: $fileToDownload"
gsutil cp -r $fileToDownload .

fileToUpload="gs://$ingestionBucket/customer01/ga_sessions/$dateToUpload/" 
echo "Destination File: $fileToUpload"
gsutil cp ./$dateToUpload/* $fileToUpload

echo "DONE" > end_file.txt
markerFile="gs://$ingestionBucket/customer01/ga_sessions/$dateToUpload/" 
gsutil cp end_file.txt $fileToUpload

rm end_file.txt
rm -r ./$dateToUpload

echo "$dayToUpload" > $uploadTrackingFile