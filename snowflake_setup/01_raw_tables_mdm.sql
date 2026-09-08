-- Raw landing tables for the MDM source system (product / HCP / sales rep
-- master data). Full current-state extract lands daily; source_updated_at
-- only changes on rows the source system actually modified -- this is what
-- dbt snapshot's timestamp strategy relies on downstream.
USE DATABASE PHARMA_RAW_&{env};

CREATE TABLE IF NOT EXISTS MDM.PRODUCT (
    product_id            VARCHAR(20),
    ndc_code              VARCHAR(20),
    product_name          VARCHAR(200),
    therapeutic_category  VARCHAR(100),
    formulation           VARCHAR(50),
    list_price            NUMBER(12,2),
    price_tier            VARCHAR(50),
    is_active             BOOLEAN,
    source_updated_at     TIMESTAMP_NTZ,
    _source_file           VARCHAR(500),
    _source_file_row_number NUMBER,
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw MDM product master, full daily extract.';

CREATE TABLE IF NOT EXISTS MDM.HCP (
    hcp_id                VARCHAR(20),
    npi_number            VARCHAR(20),
    first_name            VARCHAR(100),
    last_name             VARCHAR(100),
    specialty             VARCHAR(100),
    hcp_tier              VARCHAR(50),
    territory_id          VARCHAR(20),
    city                  VARCHAR(100),
    state                 VARCHAR(10),
    zip_code              VARCHAR(20),
    source_updated_at     TIMESTAMP_NTZ,
    _source_file           VARCHAR(500),
    _source_file_row_number NUMBER,
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw MDM healthcare provider master, full daily extract.';

CREATE TABLE IF NOT EXISTS MDM.SALES_REP (
    rep_id                VARCHAR(20),
    first_name            VARCHAR(100),
    last_name             VARCHAR(100),
    hire_date             DATE,
    territory_id          VARCHAR(20),
    manager_rep_id        VARCHAR(20),
    region                VARCHAR(50),
    source_updated_at     TIMESTAMP_NTZ,
    _source_file           VARCHAR(500),
    _source_file_row_number NUMBER,
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw MDM sales rep master, full daily extract.';
