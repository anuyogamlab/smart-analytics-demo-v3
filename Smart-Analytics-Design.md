# DECISIONS
- What open dataset to use?
- How in-depth do we want go?
- Create a good story..
- What use cases? 
- How much data:
  - batch (run some during the setup - history to build up data!)
  - batch run one file (in front of customer)
  - stream run one file (stream a file)

# DataSets
- https://pantheon.corp.google.com/marketplace/product/obfuscated-ga360-data/obfuscated-ga360-data?filter=solution-type:dataset&project=smart-analytics-demo-01&folder=&organizationId=
- Google ga_sessions


# Buckets
### sa-source-data-myid-dev
Source data used for this demo.  The data is actually downloaded from a BigQuery public dataset and placed in this bucket.

### sa-ingestion-myid-dev
Storage bucket for receiving data from customers.  Data will be uploaded here from a customer (e.g. customer01) and from here it will start to get processed by the system.  The bucket is not part of the data lake for security purposed and there will be a cloud function monitoring this bucket for new files.  Customers can upload one or many files into a folder under their "name".  When they are done they need to write a file named "end_file.txt" which will trigger the ingestion process.  This marker file indicates that the customer is completed their upload since they might have many files to upload and/or the files are large and can take a long time to upload.  The marker file avoids having to write delay loops or know how many files the customer might upload.

### sa-datalake-myid-dev
This is the main data lake of the system.  It will have a Bronze, Silver and Gold zone.  For phase 1 of this project data will be processed from the sa-ingestion-myid-dev bucket and placed into the Bronze zone as partitioned parquet files.  Silver and Gold zone process will come at a later time.


# Data Lake (flow of data Bronze -> Silver -> Gold)
1. Data has been exported from the BigQuery Open Dataset to: gs://sa-source-data-"myid"-dev/source-data for 2017-06-01 through 2017-07-31 (script: downloadPublicTestData.sh)
2. Data will be copied from the "source-data" folder (emulating a customer upload) and placed in gs://sa-ingestion-"myid"-dev/"customer01"/date partition (Cloud Composer job: )
3. A cloud function will trigger indicating the upload is complete ()
4. A Dataproc job will be called via Cloud Composer to process the ingested data, unzip it, partition it and save it to parquet in the gs://sa-datalake-myid-dev/zone/bronze
5. A Dataproc job will ???? silver / bronze
6. A Dataproc job will place the data in BiqQuery smart-analytics-demo-01:sa_bq_dataset_myid_dev.ga_sessions


# Batch (Adam)
Cloud composer
- Download files from Open Dataset 
  - Use a variable or hardcode files names
- Unzip
- Place in ingestion folder
- Call Dataproc (Python)
   - Open CSV files (DO CSV and JSON / parquest)
   - Save as Parquet in partitioned format to data lake bronze zone
   - analytic data
   - The "gold" tables (for future) might be good for when we add AI into the data.
- Call BigQuery load (on silver)


# Stream (Navdeep)
- Cloud composer (download current month data)
- Read the files and push 1 record a second to Pub/Sub (JSON)
- DataFlow (read Pub/Sub) push to BigQuery (ensure the tables a properly partitioned and clustered)
- DataFlow (read Pub/Sub) and push to bronze data lake (we would need to compact small files or export in batches)


# DataFusion (Anu)
- Use CSV for Wrangling
- What is our use case here (seems similar to Batch)?  Maybe bring in London bike data? Or releated data?
- This could show the more graphical apporach for when a business gets a new dataset and need to quickly get it implemented.
- * Show lineage *
- * PII *


# CDC


# Reporting / Looker (Sandeep)
- Database connection
- Place model in source control
- Row / column push down OAuth
- Build a report showing maps/charts (latitute/longitude)
- Build a report showing streaming dashboard

# Alerting
- Cloud Composer?  Stackdriver?

# System Reset (how to reset between uses or allow the user to test and reset)
- Cloud composer to delete all data
- Truncate BQ tables
- Clear storage
- Seek Pub/Sub to future time to clear messages
