# Trust role assumed by Snowflake's storage integration to read/write the
# raw S3 bucket (used by the RAW.* external stages). Snowflake first creates
# the STORAGE INTEGRATION (which returns an IAM user ARN + external ID),
# those two values are then fed back into this role's trust policy -- see
# docs/runbook.md "Two-step Snowflake <-> S3 trust setup".

resource "aws_iam_role" "snowflake_storage_integration" {
  name = "${var.name_prefix}-snowflake-storage-integration-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.snowflake_storage_integration_iam_user_arn != "" ? var.snowflake_storage_integration_iam_user_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
      Condition = var.snowflake_storage_integration_external_id != "" ? {
        StringEquals = {
          "sts:ExternalId" = var.snowflake_storage_integration_external_id
        }
      } : {}
    }]
  })
}

resource "aws_iam_role_policy" "snowflake_storage_integration" {
  name = "${var.name_prefix}-snowflake-s3-access"
  role = aws_iam_role.snowflake_storage_integration.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SnowflakeListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.raw_bucket_arn
      },
      {
        Sid      = "SnowflakeReadRawObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.raw_bucket_arn}/*"
      },
    ]
  })
}
