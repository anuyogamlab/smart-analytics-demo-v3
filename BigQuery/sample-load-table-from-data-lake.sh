#!/bin/bash

# NOTE: This code is NOT used, Airflow is used for this process which make the authentication easier and is integrated

# To Run: ./sample-load-table-from-data-lake.sh "smart-analytics-demo-01" "customer01/ga_sessions/2017-06-02/end_file.txt" "myid-dev" 
# Parameters (these need to be set per run)
project=$1
markerFilePath=$2
environment=$3

echo "project: $project"
echo "markerFilePath: $markerFilePath"
echo "environment: $environment"

# Variables
project_source_regex="REPLACE_ME_PROJECT"
load_table_regex="REPLACE_ME_STAGING_TABLE"

# Create the string for the table in which the data was loaded
searchString="/end_file.txt"
replaceString=""
replace01=$(echo "${markerFilePath//$searchString/$replaceString}")
echo "replace01: $replace01"
searchString="/"
replaceString="_"
replace02=$(echo "${replace01//$searchString/$replaceString}")
echo "replace02: $replace02"
searchString="-"
replaceString="_"
load_table=$(echo "${replace02//$searchString/$replaceString}")
echo "load_table: $load_table"

searchString="-"
replaceString="_"
environment_with_underscores=$(echo "${environment//$searchString/$replaceString}")
echo "environment_with_underscores: $environment_with_underscores"


# Load a temporary table since we might need to tranform some data based upon the parquet format
# NOTE: This was done in the Dataproc code, it could also be done here instead (you decide)
# data_lake_source_path="gs://sa-datalake-myid-dev/silver/customer01/ga_sessions/year=2017/month=6/day=24/*.parquet" 
# bq load \
#  --source_format=PARQUET \
#  $project:sa_bq_dataset_myid_dev.ga_sessions \
#  $data_lake_source_path

# Replace the transform SQL script with the values we are using
sed "s/$project_source_regex/$project/g" sample-load-table-from-data-lake.sql > load-sql-01.sql
sed "s/$load_table_regex/$load_table/g" load-sql-01.sql > load-sql-02.sql
QUERY="$(cat load-sql-02.sql)"
rm load-sql-01.sql
rm load-sql-02.sql
echo "QUERY: $QUERY"

# Load the final table
bq query \
  --use_legacy_sql=false \
  "$QUERY"

# Drop the load table (this might be comment out just for demo purposes)
table_to_drop="$project:sa_bq_dataset_$environment_with_underscores.$load_table"
echo "table_to_drop: $table_to_drop"
bq rm -f --table $table_to_drop