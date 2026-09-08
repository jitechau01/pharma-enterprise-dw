# The Snowflake-side half of the S3 trust relationship. This resource's
# `storage_aws_iam_user_arn` and `storage_aws_external_id` outputs are what
# get fed into terraform/modules/iam's
# snowflake_storage_integration_iam_user_arn / _external_id variables on the
# *second* apply (see docs/runbook.md).

resource "snowflake_storage_integration" "raw_s3" {
  name    = "PHARMA_RAW_S3_INTEGRATION_${upper(var.env)}"
  comment = "Allows Snowflake external stages in PHARMA_RAW to read s3://<raw-bucket>."
  type    = "EXTERNAL_STAGE"
  enabled = true

  storage_provider         = "S3"
  storage_aws_role_arn     = var.storage_integration_role_arn
  storage_allowed_locations = [var.raw_bucket_s3_uri]
}

resource "snowflake_file_format" "csv_standard" {
  for_each    = snowflake_schema.raw_source
  name        = "CSV_STANDARD"
  database    = snowflake_database.raw.name
  schema      = each.value.name
  format_type = "CSV"

  field_optionally_enclosed_by = "\""
  skip_header                  = 1
  null_if                      = ["", "NULL", "null"]
  empty_field_as_null          = true
  error_on_column_count_mismatch = false
}

resource "snowflake_stage" "raw_landing" {
  for_each            = snowflake_schema.raw_source
  name                = "${each.value.name}_RAW_STAGE"
  database            = snowflake_database.raw.name
  schema              = each.value.name
  url                 = "${var.raw_bucket_s3_uri}${lower(each.value.name)}/"
  storage_integration = snowflake_storage_integration.raw_s3.name
  file_format         = "FORMAT_NAME = ${snowflake_database.raw.name}.${each.value.name}.${snowflake_file_format.csv_standard[each.key].name}"
  comment             = "External stage over the ${each.value.name} prefix of the raw S3 landing bucket."
}
