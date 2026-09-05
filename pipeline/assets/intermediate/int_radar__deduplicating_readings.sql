/* @bruin

name: intermediate.int_radar__deduplicating_readings
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - staging.stg_radar__odin

columns:
  - name: id
    description: Unique flight identifier (radar_date + flight_id); radar points are children of a flight, ordered by dt_radar
  - name: radar_ts
    description: The timestamp of the radar record
  - name: aircraft_speed_knots
    description: The speed of the aircraft at the time of the radar record
  - name: flight_level_hundreds_of_feet
    description: The flight level of the aircraft at the time of the radar record

@bruin */

with
filtering_nulls as (
    select
      id,  
      radar_ts,
      aircraft_speed_knots,
      flight_level_hundreds_of_feet
    from staging.stg_radar__odin
    where 1=1
      and flight_id is not null
      and flight_id <> 'NULL'
      and flight_level_hundreds_of_feet is not null
      and aircraft_speed_knots is not null
),
row_number_over_id as (
    select
      *,
      row_number() over(
          partition by id, flight_level_hundreds_of_feet
          order by radar_ts desc
      ) as rn
    from filtering_nulls
),
deduplicating_records as (
    select
      id,
      radar_ts,
      aircraft_speed_knots,
      flight_level_hundreds_of_feet
    from row_number_over_id
    where rn = 1
)
select *
from deduplicating_records