/* @bruin

name: marts.fct_elapsed_time_by_fl
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - marts.fct_flights_at_tma

columns:
  - name: id
    description: Flight identifier (FK to dim_flight_attributes.id); radar points are children of a flight
  - name: aircraft_type
    description: Aircraft type
  - name: entry_ts
    description: Timestamp when the flight entered the TMA
  - name: radar_ts
    description: Timestamp of the current radar point
  - name: aircraft_speed_knots
    description: Speed of the aircraft at the radar point
  - name: flight_level_hundreds_of_feet
    description: Flight level at the radar point
  - name: avg_rocd
    description: Average rate of climb/descent between radar points (in ft/min * 100)
  - name: elapsed
    description: Elapsed time between radar points (in seconds)

custom_checks:
  - name: every flight key exists in dim_flight_attributes
    description: Referential integrity between the fact and the flight dimension; also validates the radar<->flight join produced valid flight keys.
    query: SELECT count(*) FROM marts.fct_elapsed_time_by_fl f LEFT JOIN marts.dim_flight_attributes d ON f.id = d.id WHERE d.id IS NULL
    value: 0
  - name: fact is non-empty
    description: Guards against a silently empty fact table from a broken join.
    query: SELECT count(*) > 0 FROM marts.fct_elapsed_time_by_fl
    value: 1

@bruin */

with
flights_at_tma as (
    select *
    from marts.fct_flights_at_tma
    where 1=1
),
flights_elapsed_time as (
    select
        id,
        aircraft_type,
        radar_ts,
        aircraft_speed_knots,
        flight_level_hundreds_of_feet::integer as flight_level_hundreds_of_feet,
        round(
            100 * (flight_level_hundreds_of_feet - lag(flight_level_hundreds_of_feet) over flight) /
            nullif(extract(epoch from (radar_ts - lag(radar_ts) over flight))::numeric, 0),
            2
        ) as avg_rocd,
        coalesce(extract(epoch from (radar_ts - lag(radar_ts) over flight)), 0) as elapsed
    from flights_at_tma
    where 1=1
    window flight as (partition by id order by radar_ts asc)
),
filter_null_elapsed as (
    select
        *
    from flights_elapsed_time
    where 1=1
        and elapsed <> 0
),
relevant_groups as (
    -- Reuse the flights_at_tma CTE instead of re-scanning the intermediate table
    select
        id
    from flights_at_tma
    group by id
    having count(*) >= 100
),
filter_relevant_number_of_records as (
    select
        f.*
    from filter_null_elapsed f
    join relevant_groups rg on f.id = rg.id
)
select
  *
from filter_relevant_number_of_records