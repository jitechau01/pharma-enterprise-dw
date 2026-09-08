# Functional-role pattern: humans/service-accounts get a functional role
# (LOADER / TRANSFORMER / ANALYST), which is granted only the access-grants
# it needs. Nobody is granted table privileges directly.

resource "snowflake_role" "loader" {
  name    = "PHARMA_LOADER_${upper(var.env)}"
  comment = "Ingestion service account role: write-only to PHARMA_RAW."
}

resource "snowflake_role" "transformer" {
  name    = "PHARMA_TRANSFORMER_${upper(var.env)}"
  comment = "dbt service account / CI role: read RAW, read/write DBT database (staging/snapshots/intermediate/marts)."
}

resource "snowflake_role" "analyst" {
  name    = "PHARMA_ANALYST_${upper(var.env)}"
  comment = "Read-only role for BI tools and analysts against PHARMA_ANALYTICS."
}

resource "snowflake_role_grants" "loader_users" {
  role_name = snowflake_role.loader.name
  users     = var.loader_role_users
}

resource "snowflake_role_grants" "transformer_users" {
  role_name = snowflake_role.transformer.name
  users     = var.transformer_role_users
}

resource "snowflake_role_grants" "analyst_users" {
  role_name = snowflake_role.analyst.name
  users     = var.analyst_role_users
}
