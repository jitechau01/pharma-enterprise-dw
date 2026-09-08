"""
pharma_data_quality
=====================
Runs `dbt test` against the freshly-built marts (including the custom
`no_expired_batch_shipped` regulatory guardrail), then a supplementary
business-logic check that isn't well-expressed as a dbt test: how much
at-risk inventory (near-expiry AND slow-moving) currently exists. That
number is logged and, above a configurable threshold, raises so the SNS
failure alert fires -- this is meant to model "a DQ DAG can carry checks
beyond dbt's own test framework," not to duplicate dbt's job.

Upstream: scheduled against Dataset(MARTS_BUILT_DATASET_URI) from
pharma_dbt_transform.py.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.datasets import Dataset
from airflow.exceptions import AirflowException
from airflow.models import Variable
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

from common.alerting import notify_failure

ENV = Variable.get("PHARMA_DW_ENV", default_var="dev")
DBT_PROJECT_DIR = Variable.get(
    "PHARMA_DW_DBT_PROJECT_DIR",
    default_var=os.path.join(os.environ.get("AIRFLOW_HOME", "/usr/local/airflow"), "dags", "dbt", "pharma_dw"),
)
DBT_TARGET = Variable.get("PHARMA_DW_DBT_TARGET", default_var=ENV)
SNOWFLAKE_CONN_ID = Variable.get("PHARMA_DW_SNOWFLAKE_CONN_ID", default_var="snowflake_default")
AT_RISK_INVENTORY_ALERT_THRESHOLD = int(Variable.get("PHARMA_DW_AT_RISK_INVENTORY_THRESHOLD", default_var="25"))

MARTS_BUILT_DATASET = Dataset(f"snowflake://pharma_dbt_{ENV}/marts_built")

default_args = {
    "owner": "data-platform",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": notify_failure,
}


def check_at_risk_inventory(**context):
    """Counts near-expiry batches with >60 days of stock on hand (same
    definition as dbt/pharma_dw/analyses/example_at_risk_inventory.sql) and
    fails the task -- triggering the SNS alert -- if it exceeds threshold."""
    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    hook = SnowflakeHook(snowflake_conn_id=SNOWFLAKE_CONN_ID)
    query = f"""
        select count(*) as at_risk_batches
        from PHARMA_DBT_{ENV.upper()}.MARTS.FACT_INVENTORY_SNAPSHOT f
        where f.is_near_expiry
          and f.days_on_hand > 60
          and f.snapshot_date = (
              select max(snapshot_date) from PHARMA_DBT_{ENV.upper()}.MARTS.FACT_INVENTORY_SNAPSHOT
          )
    """
    records = hook.get_first(query)
    at_risk_count = records[0] if records else 0
    context["ti"].xcom_push(key="at_risk_inventory_batches", value=at_risk_count)
    print(f"[pharma_data_quality] at-risk inventory batches: {at_risk_count}")

    if at_risk_count > AT_RISK_INVENTORY_ALERT_THRESHOLD:
        raise AirflowException(
            f"At-risk inventory ({at_risk_count} batches) exceeds threshold "
            f"({AT_RISK_INVENTORY_ALERT_THRESHOLD}). Notify commercial ops / supply chain."
        )


with DAG(
    dag_id="pharma_data_quality",
    description="dbt test + supplementary at-risk-inventory business check on the freshly built marts.",
    default_args=default_args,
    schedule=[MARTS_BUILT_DATASET],
    start_date=datetime(2026, 6, 1),
    catchup=False,
    max_active_runs=1,
    tags=["pharma-dw", "data-quality"],
) as dag:

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt test --target {DBT_TARGET}",
    )

    at_risk_inventory_check = PythonOperator(
        task_id="check_at_risk_inventory",
        python_callable=check_at_risk_inventory,
    )

    dbt_test >> at_risk_inventory_check
