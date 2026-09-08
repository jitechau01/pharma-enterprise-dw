"""
pharma_dbt_transform
======================
Runs the dbt project: seed -> snapshot (SCD2) -> staging -> intermediate ->
marts, then publishes the ANALYTICS secure views. Each layer is its own
task (rather than one `dbt build` task) so a failure is immediately visible
by layer in the Airflow UI/logs, and so a staging-only rerun doesn't need to
touch marts.

Upstream: scheduled against the RAW_LOADED_DATASET produced by
pharma_raw_ingestion.py. Dataset scheduling (vs. TriggerDagRunOperator or
ExternalTaskSensor) is used deliberately: it decouples the two DAGs' retry
behavior (a transient dbt failure doesn't block tomorrow's ingestion from
starting) while still guaranteeing transform never runs against a raw load
that didn't fully succeed.

Downstream: emits Dataset(MARTS_BUILT_DATASET_URI), which
pharma_data_quality.py is scheduled against.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.datasets import Dataset
from airflow.models import Variable
from airflow.operators.bash import BashOperator

from common.alerting import notify_failure

ENV = Variable.get("PHARMA_DW_ENV", default_var="dev")
DBT_PROJECT_DIR = Variable.get(
    "PHARMA_DW_DBT_PROJECT_DIR",
    default_var=os.path.join(os.environ.get("AIRFLOW_HOME", "/usr/local/airflow"), "dags", "dbt", "pharma_dw"),
)
DBT_TARGET = Variable.get("PHARMA_DW_DBT_TARGET", default_var=ENV)

RAW_LOADED_DATASET = Dataset(f"snowflake://pharma_raw_{ENV}/loaded")
MARTS_BUILT_DATASET = Dataset(f"snowflake://pharma_dbt_{ENV}/marts_built")

default_args = {
    "owner": "data-platform",
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
    "on_failure_callback": notify_failure,
}

DBT_BASE_CMD = f"cd {DBT_PROJECT_DIR} && dbt"

with DAG(
    dag_id="pharma_dbt_transform",
    description="dbt seed -> snapshot -> staging -> intermediate -> marts -> analytics views.",
    default_args=default_args,
    schedule=[RAW_LOADED_DATASET],
    start_date=datetime(2026, 6, 1),
    catchup=False,
    max_active_runs=1,
    tags=["pharma-dw", "transform", "dbt"],
) as dag:

    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"{DBT_BASE_CMD} deps --target {DBT_TARGET}",
    )

    dbt_seed = BashOperator(
        task_id="dbt_seed",
        bash_command=f"{DBT_BASE_CMD} seed --target {DBT_TARGET}",
    )

    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command=f"{DBT_BASE_CMD} snapshot --target {DBT_TARGET}",
    )

    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"{DBT_BASE_CMD} run --target {DBT_TARGET} --select staging.*",
    )

    dbt_run_intermediate = BashOperator(
        task_id="dbt_run_intermediate",
        bash_command=f"{DBT_BASE_CMD} run --target {DBT_TARGET} --select intermediate.*",
    )

    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"{DBT_BASE_CMD} run --target {DBT_TARGET} --select marts.*",
        outlets=[MARTS_BUILT_DATASET],
    )

    publish_analytics_views = BashOperator(
        task_id="publish_analytics_views",
        bash_command=(
            f"snowsql -c pharma_dw_{DBT_TARGET} "
            f"-f {DBT_PROJECT_DIR}/../../snowflake_setup/05_analytics_views.sql "
            f"-D env={ENV.upper()}"
        ),
    )

    dbt_deps >> dbt_seed >> dbt_snapshot >> dbt_run_staging >> dbt_run_intermediate >> dbt_run_marts >> publish_analytics_views
