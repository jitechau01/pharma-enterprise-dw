output "mwaa_execution_role_arn" {
  value = aws_iam_role.mwaa_execution.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "snowflake_storage_integration_role_arn" {
  value = aws_iam_role.snowflake_storage_integration.arn
}
