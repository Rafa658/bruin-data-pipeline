/* @bruin

name: marts.fct_tma_occupation
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_radar__filtered_by_flights_at_tma

columns:
  - name: id
    description: Surrogate row identifier for each occupation interval.
  - name: nr_aircraft_in_tma
    description: Number of aircraft in the TMA at the given time.
  - name: dt_valid_from
    description: Timestamp indicating when the record became valid.
    checks:
      - name: not_null
      - name: unique
  - name: dt_valid_to
    description: Timestamp indicating when the record is no longer valid.
  - name: is_current
    description: Boolean indicating if the record is the most current one.
    checks:
      - name: accepted_values
        value:
          - "true"
          - "false"

@bruin */

with
flight_events as (
    -- Entry events into TMA (each flight enters once)
    select distinct
        id,
        c_time as event_time,
        'entry' as event_type,
        1 as change_value
    from intermediate.int_radar__filtered_by_flights_at_tma
    where c_time is not null

    union all

    -- Exit events from TMA (landing)
    select distinct
        id,
        aldt as event_time,
        'exit' as event_type,
        -1 as change_value
    from intermediate.int_radar__filtered_by_flights_at_tma
    where aldt is not null
),

ordered_events as (
    -- Order all events chronologically and keep a running aircraft count
    select
        event_time,
        event_type,
        change_value,
        sum(change_value) over (
            order by event_time, event_type desc
            rows between unbounded preceding and current row
        ) as aircraft_count
    from flight_events
    where event_time is not null
),

occupation_changes as (
    -- Identify changes in aircraft count
    select
        event_time as valid_from,
        aircraft_count,
        lead(event_time) over (order by event_time) as valid_to
    from (
        select
            event_time,
            aircraft_count,
            row_number() over (
                partition by event_time
                order by event_time
            ) as rn
        from ordered_events
    ) sub
    where rn = 1
)

select
    row_number() over (order by valid_from) as id,
    aircraft_count as nr_aircraft_in_tma,
    valid_from as dt_valid_from,
    valid_to as dt_valid_to,
    case
        when valid_to is null then true
        else false
    end as is_current
from occupation_changes
order by valid_from
