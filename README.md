# Bruin Data Pipeline - Aviation KPI Analysis

## 📋 Overview

This project implements a production-grade data pipeline for analyzing aviation operations, specifically focused on Terminal Maneuvering Area (TMA) performance at São Paulo/Guarulhos International Airport (SBGR). The pipeline processes radar and flight data to calculate Key Performance Indicators (KPIs) that measure aircraft transit times and operational efficiency.

## 🎯 Key Features

- **Multi-layer Architecture**: Raw → Staging → Intermediate → Marts separation of concerns
- **TMA Performance Analysis**: Measures aircraft time spent in 100NM terminal area
- **Flight Level Calculations**: Computes rate of climb/descent between radar points
- **Quality Control**: Comprehensive data validation and business rule enforcement
- **DuckDB Integration**: Optimized for single-process, multi-threaded data processing
- **Materialization Strategy**: Performance-optimized table caching

## Why Bruin?

I chose [Bruin](https://getbruin.com/) over dbt for three main reasons:

1. **Already used dbt**: I've been using dbt daily at work and during my thesis development. I just wanted to try a different tool.

2. **Single-tool solution**: Bruin allows me to handle data ingestion and compilation in one tool — essentially replacing both Airflow and dbt in a single pipeline framework.

3. **Native Python support**: dbt also supports Python, but it's limited to dataframe operations. In Bruin, Python is a first-class citizen, allowing me to orchestrate Python code together with dbt compilation seamlessly.

dbt isn't bad — it's excellent and widely adopted. In fact I use it daily in my actual job. But I found working with Bruin for this project very enjoyable and plan to use it for other projects.

## 🏗️ Architecture

### Data Pipeline Layers

```
raw/                    # Raw data ingestion (1:1 with source, no transforms)
├── kpi08.sql                  # Flight KPI data (Parquet view)
├── tb_radar.sql               # Radar point data (Parquet view)
└── bada_fuel_chart.asset.yml  # BADA fuel chart (seed)

staging/               # Type-cast + rename only (no filters, no calc, no joins)
├── stg_kpi08__odin.sql          # KPI type casting (+aircraft_registration)
├── stg_radar__odin.sql          # Radar type casting (ds_registration -> flight_id)
└── stg_fuel_chart__bada.sql     # Fuel chart type casting

intermediate/          # Business logic: IDs, imputation, filters, joins
├── int_kpi08__enriched.sql                       # ID gen, setor imputation, transit_tma (no filter)
├── int_kpi08__filtered_by_forecast_conditions.sql # Business-rule filters (dep enriched)
├── int_radar_filtered_by_flights_at_tma.sql      # Radar<->flight join + TMA time window
└── int_fuel__by_flight_level.sql                 # BADA fuel_flow per radar point (exact FL match)

marts/                 # Final analytical models (dim_ descriptive, fct_ measures)
├── dim_flight_identifiers.sql           # Flight dimension (+reg, unique PK)
├── dim_flight_operational_attributes.sql # Operational attrs (descriptive only, unique PK)
├── fct_flight_transit_metrics.sql       # transito/desimp/kpi08/transit_tma (FK check)
├── fct_tma_occupation.sql               # TMA occupation over time (renamed from dim_)
└── fct_elapsed_time_by_fl.sql           # Flight performance + fuel_flow (FK + non-empty checks)
```

### Layer contract
- **raw** — 1:1 with external source. View. Source column names. Docs only.
- **staging** — type-cast + rename to snake_case. **No filters, no calc, no joins.** View.
- **intermediate** — ID gen, imputation, derived fields, business filters, cross-source joins. Table.
- **marts** — `dim_*` descriptive only + `unique` PK; `fct_*` measures + `not_null` FK + custom referential-integrity check. Table.

### Key Transformations

- **Flight composite key**: `(flight_date, flight_id)` where `flight_id` is the callsign (kpi08 `fltid`, radar `ds_registration` which is mislabeled in the source). Radar points are children of a flight, ordered by `dt_radar`.
- **Setor Imputation**: Calculates 6-sector TMA division from bearing angles (0°, 60°, 120°, 180°, 240°, 300) in `int_kpi08__enriched`.
- **TMA Filtering**: `int_radar_filtered_by_flights_at_tma` joins radar to flights on `(date, callsign)` and confines points to `[entry_time, landing_time]`.
- **KPI Calculation**: `transit_tma = desimp + kpi08` (reference time + additional delay) in `int_kpi08__enriched`.
- **Flight Level Analysis**: `fct_elapsed_time_by_fl` computes rate of climb/descent between radar points, partitioned by flight.
- **Fuel Burn**: `int_fuel__by_flight_level` joins BADA fuel_flow at exact `(aircraft_type, fl)`; LEFT-joined into `fct_elapsed_time_by_fl` (interim exact match; interpolation planned).

## 🚀 Getting Started

### Prerequisites

- **Bruin CLI**: Install from https://getbruin.com/
- **DuckDB**: Required database backend
- **Python 3.9+**: For additional tooling

### Installation

1. **Clone the repository**
```bash
git clone git@github.com:Rafa658/bruin-data-pipeline.git
cd bruin-data-pipeline
```

2. **Install Bruin CLI**
```bash
curl -LsSf https://getbruin.com/install/cli | sh
```

4. **Install DuckDB**
```bash
curl https://install.duckdb.org | sh
```

5. **Configure environment**
```bash
# Copy configuration template
cp .bruin.yml.example .bruin.yml

# Edit connection settings
nano .bruin.yml
```

## 📊 Running the Pipeline

### Basic Execution

```bash
# Run entire pipeline (recommended: single worker for DuckDB)
bruin run pipeline/pipeline.yml --workers 1

# Run specific pipeline
bruin run pipeline/pipeline.yml

# Run with debug output
bruin run pipeline/pipeline.yml --debug
```

### Pipeline Configuration

```bash
# List available pipelines
bruin run --help

# Validate configuration
bruin validate

# Test connections
bruin connections test duckdb-default
```

### Common Issues

**DuckDB Lock Conflicts:**
```bash
# Solution: Use single worker
bruin run pipeline/pipeline.yml --workers 1
```

**Materialization Performance:**
```bash
# Clear and rebuild tables
bruin clean
bruin run pipeline/pipeline.yml --workers 1
```

## 🔧 Configuration

### Environment Setup

Edit `.bruin.yml`:

```yaml
default_environment: default
environments:
  default:
    connections:
        duckdb:
            - name: duckdb-default
              path: /path/to/bruin.duckdb
        postgres:
            - name: pg-local
              username: postgres
              password: "your_password"
              host: localhost
              port: 5432
              database: aviation_kpi
```

### Pipeline Settings

Edit `pipeline/pipeline.yml`:

```yaml
name: bruin-init
schedule: daily
start_date: "2023-01-01"
catchup: false

default_connections:
    duckdb: duckdb-default
    postgres: pg-local
```

## 📈 Data Models

### Dimension Tables

**dim_flight_identifiers**
- Flight metadata (airports, aircraft, registration, dates)
- Primary key: `id` (flight_date + callsign), `unique` check

**dim_flight_operational_attributes**
- Operational descriptors (runway, bearing, sector, entry/landing times)
- Primary key: `id`, `unique` check
- Measures (transito/desimp/kpi08/transit_tma) live in `fct_flight_transit_metrics`

### Fact Tables

**fct_flight_transit_metrics**
- Per-flight transit measures: transito, desimp, kpi08, transit_tma
- FK to `dim_flight_identifiers.id` (custom referential-integrity check)

**fct_tma_occupation**
- Time-series of aircraft count in TMA (renamed from `dim_tma_occupation`)
- Validity periods (dt_valid_from, dt_valid_to), `unique` on dt_valid_from
- Current occupation status

**fct_elapsed_time_by_fl**
- Flight performance metrics: rate of climb/descent, elapsed time between radar points
- Fuel flow (BADA) LEFT-joined per radar point; NULL when no exact (aircraft_type, fl) match
- Filters: flights with 100+ radar points only
- FK + non-empty custom checks

## 🧪 Data Quality

### Quality Checks

- **Not Null**: Critical columns cannot be null
- **Positive Values**: Time, speed, and altitude must be positive
- **Accepted Values**: Setor must be in valid range
- **Referential Integrity**: Flight IDs must exist in intermediate layer
- **Temporal Logic**: Entry time must precede landing time

### Validation

```bash
# Run quality checks
bruin run pipeline/pipeline.yml --workers 1

# Check data quality logs
ls -la logs/
```

## 📊 Data Sources

### Input Data Structure

```
bruin/data/
├── kpi08/
│   └── **/*.parquet      # Flight KPI data
└── tb_radar/
    └── **/*.parquet      # Radar point data
```

### Source Data Schema

**KPI Data:**
- Flight identifiers (adep, ades, fltid, aircraft)
- Operational metrics (bearing, setor, runway)
- Transit times (transito, desimp, kpi08)
- Timestamps (c_time, aldt)

**Radar Data:**
- Aircraft registration (ds_registration)
- Flight level (nr_flightlevel)
- Speed (nr_speed)
- Radar timestamp (dt_radar)

## 🔍 Troubleshooting

### Common Errors

**1. DuckDB Lock Conflicts**
```bash
# Error: "Conflicting lock is held"
# Solution: Use single worker or kill stuck processes
ps aux | grep bruin
kill -9 <PID>
bruin run pipeline/pipeline.yml --workers 1
```

**2. Column Not Found**
```bash
# Error: "Referenced column not found"
# Solution: Check column names in staging layer
bruin query --connection duckdb-default "SELECT * FROM staging.stg_kpi08__odin LIMIT 5"
```

**3. Type Mismatch**
```bash
# Error: "Cannot compare values of type VARCHAR and type INTEGER"
# Solution: Ensure consistent type casting in staging layer
```

### Debug Mode

```bash
# Enable detailed logging
bruin run pipeline/pipeline.yml --debug

# Check specific asset
bruin render marts.fct_elapsed_time_by_fl
```

## 📚 Documentation

- **Bruin Documentation**: https://docs.bruin.io
- **DuckDB Documentation**: https://duckdb.org/docs
- **Aviation KPI Paper**: `paper.pdf` (local reference)

## 🤝 Contributing

1. Create feature branch
2. Make changes following layer separation principles
3. Test pipeline locally: `bruin run pipeline/pipeline.yml --workers 1`
4. Ensure quality checks pass
5. Commit with conventional messages

## 📝 Commit Conventions

```
feat: add new mart model for flight delays
fix: resolve DuckDB lock contention issues
refactor: separate business logic from staging layer
docs: update README with troubleshooting guide
```

## 📊 Performance Optimization

- **Materialization**: Intermediate layers use tables for caching
- **Single Worker**: DuckDB optimization for multi-threaded single process
- **Column Pruning**: Select only needed columns in transformations
- **Window Functions**: Efficient partitioning by flight ID

## 🔐 Security Notes

- Database credentials stored in `.bruin.yml` (add to `.gitignore`)
- No sensitive data in version control
- Environment-specific configurations

## 📈 Monitoring

```bash
# Check pipeline execution time
time bruin run pipeline/pipeline.yml --workers 1

# Monitor DuckDB database size
du -h bruin.duckdb

# Check log files
tail -f logs/latest_pipeline.log
```

## 🎓 Learning Resources

- **Data Engineering**: dbt best practices
- **Aviation Operations**: TMA management, flight performance
- **DuckDB**: Column-oriented analytics database
- **Bruin CLI**: Modern data pipeline orchestration

## 📞 Support

- **Bruin Community**: https://github.com/bruin-data/bruin
- **Issues**: Open GitHub issues for bugs and questions
- **Documentation**: See `/bruin-docs.html` for generated documentation

---

**Version**: 1.0.0  
**Last Updated**: 2026-07-11  
**Maintained By**: Data Engineering Team