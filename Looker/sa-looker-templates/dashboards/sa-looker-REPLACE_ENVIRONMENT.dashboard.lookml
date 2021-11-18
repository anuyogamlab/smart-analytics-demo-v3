- dashboard: sa-looker-REPLACE_ENVIRONMENT
  title: SA Demo Dashboard
  layout: newspaper
  preferred_viewer: dashboards
  elements:
  - title: Top 10 USA Cities
    name: Top 10 USA Cities
    model: sa-looker-REPLACE_ENVIRONMENT
    explore: ga_sessions
    type: looker_grid
    fields: [ga_sessions.count, ga_sessions__geo_network.city]
    filters:
      ga_sessions.date_month_name: June
      ga_sessions__geo_network.country: United States
    sorts: [ga_sessions.count desc]
    limit: 10
    dynamic_fields: [{table_calculation: sessions, label: Sessions, expression: 'sum(${ga_sessions__totals.visits})',
        value_format: !!null '', value_format_name: !!null '', _kind_hint: dimension,
        _type_hint: number, is_disabled: true}]
    query_timezone: UTC
    show_view_names: false
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    limit_displayed_rows: false
    enable_conditional_formatting: true
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    conditional_formatting: [{type: greater than, value: 10000, background_color: "#FBBC04",
        font_color: !!null '', color_application: {collection_id: google, palette_id: google-sequential-0},
        bold: false, italic: false, strikethrough: false, fields: !!null ''}]
    hidden_fields: []
    defaults_version: 1
    series_types: {}
    row: 2
    col: 0
    width: 8
    height: 7
  - title: Top Countries (Non-US)
    name: Top Countries (Non-US)
    model: sa-looker-REPLACE_ENVIRONMENT
    explore: ga_sessions
    type: looker_column
    fields: [ga_sessions.count, ga_sessions__geo_network.country]
    filters:
      ga_sessions.date_month_name: June
      ga_sessions__geo_network.country: "-United States"
    sorts: [ga_sessions.count desc]
    limit: 10
    dynamic_fields: [{table_calculation: sessions, label: Sessions, expression: 'sum(${ga_sessions__totals.visits})',
        value_format: !!null '', value_format_name: !!null '', _kind_hint: dimension,
        _type_hint: number, is_disabled: true}]
    query_timezone: UTC
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    series_types: {}
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: true
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    conditional_formatting: [{type: greater than, value: 10000, background_color: "#FBBC04",
        font_color: !!null '', color_application: {collection_id: google, palette_id: google-sequential-0},
        bold: false, italic: false, strikethrough: false, fields: !!null ''}]
    hidden_fields: []
    defaults_version: 1
    row: 2
    col: 8
    width: 16
    height: 7
  - name: Audience
    type: text
    title_text: Audience
    subtitle_text: Who is visiting your website
    body_text: ''
    row: 0
    col: 0
    width: 24
    height: 2
  - name: Acquisition
    type: text
    title_text: Acquisition
    subtitle_text: Who is visiting your website
    body_text: ''
    row: 9
    col: 0
    width: 24
    height: 4
  - title: Top Referrers
    name: Top Referrers
    model: sa-looker-REPLACE_ENVIRONMENT
    explore: ga_sessions
    type: looker_pie
    fields: [ga_sessions__traffic_source.source, ga_sessions.count]
    filters:
      ga_sessions.date_year: '2017'
    sorts: [ga_sessions.count desc]
    limit: 5
    column_limit: 50
    value_labels: legend
    label_type: labPer
    map_plot_mode: points
    heatmap_gridlines: false
    heatmap_gridlines_empty: false
    heatmap_opacity: 0.5
    show_region_field: true
    draw_map_labels_above_data: true
    map_tile_provider: light
    map_position: fit_data
    map_scale_indicator: 'off'
    map_pannable: true
    map_zoomable: true
    map_marker_type: circle
    map_marker_icon_name: default
    map_marker_radius_mode: proportional_value
    map_marker_units: meters
    map_marker_proportional_scale_type: linear
    map_marker_color_mode: fixed
    show_view_names: false
    show_legend: true
    quantize_map_value_colors: false
    reverse_map_value_colors: false
    defaults_version: 1
    series_types: {}
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    row: 13
    col: 8
    width: 16
    height: 6
  - title: Total Page Hits
    name: Total Page Hits
    model: sa-looker-REPLACE_ENVIRONMENT
    explore: ga_sessions
    type: single_value
    fields: [ga_sessions__hits.is_entrance, ga_sessions.count, ga_sessions__hits.type]
    filters:
      ga_sessions.date_year: '2017'
      ga_sessions__hits.is_entrance: 'Yes'
    sorts: [ga_sessions.count desc]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: true
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    conditional_formatting: [{type: greater than, value: 20000, background_color: "#FBBC04",
        font_color: !!null '', color_application: {collection_id: google, palette_id: google-sequential-0},
        bold: false, italic: false, strikethrough: false, fields: !!null ''}]
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    series_types: {}
    row: 13
    col: 0
    width: 8
    height: 6
