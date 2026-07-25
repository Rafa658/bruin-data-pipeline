/* @bruin

name: marts.fct_elapsed_time_by_fl
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_radar_filtered_by_flights_at_tma
  - intermediate.int_fuel__by_flight_level
  - marts.dim_flight_identifiers

columns:
  - name: id
    description: Flight identifier (FK to dim_flight_identifiers.id); radar points are children of a flight
    checks:
      - name: not_null
  - name: aircraft_type
    description: Aircraft type
    checks:
      - name: not_null
  - name: c_time
    description: Timestamp when the flight entered the TMA
    checks:
      - name: not_null
  - name: dt_radar
    description: Timestamp of the current radar point
    checks:
      - name: not_null
  - name: nr_speed
    description: Speed of the aircraft at the radar point
    checks:
      - name: not_null
  - name: fl
    description: Flight level at the radar point
    checks:
      - name: not_null
      - name: positive
  - name: avg_rocd
    description: Average rate of climb/descent between radar points (in ft/min * 100)
    checks:
      - name: not_null
  - name: elapsed
    description: Elapsed time between radar points (in seconds)
    checks:
      - name: not_null
      - name: positive
  - name: fuel_flow
    description: Fuel flow (kg/s) from BADA at the radar point; NULL when no exact (aircraft_type, fl) match (interim exact-match join)

custom_checks:
  - name: every flight key exists in dim_flight_identifiers
    description: Referential integrity between the fact and the flight dimension; also validates the radar<->flight join produced valid flight keys.
    query: SELECT count(*) FROM marts.fct_elapsed_time_by_fl f LEFT JOIN marts.dim_flight_identifiers d ON f.id = d.id WHERE d.id IS NULL
    value: 0
  - name: fact is non-empty
    description: Guards against a silently empty fact table from a broken join.
    query: SELECT count(*) > 0 FROM marts.fct_elapsed_time_by_fl
    value: 1

@bruin */

with
flights_at_tma as (
    select
        id,
        dt_radar,
        nr_speed,
        fl,
        aircraft_type,
        c_time
    from intermediate.int_radar_filtered_by_flights_at_tma
    where 1=1
),
flights_elapsed_time as (
    select
        id,
        aircraft_type,
        c_time,
        dt_radar,
        nr_speed,
        fl,
        round(
            100 * (fl - lag(fl) over flight) /
            nullif(extract(epoch from (dt_radar - lag(dt_radar) over flight))::numeric, 0),
            2
        ) as avg_rocd,
        coalesce(extract(epoch from (dt_radar - lag(dt_radar) over flight)), 0) as elapsed
    from flights_at_tma
    where 1=1
    window flight as (partition by id order by dt_radar asc)
),
filter_null_elapsed as (
    select
        id,
        aircraft_type,
        c_time,
        dt_radar,
        nr_speed,
        fl,
        avg_rocd,
        elapsed
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
),
with_fuel as (
    -- Left join so radar points without an exact BADA match keep their
    -- elapsed/ROCD values with fuel_flow = NULL (interim; interpolation planned)
    select
        f.id,
        f.aircraft_type,
        f.c_time,
        f.dt_radar,
        f.nr_speed,
        f.fl,
        f.avg_rocd,
        f.elapsed,
        fu.fuel_flow
    from filter_relevant_number_of_records f
    left join intermediate.int_fuel__by_flight_level fu
        on fu.id = f.id
        and fu.dt_radar = f.dt_radar
)
select
    id,
    aircraft_type,
    c_time,
    dt_radar,
    nr_speed,
    fl,
    avg_rocd,
    elapsed,
    fuel_flow
from with_fuel
where 1=1
