#!/usr/bin/env bash
# Sync the local synthetic raw/ landing zone (from data_generator/) up to the
# real S3 raw bucket Terraform provisioned -- a stand-in for "how the real
# CRM/ERP/MDM export jobs would land files in S3" so the ingestion DAG has
# something to actually pick up in a live AWS account.
#
# Usage: ./scripts/sync_raw_to_s3.sh <bucket-name> [--delete]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUCKET="${1:?Usage: sync_raw_to_s3.sh <bucket-name> [--delete]}"
EXTRA_ARGS="${2:-}"

if [ ! -d "$ROOT_DIR/raw" ]; then
    echo "No raw/ directory found -- run 'make generate-data' first." >&2
    exit 1
fi

echo "Syncing $ROOT_DIR/raw -> s3://$BUCKET/"
aws s3 sync "$ROOT_DIR/raw/" "s3://$BUCKET/" $EXTRA_ARGS

echo "Done. Trigger pharma_raw_ingestion in Airflow/MWAA for the relevant dt=YYYY-MM-DD partitions."
