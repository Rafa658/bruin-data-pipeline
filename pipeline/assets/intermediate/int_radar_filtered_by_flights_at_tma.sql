/* @bruin

name: intermediate.int_radar_filtered_by_flights_at_tma
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - intermediate.int_kpi08_filtered_by_forecast_conditions
  - staging.stg_radar__odin

columns:
  - name: id
    description: Unique radar point identifier (date + aircraft registration)
    checks:
      - name: not_null
  - name: dt_radar
    description: The timestamp of the radar record
    checks:
      - name: not_null
  - name: nr_speed
    description: The speed of the aircraft at the time of the radar record
    checks:
      - name: not_null
  - name: fl
    description: The flight level of the aircraft at the time of the radar record
    checks:
      - name: not_null
  - name: aircraft_type
    description: Aircraft type
    checks:
      - name: not_null
  - name: c_time
    description: Time of entry into TMA
    checks:
      - name: not_null
  - name: aldt
    description: Time of exit from TMA
    checks:
      - name: not_null

@bruin */

with
aircraft_by_id as (
    select
        id,
        aircraft_type,
        entry_time,
        landing_time,
        row_number() over(partition by id order by landing_time desc) as rn
    from intermediate.int_kpi08_filtered_by_forecast_conditions
    where 1=1
),
flights_past_tma as (
    select
        r.*,
        -- ID generation in intermediate layer
        r.radar_date || r.aircraft_registration as id,
        row_number() over(partition by r.radar_date, r.flight_level order by r.radar_timestamp asc) as rn,
        a.aircraft_type,
        a.entry_time,
        a.landing_time
    from staging.stg_radar__odin r
    join aircraft_by_id a
        on r.radar_date = a.landing_time::date
        and r.aircraft_registration = substring(a.id, -length(r.aircraft_registration))
    where 1=1
        and r.radar_timestamp >= a.entry_time
        and r.radar_timestamp <= a.landing_time
        and a.rn = 1
),
flights_deduped as (
    select
        id,
        radar_timestamp as dt_radar,
        aircraft_speed as nr_speed,
        flight_level as fl,
        aircraft_type,
        entry_time as c_time,
        landing_time as aldt
    from flights_past_tma
    where 1=1
        and rn = 1
)
select
    id,
    dt_radar,
    nr_speed,
    fl,
    aircraft_type,
    c_time,
    aldt
from flights_deduped
where 1=1
