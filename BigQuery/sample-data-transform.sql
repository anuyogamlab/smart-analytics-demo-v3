-- Shows the SQL to run to load the final table

WITH LoadData AS(
  SELECT load_table.visitId,
        load_table.visitNumber,  
        load_table.visitStartTime,  
        load_table.channelGrouping,  
        load_table.date,  
        load_table.fullVisitorId,  
        load_table.socialEngagementType,  
        load_table.totals,  
        load_table.trafficSource,  
        load_table.device,  
        load_table.geoNetwork,  
        STRUCT(hits_list.element.type, 
                hits_list.element.time,
                hits_list.element.hitNumber,
                hits_list.element.isEntrance,
                hits_list.element.isExit,
                hits_list.element.isExit,
                hits_list.element.page,
                hits_list.element.transaction
        ) AS hits
    FROM `smart-analytics-demo-01.sa_bq_dataset_myid_dev.adam_1` AS load_table
    CROSS JOIN UNNEST(load_table.hits.list) AS hits_list
),
HitsNested AS (
  SELECT visitId,
        visitNumber,  
        visitStartTime,  
        fullVisitorId,  
        ARRAY_AGG(hits) AS hits_array
  FROM LoadData
  GROUP BY visitId,
          visitNumber,  
          visitStartTime,  
          fullVisitorId
  ),
DataToLoad AS (
  SELECT stagingTable.visitId,
        stagingTable.visitNumber,
        stagingTable.visitStartTime,
        stagingTable.channelGrouping,
        stagingTable.date,
        stagingTable.fullVisitorId,
        stagingTable.socialEngagementType,
        stagingTable.totals,
        stagingTable.trafficSource,
        stagingTable.device,
        stagingTable.geoNetwork,
        HitsNested.hits_array
    FROM HitsNested 
        INNER JOIN `smart-analytics-demo-01.sa_bq_dataset_myid_dev.adam_1` AS stagingTable
        ON  stagingTable.visitId = HitsNested.visitId
        AND stagingTable.visitNumber = HitsNested.visitNumber
        AND stagingTable.visitStartTime = HitsNested.visitStartTime
        AND stagingTable.fullVisitorId = HitsNested.fullVisitorId
)
SELECT count(*) FROM DataToLoad;





INSERT INTO `smart-analytics-demo-01.sa_bq_dataset_myid_dev.ga_sessions` 
      (visitId, visitNumber, visitStartTime, channelGrouping, date, fullVisitorId, socialEngagementType,
       totals, trafficSource, device, geoNetwork, hits)
SELECT *
  FROM (SELECT stagingTable.visitId,
               stagingTable.visitNumber,
               stagingTable.visitStartTime,
               stagingTable.channelGrouping,
               stagingTable.date,
               stagingTable.fullVisitorId,
               stagingTable.socialEngagementType,
               stagingTable.totals,
               stagingTable.trafficSource,
               stagingTable.device,
               stagingTable.geoNetwork,
               HitsNested.hits_array
          FROM (
                SELECT visitId,
                       visitNumber,  
                       visitStartTime,  
                       fullVisitorId,  
                       ARRAY_AGG(hits) AS hits_array
                 FROM (
                        SELECT load_table.visitId,
                              load_table.visitNumber,  
                              load_table.visitStartTime,  
                              load_table.channelGrouping,  
                              load_table.date,  
                              load_table.fullVisitorId,  
                              load_table.socialEngagementType,  
                              load_table.totals,  
                              load_table.trafficSource,  
                              load_table.device,  
                              load_table.geoNetwork,  
                              STRUCT(hits_list.element.type, 
                                     hits_list.element.time,
                                     hits_list.element.hitNumber,
                                     hits_list.element.isEntrance,
                                     hits_list.element.isExit,
                                     hits_list.element.isExit,
                                     hits_list.element.page,
                                     hits_list.element.transaction) AS hits
                         FROM `smart-analytics-demo-01.sa_bq_dataset_myid_dev.adam_1` AS load_table
                              CROSS JOIN UNNEST(load_table.hits.list) AS hits_list
                      ) AS LoadData
                GROUP BY visitId,
                         visitNumber,  
                         visitStartTime,  
                         fullVisitorId                      
                ) AS  HitsNested
        INNER JOIN `smart-analytics-demo-01.sa_bq_dataset_myid_dev.adam_1` AS stagingTable
        ON  stagingTable.visitId = HitsNested.visitId
        AND stagingTable.visitNumber = HitsNested.visitNumber
        AND stagingTable.visitStartTime = HitsNested.visitStartTime
        AND stagingTable.fullVisitorId = HitsNested.fullVisitorId)


