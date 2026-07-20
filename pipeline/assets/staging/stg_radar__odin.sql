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
    checks:
      - name: not_null
  - name: aircraft_speed
    description: The speed of the aircraft at the time of the radar record
  - name: flight_level
    description: The flight level of the aircraft at the time of the radar record
    checks:
      - name: not_null
  - name: aircraft_registration
    description: The registration number of the aircraft
    checks:
      - name: not_null
  - name: radar_timestamp
    description: The timestamp of the radar record
    checks:
      - name: not_null

@bruin */

select
    -- Type safety and standardization only
    dt_radar::date as radar_date,
    nr_speed as aircraft_speed,
    nr_flightlevel::numeric as flight_level,
    ds_registration as aircraft_registration,
    dt_radar::timestamp as radar_timestamp
from raw.tb_radar tr
where 1=1
    and ds_registration <> 'NULL'
    and nr_flightlevel is not null
