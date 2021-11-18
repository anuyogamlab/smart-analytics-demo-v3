#!/bin/bash

# This will export the BigQuery public dataset 
# This dataset will then be used for uploading to the Demo environment to simulate a real customer upload of date
# https://www.blog.google/products/marketingplatform/analytics/introducing-google-analytics-sample/
# https://support.google.com/analytics/answer/4419694?hl=en&ref_topic=3416089


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
echo "Checking to see if files exist"
echo "---------------------------------------------------------------------------------------------------------" 

listingResults=$(gsutil ls gs://sa-source-data-${environment}/source-data-json/ga_sessions/2017-06-30/data_*.json 2>&1)
echo "listingResults: $listingResults"

if [[ "$listingResults" == *"CommandException"* ]]; then
    echo "---------------------------------------------------------------------------------------------------------" 
    echo "Transferring public dataset to your storage bucket"
    echo "---------------------------------------------------------------------------------------------------------" 
    # This is done using a for loop since each version of Bash has different date formatting issues :(
    for i in {1..30}
    do
        if (( i < 10 )); then
            formattedDay="0${i}"
        else
            formattedDay="${i}"
        fi

        echo "Downloading 2017-06-${formattedDay}"

        bq extract \
        --location=US  \
        --destination_format NEWLINE_DELIMITED_JSON \
        bigquery-public-data:google_analytics_sample.ga_sessions_201706${formattedDay} \
        gs://sa-source-data-${environment}/source-data-json/ga_sessions/2017-06-${formattedDay}/data_*.json
    done
else
    echo "Public data already downloaded"
fi



# echo "---------------------------------------------------------------------------------------------------------" 
# echo "Setting variables"
# echo "---------------------------------------------------------------------------------------------------------" 
# # Variables
# startdate=2017-06-01
# enddate=2017-07-31

# Bucket to place BigQuery Public dataset
# sourceDataBucket="sa-source-data-$environment"

# Code to download and re-upload
# sDateTs=`date -j -f "%Y-%m-%d" $startdate "+%s"`
# eDateTs=`date -j -f "%Y-%m-%d" $enddate "+%s"`
# dateTs=$sDateTs
# offset=86400

# echo "---------------------------------------------------------------------------------------------------------" 
# echo "Transferring public dataset to your storage bucket"
# echo "---------------------------------------------------------------------------------------------------------" 
# while [ "$dateTs" -le "$eDateTs" ]
# do
#     date=`date -j -f "%s" $dateTs "+%Y%m%d"`
#     year=`date -j -f "%s" $dateTs "+%Y"`
#     month=`date -j -f "%s" $dateTs "+%m"`
#     day=`date -j -f "%s" $dateTs "+%d"`

#     printf 'date: %s\n' $date
#     printf 'year: %s\n' $year
#     printf 'month: %s\n' $month
#     printf 'day: %s\n' $date

# #    bq extract \
# #    --location=US  \
# #    --destination_format NEWLINE_DELIMITED_JSON \
# #    --compression GZIP \
# #    bigquery-public-data:google_analytics_sample.ga_sessions_$date \
# #    gs://sa-source-data-${environment}/source-data-gzip/ga_sessions/$year-$month-$day/data_*.json.gzip

#     bq extract \
#     --location=US  \
#     --destination_format NEWLINE_DELIMITED_JSON \
#     bigquery-public-data:google_analytics_sample.ga_sessions_$date \
#     gs://sa-source-data-${environment}/source-data-json/ga_sessions/$year-$month-$day/data_*.json

#     dateTs=$(($dateTs+$offset))
# done