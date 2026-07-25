/* @bruin

name: staging.stg_kpi08__odin
type: duckdb.sql
tags:
  - staging

materialization:
  type: view

depends:
  - raw.kpi08

columns:
  - name: flight_date
    description: Flight date
    checks:
      - name: not_null
  - name: flight_id
    description: Flight ID
    checks:
      - name: not_null
  - name: departure_airport
    description: ICAO code of departure airport
    checks:
      - name: not_null
  - name: arrival_airport
    description: ICAO code of arrival airport
    checks:
      - name: not_null
  - name: aircraft_type
    description: Type of aircraft
    checks:
      - name: not_null
  - name: aircraft_registration
    description: Aircraft tail registration (ICAO reg, e.g. PR-ABC); sourced from kpi08.reg
    checks:
      - name: not_null
  - name: runway_validated
    description: Validated runway
  - name: bearing
    description: Bearing of the flight
  - name: setor_raw
    description: Raw sector value from source
  - name: entry_time
    description: Time of entry into TMA
  - name: cylinder_radius
    description: Cylinder radius
  - name: landing_time
    description: Time of exit from TMA
    checks:
      - name: not_null
  - name: transito_raw
    description: Raw transit time
  - name: desimp_raw
    description: Raw reference transit time
  - name: kpi08_interval
    description: Additional transit time as interval

@bruin */

select
    -- Type casting and standardization only: no filters, no calculations, no joins
    aldt::date as flight_date,
    fltid as flight_id,
    adep::varchar as departure_airport,
    ades::varchar as arrival_airport,
    type as aircraft_type,
    reg as aircraft_registration,
    drwy_validado as runway_validated,
    bear as bearing,
    setor as setor_raw,
    c_time::timestamp as entry_time,
    c as cylinder_radius,
    aldt::timestamp as landing_time,
    transito as transito_raw,
    cast(desimp as interval) as desimp_raw,
    cast(kpi08 as interval) as kpi08_interval
from raw.kpi08
where 1=1
