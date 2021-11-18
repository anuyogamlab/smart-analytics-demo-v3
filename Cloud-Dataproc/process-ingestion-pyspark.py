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

# This PySpark code will read in the JSON files, convert to parquet with a strong schema and save to a partitioned output
# To see the parquet files, download a file and then:
# On Mac: brew install parquet-tools  
# parquet-tools cat your-file-name.snappy.parquet
# parquet-tools schema your-file-name.snappy.parquet

import sys
from pyspark.sql.dataframe import DataFrame
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, BooleanType, DateType, ArrayType, TimestampType


# This will map some of the root JSON's data types
fieldMap = {
  # main
  "visitorId": "int",
  "visitNumber" : "int",
  "visitId" : "int",
  "visitStartTime" : "int"
}

# This will lookup a datatype to map
def getDataType(column_name, original_datatype):
  print ("getDataType column_name: " + column_name + " || original_datatype: " + original_datatype)
  if column_name in fieldMap.keys(): 
      return fieldMap[column_name]
  else: 
      return original_datatype


"""
20/12/28 22:08:49 INFO __main__: CODE_LOG: input_path: gs://sa-ingestion-myid-dev
20/12/28 22:08:49 INFO __main__: CODE_LOG: output_path: gs://sa-datalake-myid-dev
20/12/28 22:08:49 INFO __main__: CODE_LOG: markerFilePath: customer01/ga_sessions/2017-06-13/end_file.txt
"""
input_path     = sys.argv[1]  # gs://sa-ingestion-myid-dev
output_path    = sys.argv[2]  # gs://sa-datalake-myid-dev
markerFilePath = sys.argv[3]  # customer01/ga_sessions/2017-06-07/end_file.txt
environment    = sys.argv[4]  # myid-dev

# Spark session
spark = SparkSession.builder \
  .master("local") \
  .appName("convertToParquet") \
  .getOrCreate()


# Log the values
log4jLogger = spark._jvm.org.apache.log4j 
log = log4jLogger.LogManager.getLogger(__name__) 
log.info("CODE_LOG: input_path: " + input_path)
log.info("CODE_LOG: output_path: " + output_path)
log.info("CODE_LOG: markerFilePath: " + markerFilePath)
log.info("CODE_LOG: environment: " + environment)



# We have: gs://sa-ingestion-myid-dev/customer01/ga_sessions/2017-06-07/end_file.txt
# We want: gs://sa-ingestion-myid-dev/customer01/ga_sessions/2017-06-07/data_000000000000.json
storageSourcePath = input_path + "/" + markerFilePath
log.info("CODE_LOG: storageSourcePath:" + storageSourcePath)

storageSourcePath = storageSourcePath.replace("end_file.txt", "*.json")
log.info("CODE_LOG: storageSourcePath:" + storageSourcePath)


# We have: /customer01/ga_sessions/2017-06-07/end_file.txt
# We want: Use the output bucket, remove the date 2017-06-07 and remove the end_file.txt
# We want: gs://sa-datalake-myid-dev/customer01/ga_sessions
customerPath=markerFilePath.replace("end_file.txt", "")
log.info("CODE_LOG: customerPath:" + customerPath)

segments=customerPath.split('/')
outputBronzeDestinationPath = output_path + "/bronze/" + segments[0] + "/" + segments[1]
log.info("CODE_LOG: outputBronzeDestinationPath:" + outputBronzeDestinationPath)

outputSilverDestinationPath = output_path + "/silver/" + segments[0] + "/" + segments[1]
log.info("CODE_LOG: outputSilverDestinationPath:" + outputSilverDestinationPath)

outputGoldDestinationPath = output_path + "/gold/" + segments[0] + "/" + segments[1]
log.info("CODE_LOG: outputGoldDestinationPath:" + outputGoldDestinationPath)

"""
20/12/29 14:03:45 INFO __main__: CODE_LOG: input_path:gs://sa-ingestion-myid-dev
20/12/29 14:03:45 INFO __main__: CODE_LOG: output_path:gs://sa-datalake-myid-dev
20/12/29 14:03:45 INFO __main__: CODE_LOG: markerFilePath:customer01/ga_sessions/2017-06-14/end_file.txt
20/12/29 14:03:45 INFO __main__: CODE_LOG: storageSourcePath:gs://sa-ingestion-myid-devcustomer01/ga_sessions/2017-06-14/end_file.txt
20/12/29 14:03:45 INFO __main__: CODE_LOG: storageSourcePath:gs://sa-ingestion-myid-devcustomer01/ga_sessions/2017-06-14/*.json.gzip
20/12/29 14:03:45 INFO __main__: CODE_LOG: customerPath:customer01/ga_sessions/2017-06-14/
20/12/29 14:03:45 INFO __main__: CODE_LOG: outputBronzeDestinationPath:gs://sa-datalake-myid-dev/ga_sessions/2017-06-14
"""

##################################################
# Bronze
##################################################
# Read the JSON to a dataframe 
print ("****************** START: Bronze ******************")
dfIngested = spark.read.json(storageSourcePath)
print("Bronze: dfIngested.printSchema()")
dfIngested.printSchema()
dfIngested.show(10)
print ("Bronze: dfIngested.count(): " + str(dfIngested.count()))

# Create a timestamp for partitioning the data by day
dfIngestedWithDate = dfIngested \
  .withColumn("date_column", from_unixtime(unix_timestamp("date", "yyyyMMdd")))

dfIngestedWithDatePartitions = dfIngestedWithDate \
  .withColumn("year",  year      (col("date_column"))) \
  .withColumn("month", month     (col("date_column"))) \
  .withColumn("day",   dayofmonth(col("date_column"))) \
  .drop("date_column")

dfIngestedWithDatePartitions \
  .repartition(1) \
  .coalesce(1) \
  .write \
  .mode('append') \
  .partitionBy("year","month","day") \
  .parquet(outputBronzeDestinationPath)
print ("****************** END: Bronze ******************")


##################################################
# Silver
##################################################
print ("****************** START: Silver ******************")
# Trasform the dataFrame and map each type
dfSilver=dfIngested.select([col(col_name).cast(getDataType(col_name,dict(dfIngested.dtypes)[col_name])) for col_name in dfIngested.columns])
print("Silver: dfSilver.show(10)")
dfSilver.show(10)
dfSilver.printSchema()
print ("Silver: dfSilver.count(): " + str(dfSilver.count()))

# Create a timestamp for partitioning the data by day
dfSilverWithDate = dfSilver \
  .withColumn("date_column", from_unixtime(unix_timestamp("date", "yyyyMMdd"))) \
  .withColumn("date_column_datetype", to_date(unix_timestamp("date", "yyyyMMdd").cast("timestamp")))

dfSilverWithDatePartitions = dfSilverWithDate \
  .withColumn("year",  year      (col("date_column"))) \
  .withColumn("month", month     (col("date_column"))) \
  .withColumn("day",   dayofmonth(col("date_column"))) \
  .drop("date") \
  .drop("date_column") \
  .withColumnRenamed("date_column_datetype","date")

print("Silver: dfSilverWithDatePartitions.printSchema()")
dfSilverWithDatePartitions.printSchema()

dfSilverWithDatePartitions \
  .repartition(1) \
  .coalesce(1) \
  .write \
  .mode('append') \
  .partitionBy("year","month","day") \
  .parquet(outputSilverDestinationPath)
print ("****************** END: Silver ******************")

##################################################
# Gold
##################################################
print ("****************** START: Gold ******************")

df = dfIngested \
  .withColumn("date_column", from_unixtime(unix_timestamp("date", "yyyyMMdd"))) 

df = df \
  .withColumn("year",  year      (col("date_column"))) \
  .withColumn("month", month     (col("date_column"))) \
  .withColumn("day",   dayofmonth(col("date_column"))) \
  .drop("date_column") 

# Main columns (off of root of JSON)
print("Gold: dict(dfIngested.select(\"*\").dtypes)")
colsDict = dict(dfIngested.select("*").dtypes)
print(colsDict)

colName = "visitId"
dataType = IntegerType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))

colName = "visitNumber"
dataType = IntegerType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))

colName = "visitStartTime"
dataType = IntegerType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))

colName = "channelGrouping"
dataType = IntegerType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))

colName = "date"
dataType = TimestampType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, to_date(unix_timestamp(colName, "yyyyMMdd").cast("timestamp")))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))

colName = "fullVisitorId"
dataType = StringType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))

colName = "socialEngagementType"
dataType = StringType()
if colName in colsDict.keys(): 
    df = df.withColumn("new_" + colName, col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName, lit(None).cast(dataType))


# totals Struct
print ("****************** BEGIN: totals Struct ******************")
print("totals Struct: dict(dfIngested.select(\"totals.*\").dtypes)")
colsDict = dict(dfIngested.select("totals.*").dtypes)
print(colsDict)

colName = "totals.hits"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.bounces"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.newVisits"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.pageviews"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.totalTransactionRevenue"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.transactionRevenue"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.transactions"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "totals.visits"
dataType = IntegerType()
if colName.replace("totals.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

print("totals Struct: df.printSchema()")
df.printSchema()
df.show(10)


# Create Totals struct
df = df.withColumn("new_totals", \
  struct( \
  col("new_totals_hits").alias("hits"), \
  col("new_totals_bounces").alias("bounces"), \
  col("new_totals_newVisits").alias("newVisits"), \
  col("new_totals_pageviews").alias("pageviews"), \
  col("new_totals_totalTransactionRevenue").alias("totalTransactionRevenue"), \
  col("new_totals_transactionRevenue").alias("transactionRevenue"), \
  col("new_totals_transactions").alias("transactions"), \
  col("new_totals_visits").alias("visits") \
  )) \
  .drop("new_totals_hits") \
  .drop("new_totals_bounces") \
  .drop("new_totals_newVisits") \
  .drop("new_totals_pageviews") \
  .drop("new_totals_totalTransactionRevenue") \
  .drop("new_totals_transactionRevenue") \
  .drop("new_totals_transactions") \
  .drop("new_totals_visits") 

print("totals Struct: df.printSchema()")
df.printSchema()
df.show(10)
print ("****************** END: totals Struct ******************")


print ("****************** BEGIN: trafficSource Struct ******************")
# trafficSource Struct
print("trafficSource Struct: dict(dfIngested.select(\"trafficSource.*\").dtypes)")
colsDict = dict(dfIngested.select("trafficSource.*").dtypes)
print(colsDict)

colName = "trafficSource.campaign"
dataType = StringType()
if colName.replace("trafficSource.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "trafficSource.isTrueDirect"
dataType = BooleanType()
if colName.replace("trafficSource.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "trafficSource.keyword"
dataType = StringType()
if colName.replace("trafficSource.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "trafficSource.source"
dataType = StringType()
if colName.replace("trafficSource.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))    

# Create trafficSource struct
df = df.withColumn("new_trafficSource", \
  struct( \
  col("new_trafficSource_campaign").alias("campaign"), \
  col("new_trafficSource_isTrueDirect").alias("isTrueDirect"), \
  col("new_trafficSource_keyword").alias("keyword"), \
  col("new_trafficSource_source").alias("source") \
  )) \
  .drop("new_trafficSource_campaign") \
  .drop("new_trafficSource_isTrueDirect") \
  .drop("new_trafficSource_keyword") \
  .drop("new_trafficSource_source") 

print("trafficSource Struct: printSchema()")
df.printSchema()
df.show(10)
print ("****************** END: trafficSource Struct ******************")


print ("****************** BEGIN: device Struct ******************")

print("device Struct: dict(dfIngested.select(\"device.*\").dtypes)")
colsDict = dict(dfIngested.select("device.*").dtypes)
print(colsDict)

colName = "device.browser"
dataType = StringType()
if colName.replace("device.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "device.browserVersion"
dataType = StringType()
if colName.replace("device.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "device.deviceCategory"
dataType = StringType()
if colName.replace("device.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "device.isMobile"
dataType = BooleanType()
if colName.replace("device.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

# Create device struct
df = df.withColumn("new_device", \
  struct( \
  col("new_device_browser").alias("browser"), \
  col("new_device_browserVersion").alias("browserVersion"), \
  col("new_device_deviceCategory").alias("deviceCategory"), \
  col("new_device_isMobile").alias("isMobile") \
  )) \
  .drop("new_device_browser") \
  .drop("new_device_browserVersion") \
  .drop("new_device_deviceCategory") \
  .drop("new_device_isMobile") 

print("device Struct: df.printSchema()")
df.printSchema()
df.show(10)
print ("****************** END: device Struct ******************")


print ("****************** BEGIN: geoNetwork Struct ******************")

print("geoNetwork Struct: dict(dfIngested.select(\"geoNetwork.*\").dtypes)")
colsDict = dict(dfIngested.select("geoNetwork.*").dtypes)
print(colsDict)

colName = "geoNetwork.city"
dataType = StringType()
if colName.replace("geoNetwork.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "geoNetwork.country"
dataType = StringType()
if colName.replace("geoNetwork.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "geoNetwork.latitude"
dataType = StringType()
if colName.replace("geoNetwork.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "geoNetwork.longitude"
dataType = StringType()
if colName.replace("geoNetwork.","") in colsDict.keys():
    df = df.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    df = df.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))


# Create geoNetwork struct
df = df.withColumn("new_geoNetwork", \
  struct( \
  col("new_geoNetwork_city").alias("city"), \
  col("new_geoNetwork_country").alias("country"), \
  col("new_geoNetwork_latitude").alias("latitude"), \
  col("new_geoNetwork_longitude").alias("longitude") \
  )) \
  .drop("new_geoNetwork_city") \
  .drop("new_geoNetwork_country") \
  .drop("new_geoNetwork_latitude") \
  .drop("new_geoNetwork_longitude") 

print("geoNetwork Struct: df.printSchema()")
df.printSchema()
df.show(10)

print ("****************** END: geoNetwork Struct ******************")



# hits Array
print ("****************** BEGIN: Hits Array ******************")

dfHits = df.select( \
  "new_visitNumber", \
  "new_visitId", \
  "new_visitStartTime", \
  "new_fullVisitorId", \
  explode("hits").alias("hits"))

print ("Hits Array: dfHits.show(10)")
dfHits.show(10)
dfHits.printSchema()
print ("Gold: EXPLODED dfHits.count(): " + str(dfHits.count()))

print ("Hits Array: dict(dfHits.select(\"hits.*\").dtypes)")
colsDict = dict(dfHits.select("hits.*").dtypes)
print(colsDict)

colName = "hits.type"
dataType = StringType()
if colName.replace("hits.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.time"
dataType = IntegerType()
if colName.replace("hits.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.hitNumber"
dataType = IntegerType()
if colName.replace("hits.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.isEntrance"
dataType = BooleanType()
if colName.replace("hits.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.isExit"
dataType = BooleanType()
if colName.replace("hits.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.isInteraction"
dataType = BooleanType()
if colName.replace("hits.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

print ("Hits Array: dfHits.printSchema()")
dfHits.printSchema()
dfHits.show(10)


# hits page Struct
print ("Hits Array: dict(dfHits.select(\"hits.page.*\").dtypes)")
colsDict = dict(dfHits.select("hits.page.*").dtypes)
print(colsDict)

colName = "hits.page.hostname"
dataType = StringType()
if colName.replace("hits.page.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.page.pagePath"
dataType = StringType()
if colName.replace("hits.page.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.page.pageTitle"
dataType = StringType()
if colName.replace("hits.page.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.page.searchCategory"
dataType = StringType()
if colName.replace("hits.page.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.page.searchKeyword"
dataType = StringType()
if colName.replace("hits.page.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

print ("Hits Array: dfHits.printSchema()")
dfHits.printSchema()
dfHits.show(10)


# hits transaction Struct
print ("Hits Array: dict(dfHits.select(\"hits.transaction.*\").dtypes)")
colsDict = dict(dfHits.select("hits.transaction.*").dtypes)
print(colsDict)

colName = "hits.transaction.affiliation"
dataType = StringType()
if colName.replace("hits.transaction.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
    print("Column found: " + colName)
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))
    print("Column NOT found: " + colName)

colName = "hits.transaction.currencyCode"
dataType = StringType()
if colName.replace("transaction.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.transaction.transactionId"
dataType = StringType()
if colName.replace("transaction.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.transaction.transactionRevenue"
dataType = IntegerType()
if colName.replace("transaction.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.transaction.transactionShipping"
dataType = IntegerType()
if colName.replace("transaction.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

colName = "hits.transaction.transactionTax"
dataType = IntegerType()
if colName.replace("transaction.","") in colsDict.keys():
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), col(colName).cast(dataType))
else: 
    dfHits = dfHits.withColumn("new_" + colName.replace(".","_"), lit(None).cast(dataType))

print ("Hits Array: dfHits.printSchema()")
dfHits.printSchema()
dfHits.show(10)


# Create hits struct
dfHits = dfHits.withColumn("new_hits", \
  struct( \
    col("new_hits_type").alias("type"), \
    col("new_hits_time").alias("time"), \
    col("new_hits_hitNumber").alias("hitNumber"), \
    col("new_hits_isEntrance").alias("isEntrance"), \
    col("new_hits_isExit").alias("isExit"), \
    col("new_hits_isInteraction").alias("isInteraction"), \
    struct( \
      col("new_hits_page_hostname").alias("hostname"), \
      col("new_hits_page_pagePath").alias("pagePath"), \
      col("new_hits_page_pageTitle").alias("pageTitle"), \
      col("new_hits_page_searchCategory").alias("searchCategory"), \
      col("new_hits_page_searchKeyword").alias("searchKeyword") \
    ).alias("page"), \
    struct( \
      col("new_hits_transaction_affiliation").alias("affiliation"), \
      col("new_hits_transaction_currencyCode").alias("currencyCode"), \
      col("new_hits_transaction_transactionId").alias("transactionId"), \
      col("new_hits_transaction_transactionRevenue").alias("transactionRevenue"), \
      col("new_hits_transaction_transactionShipping").alias("transactionShipping"), \
      col("new_hits_transaction_transactionTax").alias("transactionTax") \
    ).alias("transaction") \
   )) \
  .drop("hits")

print ("Hits Array: dfHits")
dfHits.printSchema()
dfHits.show(10)
print ("Gold: dfHits.count(): " + str(dfHits.count()))


# Package back up into an Array
aggHits = dfHits.groupBy( \
  "new_visitNumber", \
  "new_visitId", \
  "new_visitStartTime", \
  "new_fullVisitorId" \
  ) \
  .agg(collect_list("new_hits").alias("array_hits"))


print ("Hits Array: aggHits")
aggHits.printSchema()
aggHits.show(10)
print ("Gold: aggHits.count(): " + str(aggHits.count()))


print ("****************** END: Hits Array ******************")


# Join back to main working dataFrame and alias the columns to the correct names
dfGold = df.alias("df_main")  \
  .join(aggHits.alias("df_hits"), \
    (df.new_visitNumber    == aggHits.new_visitNumber) & \
    (df.new_visitId        == aggHits.new_visitId) & \
    (df.new_visitStartTime == aggHits.new_visitStartTime) & \
    (df.new_fullVisitorId  == aggHits.new_fullVisitorId), \
    "inner") \
  .select( \
    col("df_main.year").alias("year"), \
    col("df_main.month").alias("month"), \
    col("df_main.day").alias("day"), \
    col("df_main.new_visitId").alias("visitId"), \
    col("df_main.new_visitNumber").alias("visitNumber"), \
    col("df_main.new_visitStartTime").alias("visitStartTime"), \
    col("df_main.new_channelGrouping").alias("channelGrouping"), \
    col("df_main.new_date").alias("date"), \
    col("df_main.new_fullVisitorId").alias("fullVisitorId"), \
    col("df_main.new_socialEngagementType").alias("socialEngagementType"), \
    col("df_main.new_totals").alias("totals"), \
    col("df_main.new_trafficSource").alias("trafficSource"), \
    col("df_main.new_device").alias("device"), \
    col("df_main.new_geoNetwork").alias("geoNetwork"), \
    col("df_hits.array_hits").alias("hits") \
  )

# Could also do: col("df_hits.array_hits.new_hits").alias("hits") \ in the above query

print ("Gold: dfGold")
dfGold.printSchema()
dfGold.show(10)
print ("Gold: dfGold.count(): " + str(dfGold.count()))


dfGold \
  .repartition(1) \
  .coalesce(1) \
  .write \
  .mode('append') \
  .partitionBy("year","month","day") \
  .parquet(outputGoldDestinationPath)

print ("****************** END: Gold ******************")


print ("****************** BEGIN: BigQuery Python Script ******************")
# You will need to create the cluster with an init script
# SCRIPT: gs://goog-dataproc-initialization-actions-us-west4/python/pip-install.sh
# METADATA: PIP_PACKAGES google.cloud.bigquery pandas

# Reference
# https://googleapis.dev/python/bigquery/latest/generated/google.cloud.bigquery.client.Client.html#google.cloud.bigquery.client.Client.insert_rows_from_dataframe

# client = bigquery.Client()
# job_config = bigquery.LoadJobConfig(autodetect=True)
# table_id = client.get_table('smart-analytics-demo-01.sa_bq_dataset_myid_dev.ga_sessions') 
# Do inserts
# client.insert_rows_from_dataframe(table_id,dfGold.toPandas())
# Or insert whole dataframe
# job=client.load_table_from_dataframe(dfGold.toPandas(),table_id,job_config=job_config).result()
print ("****************** END: BigQuery Python Script ******************")


print ("****************** BEGIN: BigQuery Dataframe Load ******************")
# You will need to create the cluster with an init script
# SCRIPT: gs://goog-dataproc-initialization-actions-${REGION}/connectors/connectors.sh
# METADATA: gcs-connector-version 2.1.1
# METADATA: bigquery-connector-version 1.1.1 
# METADATA: spark-bigquery-connector-version 0.13.1-beta

# Reference
# https://cloud.google.com/dataproc/docs/tutorials/bigquery-connector-spark-example
# https://github.com/GoogleCloudDataproc/spark-bigquery-connector

bucket = output_path.replace("gs://","")
spark.conf.set("temporaryGcsBucket",bucket)

# markerFilePath: customer01/ga_sessions/2017-06-13/end_file.txt
environment_underscore=environment.replace("-","_")
load_table="sa_bq_dataset_" + environment_underscore + "." + markerFilePath.replace("/end_file.txt","").replace("/","_").replace("-","_")
print ("load_table: " + load_table)

dfGold.write.format("bigquery") \
  .option("table",load_table) \
  .mode('overwrite') \
  .save()

print ("****************** END: BigQuery Dataframe Load ******************")
