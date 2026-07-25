/* @bruin

name: intermediate.int_fuel__bada_interpolated
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - staging.stg_fuel_chart__bada

columns:
  - name: aircraft
    description: Aircraft type code (ICAO designator)
    checks:
      - name: not_null
  - name: fl
    description: Flight level (0-400, integer)
    checks:
      - name: not_null
  - name: tas_ms
    description: True airspeed (m/s) linearly interpolated from BADA multiples-of-10 values
    checks:
      - name: not_null
  - name: fuel_flow_kg_s
    description: Fuel flow (kg/s) linearly interpolated from BADA multiples-of-10 values
    checks:
      - name: not_null

@bruin */

with
fl_series as (
    -- Generate all FL values 0..400 for each aircraft type in the BADA chart
    select
        aircraft,
        unnest(range(0, 401))::int as fl
    from staging.stg_fuel_chart__bada
    group by aircraft
),
joined as (
    -- For each generated FL, find the nearest lower and upper BADA FL (multiples of 10)
    select
        s.aircraft,
        s.fl,
        s.fl - (s.fl % 10) as fl_lower,
        s.fl - (s.fl % 10) + 10 as fl_upper,
        b_lower.tas_ms as tas_lower,
        b_upper.tas_ms as tas_upper,
        b_lower.fuel_flow_kg_s as fuel_lower,
        b_upper.fuel_flow_kg_s as fuel_upper
    from fl_series s
    left join staging.stg_fuel_chart__bada b_lower
        on b_lower.aircraft = s.aircraft
        and b_lower.fl = s.fl - (s.fl % 10)
    left join staging.stg_fuel_chart__bada b_upper
        on b_upper.aircraft = s.aircraft
        and b_upper.fl = s.fl - (s.fl % 10) + 10
    where 1=1
        and tas_lower is not null
        and tas_upper is not null
        and fuel_lower is not null
        and fuel_upper is not null
)
select
    aircraft,
    fl,
    -- Linear interpolation: lower + (upper - lower) * (fl - fl_lower) / (fl_upper - fl_lower)
    tas_lower + (tas_upper - tas_lower)::double * (fl - fl_lower) / (fl_upper - fl_lower) as tas_ms,
    fuel_lower + (fuel_upper - fuel_lower)::double * (fl - fl_lower) / (fl_upper - fl_lower) as fuel_flow_kg_s
from joined
where 1=1
