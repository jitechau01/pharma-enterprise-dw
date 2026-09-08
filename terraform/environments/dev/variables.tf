variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "github_org" {
  description = "GitHub org/user that owns this repo, for CI OIDC trust"
  type        = string
}

variable "github_repo" {
  type    = string
  default = "pharma-enterprise-dw"
}

variable "mwaa_alert_email" {
  description = "Email subscribed to DAG/scheduler failure alerts"
  type        = string
  default     = ""
}

variable "snowflake_loader_users" {
  type    = list(string)
  default = []
}

variable "snowflake_transformer_users" {
  type    = list(string)
  default = []
}

variable "snowflake_analyst_users" {
  type    = list(string)
  default = []
}

# --- Two-step Snowflake <-> S3 trust (see docs/runbook.md) --------------
# Leave blank on the FIRST apply. Snowflake's storage_integration will be
# created with a placeholder trust; after the first apply, read
# `terraform output snowflake_storage_integration_iam_user_arn` /
# `_external_id`, set these two variables, and re-apply so the IAM role's
# trust policy is tightened to the real Snowflake-generated principal.
variable "snowflake_storage_integration_iam_user_arn" {
  type    = string
  default = ""
}

variable "snowflake_storage_integration_external_id" {
  type    = string
  default = ""
}
