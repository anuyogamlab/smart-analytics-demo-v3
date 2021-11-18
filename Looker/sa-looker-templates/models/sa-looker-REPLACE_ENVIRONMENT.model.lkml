connection: "sa_bq_dataset_REPLACE_ENVIRONMENT_UNDERSCORES_connection"

# include all the views
include: "/views/**/*.view"
include: "/dashboards/**/*.dashboard"

datagroup: sa_looker_default_datagroup {
  # sql_trigger: SELECT MAX(id) FROM etl_log;;
  max_cache_age: "1 hour"
}

persist_with: sa_looker_default_datagroup

explore: ga_sessions {
  join: ga_sessions__hits {
    view_label: "Ga Sessions: Hits"
    sql: LEFT JOIN UNNEST(${ga_sessions.hits}) as ga_sessions__hits ;;
    relationship: one_to_many
  }

  join: ga_sessions__hits__page {
    view_label: "Ga Sessions: Hits Page"
    sql: LEFT JOIN UNNEST([${ga_sessions__hits.page}]) as ga_sessions__hits__page ;;
    relationship: one_to_one
  }

  join: ga_sessions__hits__transaction {
    view_label: "Ga Sessions: Hits Transaction"
    sql: LEFT JOIN UNNEST([${ga_sessions__hits.transaction}]) as ga_sessions__hits__transaction ;;
    relationship: one_to_one
  }

  join: ga_sessions__geo_network {
    view_label: "Ga Sessions: Geonetwork"
    sql: LEFT JOIN UNNEST([${ga_sessions.geo_network}]) as ga_sessions__geo_network ;;
    relationship: one_to_one
  }

  join: ga_sessions__totals {
    view_label: "Ga Sessions: Totals"
    sql: LEFT JOIN UNNEST([${ga_sessions.totals}]) as ga_sessions__totals ;;
    relationship: one_to_one
  }

  join: ga_sessions__traffic_source {
    view_label: "Ga Sessions: Trafficsource"
    sql: LEFT JOIN UNNEST([${ga_sessions.traffic_source}]) as ga_sessions__traffic_source ;;
    relationship: one_to_one
  }

  join: ga_sessions__device {
    view_label: "Ga Sessions: Device"
    sql: LEFT JOIN UNNEST([${ga_sessions.device}]) as ga_sessions__device ;;
    relationship: one_to_one
  }
}
