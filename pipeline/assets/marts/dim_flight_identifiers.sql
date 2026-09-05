/* @bruin

name: marts.dim_flight_identifiers
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_kpi08__filtered_by_forecast_conditions

columns:
  - name: id
    description: "Flight natural key (flight_date + flight_id callsign). Non-unique: a callsign can operate distinct flights on the same date; the radar join is disambiguated by the TMA time window."
    checks:
      - name: not_null
  - name: adep
    description: ICAO code of departure airport
    checks:
      - name: not_null
  - name: ades
    description: ICAO code of destination airport
    checks:
      - name: not_null
  - name: fltid
    description: Flight callsign (ICAO airline code + number)
    checks:
      - name: not_null
  - name: aircraft
    description: Aircraft type code (ICAO aircraft type designator)
    checks:
      - name: not_null
  - name: reg
    description: Aircraft tail registration
  - name: date
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
    aircraft_registration as reg,
    flight_date as date
from intermediate.int_kpi08__filtered_by_forecast_conditions
where 1=1
