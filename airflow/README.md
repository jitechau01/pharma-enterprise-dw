# Airflow / MWAA

```
airflow/
├── dags/
│   ├── pharma_raw_ingestion.py      S3 -> Snowflake RAW (9 tables, sensor + COPY INTO each)
│   ├── pharma_dbt_transform.py       dbt seed/snapshot/run (staging/intermediate/marts) + publish analytics views
│   ├── pharma_data_quality.py         dbt test + custom at-risk-inventory business check
│   └── common/                          shared table config, COPY INTO SQL builder, SNS alerting
├── plugins/                              empty placeholder (no custom plugins needed -- see plugins/README.md)
├── include/sql/                           reserved for ad hoc SQL (see include/sql/README.md)
├── requirements.txt                        MWAA-installed Python deps (dbt-core, dbt-snowflake, providers)
├── Dockerfile + docker-compose.yaml         local dev parity environment
└── .env.example                             local connection/variable config template
```

## DAG dependency chain

```
pharma_raw_ingestion  --[Dataset: snowflake://pharma_raw_<env>/loaded]-->
pharma_dbt_transform  --[Dataset: snowflake://pharma_dbt_<env>/marts_built]-->
pharma_data_quality
```

Airflow **Datasets** (not `TriggerDagRunOperator` or `ExternalTaskSensor`)
chain these three DAGs. This was a deliberate choice: Dataset scheduling
means each DAG's retry/backfill behavior is independent (a flaky Snowflake
connection during `dbt test` doesn't block tomorrow's ingestion), while
still guaranteeing `pharma_dbt_transform` never starts against a partially
loaded raw day (every one of the 9 `copy_*_to_raw` tasks must succeed and
declare the outlet before the dataset is considered updated), and
`pharma_data_quality` never runs against marts that failed to build.

## Running locally

```bash
cd airflow
cp .env.example .env        # fill in Snowflake/AWS connection strings
docker compose up airflow-init
docker compose up
# http://localhost:8080  (airflow / airflow)
```

The dbt project (`../dbt/pharma_dw`) and `../snowflake_setup` are mounted
directly into the containers (see `docker-compose.yaml` volumes), so DAG and
dbt model edits are picked up without rebuilding the image.

## Validated without live AWS/Snowflake

Every DAG in this project was parsed with `apache-airflow==2.9.2` +
`apache-airflow-providers-amazon` + `apache-airflow-providers-snowflake`
installed in this build environment (`airflow dags list-import-errors`
reported zero errors, and `airflow tasks list` was used to confirm all 18
ingestion tasks and both downstream DAGs' task graphs are exactly as
described above). What was **not** validated here: actually connecting to
S3/Snowflake (no credentials in this sandbox) and the MWAA-specific
deployment path (requirements.txt install, execution role, VPC networking)
-- exercise those against your own AWS account per `terraform/README.md`.

## Deploying to MWAA

CI/CD (`.github/workflows/terraform_apply.yml` and a dedicated deploy step,
see `.github/workflows/dbt_ci.yml`'s deploy job) syncs three things to the
MWAA S3 bucket Terraform provisions:

```bash
aws s3 sync airflow/dags/        s3://<mwaa-bucket>/dags/
aws s3 sync dbt/pharma_dw/        s3://<mwaa-bucket>/dags/dbt/pharma_dw/
aws s3 cp    airflow/requirements.txt s3://<mwaa-bucket>/requirements.txt
```

DAGs reference the dbt project at `dags/dbt/pharma_dw` (relative to the
MWAA-synced `dags/` prefix) via the `PHARMA_DW_DBT_PROJECT_DIR` Airflow
Variable -- set it to
`{{ '/usr/local/airflow/dags/dbt/pharma_dw' }}` in the MWAA UI (Admin ->
Variables) or seed it via `airflow variables import` as part of the deploy
job.
