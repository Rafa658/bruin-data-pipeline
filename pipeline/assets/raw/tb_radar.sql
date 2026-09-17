/* @bruin

name: raw.tb_radar
type: duckdb.sql
connection: duckdb-default

materialization:
  type: view

@bruin */

select *
from read_parquet(
  's3://odin-data/tb-radar/**/*.parquet',
  hive_partitioning = true,
  union_by_name = true
)
