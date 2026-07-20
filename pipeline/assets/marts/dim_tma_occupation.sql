/* @bruin

name: marts.dim_tma_occupation
type: duckdb.sql
tags:
  - marts

materialization:
  type: table

depends:
  - intermediate.int_radar_filtered_by_flights_at_tma
  - intermediate.int_kpi08_filtered_by_forecast_conditions

columns:
  - name: id
    description: Unique identifier for each record.
  - name: nr_aircraft_in_tma
    description: Number of aircraft in the TMA at the given time.
  - name: dt_valid_from
    description: Timestamp indicating when the record became valid.
    checks:
      - name: not_null
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

WITH 
flight_events AS (
    -- Eventos de entrada na TMA (cada voo entra uma vez)
    SELECT DISTINCT
        f.id,
        k.c_time AS event_time,
        'entry' AS event_type,
        1 AS change_value
    FROM intermediate.int_radar_filtered_by_flights_at_tma f
    LEFT JOIN intermediate.int_kpi08_filtered_by_forecast_conditions k
      USING (id)
    WHERE c_time IS NOT NULL
    
    UNION ALL
    
    -- Eventos de saída da TMA (pouso)
    SELECT DISTINCT
        f.id,
        k.aldt AS event_time,
        'exit' AS event_type,
        -1 AS change_value
    FROM intermediate.int_radar_filtered_by_flights_at_tma f
    LEFT JOIN intermediate.int_kpi08_filtered_by_forecast_conditions k
      USING (id)
    WHERE aldt IS NOT NULL
),

ordered_events AS (
    -- Ordena todos os eventos cronologicamente
    SELECT
        event_time,
        event_type,
        change_value,
        SUM(change_value) OVER (
            ORDER BY event_time, event_type DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS aircraft_count
    FROM flight_events
    WHERE event_time IS NOT NULL
),

occupation_changes AS (
    -- Identifica mudanças na quantidade de aviões
    SELECT
        event_time AS valid_from,
        aircraft_count,
        LEAD(event_time) OVER (ORDER BY event_time) AS valid_to
    FROM (
        SELECT
            event_time,
            aircraft_count,
            ROW_NUMBER() OVER (
                PARTITION BY event_time 
                ORDER BY event_time
            ) AS rn
        FROM ordered_events
    ) sub
    WHERE rn = 1
)

SELECT
    ROW_NUMBER() OVER (ORDER BY valid_from) AS id,
    aircraft_count AS nr_aircraft_in_tma,
    valid_from AS dt_valid_from,
    valid_to AS dt_valid_to,
    CASE 
        WHEN valid_to IS NULL THEN TRUE 
        ELSE FALSE 
    END AS is_current
FROM occupation_changes
ORDER BY valid_from
