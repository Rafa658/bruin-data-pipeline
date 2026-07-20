/* @bruin

name: staging.stg_fuel_chart__bada
type: duckdb.sql
tags:
  - staging

materialization:
  type: view

depends:
  - raw.bada_fuel_chart

columns:
  - name: aircraft
  - name: tas_ms
  - name: fl
  - name: fuel_flow_kg_s

@bruin */

select
    aircraft,
    tas_ms,
    cast(fl as int) as fl,
    cast(fuel_flow_kg_s as double) as flow
from raw.bada_fuel_chart
where 1=1
