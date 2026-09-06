/* @bruin

name: marts.dim_flight_attributes
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_kpi08__filtered_by_forecast_conditions

columns:
  - name: id
    description: "Flight natural key (FK to dim_flight_identifiers.id). Non-unique: a callsign can operate distinct flights on the same date."
  - name: drwy_validado
    description: Runway identifier at destination airport
  - name: adep
    description: ICAO code of departure airport
  - name: ades
    description: ICAO code of destination airport
  - name: fltid
    description: Flight callsign (ICAO airline code + number)
  - name: aircraft
    description: Aircraft type code (ICAO aircraft type designator)
  - name: reg
    description: Aircraft tail registration
  - name: date
    description: Flight date
  - name: bear
    description: Angle (0-360 degrees) relative to airport TMA
  - name: sector
    description: TMA sector (0, 60, 120, 180, 240, 300) based on bearing
  - name: c_time
    description: Timestamp when aircraft enters TMA cylinder (100NM radius)
  - name: aldt
    description: Actual landing time at destination airport
@bruin */

select
  id,
  -- operational attributes
  departure_airport,
  arrival_airport,
  flight_id,
  aircraft_type,
  aircraft_registration,
  flight_date,
  -- derived operational attributes
  runway_validated,
  bearing,
  sector,
  entry_ts,
  landing_ts
from intermediate.int_kpi08__filtered_by_forecast_conditions
where 1=1
