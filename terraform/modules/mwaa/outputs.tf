output "webserver_url" {
  value = aws_mwaa_environment.this.webserver_url
}

output "environment_arn" {
  value = aws_mwaa_environment.this.arn
}

output "dag_failure_sns_topic_arn" {
  value = aws_sns_topic.dag_failures.arn
}
