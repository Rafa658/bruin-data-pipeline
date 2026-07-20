/* @bruin

type: duckdb.sql

materialization:
  type: view

@bruin */

select *
from read_parquet('../bruin/data/kpi08/**/*.parquet', hive_partitioning = true)
