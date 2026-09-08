-- Reference COPY INTO statements -- one per raw table. These are the same
-- statements airflow/dags/pharma_raw_ingestion.py generates programmatically
-- (see airflow/dags/common/snowflake_copy.py); kept here too so they can be
-- run/tested by hand from SnowSQL without spinning up Airflow.
--
-- ${schema}       e.g. MDM, CRM, ERP
-- ${table}        e.g. PRODUCT
-- ${stage}        e.g. MDM_RAW_STAGE (created by terraform/modules/snowflake/storage_integration.tf)
-- ${dt}            simulated business day, e.g. 2026-06-05 (matches the S3 dt=YYYY-MM-DD partition)

USE DATABASE PHARMA_RAW_&{env};
USE WAREHOUSE PHARMA_LOADING_WH_&{env};

-- Example: MDM.PRODUCT
COPY INTO MDM.PRODUCT (
    product_id, ndc_code, product_name, therapeutic_category, formulation,
    list_price, price_tier, is_active, source_updated_at,
    _source_file, _source_file_row_number
)
FROM (
    SELECT
        $1, $2, $3, $4, $5, $6, $7, $8, $9,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @MDM.MDM_RAW_STAGE/product/dt=&{dt}/
)
FILE_FORMAT = (FORMAT_NAME = 'MDM.CSV_STANDARD')
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

-- Example: ERP.SALES_ORDER
COPY INTO ERP.SALES_ORDER (
    order_id, order_line_id, order_date, distributor_id, product_id,
    batch_id, warehouse_id, quantity, list_price, discount_pct,
    rebate_pct, chargeback_amount, ship_date, created_at,
    _source_file, _source_file_row_number
)
FROM (
    SELECT
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @ERP.ERP_RAW_STAGE/sales_order/dt=&{dt}/
)
FILE_FORMAT = (FORMAT_NAME = 'ERP.CSV_STANDARD')
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

-- The remaining 7 tables (MDM.HCP, MDM.SALES_REP, CRM.HCP_VISIT,
-- ERP.DISTRIBUTOR, ERP.WAREHOUSE, ERP.RETURN, ERP.INVENTORY_SNAPSHOT)
-- follow the identical pattern -- column list in raw-file order, stage path
-- `@<SCHEMA>.<SCHEMA>_RAW_STAGE/<table>/dt=<dt>/`. Airflow builds all 9
-- statements from a single table-config dict rather than repeating this SQL
-- nine times -- see airflow/dags/common/snowflake_copy.py.
