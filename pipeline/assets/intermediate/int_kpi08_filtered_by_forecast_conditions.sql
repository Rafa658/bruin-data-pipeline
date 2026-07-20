/* @bruin

name: intermediate.int_kpi08_filtered_by_forecast_conditions
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - staging.stg_kpi08__odin

columns:
  - name: id
    description: Unique flight identifier (date + flight_id)
    checks:
      - name: not_null
  - name: flight_date
    description: Flight date
    checks:
      - name: not_null
  - name: flight_id
    description: Flight ID
    checks:
      - name: not_null
  - name: departure_airport
    description: ICAO code of departure airport
    checks:
      - name: not_null
  - name: arrival_airport
    description: ICAO code of arrival airport
    checks:
      - name: not_null
  - name: aircraft_type
    description: Type of aircraft
    checks:
      - name: not_null
  - name: runway_validated
    description: Validated runway
  - name: bearing
    description: Bearing of the flight (0-360 degrees)
    checks:
      - name: not_null
  - name: setor
    description: TMA sector (0, 60, 120, 180, 240, 300) calculated from bearing
    checks:
      - name: not_null
      - name: accepted_values
        value:
          - "0"
          - "60"
          - "120"
          - "180"
          - "240"
          - "300"
  - name: entry_time
    description: Time of entry into TMA
  - name: cylinder_radius
    description: Cylinder radius
  - name: landing_time
    description: Time of exit from TMA
    checks:
      - name: not_null
  - name: transito
    description: Time between entering TMA cylinder and landing (in seconds)
    checks:
      - name: not_null
  - name: desimp
    description: Reference transit time (20th percentile for similar flights)
    checks:
      - name: not_null
  - name: kpi08
    description: Additional transit time (transito - desimp) representing delay
    checks:
      - name: not_null
  - name: transit_tma
    description: Actual transit time inside TMA (sum of desimp and kpi08)
    checks:
      - name: not_null

@bruin */

with
setor_imputation as (
    select
        -- ID generation (business logic)
        flight_date || flight_id as id,
        flight_date,
        flight_id,
        departure_airport,
        arrival_airport,
        aircraft_type,
        runway_validated,
        bearing,
        -- Mathematical calculation + imputation strategy
        case
            when setor_raw is not null then cast(setor_raw as integer)::varchar
            when bearing is not null then cast(floor(bearing/60) * 60 as integer)::varchar
            else null
        end as setor,
        entry_time,
        cylinder_radius,
        landing_time,
        transito_raw as transito,
        desimp_raw as desimp,
        kpi08_interval as kpi08,
        -- Business calculation: transit_tma = desimp + kpi08
        desimp_raw + kpi08_interval as transit_tma
    from staging.stg_kpi08__odin
),
filter_by_business_rules as (
  select
    id,
    departure_airport,
    arrival_airport,
    flight_id,
    aircraft_type,
    runway_validated,
    bearing,
    setor,
    flight_date,
    entry_time,
    cylinder_radius,
    landing_time,
    transito,
    desimp,
    kpi08,
    transit_tma
  from setor_imputation
  where 1=1
  -- Business rule: flights arrived at SBGR
  and arrival_airport = 'SBGR'
  -- Business rule: terminal maneuvering area cylinder radius is 100 nautical miles
  and cylinder_radius = 100
  -- Data quality: exclude flights without calculated kpi08
  and kpi08 is not null
  -- Data quality: exclude flights without setor
  and setor is not null
  -- Business rule: filter departures from airports in Brazil
  and departure_airport like 'SB%'
  -- Business rule: filter for most common aircraft types in Brazilian civil aviation
  and aircraft_type in (
    'A320', 'A321', 'B738', 'B38M',
    'A20N', 'A319', 'A21N', 'E195', 'B737', 'B734'
  )
)
select
  id,
  departure_airport,
  arrival_airport,
  flight_id,
  aircraft_type,
  runway_validated,
  bearing,
  setor,
  flight_date,
  entry_time,
  cylinder_radius,
  landing_time,
  transito,
  desimp,
  kpi08,
  transit_tma
from filter_by_business_rules