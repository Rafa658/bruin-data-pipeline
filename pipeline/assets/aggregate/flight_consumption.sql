/* @bruin

name: aggregate.flight_consumption
type: duckdb.sql
tags:
  - aggregate

materialization:
  type: table

depends:
  - marts.fct_elapsed_time_by_fl
  - marts.fct_fuel_flow_by_flight_level
  - marts.dim_flight_attributes
  - marts.dim_flight_transit_metrics
  - marts.fct_tma_occupation

@bruin */

with
consumption_points as (
    select
        e.id,
        e.elapsed,
        f.fuel_flow
    from marts.fct_elapsed_time_by_fl e
    join marts.fct_fuel_flow_by_flight_level f
        on e.id = f.id
        and e.radar_ts = f.radar_ts
        and e.flight_level_hundreds_of_feet = f.flight_level_hundreds_of_feet
        and e.aircraft_type = f.aircraft_type
),
flight_metrics as (
    select
        a.id,
        a.landing_ts as aldt,
        a.entry_ts as c_time,
        a.flight_date as date,
        extract(hour from a.entry_ts)::int as hour,
        a.departure_airport as adep,
        a.aircraft_type as aircraft,
        a.runway_validated,
        a.bearing,
        a.sector,
        m.kpi08,
        m.transit_in_tma_interval
    from marts.dim_flight_attributes a
    join marts.dim_flight_transit_metrics m using (id)
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
    k.sector,
    epoch(k.kpi08) as kpi08,
    epoch(k.transit_in_tma_interval) as transit_in_tma_interval,
    null as visibility,
    null as ceiling,
    t.nr_aircraft_in_tma,
    c.consumption_kg
from flight_metrics k
left join consumption c using(id)
left join tma_occupation t
    on k.c_time >= t.dt_valid_from
    and k.c_time < t.dt_valid_to
where 1=1
