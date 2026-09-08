Reserved for ad hoc SQL used directly by Airflow tasks that isn't part of
the dbt project (e.g. one-off backfill scripts, the raw-table bootstrap DDL
mirrored from `../../snowflake_setup/`). Currently empty in this reference
project -- `snowflake_setup/*.sql` is referenced in place via the mounted
volume (see `../docker-compose.yaml`) rather than duplicated here.
