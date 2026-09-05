/* @bruin

name: intermediate.int_fuel__by_flight_level
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - intermediate.int_radar__filtered_by_flights_at_tma
  - intermediate.int_fuel__bada_interpolated

columns:
  - name: id
    description: Flight composite key (radar_date + flight_id)
    checks:
      - name: not_null
  - name: dt_radar
    description: Radar timestamp the fuel flow applies to
    checks:
      - name: not_null
  - name: fl
    description: Flight level at the radar point (0-400, integer)
    checks:
      - name: not_null
  - name: aircraft_type
    description: Aircraft type
    checks:
      - name: not_null
  - name: fuel_flow
    description: Fuel flow (kg/s) from BADA interpolated table at the exact (aircraft_type, fl)

@bruin */

select
    r.id,
    r.dt_radar,
    r.fl,
    r.aircraft_type,
    b.fuel_flow_kg_s as fuel_flow
from intermediate.int_radar__filtered_by_flights_at_tma r
join intermediate.int_fuel__bada_interpolated b
    on b.aircraft = r.aircraft_type
    and b.fl = r.fl::int
where 1=1
