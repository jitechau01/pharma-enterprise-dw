-- Raw landing table for the CRM source system: rep <-> HCP interaction
-- events (append-only, one file of "today's visits" per business day).
USE DATABASE PHARMA_RAW_&{env};

CREATE TABLE IF NOT EXISTS CRM.HCP_VISIT (
    visit_id               VARCHAR(30),
    rep_id                  VARCHAR(20),
    hcp_id                  VARCHAR(20),
    visit_date              DATE,
    visit_type              VARCHAR(50),
    duration_minutes        NUMBER(6,0),
    samples_dropped_qty     NUMBER(8,0),
    sample_product_id       VARCHAR(20),
    created_at               TIMESTAMP_NTZ,
    _source_file             VARCHAR(500),
    _source_file_row_number  NUMBER,
    _loaded_at                TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw CRM rep<->HCP visit/sample-drop events, append-only daily extract.';
