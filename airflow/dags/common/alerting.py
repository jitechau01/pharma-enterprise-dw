"""
Shared failure callback: publishes a concise message to the SNS topic
Terraform provisions in modules/mwaa (dag_failure_sns_topic_arn), which fans
out to email (and, if you subscribe it, a Slack-forwarding Lambda/webhook).

Falls back to a plain Airflow log line when SNS_TOPIC_ARN isn't set, which
is the case in local Docker Compose dev -- no AWS credentials assumed there.
"""
from __future__ import annotations

import logging
import os

logger = logging.getLogger(__name__)

SNS_TOPIC_ARN = os.environ.get("PHARMA_DW_DAG_FAILURE_SNS_TOPIC_ARN", "")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")


def notify_failure(context) -> None:
    task_instance = context["task_instance"]
    dag_id = task_instance.dag_id
    task_id = task_instance.task_id
    execution_date = context.get("ds", "unknown-date")
    log_url = task_instance.log_url
    exception = context.get("exception")

    message = (
        f"[pharma-enterprise-dw] Task FAILED\n"
        f"DAG: {dag_id}\n"
        f"Task: {task_id}\n"
        f"Execution date: {execution_date}\n"
        f"Exception: {exception}\n"
        f"Logs: {log_url}\n"
    )

    if not SNS_TOPIC_ARN:
        logger.warning("SNS_TOPIC_ARN not configured; logging failure instead of alerting.\n%s", message)
        return

    try:
        import boto3

        client = boto3.client("sns", region_name=AWS_REGION)
        client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[pharma-enterprise-dw] {dag_id}.{task_id} failed",
            Message=message,
        )
        logger.info("Published failure notification to SNS topic %s", SNS_TOPIC_ARN)
    except Exception:  # noqa: BLE001 -- never let alerting itself break the DAG run
        logger.exception("Failed to publish SNS failure notification")
