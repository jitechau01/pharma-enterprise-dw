output "raw_database_name" {
  value = snowflake_database.raw.name
}

output "dbt_database_name" {
  value = snowflake_database.dbt.name
}

output "analytics_database_name" {
  value = snowflake_database.analytics.name
}

output "loading_warehouse_name" {
  value = snowflake_warehouse.loading.name
}

output "transforming_warehouse_name" {
  value = snowflake_warehouse.transforming.name
}

output "reporting_warehouse_name" {
  value = snowflake_warehouse.reporting.name
}

output "storage_integration_name" {
  value = snowflake_storage_integration.raw_s3.name
}

output "storage_integration_iam_user_arn" {
  description = "Feed into terraform/modules/iam var.snowflake_storage_integration_iam_user_arn"
  value       = snowflake_storage_integration.raw_s3.storage_aws_iam_user_arn
}

output "storage_integration_external_id" {
  description = "Feed into terraform/modules/iam var.snowflake_storage_integration_external_id"
  value       = snowflake_storage_integration.raw_s3.storage_aws_external_id
}

output "loader_role_name" {
  value = snowflake_role.loader.name
}

output "transformer_role_name" {
  value = snowflake_role.transformer.name
}

output "analyst_role_name" {
  value = snowflake_role.analyst.name
}
