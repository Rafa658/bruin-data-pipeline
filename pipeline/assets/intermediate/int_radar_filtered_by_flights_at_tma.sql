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
    description: Unique flight identifier (radar_date + flight_id); radar points are children of a flight, ordered by dt_radar
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
flights as (
    -- Dedup kpi08 flights by composite key (flight_date + flight_id), keeping the
    -- latest landing_time when the same callsign appears more than once on a date
    select
        id,
        flight_id,
        flight_date,
        aircraft_type,
        entry_time,
        landing_time,
        row_number() over(partition by id order by landing_time desc) as rn
    from intermediate.int_kpi08_filtered_by_forecast_conditions
    where 1=1
),
flights_one as (
    select
        id,
        flight_id,
        flight_date,
        aircraft_type,
        entry_time,
        landing_time
    from flights
    where rn = 1
),
radar_at_tma as (
    -- Join radar to flights on composite key (date + callsign) and confine to the
    -- TMA transit window [entry_time, landing_time]. Quality filters relocated here
    -- from staging because the radar source contains literal 'NULL' callsign strings
    -- and null flight levels.
    select
        r.radar_date || r.flight_id as id,
        r.radar_timestamp as dt_radar,
        r.aircraft_speed as nr_speed,
        r.flight_level as fl,
        f.aircraft_type,
        f.entry_time as c_time,
        f.landing_time as aldt,
        row_number() over(
            partition by r.flight_id, r.radar_date, r.flight_level
            order by r.radar_timestamp asc
        ) as rn
    from staging.stg_radar__odin r
    join flights_one f
        on r.flight_id = f.flight_id
        and r.radar_date = f.flight_date
    where 1=1
        and r.flight_id is not null
        and r.flight_id <> 'NULL'
        and r.flight_level is not null
        and r.aircraft_speed is not null
        and r.radar_timestamp >= f.entry_time
        and r.radar_timestamp <= f.landing_time
)
select
    id,
    dt_radar,
    nr_speed,
    fl,
    aircraft_type,
    c_time,
    aldt
from radar_at_tma
where 1=1
    and rn = 1
