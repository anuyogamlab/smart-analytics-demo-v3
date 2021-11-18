# Test script
# This script has been automated in the downloadPublicTestData.sh
# bq show bigquery-public-data:google_analytics_sample 

# Get the schema
bq show --schema --format=prettyjson bigquery-public-data:google_analytics_sample.ga_sessions_20170801 > ga_sessions_schema.json

# Test an export as Gzip
bq extract \
--location=US  \
--destination_format NEWLINE_DELIMITED_JSON \
--compression GZIP \
bigquery-public-data:google_analytics_sample.ga_sessions_20170801 \
gs://sa-datalake-myid-dev/source-data/ga_sessions/2017/08/01/data_*.json.gzip

bq extract \
--location=US  \
--destination_format NEWLINE_DELIMITED_JSON \
bigquery-public-data:google_analytics_sample.ga_sessions_20170801 \
gs://sa-datalake-myid-dev/zone/ingestion/ga_sessions/2017/01/01/data_*.json


# Make table
bq mk --table \
    --schema ga_sessions_schema.json \
    --time_partitioning_field date \
    --time_partitioning_type DAY \
    --description "Google Analytics Data" \
    --label environment:dev \
    smart-analytics-demo-01:sa_bq_dataset_myid_dev.ga_sessions

# Delete the table
# bq rm --table smart-analytics-demo-01:sa_bq_dataset_myid_dev.ga_sessions


# Load parquet file
bq load \
    --source_format=PARQUET \
    --time_partitioning_field date \
    sa_bq_dataset_myid_dev.ga_sessions \
    gs://sa-datalake-myid-dev/zone/bronze/ga_sessions/year=2017/month=8/day=1/*.parquet
