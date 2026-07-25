/* @bruin

name: intermediate.int_kpi08__enriched
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - staging.stg_kpi08__odin

columns:
  - name: id
    description: Unique flight identifier (flight_date + flight_id)
    checks:
      - name: not_null
  - name: flight_date
    description: Flight date
    checks:
      - name: not_null
  - name: flight_id
    description: Flight callsign (ICAO airline code + number)
    checks:
      - name: not_null
  - name: departure_airport
    description: ICAO code of departure airport
  - name: arrival_airport
    description: ICAO code of arrival airport
  - name: aircraft_type
    description: Type of aircraft
  - name: aircraft_registration
    description: Aircraft tail registration
  - name: runway_validated
    description: Validated runway
  - name: bearing
    description: Bearing of the flight
  - name: setor
    description: TMA sector (0, 60, 120, 180, 240, 300) calculated from bearing when setor_raw is null
  - name: entry_time
    description: Time of entry into TMA
  - name: cylinder_radius
    description: Cylinder radius
  - name: landing_time
    description: Time of exit from TMA
  - name: transito
    description: Raw transit time inside TMA
  - name: desimp
    description: Reference transit time (interval)
  - name: kpi08
    description: Additional transit time as interval
  - name: transit_tma
    description: Actual transit time inside TMA (desimp + kpi08)

@bruin */

select
    -- ID generation (business key): flight_date + flight_id (callsign)
    flight_date || flight_id as id,
    flight_date,
    flight_id,
    departure_airport,
    arrival_airport,
    aircraft_type,
    aircraft_registration,
    runway_validated,
    bearing,
    -- Imputation strategy: use raw setor when present, otherwise derive from bearing
    case
        when setor_raw is not null then cast(setor_raw as integer)::varchar
        when bearing is not null then cast(floor(bearing / 60) * 60 as integer)::varchar
        else null
    end as setor,
    entry_time,
    cylinder_radius,
    landing_time,
    transito_raw as transito,
    desimp_raw as desimp,
    kpi08_interval as kpi08,
    -- Business calculation: transit_tma = desimp + kpi08
    desimp_raw + kpi08_interval as transit_tma
from staging.stg_kpi08__odin
where 1=1
