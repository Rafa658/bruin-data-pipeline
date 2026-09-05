/* @bruin

name: intermediate.int_kpi08__filtered_by_forecast_conditions
type: duckdb.sql
tags:
  - intermediate

materialization:
  type: table

depends:
  - staging.stg_kpi08__odin

columns:
  - name: id
    description: Unique flight identifier (flight_date + flight_id)
    checks:
      - name: not_null
  - name: flight_date
    description: Flight date
    checks:
      - name: not_null
  - name: flight_id
    description: Flight callsign (ICAO airline code + number)
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
  - name: aircraft_registration
    description: Aircraft tail registration
  - name: runway_validated
    description: Validated runway
  - name: bearing
    description: Bearing of the flight (0-360 degrees)
    checks:
      - name: not_null
  - name: sector
    description: TMA sector (0, 60, 120, 180, 240, 300) calculated from bearing
    checks:
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
  - name: landing_ts
    description: Time of exit from TMA
    checks:
      - name: not_null
  - name: transit_interval
    description: Time between entering TMA cylinder and landing (in seconds)
    checks:
      - name: not_null
  - name: unimpeded_interval
    description: Reference transit time (20th percentile for similar flights)
    checks:
      - name: not_null
  - name: kpi08
    description: Additional transit time (transito - desimp) representing delay
  - name: transit_in_tma_interval
    description: Actual transit time inside TMA (sum of desimp and kpi08)
    checks:
      - name: not_null

@bruin */

select
    id,
    flight_date,
    flight_id,
    departure_airport,
    arrival_airport,
    aircraft_type,
    aircraft_registration,
    runway_validated,
    bearing,
    sector,
    entry_ts,
    landing_ts,
    cylinder_radius,
    transit_interval,
    unimpeded_interval,
    kpi08,
    transit_in_tma_interval
from staging.stg_kpi08__odin
where 1=1
    -- Business rule: flights arrived at SBGR
    and arrival_airport = 'SBGR'
    -- Business rule: terminal maneuvering area cylinder radius is 100 nautical miles
    and cylinder_radius = 100
    -- Data quality: exclude flights without calculated kpi08
    and kpi08 is not null
    -- Data quality: exclude flights without sector
    and sector is not null
    -- Business rule: filter departures from airports in Brazil
    and departure_airport like 'SB%'
    -- Business rule: filter for most common aircraft types in Brazilian civil aviation
    and aircraft_type in (
        'A320', 'A321', 'B738', 'B38M',
        'A20N', 'A319', 'A21N', 'E195', 'B737', 'B734'
    )
