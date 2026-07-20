/* @bruin

name: marts.dim_flight_operational_attributes
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_kpi08_filtered_by_forecast_conditions

columns:
  - name: id
    description: Unique flight identifier
    checks:
      - name: not_null
  - name: runway_validated
    description: Runway identifier at destination airport
    checks:
      - name: not_null
  - name: bearing
    description: Angle (0-360 degrees) relative to airport TMA
    checks:
      - name: not_null
  - name: setor
    description: TMA sector (0, 60, 120, 180, 240, 300) based on bearing
    checks:
      - name: not_null
      - name: accepted_values
        value:
          - "0"
          - "60"
          - "120"
          - "180"
          - "240"
          - "300"
  - name: entry_time
    description: Timestamp when aircraft enters TMA cylinder (100NM radius)
    checks:
      - name: not_null
  - name: landing_time
    description: Actual landing time at destination airport
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
@bruin */

select
  id,
  runway_validated as drwy_validado,
  bearing as bear,
  setor,
  entry_time as c_time,
  landing_time as aldt,
  transito,
  desimp,
  kpi08,
  transit_tma
from intermediate.int_kpi08_filtered_by_forecast_conditions
where 1=1
