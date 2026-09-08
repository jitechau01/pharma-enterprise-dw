# Data dictionary

Scope: the curated star schema (`PHARMA_DBT_<env>.MARTS`, mirrored as secure
views in `PHARMA_ANALYTICS_<env>.ANALYTICS`). For raw table shape, see
`snowflake_setup/*.sql`; for the full column-level catalog including staging
and intermediate models, run `make dbt-docs`.

## Dimensions

### dim_product (SCD2)

| Column | Type | Description |
|---|---|---|
| product_key | string (hash) | Surrogate key, versioned per SCD2 change. Fact join key. |
| product_id | string | Natural key (MDM). |
| ndc_code | string | Simulated National Drug Code identifier. |
| product_name | string | |
| therapeutic_category | string | MDM-sourced category (Oncology, Cardiology, ...). |
| category_group | string | Business grouping from `seed_therapeutic_category_group`. |
| formulation | string | Tablet / Capsule / Injection / etc. |
| list_price | number(12,2) | List price at this version. |
| price_tier | string | Tier 1 - Specialty / Tier 2 - Branded / Tier 3 - Generic-Equivalent. |
| is_active | boolean | |
| valid_from / valid_to | timestamp | SCD2 validity window (`dbt_valid_from`/`dbt_valid_to`). |
| is_current | boolean | True for the currently active version. |

### dim_hcp (SCD2)

| Column | Type | Description |
|---|---|---|
| hcp_key | string (hash) | Surrogate key, versioned per SCD2 change. |
| hcp_id | string | Natural key. |
| npi_number | string | Simulated National Provider Identifier. |
| specialty | string | |
| hcp_tier | string | Tier A (KOL) / B (High Prescriber) / C (Standard). |
| territory_id, territory_name, region | string | Resolved via `seed_territory`. |
| valid_from / valid_to / is_current | | SCD2 fields, as above. |

### dim_sales_rep (SCD2)

| Column | Type | Description |
|---|---|---|
| rep_key | string (hash) | Surrogate key, versioned per SCD2 change. |
| rep_id | string | Natural key. |
| territory_id, territory_name, region | string | Resolved via `seed_territory`. |
| manager_rep_id, manager_name | string | Resolved against the *current* manager row (see model header comment for the as-of alternative). |
| valid_from / valid_to / is_current | | SCD2 fields. |

### dim_distributor (SCD1) / dim_warehouse (SCD1)

Current-state only (no history). `distributor_key` / `warehouse_key` are
stable surrogate keys (natural-key hash) that never change version.
`first_loaded_at` tracks true first-seen date across merges.

### dim_date

Standard generated calendar dimension, `date_key` (YYYYMMDD int) and
`date_day` (date) both usable as join keys, plus year/quarter/month/
day-of-week/is_weekend attributes.

## Facts

### fact_sales_orders — grain: one row per order line

| Column | Description |
|---|---|
| order_line_id | Natural + primary key. |
| product_key, distributor_key, warehouse_key | Dimension FKs (product_key is as-of order_date). |
| batch_id, lot_expiry_date | Lot tracking; `is_expired_at_ship` flags a regulatory violation. |
| quantity, list_price, discount_pct, rebate_pct | Inputs to the revenue waterfall. |
| gross_amount, discount_amount, rebate_amount, chargeback_amount, net_revenue | Gross-to-net waterfall (see `int_sales_gross_to_net`). |

### fact_hcp_visits — grain: one row per rep<->HCP visit event

| Column | Description |
|---|---|
| visit_id | Primary key. |
| hcp_key, rep_key, sample_product_key | Dimension FKs, as-of visit_date. |
| visit_type, duration_minutes, samples_dropped_qty | |
| visits_trailing_window, samples_trailing_window, days_since_prior_visit | Rolling-window inputs to engagement_score. |
| engagement_score | 0-100, see `int_hcp_engagement_score` for the formula. |

### fact_inventory_snapshot — grain: one row per warehouse/product/batch/day

| Column | Description |
|---|---|
| snapshot_date, warehouse_key, product_key, batch_id | Grain columns. |
| qty_on_hand | |
| avg_daily_consumption, days_on_hand | Trailing-window consumption rate and resulting runway. |
| days_to_expiry, is_near_expiry, is_expired | Lot expiry risk flags. |

### fact_returns — grain: one row per return line

| Column | Description |
|---|---|
| return_id | Primary key. |
| original_order_id | Links back to `fact_sales_orders.order_id`. |
| product_key, distributor_key | Dimension FKs. |
| reason_code, reason_category, is_controllable | Classified via `seed_return_reason_lookup`. |
| recall_flag | True for recall-driven returns. |

## Conventions

- All surrogate keys (`*_key`) are `md5(concat_ws('|', ...))` hashes (see
  `macros/surrogate_key.sql`) -- stable, deterministic, and safe to
  recompute idempotently.
- SCD2 dims join to facts via an **as-of** condition
  (`event_date >= valid_from and event_date < coalesce(valid_to, '9999-12-31')`),
  never by joining on the natural key alone -- joining on the natural key
  would silently multiply fact rows by the number of dimension versions.
- `NULL` in a fact's dimension key column means the as-of join found no
  matching version (data quality issue, caught by the `relationships` +
  `not_null` tests in each fact's `_*.yml`) -- it does not mean "unknown/NA"
  by design; there is no intentional -1/"Unknown" dummy row in this project
  (a common alternative pattern, noted here as a possible enhancement).
