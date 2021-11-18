#!/bin/bash

project="smart-analytics-demo-01"  

# Extract schema
#bq show --schema --format=prettyjson $project:sa_bq_dataset_myid_dev.ga_sessions > temp.json

bq rm -f --table $project:sa_bq_dataset_myid_dev.ga_sessions

bq mk --table \
    --schema sa-analytics-schema.json \
    --time_partitioning_field date \
    --time_partitioning_type DAY \
    --description "Google Analytics Data" \
    --label environment:dev \
    $project:sa_bq_dataset_myid_dev.ga_sessions 