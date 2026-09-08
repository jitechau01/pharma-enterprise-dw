#!/usr/bin/env bash
# One-time local dev bootstrap: checks for required tools, installs Python
# deps for the data generator, and copies .env/.tfvars examples so you have
# something to edit instead of hunting for the right filenames.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Checking required tools =="
for tool in python3 pip3 docker git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "MISSING: $tool -- install it before continuing." >&2
        exit 1
    fi
    echo "  OK: $tool"
done

if ! command -v terraform >/dev/null 2>&1; then
    echo "  NOTE: terraform not found on PATH -- install >=1.7.0 before running 'make tf-plan'."
fi
if ! command -v dbt >/dev/null 2>&1; then
    echo "  NOTE: dbt not found on PATH -- 'pip install dbt-core dbt-snowflake' before running 'make dbt-build'."
fi

echo "== Installing data_generator dependencies =="
pip3 install -r data_generator/requirements.txt --break-system-packages -q || pip3 install -r data_generator/requirements.txt -q

echo "== Seeding local config files from examples (only if missing) =="
[ -f airflow/.env ] || { cp airflow/.env.example airflow/.env; echo "  created airflow/.env -- fill in Snowflake/AWS values"; }
[ -f terraform/environments/dev/terraform.tfvars ] || { cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars; echo "  created terraform/environments/dev/terraform.tfvars -- fill in values"; }
[ -f dbt/pharma_dw/profiles.yml ] || echo "  NOTE: copy dbt/pharma_dw/profiles.yml.example to ~/.dbt/profiles.yml and fill in values"

echo "== Done. Next steps =="
echo "  1. make generate-data     # synthetic source data -> raw/"
echo "  2. make airflow-up         # local Airflow at http://localhost:8080"
echo "  3. make tf-plan ENV=dev     # after filling in terraform.tfvars"
