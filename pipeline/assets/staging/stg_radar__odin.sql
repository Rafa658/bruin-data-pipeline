/* @bruin

name: staging.stg_radar__odin
type: duckdb.sql
tags:
  - staging

materialization:
  type: view

depends:
  - raw.tb_radar

columns:
  - name: radar_date
    description: The date of the radar record
  - name: aircraft_speed
    description: The speed of the aircraft at the time of the radar record
  - name: flight_level
    description: The flight level of the aircraft at the time of the radar record
  - name: flight_id
    description: Flight callsign (ICAO airline code + number, e.g. TAM3763); sourced from radar.ds_registration which is mislabeled in the source schema
  - name: radar_timestamp
    description: The timestamp of the radar record

@bruin */

select
    -- Type casting and standardization only: no filters, no calculations, no joins
    -- Source ds_registration is filtered in intermediate layer (contains literal 'NULL' strings)
    dt_radar::date as radar_date,
    nr_speed as aircraft_speed,
    nr_flightlevel::numeric as flight_level,
    ds_registration as flight_id,
    dt_radar::timestamp as radar_timestamp
from raw.tb_radar
where 1=1
