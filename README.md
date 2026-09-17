# Bruin Aviation KPI Pipeline

This repository contains a [Bruin](https://getbruin.com/) pipeline that prepares
flight, radar, and BADA aircraft-performance data for analysis of operations in
the 100 NM Terminal Maneuvering Area (TMA) around São Paulo/Guarulhos
International Airport (SBGR).

The active pipeline runs on DuckDB. It filters the study population, matches
radar readings to flights, calculates flight-level movement and TMA occupancy,
and attaches interpolated BADA fuel-flow values to radar points.

## Repository layout

```text
.
├── .bruin.example.yml             # Local Bruin connection template
├── pyproject.toml                 # Python tooling metadata
├── README.md
└── pipeline/
    ├── pipeline.yml               # Pipeline schedule and default connections
    ├── README.md                  # Pipeline-specific notes
    └── assets/
        ├── raw/                   # External Parquet views and BADA seed asset
        ├── staging/               # Source renaming and type normalization
        ├── intermediate/          # Filtering, deduplication, and interpolation
        ├── marts/                 # Runnable analytical tables
        ├── aggregate/             # Disabled experimental KPI16 outputs
        └── seeds/
            └── bada_fuel_chart.csv
```

Generated local files such as `.bruin.yml`, `bruin.duckdb`, `bruin-docs.html`,
logs, and `graphify-out/` are intentionally ignored by Git.

## Pipeline architecture

```text
KPI08 Parquet ──> raw.kpi08 ──> staging.stg_kpi08__odin
                                      │
                                      v
                    intermediate.int_kpi08__filtered_by_forecast_conditions
                         │             │                    │
                         v             v                    v
              dim_flight_attributes   dim_flight_       fct_flights_at_tma
                                     transit_metrics           │
                                                              ├──> fct_tma_occupation
Radar Parquet ──> raw.tb_radar ──> staging.stg_radar__odin     │
                                      │                        v
                                      └──> int_radar__    fct_elapsed_time_by_fl
                                           deduplicating_      │
                                           readings            v
                                                     fct_fuel_flow_by_flight_level
                                                              ^
BADA CSV ──> raw.bada_fuel_chart ──> staging.stg_fuel_chart__bada
                                      │
                                      └──> int_fuel__bada_interpolated
```

### Layers and assets

| Layer | Purpose | Current assets |
|---|---|---|
| `raw` | Expose source data with minimal transformation. | `kpi08`, `tb_radar`, `bada_fuel_chart` |
| `staging` | Normalize names and types and create the shared flight key. | `stg_kpi08__odin`, `stg_radar__odin`, `stg_fuel_chart__bada` |
| `intermediate` | Apply study filters, remove duplicate readings, and interpolate BADA values. | `int_kpi08__filtered_by_forecast_conditions`, `int_radar__deduplicating_readings`, `int_fuel__bada_interpolated` |
| `marts` | Materialize flight attributes, KPI08 metrics, radar-point facts, TMA occupancy, elapsed time, and fuel flow. | `dim_flight_attributes`, `dim_flight_transit_metrics`, `fct_flights_at_tma`, `fct_tma_occupation`, `fct_elapsed_time_by_fl`, `fct_fuel_flow_by_flight_level` |
| `aggregate` | Prototype flight-consumption and ML-ready datasets. | `agg_flight_consumption`, `agg_flight_consumption_ml_ready` |

Both aggregate assets currently have `enabled: false`. They still reference an
earlier marts schema and are not part of a normal pipeline run.

## Key modeling rules

- A flight is matched across KPI08 and radar data with `date || callsign`.
  `raw.tb_radar.ds_registration` is misleadingly named: it contains a callsign,
  so staging renames it to `flight_id`.
- The study population is limited to flights arriving at SBGR, entering the
  100 NM cylinder, departing from Brazilian airports (`SB%`), using one of the
  configured common aircraft types, and having usable KPI08 and sector data.
- KPI08 rows are deduplicated by flight key, keeping the latest landing
  timestamp.
- Radar rows with missing identifiers, flight levels, or speed are removed.
  Readings are deduplicated by flight and flight level.
- `marts.fct_flights_at_tma` keeps radar points inside each flight's inclusive
  `[entry_ts, landing_ts]` interval.
- `marts.fct_elapsed_time_by_fl` calculates elapsed seconds and average
  climb/descent rate between consecutive radar points. Flights with fewer than
  100 retained radar readings are excluded.
- `intermediate.int_fuel__bada_interpolated` linearly fills BADA flight levels
  from 0 through 400. `marts.fct_fuel_flow_by_flight_level` then joins the
  interpolated value by aircraft type and integer flight level.
- `marts.fct_tma_occupation` turns flight entry and landing events into
  validity intervals containing the number of aircraft in the TMA.

## Prerequisites

- [Bruin CLI](https://getbruin.com/docs/getting-started/installation)
- Source KPI08 and radar Parquet datasets
- A local DuckDB database path
- Python 3.14+ and Poetry only if you need the Python dependencies declared in
  `pyproject.toml`

Install the Bruin CLI on macOS or Linux:

```bash
curl -LsSf https://getbruin.com/install/cli | sh
```

Optional Python environment:

```bash
poetry install --no-root
```

## Local setup

1. Clone the repository.

   ```bash
   git clone git@github.com:Rafa658/bruin-data-pipeline.git
   cd bruin-data-pipeline
   ```

2. Create the local Bruin configuration.

   ```bash
   cp .bruin.example.yml .bruin.yml
   ```

3. Edit `.bruin.yml` and set the `duckdb-default` path to a writable local
   database file. The PostgreSQL connection remains in the pipeline
   configuration but is not used by the current DuckDB SQL assets.

4. The `s3-local` connection is available to Ingestr assets, but DuckDB SQL
   assets do not automatically inherit separate S3 connections. Create a local
   persistent DuckDB secret using the same MinIO values from `s3-local`,
   replacing the placeholders below:

   ```bash
   bruin query --connection duckdb-default --query "
     INSTALL httpfs;
     LOAD httpfs;
     CREATE OR REPLACE PERSISTENT SECRET minio_odin (
       TYPE s3,
       KEY_ID '<minio-access-key>',
       SECRET '<minio-secret-key>',
       ENDPOINT '<minio-host:port>',
       USE_SSL false,
       URL_STYLE 'path',
       SCOPE 's3://odin-data'
     );
   "
   ```

   The raw assets read `s3://odin-data/kpi08/**/*.parquet` and
   `s3://odin-data/tb-radar/**/*.parquet`, both Hive-partitioned by
   `ingestion_date`. The BADA seed is already tracked at
   `pipeline/assets/seeds/bada_fuel_chart.csv`.

5. Validate the project.

   ```bash
   bruin validate .
   ```

## Running and inspecting the pipeline

Run from the repository root. Use one worker because concurrent writers can
contend for the same DuckDB file.

```bash
# First load: create the raw tables for the selected interval
bruin run pipeline/pipeline.yml --start-date 2026-09-15 --end-date 2026-09-16 --full-refresh --workers 1

# Incremental run or backfill; start is inclusive and end is exclusive
bruin run pipeline/pipeline.yml --start-date 2026-09-01 --end-date 2026-09-08 --workers 1

# Run only the raw layer
bruin run pipeline/pipeline.yml --start-date 2026-09-15 --end-date 2026-09-16 --workers 1 --selector 'path:assets/raw/*'

# Recreate only the staging views for an interval (raw tables must already exist)
bruin run pipeline/pipeline.yml --start-date 2026-09-15 --end-date 2026-09-16 --workers 1 --selector 'path:assets/staging/*'

# Render a staging view without executing it
bruin render pipeline/assets/staging/stg_radar__odin.sql --start-date 2026-09-15 --end-date 2026-09-16

# Inspect a result table
bruin query --connection duckdb-default \
  --query "select * from marts.fct_elapsed_time_by_fl limit 10"
```

Bruin infers dependencies from each asset's `depends` metadata. Column and
custom checks are declared in the asset headers and run with the pipeline.
`--full-refresh` replaces each raw table with only the selected interval; use
it only for the first load or an intentional reset.

The KPI08 and radar staging views retain `ingestion_date` and filter it using
the same half-open interval: `ingestion_date >= start_date` and
`ingestion_date < end_date`. A one-day run such as `2026-09-15` through
`2026-09-16` therefore exposes only the `2026-09-15` ingestion partition.
Staging views always represent the most recently rendered interval; they do
not persist previous backfill windows.

## Main outputs

| Asset | Grain and use |
|---|---|
| `marts.dim_flight_attributes` | One retained KPI08 flight record with route, aircraft, runway, sector, and TMA timestamps. |
| `marts.dim_flight_transit_metrics` | KPI08 transit, unimpeded, delay, and total TMA intervals by flight key. |
| `marts.fct_flights_at_tma` | Radar points matched to retained flights and restricted to their TMA transit window. |
| `marts.fct_elapsed_time_by_fl` | Consecutive radar-point elapsed time and climb/descent rate for sufficiently sampled flights. |
| `marts.fct_fuel_flow_by_flight_level` | BADA fuel flow attached to each eligible radar point. |
| `marts.fct_tma_occupation` | Time intervals with the concurrent aircraft count inside the TMA. |

## Development conventions

- Keep source-specific renaming and casting in `staging`.
- Put filtering, deduplication, interpolation, and cross-source preparation in
  `intermediate`.
- Materialize consumer-facing analytical datasets in `marts`.
- Add Bruin metadata, dependencies, column descriptions, and checks directly
  to each asset definition.
- Before opening a pull request, run:

  ```bash
  bruin validate .
  bruin run pipeline/pipeline.yml --workers 1
  ```

Use conventional commit prefixes such as `feat:`, `fix:`, `refactor:`,
`test:`, `docs:`, and `chore:`.

## References

- [Bruin documentation](https://getbruin.com/docs/)
- [DuckDB documentation](https://duckdb.org/docs/)
- `pipeline/README.md` for concise pipeline notes
