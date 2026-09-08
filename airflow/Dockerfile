# Local dev parity image -- mirrors the MWAA airflow_version (2.9.2) and
# installs the same requirements.txt MWAA would install, so DAGs behave
# the same locally as in AWS. Not used for the real MWAA deploy (MWAA
# manages its own image); this is purely for `docker compose up` dev/test.
FROM apache/airflow:2.9.2-python3.11

USER airflow
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# dbt project + snowflake_setup are mounted read-only at runtime via
# docker-compose.yaml volumes (see PHARMA_DW_DBT_PROJECT_DIR env var), not
# baked into the image, so local dbt model edits don't require a rebuild.
