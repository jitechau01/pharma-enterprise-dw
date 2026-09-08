# Pharma Commercial Data Platform (Reference Implementation)

An end-to-end, enterprise-grade data platform for a pharmaceutical company's
**commercial analytics** function — sales orders, HCP (Healthcare Provider)
engagement, field-rep sample drops, inventory/batch tracking, and returns —
built on:

| Layer | Technology |
|---|---|
| Cloud infrastructure | **AWS** (S3, IAM, VPC, MWAA, Secrets Manager, KMS, CloudWatch, SNS) |
| Infrastructure as Code | **Terraform** (AWS provider + Snowflake provider) |
| Data warehouse | **Snowflake** (RAW → STAGING → CURATED → ANALYTICS databases) |
| Transformation | **dbt Core** (staging → intermediate → marts, snapshots for SCD2) |
| Orchestration | **Amazon MWAA** (managed Airflow) + local Airflow via Docker Compose for dev |
| CI/CD & source control | **GitHub** + **GitHub Actions** |
| Data quality | dbt tests + `dbt_expectations` package, custom generic tests |
| Synthetic data | Python + Faker, multi-day extracts that trigger real SCD1/SCD2 changes |

> **Scope note:** This is a *reference implementation* — a complete, realistic
> codebase you can deploy into your own AWS + Snowflake accounts. No live
> cloud resources were provisioned while building it (this session has no
> AWS/Snowflake credentials). Every module is written to `terraform apply`
> and `dbt run` cleanly once you plug in your own account details.

---

## 1. What this project demonstrates

- **Medallion architecture**: immutable raw landing zone → cleaned/typed
  staging → business-curated marts, implemented across S3 *and* Snowflake.
- **Three source systems** feeding one warehouse: a CRM (rep visits/sample
  drops), an ERP (orders, shipments, invoices), and an MDM/reference system
  (product, HCP, territory, sales-rep master data).
- **Dimensional modeling**: a star schema with **6 dimensions** (2 SCD1,
  3 SCD2, 1 role-playing date dimension) and **4 fact tables** at different
  grains (line-item, event, daily snapshot, transaction).
- **SCD1 and SCD2, done two ways**: dbt `snapshot` blocks (timestamp
  strategy) for SCD2 dimensions, and an incremental `merge` macro pattern for
  SCD1 dimensions — both are real, runnable dbt patterns, not pseudocode.
- **Pharma-specific business logic**: gross-to-net revenue (list price →
  contract discount → rebate accrual → chargeback), lot/batch expiry
  tracking with "no expired stock shipped" data-quality guardrails, HCP
  engagement scoring, and days-of-inventory-on-hand.
- **Orchestration as code**: MWAA-ready DAGs for ingestion, dbt
  transformation, and data-quality gating, plus a docker-compose stack so
  DAGs are testable locally before they ever touch AWS.
- **CI/CD**: GitHub Actions lint and build the dbt project and `terraform
  plan` every PR; `terraform apply` and dbt deploy run on merge to `main`,
  gated by GitHub Environments.

## 2. Repository layout

```
pharma-enterprise-dw/
├── data_generator/       # Synthetic multi-day source data (Faker)
├── terraform/            # AWS + Snowflake IaC (modules + dev/staging/prod envs)
├── snowflake_setup/      # Bootstrap SQL: raw schemas, stages, file formats
├── dbt/pharma_dw/        # dbt Core project (staging, snapshots, intermediate, marts)
├── airflow/              # MWAA DAGs + local Docker Compose Airflow
├── .github/workflows/    # CI/CD pipelines
├── scripts/              # Helper scripts (raw loaders, local env setup)
├── docs/                 # Architecture, data dictionary, runbook
└── Makefile
```

## 3. Data flow (raw → staging → curated)

```
Source systems (CRM / ERP / MDM)
        │  (Faker-generated CSV extracts, one batch per simulated business day)
        ▼
  S3 raw landing zone  s3://<env>-pharma-raw/<source>/<table>/dt=YYYY-MM-DD/
        │  MWAA DAG: pharma_raw_ingestion  (S3 sensor → Snowflake COPY INTO)
        ▼
  Snowflake RAW database        (schema-on-read, VARIANT/typed staging tables, load metadata columns)
        │  dbt: models/staging/*  (cast types, dedupe, standardize, 1:1 with source)
        ▼
  Snowflake STAGING database (via dbt "staging" schema)
        │  dbt snapshots (SCD2) + dbt: models/intermediate/*  (joins, business rules)
        ▼
  Snowflake CURATED database    dims (SCD1/SCD2) + facts, dbt: models/marts/*
        │  dbt tests + dbt_expectations + custom generic tests
        ▼
  Snowflake ANALYTICS database  (consumption-ready star schema for BI/reporting)
```

Full detail: see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## 4. Dimensional model

**Dimensions**

| Dimension | Type | Notes |
|---|---|---|
| `dim_product` | SCD2 | tracks price-tier, therapeutic category, formulation changes |
| `dim_hcp` | SCD2 | tracks specialty, territory, prescriber-tier changes |
| `dim_sales_rep` | SCD2 | tracks territory reassignment, manager changes |
| `dim_distributor` | SCD1 | current-state only (address, tier) |
| `dim_warehouse` | SCD1 | current-state only |
| `dim_date` | Static/generated | standard calendar dimension |

**Facts**

| Fact | Grain | Notes |
|---|---|---|
| `fact_sales_orders` | one row per order line | gross-to-net revenue waterfall |
| `fact_hcp_visits` | one row per rep↔HCP interaction | samples dropped, call duration, engagement points |
| `fact_inventory_snapshot` | one row per warehouse/product/batch/day | days-on-hand, expiry flag |
| `fact_returns` | one row per return line | reason code, recall linkage |

## 5. Getting started

```bash
# 1. Generate synthetic multi-day source data
make generate-data

# 2. Stand up local Airflow (Docker) to inspect/run DAGs
make airflow-up

# 3. Provision AWS + Snowflake infra (dev environment) — requires your own
#    AWS credentials and a Snowflake account/user with ACCOUNTADMIN or a
#    delegated role; copy terraform.tfvars.example -> terraform.tfvars first
make tf-plan ENV=dev
make tf-apply ENV=dev

# 4. Bootstrap raw Snowflake objects (schemas, stages, file formats)
#    snowflake_setup/*.sql — run via SnowSQL or the Snowflake Terraform provider

# 5. Run the dbt project
make dbt-build
```

See [`docs/runbook.md`](docs/runbook.md) for full operational steps,
including how MWAA picks this up end-to-end in AWS.

## 6. CI/CD

| Workflow | Trigger | What it does |
|---|---|---|
| `dbt_ci.yml` | PR touching `dbt/**` | `sqlfluff lint`, `dbt deps`, `dbt parse`, `dbt build --target ci` (slim/state-aware) |
| `terraform_plan.yml` | PR touching `terraform/**` | `terraform fmt -check`, `validate`, `plan` per environment, posts plan as PR comment |
| `terraform_apply.yml` | push to `main` touching `terraform/**` | `terraform apply` gated by a GitHub Environment approval |
| `python_ci.yml` | PR touching `data_generator/**` or `scripts/**` or `airflow/**` | `ruff`/`flake8` lint, `pytest`, DAG-import smoke test |

## 7. Supporting tools used in this project

- **dbt packages**: `dbt_utils` (surrogate keys, date spine), `dbt_expectations`
  (statistical/data-quality tests), `codegen` (source/model scaffolding).
- **sqlfluff** — SQL linting/formatting for dbt models (dialect: snowflake, templater: dbt).
- **pre-commit** — runs `terraform fmt`, `sqlfluff`, `black`/`ruff`, and
  `end-of-file-fixer` before every commit.
- **Faker** — realistic synthetic pharma data (HCP names/NPIs, drug names,
  NDC-style product codes, addresses).
- **Great Expectations-style checks** implemented via `dbt_expectations` to
  keep the data-quality tooling inside the dbt/SQL stack rather than adding
  a second DQ framework — noted as a swappable choice in `docs/ARCHITECTURE.md`.
- **AWS Secrets Manager** — Snowflake credentials and Airflow connections,
  referenced (not hardcoded) from Terraform and Airflow.
- **CloudWatch + SNS** — MWAA task failure alarms and DAG-failure notifications.
- **Docker Compose** — local Airflow parity environment for DAG development
  without needing live AWS/MWAA.

## 8. What you'd still need to do to go live

1. Create/point to a real AWS account + Snowflake account.
2. Fill in `terraform/environments/<env>/terraform.tfvars` (account IDs, CIDR
   ranges, Snowflake account locator, admin role, etc.).
3. Wire GitHub Actions secrets (`AWS_ROLE_ARN` for OIDC, `SNOWFLAKE_*`).
4. Run `make tf-apply ENV=dev`, bootstrap Snowflake via `snowflake_setup/`,
   upload `dbt/` and `airflow/dags/` to the MWAA S3 bucket (Terraform-managed),
   and trigger the `pharma_raw_ingestion` DAG.

