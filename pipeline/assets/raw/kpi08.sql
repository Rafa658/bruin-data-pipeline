/* @bruin

type: duckdb.sql

materialization:
  type: view

@bruin */

select *
from read_parquet('~/Documents/bruin/data/kpi08/**/*.parquet', hive_partitioning = true)
