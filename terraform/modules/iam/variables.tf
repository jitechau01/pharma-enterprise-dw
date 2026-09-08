variable "name_prefix" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "mwaa_bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "github_org" {
  description = "GitHub organization/user that owns this repo (for OIDC trust condition)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name (org/repo), used to scope the OIDC trust condition"
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Set false if a GitHub OIDC provider already exists in this AWS account"
  type        = bool
  default     = true
}

# Populated after Snowflake storage integration is created (chicken/egg: the
# integration needs the role ARN, the role's trust policy needs the
# integration's external ID). See terraform/environments/dev/main.tf for the
# two-step apply this requires, documented in docs/runbook.md.
variable "snowflake_storage_integration_iam_user_arn" {
  type    = string
  default = ""
}

variable "snowflake_storage_integration_external_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
