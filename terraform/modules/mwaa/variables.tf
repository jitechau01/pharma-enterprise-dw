variable "name_prefix" {
  type = string
}

variable "airflow_version" {
  type    = string
  default = "2.9.2"
}

variable "environment_class" {
  description = "mw1.small | mw1.medium | mw1.large"
  type        = string
  default     = "mw1.small"
}

variable "min_workers" {
  type    = number
  default = 1
}

variable "max_workers" {
  type    = number
  default = 5
}

variable "dags_s3_bucket_arn" {
  type = string
}

variable "dags_s3_bucket_id" {
  type = string
}

variable "dag_s3_path" {
  type    = string
  default = "dags"
}

variable "requirements_s3_path" {
  type    = string
  default = "requirements.txt"
}

variable "plugins_s3_path" {
  type    = string
  default = "plugins.zip"
}

variable "execution_role_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "webserver_access_mode" {
  description = "PRIVATE_ONLY or PUBLIC_ONLY"
  type        = string
  default     = "PUBLIC_ONLY" # PRIVATE_ONLY + VPN/Direct Connect recommended for real prod use
}

variable "kms_key_arn" {
  type = string
}

variable "alert_email_endpoint" {
  description = "Email address subscribed to the DAG/task failure SNS topic"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
