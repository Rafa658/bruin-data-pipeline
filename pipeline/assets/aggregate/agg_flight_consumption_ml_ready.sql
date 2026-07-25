/* @bruin

name: agg.flight_consumption_ml_ready
type: duckdb.sql
tags:
  - aggregate

materialization:
  type: table

depends:
  - agg.flight_consumption

@bruin */

with
base as (
    select
        fc.*,
        extract(day   from fc.aldt)::int as day,
        extract(month from fc.aldt)::int as month,
        extract(dow   from fc.aldt)::int as dow
    from agg.flight_consumption fc
    where 1=1
),
percentiles as (
    select
        adep,
        aircraft,
        drwy_validado,
        percentile_cont(0.2) WITHIN GROUP (ORDER BY consumption_kg) AS consumption_20p
    from base
    group by 1, 2, 3
),
transit_tma_moving_avg as (
    select
        id,
        avg(transit_tma) OVER (
            PARTITION BY drwy_validado, setor
            ORDER BY aldt
            RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW
        ) as transit_tma_predicted
    from base
),
final as (
    select
        b.id,
        b.date,
        b.adep,
        b.aircraft,
        b.drwy_validado,
        b.day,
        b.month,
        b.hour,
        case
            when b.dow = 0 then 'sun'
            when b.dow = 1 then 'mon'
            when b.dow = 2 then 'tue'
            when b.dow = 3 then 'wed'
            when b.dow = 4 then 'thu'
            when b.dow = 5 then 'fri'
            when b.dow = 6 then 'sat'
            else 'invalid'
        end as dow,
        b.setor,
        b.kpi08,
        b.transit_tma,
        t.transit_tma_predicted,
        b.visibility,
        b.ceiling,
        b.consumption_kg,
        p.consumption_20p,
        b.nr_aircraft_in_tma,
        b.consumption_kg - p.consumption_20p as kpi16
    from base b
        left join percentiles p using (adep, aircraft, drwy_validado)
        left join transit_tma_moving_avg t using (id)
)
select * from final
