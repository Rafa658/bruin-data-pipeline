/* @bruin

name: marts.dim_flight_identifiers
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
  - name: departure_airport
    description: ICAO code of departure airport
    checks:
      - name: not_null
  - name: arrival_airport
    description: ICAO code of destination airport
    checks:
      - name: not_null
  - name: flight_id
    description: Flight identification number
    checks:
      - name: not_null
  - name: aircraft_type
    description: Aircraft type code (ICAO aircraft type designator)
    checks:
      - name: not_null
  - name: flight_date
    description: Flight date
    checks:
      - name: not_null

@bruin */

select
    id,
    departure_airport as adep,
    arrival_airport as ades,
    flight_id as fltid,
    aircraft_type as aircraft,
    flight_date as date
from intermediate.int_kpi08_filtered_by_forecast_conditions
where 1=1
