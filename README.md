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

## 🏗️ Architecture

### Data Pipeline Layers

```
raw/                    # Raw data ingestion
├── kpi08/             # Flight KPI data (Parquet files)
└── tb_radar/          # Radar point data

staging/               # Data preparation & type safety  
├── stg_kpi08__odin.sql        # KPI data type casting
├── stg_radar__odin.sql        # Radar data type casting
└── stg_fuel_chart__bada.sql   # Fuel chart data

intermediate/           # Business logic & transformations
├── int_kpi08_filtered_by_forecast_conditions.sql  # Business rules & filtering
└── int_radar_filtered_by_flights_at_tma.sql       # TMA radar filtering

marts/                 # Final analytical models
├── dim_flight_identifiers.sql              # Flight dimension
├── dim_flight_operational_attributes.sql    # Operational metrics
├── dim_tma_occupation.sql                  # TMA occupation over time
└── fct_elapsed_time_by_fl.sql              # Flight performance facts
```

### Key Transformations

- **Setor Imputation**: Calculates 6-sector TMA division from bearing angles (0°, 60°, 120°, 180°, 240°, 300°)
- **TMA Filtering**: Identifies radar points within 100NM cylinder during flight transit
- **KPI Calculation**: `transit_tma = desimp + kpi08` (reference time + additional delay)
- **Flight Level Analysis**: Computes rate of climb/descent between radar points

## 🚀 Getting Started

### Prerequisites

- **Bruin CLI**: Install from https://bruin.io
- **DuckDB**: Required database backend
- **Python 3.9+**: For additional tooling

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd bruin-kpi16
```

2. **Install Bruin CLI**
```bash
# macOS
brew install anomalyco/tap/bruin

# Or download from https://bruin.io
```

3. **Configure environment**
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
- Flight metadata (airports, aircraft, dates)
- Primary key: `id` (date + flight_id)

**dim_flight_operational_attributes**
- Operational metrics (runway, bearing, sector, transit times)
- TMA sector division (0, 60, 120, 180, 240, 300)
- KPI08: Additional transit time above reference

**dim_tma_occupation**
- Time-series of aircraft count in TMA
- Validity periods (dt_valid_from, dt_valid_to)
- Current occupation status

### Fact Tables

**fct_elapsed_time_by_fl**
- Flight performance metrics
- Rate of climb/descent between radar points
- Time elapsed between radar observations
- Filters: Flights with 100+ radar points only

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