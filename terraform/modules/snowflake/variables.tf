variable "env" {
  description = "dev | staging | prod -- prefixed onto every Snowflake object name"
  type        = string
}

variable "raw_database_name" {
  type    = string
  default = "PHARMA_RAW"
}

variable "dbt_database_name" {
  type    = string
  default = "PHARMA_DBT"
}

variable "analytics_database_name" {
  type    = string
  default = "PHARMA_ANALYTICS"
}

variable "raw_source_schemas" {
  description = "One schema per source system landing into RAW"
  type        = list(string)
  default     = ["MDM", "CRM", "ERP"]
}

variable "loading_warehouse_size" {
  type    = string
  default = "XSMALL"
}

variable "transforming_warehouse_size" {
  type    = string
  default = "SMALL"
}

variable "reporting_warehouse_size" {
  type    = string
  default = "XSMALL"
}

variable "monthly_credit_quota" {
  description = "Resource monitor quota (credits/month) across all three warehouses"
  type        = number
  default     = 200
}

variable "loader_role_users" {
  description = "Snowflake usernames granted the PHARMA_LOADER functional role (typically just the ingestion service account)"
  type        = list(string)
  default     = []
}

variable "transformer_role_users" {
  description = "Snowflake usernames granted PHARMA_TRANSFORMER (dbt service account, CI service account)"
  type        = list(string)
  default     = []
}

variable "analyst_role_users" {
  description = "Snowflake usernames granted PHARMA_ANALYST (read-only BI/reporting)"
  type        = list(string)
  default     = []
}

variable "storage_integration_role_arn" {
  description = "IAM role ARN (from the iam module) that Snowflake's storage integration assumes to read the raw S3 bucket"
  type        = string
}

variable "raw_bucket_s3_uri" {
  description = "e.g. s3://dev-pharma-raw-landing/"
  type        = string
}
