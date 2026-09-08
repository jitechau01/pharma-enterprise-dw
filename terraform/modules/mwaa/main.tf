resource "aws_mwaa_environment" "this" {
  name              = "${var.name_prefix}-mwaa"
  airflow_version   = var.airflow_version
  environment_class = var.environment_class
  source_bucket_arn = var.dags_s3_bucket_arn
  dag_s3_path       = var.dag_s3_path
  execution_role_arn = var.execution_role_arn

  requirements_s3_path = var.requirements_s3_path
  plugins_s3_path       = var.plugins_s3_path

  max_workers = var.max_workers
  min_workers = var.min_workers

  webserver_access_mode = var.webserver_access_mode

  network_configuration {
    security_group_ids = var.security_group_ids
    subnet_ids          = var.private_subnet_ids
  }

  kms_key = var.kms_key_arn

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  airflow_configuration_options = {
    "core.default_task_retries"        = 2
    "core.dag_file_processor_timeout"  = 120
    "email.email_backend"              = "airflow.utils.email.send_email_smtp"
  }

  tags = var.tags
}

# --- Failure alerting -------------------------------------------------
# DAGs publish to this topic on task/DAG failure (see
# airflow/dags/common/alerting.py); also alarmed on scheduler health via
# CloudWatch so a stuck/broken MWAA environment itself pages someone.

resource "aws_sns_topic" "dag_failures" {
  name              = "${var.name_prefix}-dag-failures"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email_endpoint != "" ? 1 : 0
  topic_arn = aws_sns_topic.dag_failures.arn
  protocol  = "email"
  endpoint  = var.alert_email_endpoint
}

resource "aws_cloudwatch_log_metric_filter" "scheduler_heartbeat_errors" {
  name           = "${var.name_prefix}-scheduler-errors"
  log_group_name = "airflow-${var.name_prefix}-mwaa-Scheduler"
  pattern        = "ERROR"

  metric_transformation {
    name      = "${var.name_prefix}SchedulerErrors"
    namespace = "PharmaDW/MWAA"
    value     = "1"
  }

  depends_on = [aws_mwaa_environment.this]
}

resource "aws_cloudwatch_metric_alarm" "scheduler_errors" {
  alarm_name          = "${var.name_prefix}-mwaa-scheduler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "${var.name_prefix}SchedulerErrors"
  namespace            = "PharmaDW/MWAA"
  period               = 300
  statistic            = "Sum"
  threshold            = 5
  alarm_description    = "MWAA scheduler logged >5 ERROR lines in 5 minutes"
  alarm_actions        = [aws_sns_topic.dag_failures.arn]
  treat_missing_data    = "notBreaching"
}
