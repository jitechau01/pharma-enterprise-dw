# Three-database layout keeps blast radius and RBAC simple:
#   PHARMA_RAW        -- landing tables, 1:1 with source, loaded by Airflow COPY INTO
#   PHARMA_DBT         -- dbt's working area: STAGING / SNAPSHOTS / INTERMEDIATE / MARTS schemas
#   PHARMA_ANALYTICS   -- consumption layer: secure views granted to BI tools/analysts
#
# dbt itself only ever writes into PHARMA_DBT (see dbt/pharma_dw/dbt_project.yml
# `+database:` / `+schema:` configs, which are environment-parameterized).

resource "snowflake_database" "raw" {
  name    = "${var.raw_database_name}_${upper(var.env)}"
  comment = "Immutable landing zone. 1:1 with source system extracts. Written only by the ingestion role."
}

resource "snowflake_database" "dbt" {
  name    = "${var.dbt_database_name}_${upper(var.env)}"
  comment = "dbt Core working database: staging, snapshots, intermediate, and marts schemas."
}

resource "snowflake_database" "analytics" {
  name    = "${var.analytics_database_name}_${upper(var.env)}"
  comment = "BI/reporting consumption layer. Secure views over PHARMA_DBT marts."
}

resource "snowflake_schema" "raw_source" {
  for_each = toset(var.raw_source_schemas)
  database = snowflake_database.raw.name
  name     = each.value
  comment  = "Raw landing tables for the ${each.value} source system."
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.dbt.name
  name     = "STAGING"
  comment  = "dbt staging models -- 1:1 cleaned/typed views over RAW."
}

resource "snowflake_schema" "snapshots" {
  database = snowflake_database.dbt.name
  name     = "SNAPSHOTS"
  comment  = "dbt snapshot tables -- SCD2 history for product/HCP/sales_rep."
}

resource "snowflake_schema" "intermediate" {
  database = snowflake_database.dbt.name
  name     = "INTERMEDIATE"
  comment  = "dbt intermediate models -- business logic, multi-source joins."
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.dbt.name
  name     = "MARTS"
  comment  = "dbt marts -- final dim_*/fact_* tables."
}

resource "snowflake_schema" "analytics" {
  database = snowflake_database.analytics.name
  name     = "ANALYTICS"
  comment  = "Secure views over MARTS, granted to PHARMA_ANALYST."
}
