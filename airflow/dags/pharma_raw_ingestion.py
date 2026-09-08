"""
pharma_raw_ingestion
=====================
Waits for the day's source extracts to land in the S3 raw bucket, then loads
each of the 9 raw tables into Snowflake via COPY INTO.

Upstream: none (this is the entry point -- triggered by schedule, or by
whatever process lands files in S3, e.g. an SFTP-to-S3 sync from the real
CRM/ERP/MDM systems; in this reference project that's
`data_generator/generate_synthetic_data.py` run ahead of time / on a cron).

Downstream: emits Dataset(RAW_LOADED_DATASET_URI) on success, which
pharma_dbt_transform.py is scheduled against -- see that DAG for why
Datasets (not TriggerDagRunOperator/ExternalTaskSensor) were chosen.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.datasets import Dataset
from airflow.models import Variable
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
from airflow.providers.snowflake.operators.snowflake import SQLExecuteQueryOperator

from common.alerting import notify_failure
from common.snowflake_copy import build_copy_into_sql, build_use_statements
from common.table_config import RAW_TABLES

ENV = Variable.get("PHARMA_DW_ENV", default_var="dev")
RAW_BUCKET = Variable.get("PHARMA_DW_RAW_BUCKET", default_var=f"{ENV}-pharma-raw-landing")
SNOWFLAKE_CONN_ID = Variable.get("PHARMA_DW_SNOWFLAKE_CONN_ID", default_var="snowflake_default")

RAW_LOADED_DATASET = Dataset(f"snowflake://pharma_raw_{ENV}/loaded")

default_args = {
    "owner": "data-platform",
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": notify_failure,
}

with DAG(
    dag_id="pharma_raw_ingestion",
    description="Land daily CRM/ERP/MDM extracts from S3 into Snowflake RAW.",
    default_args=default_args,
    schedule="0 6 * * *",  # 06:00 UTC daily -- after overnight source exports land
    start_date=datetime(2026, 6, 1),
    catchup=False,
    max_active_runs=1,
    tags=["pharma-dw", "ingestion"],
) as dag:

    use_statements = build_use_statements(ENV)

    wait_tasks = []
    copy_tasks = []

    for table in RAW_TABLES:
        s3_prefix = f"{table.source_system}/{table.table_name.lower()}/dt={{{{ ds }}}}/"

        wait_for_file = S3KeySensor(
            task_id=f"wait_for_{table.source_system}_{table.table_name.lower()}",
            bucket_name=RAW_BUCKET,
            bucket_key=f"{s3_prefix}*.csv",
            wildcard_match=True,
            aws_conn_id="aws_default",
            timeout=60 * 60 * 2,       # 2 hours
            poke_interval=60 * 5,       # check every 5 minutes
            mode="reschedule",           # free up a worker slot between pokes
        )

        copy_into = SQLExecuteQueryOperator(
            task_id=f"copy_{table.source_system}_{table.table_name.lower()}_to_raw",
            conn_id=SNOWFLAKE_CONN_ID,
            sql=use_statements + [build_copy_into_sql(table, ENV, "{{ ds }}")],
            # Every copy task declares the same dataset outlet: the dataset
            # only fires "updated" (and pharma_dbt_transform only triggers)
            # once ALL 9 tasks have completed, since Airflow's dataset
            # scheduler requires every producing task in the DAG run to
            # succeed before consumers see the update.
            outlets=[RAW_LOADED_DATASET],
        )

        wait_for_file >> copy_into
        wait_tasks.append(wait_for_file)
        copy_tasks.append(copy_into)
