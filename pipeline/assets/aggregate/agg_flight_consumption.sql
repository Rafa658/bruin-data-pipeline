/* @bruin

name: agg.flight_consumption
type: duckdb.sql
tags:
  - aggregate

materialization:
  type: table

depends:
  - marts.fct_elapsed_time_by_fl
  - marts.dim_flight_identifiers
  - intermediate.int_kpi08_filtered_by_forecast_conditions
  - marts.fct_tma_occupation

@bruin */

with
consumption_points as (
    select
        id,
        dt_radar,
        nr_speed,
        fl,
        avg_rocd,
        elapsed,
        fuel_flow
    from marts.fct_elapsed_time_by_fl
    where 1=1
),
id_aircraft as (
    select
        id,
        flight_date as date,
        aircraft_type as aircraft,
        entry_time as c_time,
        landing_time as aldt
    from marts.dim_flight_identifiers
    where 1=1
),
kpi08 as (
    select
        k.id,
        k.departure_airport as adep,
        k.arrival_airport as ades,
        k.flight_id as fltid,
        k.aircraft_type as aircraft,
        k.runway_validated,
        k.bearing,
        k.setor,
        k.flight_date as date,
        extract(hour from k.entry_time)::int as hour,
        k.entry_time as c_time,
        k.landing_time as aldt,
        k.transito,
        k.desimp,
        k.kpi08,
        k.transit_tma
    from intermediate.int_kpi08_filtered_by_forecast_conditions k
    where 1=1
),
consumption as (
    select
        c.id,
        sum(c.elapsed * c.fuel_flow) as consumption_kg
    from consumption_points c
    group by 1
),
tma_occupation as (
    select
        id,
        nr_aircraft_in_tma,
        dt_valid_from,
        dt_valid_to,
        is_current
    from marts.fct_tma_occupation
    where 1=1
)

select
    c.id,
    k.aldt,
    k.c_time,
    k.date,
    k.hour,
    k.adep,
    k.aircraft,
    k.runway_validated as drwy_validado,
    k.bearing as bear,
    k.setor,
    epoch(k.kpi08) as kpi08,
    epoch(k.transit_tma) as transit_tma,
    null as visibility,
    null as ceiling,
    t.nr_aircraft_in_tma,
    c.consumption_kg
from kpi08 k
left join consumption c using(id)
left join tma_occupation t
    on k.c_time >= t.dt_valid_from
    and k.c_time < t.dt_valid_to
where 1=1
