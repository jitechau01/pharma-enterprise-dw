output "raw_bucket_id" {
  value = module.s3_raw.bucket_id
}

output "mwaa_bucket_id" {
  value = module.s3_mwaa.bucket_id
}

output "mwaa_webserver_url" {
  value = module.mwaa.webserver_url
}

output "dag_failure_sns_topic_arn" {
  value = module.mwaa.dag_failure_sns_topic_arn
}

output "snowflake_storage_integration_iam_user_arn" {
  description = "After first apply, feed this into terraform.tfvars snowflake_storage_integration_iam_user_arn and re-apply"
  value       = module.snowflake.storage_integration_iam_user_arn
}

output "snowflake_storage_integration_external_id" {
  description = "After first apply, feed this into terraform.tfvars snowflake_storage_integration_external_id and re-apply"
  value       = module.snowflake.storage_integration_external_id
}

output "snowflake_raw_database" {
  value = module.snowflake.raw_database_name
}

output "snowflake_dbt_database" {
  value = module.snowflake.dbt_database_name
}

output "snowflake_analytics_database" {
  value = module.snowflake.analytics_database_name
}

output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}
