
INSERT INTO `REPLACE_ME_PROJECT.sa_bq_dataset_myid_dev.ga_sessions` 
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
                         FROM `REPLACE_ME_PROJECT.sa_bq_dataset_myid_dev.REPLACE_ME_STAGING_TABLE` AS load_table
                              CROSS JOIN UNNEST(load_table.hits.list) AS hits_list
                      ) AS LoadData
                GROUP BY visitId,
                         visitNumber,  
                         visitStartTime,  
                         fullVisitorId                      
                ) AS  HitsNested
        INNER JOIN `REPLACE_ME_PROJECT.sa_bq_dataset_myid_dev.REPLACE_ME_STAGING_TABLE` AS stagingTable
        ON  stagingTable.visitId = HitsNested.visitId
        AND stagingTable.visitNumber = HitsNested.visitNumber
        AND stagingTable.visitStartTime = HitsNested.visitStartTime
        AND stagingTable.fullVisitorId = HitsNested.fullVisitorId)