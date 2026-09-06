/* @bruin

name: marts.dim_flight_transit_metrics
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_kpi08__filtered_by_forecast_conditions
  - marts.dim_flight_attributes

columns:
  - name: id
    description: Flight identifier (FK to dim_flight_attributes.id)
    checks:
      - name: not_null
  - name: transit_interval
    description: Time between entering TMA cylinder and landing (in seconds)
    checks:
      - name: not_null
  - name: unimpeded_interval
    description: Reference transit time (20th percentile for similar flights by aircraft/runway/destination)
    checks:
      - name: not_null
  - name: kpi08
    description: Additional transit time (transit_interval - unimpeded_interval) representing delay above reference
    checks:
      - name: not_null
  - name: transit_in_tma_interval
    description: Actual transit time inside TMA (sum of unimpeded_interval and kpi08)
    checks:
      - name: not_null

custom_checks:
  - name: every flight key exists in dim_flight_attributes
    description: Asserts referential integrity between the fact and the flight dimension.
    query: SELECT count(*) FROM marts.dim_flight_transit_metrics f LEFT JOIN marts.dim_flight_attributes d ON f.id = d.id WHERE d.id IS NULL
    value: 0

@bruin */

select
  id,
  transit_interval,
  unimpeded_interval,
  kpi08,
  transit_in_tma_interval
from intermediate.int_kpi08__filtered_by_forecast_conditions
where 1=1
