/* @bruin

name: marts.fct_flights_at_tma
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_kpi08__filtered_by_forecast_conditions
  - intermediate.int_radar__deduplicating_readings

columns:
  - name: id
    description: Unique flight identifier (radar_date + flight_id); radar points are children of a flight, ordered by dt_radar
  - name: radar_ts
    description: The timestamp of the radar record
  - name: aircraft_speed_knots
    description: The speed of the aircraft at the time of the radar record
  - name: flight_level_hundreds_of_feet
    description: The flight level of the aircraft at the time of the radar record
  - name: aircraft_type
    description: Aircraft type
  - name: entry_ts
    description: Time of entry into TMA
  - name: landing_ts
    description: Time of exit from TMA

@bruin */

with
radar_at_tma as (
    -- Join radar to flights on composite key (date + callsign) and confine to the
    -- TMA transit window [entry_time, landing_time]. Quality filters relocated here
    -- from staging because the radar source contains literal 'NULL' callsign strings
    -- and null flight levels.
    select
        r.id,
        r.radar_ts,
        r.aircraft_speed_knots,
        r.flight_level_hundreds_of_feet,
        f.aircraft_type,
        f.entry_ts,
        f.landing_ts,
        row_number() over(
            partition by r.id, r.radar_date, r.flight_level_hundreds_of_feet
            order by r.radar_ts asc
        ) as rn
    from intermediate.int_radar__deduplicating_readings r
    join intermediate.int_kpi08__filtered_by_forecast_conditions f
        on r.id = f.id
        and r.radar_date = f.flight_date
    where 1=1
        and r.radar_ts >= f.entry_ts
        and r.radar_ts <= f.landing_ts
)
select
    id,
    radar_ts,
    aircraft_speed_knots,
    flight_level_hundreds_of_feet,
    aircraft_type,
    entry_ts,
    landing_ts
from radar_at_tma
where 1=1
    and rn = 1
