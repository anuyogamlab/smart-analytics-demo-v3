view: ga_sessions {
  sql_table_name: `sa_bq_dataset_REPLACE_ENVIRONMENT_UNDERSCORES.ga_sessions`
    ;;

  dimension: channel_grouping {
    type: number
    sql: ${TABLE}.channelGrouping ;;
  }

  dimension_group: date {
    type: time
    timeframes: [
      raw,
      date,
      week,
      month,
      month_name,
      quarter,
      year
    ]
    convert_tz: no
    datatype: date
    sql: ${TABLE}.date ;;
  }

  dimension: device {
    hidden: yes
    sql: ${TABLE}.device ;;
  }

  dimension: full_visitor_id {
    primary_key: yes
    type: string
    sql: ${TABLE}.fullVisitorId ;;
  }

  dimension: geo_network {
    hidden: yes
    sql: ${TABLE}.geoNetwork ;;
  }

  dimension: hits {
    hidden: yes
    sql: ${TABLE}.hits ;;
  }

  dimension: social_engagement_type {
    type: string
    sql: ${TABLE}.socialEngagementType ;;
  }

  dimension: totals {
    hidden: yes
    sql: ${TABLE}.totals ;;
  }

  dimension: traffic_source {
    hidden: yes
    sql: ${TABLE}.trafficSource ;;
  }

  dimension: visit_id {
    type: number
    sql: ${TABLE}.visitId ;;
  }

  dimension: visit_number {
    type: number
    sql: ${TABLE}.visitNumber ;;
  }

  dimension: visit_start_time {
    type: number
    sql: ${TABLE}.visitStartTime ;;
  }

  measure: count {
    type: count
    drill_fields: []
  }
}

view: ga_sessions__hits {
  dimension: hit_number {
    type: number
    sql: ${TABLE}.hitNumber ;;
  }

  dimension: is_entrance {
    type: yesno
    sql: ${TABLE}.isEntrance ;;
  }

  dimension: is_exit {
    type: yesno
    sql: ${TABLE}.isExit ;;
  }

  dimension: is_interaction {
    type: yesno
    sql: ${TABLE}.isInteraction ;;
  }

  dimension: page {
    hidden: yes
    sql: ${TABLE}.page ;;
  }

  dimension: time {
    type: number
    sql: ${TABLE}.time ;;
  }

  dimension: transaction {
    hidden: yes
    sql: ${TABLE}.transaction ;;
  }

  dimension: type {
    type: string
    sql: ${TABLE}.type ;;
  }
}

view: ga_sessions__hits__page {
  dimension: hostname {
    type: string
    sql: ${TABLE}.hostname ;;
  }

  dimension: page_path {
    type: string
    sql: ${TABLE}.pagePath ;;
  }

  dimension: page_title {
    type: string
    sql: ${TABLE}.pageTitle ;;
  }

  dimension: search_category {
    type: string
    sql: ${TABLE}.searchCategory ;;
  }

  dimension: search_keyword {
    type: string
    sql: ${TABLE}.searchKeyword ;;
  }
}

view: ga_sessions__hits__transaction {
  dimension: affiliation {
    type: string
    sql: ${TABLE}.affiliation ;;
  }

  dimension: currency_code {
    type: string
    sql: ${TABLE}.currencyCode ;;
  }

  dimension: transaction_id {
    type: string
    sql: ${TABLE}.transactionId ;;
  }

  dimension: transaction_revenue {
    type: number
    sql: ${TABLE}.transactionRevenue ;;
  }

  dimension: transaction_shipping {
    type: number
    sql: ${TABLE}.transactionShipping ;;
  }

  dimension: transaction_tax {
    type: number
    sql: ${TABLE}.transactionTax ;;
  }
}

view: ga_sessions__geo_network {
  dimension: city {
    type: string
    sql: ${TABLE}.city ;;
  }

  dimension: country {
    type: string
    map_layer_name: countries
    sql: ${TABLE}.country ;;
  }

  dimension: latitude {
    type: string
    sql: ${TABLE}.latitude ;;
  }

  dimension: longitude {
    type: string
    sql: ${TABLE}.longitude ;;
  }
}

view: ga_sessions__totals {
  dimension: bounces {
    type: number
    sql: ${TABLE}.bounces ;;
  }

  dimension: hits {
    type: number
    sql: ${TABLE}.hits ;;
  }

  dimension: new_visits {
    type: number
    sql: ${TABLE}.newVisits ;;
  }

  dimension: pageviews {
    type: number
    sql: ${TABLE}.pageviews ;;
  }

  dimension: total_transaction_revenue {
    type: number
    sql: ${TABLE}.totalTransactionRevenue ;;
  }

  dimension: transaction_revenue {
    type: number
    sql: ${TABLE}.transactionRevenue ;;
  }

  dimension: transactions {
    type: number
    sql: ${TABLE}.transactions ;;
  }

  dimension: visits {
    type: number
    sql: ${TABLE}.visits ;;
  }
  measure: total_sessions {
    type: sum
    sql: ${visits} ;;
  }
}

view: ga_sessions__traffic_source {
  dimension: campaign {
    type: string
    sql: ${TABLE}.campaign ;;
  }

  dimension: is_true_direct {
    type: yesno
    sql: ${TABLE}.isTrueDirect ;;
  }

  dimension: keyword {
    type: string
    sql: ${TABLE}.keyword ;;
  }

  dimension: source {
    type: string
    sql: ${TABLE}.source ;;
  }
}

view: ga_sessions__device {
  dimension: browser {
    type: string
    sql: ${TABLE}.browser ;;
  }

  dimension: browser_version {
    type: string
    sql: ${TABLE}.browserVersion ;;
  }

  dimension: device_category {
    type: string
    sql: ${TABLE}.deviceCategory ;;
  }

  dimension: is_mobile {
    type: yesno
    sql: ${TABLE}.isMobile ;;
  }
}
