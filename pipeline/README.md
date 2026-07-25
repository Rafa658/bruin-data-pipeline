# Bruin Pipeline — Aviation KPI16 (SBGR TMA)

This pipeline ingests flight KPI, radar, and BADA fuel data and builds the
dimensional/factual marts used by the KPI16 study (paper.pdf).

## Layout

```
pipeline/
├── pipeline.yml
└── assets/
    ├── raw/          # 1:1 with external sources (views + seed)
    ├── staging/      # type-cast + rename only
    ├── intermediate/ # IDs, imputation, filters, joins
    ├── marts/        # dim_* (descriptive) + fct_* (measures)
    └── seeds/        # bada_fuel_chart.csv
```

See `../REFACTORING_PLAN.md` for the layer contract and decisions, and
`../README.md` for the architecture overview.

## Run

```bash
# from repo root
bruin validate .
bruin run pipeline/pipeline.yml --workers 1   # DuckDB: single worker avoids lock contention
```

## Data sources

Sources live in the sibling `../bruin/data/` directory (referenced via
`read_parquet('../bruin/data/...')` from the raw SQL assets):

- `kpi08/**/*.parquet` — flight KPI (hive-partitioned by `ingestion_date`)
- `tb_radar/**/*.parquet` — radar points (hive-partitioned)
- `fuel_chart.csv` — BADA fuel chart (also seeded at `assets/seeds/bada_fuel_chart.csv`)

## Notes

- `raw.tb_radar.ds_registration` is mislabeled in the source: it holds flight
  **callsigns**, not tail registrations. `stg_radar__odin` renames it to
  `flight_id` to make the join with `stg_kpi08__odin.flight_id` (from `fltid`)
  explicit.
- `int_fuel__by_flight_level` joins BADA on exact `(aircraft_type, fl)`; BADA
  interpolation is planned and tracked in `../REFACTORING_PLAN.md`.
