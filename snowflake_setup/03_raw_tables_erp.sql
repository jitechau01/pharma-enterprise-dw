-- Raw landing tables for the ERP source system: distributor/warehouse
-- master data (SCD1-style full extract) plus order, return, and inventory
-- event/snapshot extracts.
USE DATABASE PHARMA_RAW_&{env};

CREATE TABLE IF NOT EXISTS ERP.DISTRIBUTOR (
    distributor_id         VARCHAR(20),
    distributor_name        VARCHAR(200),
    distributor_tier        VARCHAR(50),
    city                     VARCHAR(100),
    state                    VARCHAR(10),
    zip_code                 VARCHAR(20),
    source_updated_at        TIMESTAMP_NTZ,
    _source_file              VARCHAR(500),
    _source_file_row_number   NUMBER,
    _loaded_at                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw ERP distributor/customer master, full daily extract (SCD1).';

CREATE TABLE IF NOT EXISTS ERP.WAREHOUSE (
    warehouse_id            VARCHAR(20),
    warehouse_name           VARCHAR(200),
    region                    VARCHAR(50),
    city                      VARCHAR(100),
    state                     VARCHAR(10),
    source_updated_at         TIMESTAMP_NTZ,
    _source_file               VARCHAR(500),
    _source_file_row_number    NUMBER,
    _loaded_at                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw ERP warehouse/distribution-center master, full daily extract (SCD1).';

CREATE TABLE IF NOT EXISTS ERP.SALES_ORDER (
    order_id                 VARCHAR(30),
    order_line_id             VARCHAR(40),
    order_date                 DATE,
    distributor_id             VARCHAR(20),
    product_id                  VARCHAR(20),
    batch_id                     VARCHAR(30),
    warehouse_id                 VARCHAR(20),
    quantity                      NUMBER(10,0),
    list_price                     NUMBER(12,2),
    discount_pct                    NUMBER(6,4),
    rebate_pct                       NUMBER(6,4),
    chargeback_amount                 NUMBER(12,2),
    ship_date                          DATE,
    created_at                          TIMESTAMP_NTZ,
    _source_file                         VARCHAR(500),
    _source_file_row_number               NUMBER,
    _loaded_at                             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw ERP sales order lines, append-only daily extract.';

CREATE TABLE IF NOT EXISTS ERP.RETURN (
    return_id                VARCHAR(30),
    original_order_id         VARCHAR(30),
    product_id                 VARCHAR(20),
    batch_id                    VARCHAR(30),
    distributor_id                VARCHAR(20),
    return_date                    DATE,
    quantity                        NUMBER(10,0),
    reason_code                      VARCHAR(50),
    recall_flag                       BOOLEAN,
    created_at                         TIMESTAMP_NTZ,
    _source_file                        VARCHAR(500),
    _source_file_row_number              NUMBER,
    _loaded_at                            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw ERP product returns, append-only daily extract.';

CREATE TABLE IF NOT EXISTS ERP.INVENTORY_SNAPSHOT (
    snapshot_date             DATE,
    warehouse_id                VARCHAR(20),
    product_id                    VARCHAR(20),
    batch_id                       VARCHAR(30),
    lot_expiry_date                  DATE,
    qty_on_hand                        NUMBER(12,0),
    created_at                          TIMESTAMP_NTZ,
    _source_file                         VARCHAR(500),
    _source_file_row_number               NUMBER,
    _loaded_at                             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw ERP daily on-hand inventory snapshot by warehouse/product/batch.';
