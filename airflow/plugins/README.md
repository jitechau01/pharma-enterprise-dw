No custom Airflow plugins are needed for this project -- the Snowflake and
S3 providers (`apache-airflow-providers-snowflake`,
`apache-airflow-providers-amazon`, both in `../requirements.txt`) cover
every operator/sensor/hook used in `../dags/`.

This directory (and `plugins.zip`, which Terraform's `mwaa` module wires up
via `plugins_s3_path`) is kept as an empty placeholder so the project's
structure matches a real MWAA deployment 1:1 -- teams that outgrow the
provider operators typically add custom Airflow plugins here (e.g. a custom
sensor for a proprietary source system, or shared UI views).
