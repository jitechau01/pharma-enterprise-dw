# MWAA execution role: what the Airflow environment itself assumes to read
# DAGs/requirements from S3, write logs to CloudWatch, publish metrics, and
# (via task-level code) reach the raw S3 bucket and Secrets Manager.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "mwaa_execution" {
  name = "${var.name_prefix}-mwaa-execution-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "airflow.amazonaws.com",
          "airflow-env.amazonaws.com",
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "mwaa_execution" {
  name = "${var.name_prefix}-mwaa-execution-policy"
  role = aws_iam_role.mwaa_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AirflowPublishMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        Sid    = "AirflowS3DagsAndData"
        Effect = "Allow"
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*",
        ]
        Resource = [
          var.mwaa_bucket_arn,
          "${var.mwaa_bucket_arn}/*",
          var.raw_bucket_arn,
          "${var.raw_bucket_arn}/*",
        ]
      },
      {
        Sid      = "AirflowCloudWatchLogs"
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups",
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:airflow-${var.name_prefix}-*"
      },
      {
        Sid      = "AirflowSQS"
        Effect   = "Allow"
        Action   = ["sqs:ChangeMessageVisibility", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage", "sqs:SendMessage"]
        Resource = "arn:aws:sqs:${data.aws_region.current.name}:*:airflow-celery-*"
      },
      {
        Sid    = "AirflowKMS"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey*", "kms:Encrypt"]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "AirflowSecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:airflow/*"
      },
      {
        Sid      = "AirflowSNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.name_prefix}-*"
      },
    ]
  })
}
