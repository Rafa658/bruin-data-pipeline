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
    description: "Flight natural key (FK to dim_flight_identifiers.id). Non-unique: a callsign can operate distinct flights on the same date."
    checks:
      - name: not_null
  - name: drwy_validado
    description: Runway identifier at destination airport
    checks:
      - name: not_null
  - name: bear
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
  - name: c_time
    description: Timestamp when aircraft enters TMA cylinder (100NM radius)
    checks:
      - name: not_null
  - name: aldt
    description: Actual landing time at destination airport
    checks:
      - name: not_null
@bruin */

select
  id,
  runway_validated as drwy_validado,
  bearing as bear,
  setor,
  entry_time as c_time,
  landing_time as aldt
from intermediate.int_kpi08_filtered_by_forecast_conditions
where 1=1
