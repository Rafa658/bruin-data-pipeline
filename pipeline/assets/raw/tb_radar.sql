/* @bruin

type: duckdb.sql

materialization:
  type: view

@bruin */

select *
from read_parquet('../bruin/data/tb_radar/**/*.parquet', hive_partitioning = true)
