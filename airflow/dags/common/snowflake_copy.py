"""
Builds the COPY INTO statement for a given RawTable + business date. Mirrors
snowflake_setup/04_copy_into_templates.sql exactly, but generated from
table_config.py so there's one definition of "column order per table," not
nine hand-written SQL blocks to keep in sync.
"""
from __future__ import annotations

from common.table_config import RawTable


def build_copy_into_sql(table: RawTable, env: str, ds: str) -> str:
    """
    Args:
        table: the RawTable definition (see table_config.py)
        env: DEV | STAGING | PROD (matches Terraform-provisioned database naming)
        ds:  Airflow execution date string, YYYY-MM-DD (matches the S3
             dt=YYYY-MM-DD partition the synthetic generator / real source
             extracts write to)
    """
    schema = table.source_system.upper()
    positional_cols = ", ".join(f"${i+1}" for i in range(len(table.columns)))
    target_cols = ", ".join(table.columns)

    return f"""
COPY INTO {schema}.{table.table_name} (
    {target_cols}, _source_file, _source_file_row_number
)
FROM (
    SELECT
        {positional_cols},
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @{schema}.{schema}_RAW_STAGE/{table.table_name.lower()}/dt={ds}/
)
FILE_FORMAT = (FORMAT_NAME = '{schema}.CSV_STANDARD')
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;
""".strip()


def build_use_statements(env: str) -> list[str]:
    return [
        f"USE DATABASE PHARMA_RAW_{env.upper()};",
        f"USE WAREHOUSE PHARMA_LOADING_WH_{env.upper()};",
    ]
