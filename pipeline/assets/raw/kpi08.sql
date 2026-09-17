/* @bruin

name: raw.kpi08
type: duckdb.sql
connection: duckdb-default

materialization:
  type: view

@bruin */

select *
from read_parquet(
  's3://odin-data/kpi08/**/*.parquet',
  hive_partitioning = true,
  union_by_name = true
)
