/* @bruin

name: marts.fct_elapsed_time_by_fl
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_radar_filtered_by_flights_at_tma

columns:
  - name: id
    description: Flight ID
    checks:
      - name: not_null
  - name: aircraft_type
    description: Aircraft type
    checks:
      - name: not_null
  - name: c_time
    description: Date of the flight
    checks:
      - name: not_null
  - name: nr_speed
    description: Speed of the aircraft
    checks:
      - name: not_null
  - name: fl
    description: Flight level
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

@bruin */

with
flights_at_tma as (
  select
      r.id,
      r.dt_radar,
      r.nr_speed,
      r.fl,
      r.aircraft_type,
      r.c_time
  from intermediate.int_radar_filtered_by_flights_at_tma r
),
flights_elapsed_time as (
  select
      id,
      nr_speed,
      fl,
      round(100 * (fl - lag(fl) over flight)/
      nullif(extract(epoch from (dt_radar - lag(dt_radar) over flight))::numeric, 0), 2) as avg_rocd,
      coalesce(extract(epoch from (dt_radar - lag(dt_radar) over flight)), 0) as elapsed
  from flights_at_tma
  where 1=1
  window flight as (partition by id order by dt_radar asc)
),
filter_null_elapsed as (
    select
        id,
        nr_speed,
        fl,
        avg_rocd,
        elapsed
    from flights_elapsed_time f
    where 1=1
        and elapsed <> 0
),
relevant_groups as (
    select 
      id, 
      count(*) as cnt
    from intermediate.int_radar_filtered_by_flights_at_tma
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