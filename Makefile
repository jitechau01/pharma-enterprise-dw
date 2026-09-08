.PHONY: help generate-data sync-raw airflow-up airflow-down tf-init tf-plan tf-apply dbt-deps dbt-build dbt-docs lint clean

ENV ?= dev

help:
	@echo "Targets:"
	@echo "  generate-data   Generate synthetic multi-day source data (data_generator/)"
	@echo "  sync-raw        Sync local raw/ landing zone to S3 (requires AWS creds + ENV=<env>)"
	@echo "  airflow-up      Start local Airflow (docker compose) for DAG dev/testing"
	@echo "  airflow-down    Stop local Airflow"
	@echo "  tf-plan ENV=dev Terraform plan for the given environment"
	@echo "  tf-apply ENV=dev Terraform apply for the given environment"
	@echo "  dbt-deps        Install dbt packages"
	@echo "  dbt-build       dbt seed + snapshot + run + test (target=dev)"
	@echo "  dbt-docs        Generate and serve dbt docs"
	@echo "  lint            Run sqlfluff (dbt) + ruff (python) + terraform fmt -check"
	@echo "  clean           Remove generated raw/ data and dbt/terraform artifacts"

generate-data:
	cd data_generator && pip install -r requirements.txt --break-system-packages -q && python3 generate_synthetic_data.py

sync-raw:
	aws s3 sync raw/ s3://$(ENV)-pharma-raw-landing-<suffix>/ --exclude ".gitkeep"
	@echo "NOTE: replace <suffix> with your actual bucket name (see terraform output raw_bucket_id)"

airflow-up:
	cd airflow && docker compose up airflow-init && docker compose up

airflow-down:
	cd airflow && docker compose down

tf-init:
	cd terraform/environments/$(ENV) && terraform init

tf-plan: tf-init
	cd terraform/environments/$(ENV) && terraform plan

tf-apply: tf-init
	cd terraform/environments/$(ENV) && terraform apply

dbt-deps:
	cd dbt/pharma_dw && dbt deps

dbt-build: dbt-deps
	cd dbt/pharma_dw && dbt seed --target dev && dbt snapshot --target dev && dbt run --target dev && dbt test --target dev

dbt-docs:
	cd dbt/pharma_dw && dbt docs generate --target dev && dbt docs serve

lint:
	cd dbt/pharma_dw && sqlfluff lint models --dialect snowflake
	ruff check data_generator scripts airflow/dags
	terraform fmt -check -recursive terraform/

clean:
	rm -rf raw/
	rm -rf dbt/pharma_dw/target dbt/pharma_dw/dbt_packages dbt/pharma_dw/logs dbt/pharma_dw/package-lock.yml
	find terraform -name ".terraform" -type d -prune -exec rm -rf {} +
