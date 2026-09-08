# --- PHARMA_LOADER: write-only into RAW ---------------------------------

resource "snowflake_database_grant" "loader_raw_usage" {
  database_name = snowflake_database.raw.name
  privilege     = "USAGE"
  roles         = [snowflake_role.loader.name]
}

resource "snowflake_schema_grant" "loader_raw_schema_usage" {
  for_each      = snowflake_schema.raw_source
  database_name = snowflake_database.raw.name
  schema_name   = each.value.name
  privilege     = "USAGE"
  roles         = [snowflake_role.loader.name]
}

resource "snowflake_schema_grant" "loader_raw_schema_create_table" {
  for_each      = snowflake_schema.raw_source
  database_name = snowflake_database.raw.name
  schema_name   = each.value.name
  privilege     = "CREATE TABLE"
  roles         = [snowflake_role.loader.name]
}

resource "snowflake_table_grant" "loader_raw_table_dml" {
  for_each      = snowflake_schema.raw_source
  database_name = snowflake_database.raw.name
  schema_name   = each.value.name
  privilege     = "INSERT"
  roles         = [snowflake_role.loader.name]
  on_future     = true
}

resource "snowflake_warehouse_grant" "loader_wh_usage" {
  warehouse_name = snowflake_warehouse.loading.name
  privilege      = "USAGE"
  roles          = [snowflake_role.loader.name]
}

# --- PHARMA_TRANSFORMER: read RAW, full control of DBT database ---------

resource "snowflake_database_grant" "transformer_raw_usage" {
  database_name = snowflake_database.raw.name
  privilege     = "USAGE"
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_schema_grant" "transformer_raw_schema_usage" {
  for_each      = snowflake_schema.raw_source
  database_name = snowflake_database.raw.name
  schema_name   = each.value.name
  privilege     = "USAGE"
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_table_grant" "transformer_raw_select" {
  for_each      = snowflake_schema.raw_source
  database_name = snowflake_database.raw.name
  schema_name   = each.value.name
  privilege     = "SELECT"
  roles         = [snowflake_role.transformer.name]
  on_future     = true
}

resource "snowflake_database_grant" "transformer_dbt_all" {
  database_name = snowflake_database.dbt.name
  privilege     = "USAGE"
  roles         = [snowflake_role.transformer.name]
}

resource "snowflake_database_grant" "transformer_dbt_create_schema" {
  database_name = snowflake_database.dbt.name
  privilege     = "CREATE SCHEMA"
  roles         = [snowflake_role.transformer.name]
}

# dbt needs full DDL/DML in its own working database (it creates/drops
# tables and views constantly across staging/snapshots/intermediate/marts).
resource "snowflake_database_grant" "transformer_dbt_ownership" {
  database_name     = snowflake_database.dbt.name
  privilege         = "OWNERSHIP"
  roles             = [snowflake_role.transformer.name]
  with_grant_option = false
}

resource "snowflake_warehouse_grant" "transformer_wh_usage" {
  warehouse_name = snowflake_warehouse.transforming.name
  privilege      = "USAGE"
  roles          = [snowflake_role.transformer.name]
}

# --- PHARMA_ANALYST: read-only against ANALYTICS -------------------------

resource "snowflake_database_grant" "analyst_analytics_usage" {
  database_name = snowflake_database.analytics.name
  privilege     = "USAGE"
  roles         = [snowflake_role.analyst.name]
}

resource "snowflake_schema_grant" "analyst_analytics_schema_usage" {
  database_name = snowflake_database.analytics.name
  schema_name   = snowflake_schema.analytics.name
  privilege     = "USAGE"
  roles         = [snowflake_role.analyst.name]
}

resource "snowflake_view_grant" "analyst_analytics_select" {
  database_name = snowflake_database.analytics.name
  schema_name   = snowflake_schema.analytics.name
  privilege     = "SELECT"
  roles         = [snowflake_role.analyst.name]
  on_future     = true
}

resource "snowflake_warehouse_grant" "analyst_wh_usage" {
  warehouse_name = snowflake_warehouse.reporting.name
  privilege      = "USAGE"
  roles          = [snowflake_role.analyst.name]
}
