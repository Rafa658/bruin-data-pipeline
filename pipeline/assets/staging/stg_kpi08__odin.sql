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
  - name: flight_id
    description: Flight ID
  - name: departure_airport
    description: ICAO code of departure airport
  - name: arrival_airport
    description: ICAO code of arrival airport
  - name: aircraft_type
    description: Type of aircraft
  - name: aircraft_registration
    description: Aircraft tail registration (ICAO reg, e.g. PR-ABC); sourced from kpi08.reg
  - name: runway_validated
    description: Validated runway
  - name: bearing
    description: Bearing of the flight
  - name: sector
    description: Sector value
  - name: entry_time
    description: Time of entry into TMA
  - name: cylinder_radius
    description: Cylinder radius
  - name: landing_time
    description: Time of exit from TMA
  - name: transito_raw
    description: Raw transit time
  - name: desimp_raw
    description: Raw reference transit time
  - name: kpi08_interval
    description: Additional transit time as interval

@bruin */

with
transformed as (
  select
      -- Type casting and standardization only: no filters, no calculations, no joins
      aldt::date as flight_date,
      fltid as flight_id,
      aldt::date || fltid as id,
      adep::varchar as departure_airport,
      ades::varchar as arrival_airport,
      type as aircraft_type,
      reg as aircraft_registration,
      drwy_validado as runway_validated,
      bear as bearing,
      case
          when sector is not null then cast(sector as integer)::varchar
          when bearing is not null then cast(floor(bearing / 60) * 60 as integer)::varchar
          else null
      end as sector,
      c_time::timestamp as entry_ts,
      c as cylinder_radius,
      aldt::timestamp as landing_ts,
      transito as transit_interval,
      -- CAST varchar interval strings to INTERVAL type (PostgreSQL stores intervals as 'HH:MM:SS')
      CASE 
          WHEN transito ~ '^\d{2}:\d{2}:\d{2}$' THEN transito::interval
          ELSE NULL
      END as unimpeded_interval,
      CASE 
          WHEN desimp ~ '^\d{2}:\d{2}:\d{2}$' THEN desimp::interval
          ELSE NULL
      END as kpi08
  from raw.kpi08
),
sum_transit_times as (
  select
    *,
    unimpeded_interval + kpi08 as transit_in_tma_interval
  from transformed
)
select *
from sum_transit_times