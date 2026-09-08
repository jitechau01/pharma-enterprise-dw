-- Consumption-layer secure views: PHARMA_ANALYTICS.ANALYTICS wraps
-- PHARMA_DBT.MARTS so PHARMA_ANALYST is never granted anything directly on
-- the dbt-owned database (keeps "what can a BI tool see" decoupled from
-- "what does dbt currently materialize", and SECURE VIEW prevents analysts
-- from seeing the underlying query text/data via query profile).
--
-- Run after every dbt deploy (see airflow/dags/pharma_dbt_transform.py,
-- final task `publish_analytics_views`) or manually via SnowSQL.

USE DATABASE PHARMA_ANALYTICS_&{env};
USE SCHEMA ANALYTICS;

CREATE OR REPLACE SECURE VIEW dim_product AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.DIM_PRODUCT;

CREATE OR REPLACE SECURE VIEW dim_hcp AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.DIM_HCP;

CREATE OR REPLACE SECURE VIEW dim_sales_rep AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.DIM_SALES_REP;

CREATE OR REPLACE SECURE VIEW dim_distributor AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.DIM_DISTRIBUTOR;

CREATE OR REPLACE SECURE VIEW dim_warehouse AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.DIM_WAREHOUSE;

CREATE OR REPLACE SECURE VIEW dim_date AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.DIM_DATE;

CREATE OR REPLACE SECURE VIEW fact_sales_orders AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.FACT_SALES_ORDERS;

CREATE OR REPLACE SECURE VIEW fact_hcp_visits AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.FACT_HCP_VISITS;

CREATE OR REPLACE SECURE VIEW fact_inventory_snapshot AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.FACT_INVENTORY_SNAPSHOT;

CREATE OR REPLACE SECURE VIEW fact_returns AS
    SELECT * FROM PHARMA_DBT_&{env}.MARTS.FACT_RETURNS;
