/* @bruin

type: duckdb.sql

materialization:
  type: view

@bruin */

select *
from read_parquet('~/Documents/bruin/data/tb_radar/**/*.parquet', hive_partitioning = true)
