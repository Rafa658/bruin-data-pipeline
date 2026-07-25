/* @bruin

name: marts.fct_flight_transit_metrics
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_kpi08_filtered_by_forecast_conditions
  - marts.dim_flight_identifiers

columns:
  - name: id
    description: Flight identifier (FK to dim_flight_identifiers.id)
    checks:
      - name: not_null
  - name: transito
    description: Time between entering TMA cylinder and landing (in seconds)
    checks:
      - name: not_null
  - name: desimp
    description: Reference transit time (20th percentile for similar flights by aircraft/runway/destination)
    checks:
      - name: not_null
  - name: kpi08
    description: Additional transit time (transito - desimp) representing delay above reference
    checks:
      - name: not_null
  - name: transit_tma
    description: Actual transit time inside TMA (sum of desimp and kpi08)
    checks:
      - name: not_null

custom_checks:
  - name: every flight key exists in dim_flight_identifiers
    description: Asserts referential integrity between the fact and the flight dimension.
    query: SELECT count(*) FROM marts.fct_flight_transit_metrics f LEFT JOIN marts.dim_flight_identifiers d ON f.id = d.id WHERE d.id IS NULL
    value: 0

@bruin */

select
  id,
  transito,
  desimp,
  kpi08,
  transit_tma
from intermediate.int_kpi08_filtered_by_forecast_conditions
where 1=1
