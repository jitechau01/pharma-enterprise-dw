variable "bucket_name" {
  description = "Globally-unique S3 bucket name"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable S3 object versioning"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS CMK ARN used for SSE-KMS bucket encryption"
  type        = string
}

variable "lifecycle_glacier_after_days" {
  description = "Days after object creation before transitioning to GLACIER. Set to 0 to disable."
  type        = number
  default     = 180
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket (dev/staging only, never prod)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
