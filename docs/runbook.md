# Operational runbook

## First-time setup (new AWS + Snowflake accounts)

1. **Bootstrap Terraform remote state** (once per environment) --
   see `terraform/README.md` "Remote state bootstrap."
2. **Terraform apply, pass 1**:
   ```bash
   cd terraform/environments/dev
   cp terraform.tfvars.example terraform.tfvars   # fill in values
   export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PRIVATE_KEY_PATH=...
   terraform init && terraform apply
   ```
3. **Two-step Snowflake <-> S3 trust**: read the two outputs and put them
   into `terraform.tfvars`, then `terraform apply` again --
   see `terraform/README.md` for why this is two passes.
4. **Bootstrap raw table DDL**: run `snowflake_setup/01_raw_tables_mdm.sql`
   through `03_raw_tables_erp.sql` as `PHARMA_TRANSFORMER_DEV` (see
   `snowflake_setup/README.md`).
5. **Generate + land synthetic data** (or point real source-system exports
   at the raw bucket instead):
   ```bash
   make generate-data
   ./scripts/sync_raw_to_s3.sh <raw-bucket-name>
   ```
6. **Deploy DAGs + dbt project to MWAA**:
   ```bash
   aws s3 sync airflow/dags/ s3://<mwaa-bucket>/dags/
   aws s3 sync dbt/pharma_dw/ s3://<mwaa-bucket>/dags/dbt/pharma_dw/
   aws s3 cp airflow/requirements.txt s3://<mwaa-bucket>/requirements.txt
   ```
   (this is what `.github/workflows/dbt_ci.yml`'s `deploy_to_mwaa` job
   automates on merge to `main`).
7. **Set MWAA Airflow Variables** (Admin -> Variables in the MWAA UI, or
   `airflow variables import`): `PHARMA_DW_ENV`, `PHARMA_DW_RAW_BUCKET`,
   `PHARMA_DW_DBT_PROJECT_DIR=/usr/local/airflow/dags/dbt/pharma_dw`,
   `PHARMA_DW_DBT_TARGET`, `PHARMA_DW_AT_RISK_INVENTORY_THRESHOLD`.
8. **Set the MWAA Snowflake connection** (Admin -> Connections):
   `snowflake_default`, using the `PHARMA_TRANSFORMER_<env>` service account
   (key-pair auth recommended -- store the private key in Secrets Manager
   and reference it via MWAA's `secrets_backend` configuration rather than
   pasting it into the connection form).
9. **Unpause and trigger** `pharma_raw_ingestion` for the date(s) you landed
   data for. `pharma_dbt_transform` and `pharma_data_quality` fire
   automatically via Dataset scheduling once ingestion succeeds.

## Day-to-day operation

- **Adding a new source column**: update
  `data_generator/generate_synthetic_data.py` (if simulating), the relevant
  `snowflake_setup/0X_raw_tables_*.sql` (add the column,
  `CREATE TABLE IF NOT EXISTS` won't alter an existing table -- use
  `ALTER TABLE ... ADD COLUMN` for a live table), `airflow/dags/common/table_config.py`
  (column order), and the corresponding `stg_*` model + its `_*.yml` tests.
- **Backfilling a historical date range**: `airflow dags backfill
  pharma_raw_ingestion -s 2026-05-01 -e 2026-05-31` (raw ingestion only --
  the downstream DAGs pick it up automatically via Dataset scheduling once
  each day's ingestion run completes; note dbt's incremental facts only
  reprocess a short trailing window by default, so a large backfill may need
  `dbt run --full-refresh` afterward).
- **A dbt snapshot "misses" a change**: the timestamp strategy only detects
  a change if `source_updated_at` actually changed on that row in that
  day's MDM extract. If a real source system doesn't reliably bump its
  updated-at column on every change, switch that snapshot to
  `strategy='check'` with an explicit `check_cols` list instead --
  slower, but detects changes regardless of source timestamp hygiene.
- **Rotating the dbt/CI Snowflake service account key**: update the
  `SNOWFLAKE_CI_PRIVATE_KEY` GitHub secret and the MWAA Secrets Manager
  entry in the same change; both `dbt_ci.yml` and the MWAA connection read
  from these two independently.

## Incident response

- **`pharma_raw_ingestion` stuck on a `wait_for_*` sensor**: the source
  export for that table didn't land in S3 within the 2-hour timeout. Check
  the upstream export job; once the file lands, the sensor (mode=
  `reschedule`) picks it up on its next poke without manual intervention.
- **`no_expired_batch_shipped` test fails**: an order shipped a batch after
  its `lot_expiry_date`. This should be treated as a P1 in a real
  pharma environment (regulatory exposure) -- the failing rows are visible
  in `dbt_test_failures` schema (via `store_failures: true`, see
  `dbt_project.yml`) for immediate triage, independent of re-running dbt.
- **`pharma_data_quality`'s at-risk-inventory check fires**: informational
  by design (see `pharma_data_quality.py` docstring) -- review
  `dbt/pharma_dw/analyses/example_at_risk_inventory.sql`'s output and loop
  in supply chain / commercial ops; it is not itself a data-integrity bug.
- **MWAA scheduler CloudWatch alarm fires** (`scheduler_errors`, from
  `terraform/modules/mwaa`): check the `airflow-<env>-pharma-mwaa-Scheduler`
  CloudWatch log group directly; this alarm means the environment itself is
  unhealthy, not a specific DAG failure.

## Common commands reference

| Task | Command |
|---|---|
| Regenerate synthetic data | `make generate-data` |
| Run dbt end-to-end locally | `make dbt-build` |
| Browse dbt lineage/docs | `make dbt-docs` |
| Start local Airflow | `make airflow-up` |
| Plan/apply infra | `make tf-plan ENV=dev` / `make tf-apply ENV=dev` |
| Lint everything | `make lint` |
| Full local reset | `make clean` |
