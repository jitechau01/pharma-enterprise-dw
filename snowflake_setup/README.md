# Snowflake bootstrap SQL

Terraform (`terraform/modules/snowflake`) creates the databases, schemas,
warehouses, roles/grants, the storage integration, and the external stages.
What Terraform deliberately does **not** manage is raw table DDL — column-by-
column schema evolution is painful to express/re-plan in Terraform, and raw
table shape changes fairly often as source systems evolve. Instead, raw
tables are plain SQL, run once at bootstrap and re-run (idempotently, all
`CREATE TABLE IF NOT EXISTS`) whenever a source schema changes.

Run these in order, as a role with `OWNERSHIP` on `PHARMA_RAW_<ENV>` (i.e.
`PHARMA_TRANSFORMER_<ENV>` or `SYSADMIN`):

```bash
snowsql -a <account> -u <user> -r PHARMA_TRANSFORMER_DEV \
  -f 01_raw_tables_mdm.sql \
  -D env=DEV
# ...repeat for 02_raw_tables_crm.sql and 03_raw_tables_erp.sql
```

Or, since these are just parameterized `CREATE TABLE IF NOT EXISTS`
statements, they're also safe to run as a one-time Airflow task
(`airflow/dags/pharma_raw_ingestion.py` includes a commented-out
`bootstrap_raw_tables` task using exactly these files via
`SQLExecuteQueryOperator` for environments that prefer "infra as DAG" over a
manual SnowSQL step).

Every raw table carries three load-metadata columns, populated by the
`COPY INTO` statements in `04_copy_into_templates.sql` (and by
`airflow/dags/pharma_raw_ingestion.py`, which builds the same statements
programmatically per table):

| Column | Populated from |
|---|---|
| `_source_file` | `METADATA$FILENAME` |
| `_source_file_row_number` | `METADATA$FILE_ROW_NUMBER` |
| `_loaded_at` | `CURRENT_TIMESTAMP()` |

These are what dbt's staging models use to dedupe (`qualify
row_number() over (partition by <natural_key> order by _loaded_at desc) = 1`)
when a file is accidentally reprocessed.
