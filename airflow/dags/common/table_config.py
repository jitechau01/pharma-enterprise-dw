"""
Single source of truth for the 9 raw source tables: which schema/stage they
land under, their column order (must match the CSVs the synthetic generator
/ real source extracts produce and the snowflake_setup/*.sql DDL), and their
natural key (used for logging / future dedupe tooling).

Both pharma_raw_ingestion.py (COPY INTO generation) and
snowflake_setup/04_copy_into_templates.sql are derived from this same
table shape -- if a source adds/removes a column, update it here first.
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RawTable:
    source_system: str      # mdm | crm | erp -- also the Snowflake schema name (upper-cased)
    table_name: str         # snowflake table name (upper-cased)
    columns: tuple[str, ...]  # raw file column order
    natural_key: tuple[str, ...]


RAW_TABLES: list[RawTable] = [
    RawTable(
        source_system="mdm",
        table_name="PRODUCT",
        columns=(
            "product_id", "ndc_code", "product_name", "therapeutic_category",
            "formulation", "list_price", "price_tier", "is_active", "source_updated_at",
        ),
        natural_key=("product_id",),
    ),
    RawTable(
        source_system="mdm",
        table_name="HCP",
        columns=(
            "hcp_id", "npi_number", "first_name", "last_name", "specialty",
            "hcp_tier", "territory_id", "city", "state", "zip_code", "source_updated_at",
        ),
        natural_key=("hcp_id",),
    ),
    RawTable(
        source_system="mdm",
        table_name="SALES_REP",
        columns=(
            "rep_id", "first_name", "last_name", "hire_date", "territory_id",
            "manager_rep_id", "region", "source_updated_at",
        ),
        natural_key=("rep_id",),
    ),
    RawTable(
        source_system="crm",
        table_name="HCP_VISIT",
        columns=(
            "visit_id", "rep_id", "hcp_id", "visit_date", "visit_type",
            "duration_minutes", "samples_dropped_qty", "sample_product_id", "created_at",
        ),
        natural_key=("visit_id",),
    ),
    RawTable(
        source_system="erp",
        table_name="DISTRIBUTOR",
        columns=(
            "distributor_id", "distributor_name", "distributor_tier", "city",
            "state", "zip_code", "source_updated_at",
        ),
        natural_key=("distributor_id",),
    ),
    RawTable(
        source_system="erp",
        table_name="WAREHOUSE",
        columns=(
            "warehouse_id", "warehouse_name", "region", "city", "state", "source_updated_at",
        ),
        natural_key=("warehouse_id",),
    ),
    RawTable(
        source_system="erp",
        table_name="SALES_ORDER",
        columns=(
            "order_id", "order_line_id", "order_date", "distributor_id", "product_id",
            "batch_id", "warehouse_id", "quantity", "list_price", "discount_pct",
            "rebate_pct", "chargeback_amount", "ship_date", "created_at",
        ),
        natural_key=("order_line_id",),
    ),
    RawTable(
        source_system="erp",
        table_name="RETURN",
        columns=(
            "return_id", "original_order_id", "product_id", "batch_id", "distributor_id",
            "return_date", "quantity", "reason_code", "recall_flag", "created_at",
        ),
        natural_key=("return_id",),
    ),
    RawTable(
        source_system="erp",
        table_name="INVENTORY_SNAPSHOT",
        columns=(
            "snapshot_date", "warehouse_id", "product_id", "batch_id",
            "lot_expiry_date", "qty_on_hand", "created_at",
        ),
        natural_key=("snapshot_date", "warehouse_id", "product_id", "batch_id"),
    ),
]
