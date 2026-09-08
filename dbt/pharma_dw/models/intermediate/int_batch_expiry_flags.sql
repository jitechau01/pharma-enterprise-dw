{#
    Batch/lot-level expiry metadata, deduped to one row per batch (a batch's
    lot_expiry_date is fixed at manufacture, so we only need the most recent
    snapshot to know it -- this model is a lookup, not a time series).
    Consumed by fact_inventory_snapshot (near-expiry flag) and
    fact_sales_orders (the no_expired_batch_shipped guardrail test).
#}
{% set near_expiry_days = var('near_expiry_threshold_days') %}

with inventory as (
    select * from {{ ref('stg_erp__inventory_snapshot') }}
),

batch_expiry as (
    select distinct
        product_id,
        batch_id,
        lot_expiry_date
    from inventory
),

flagged as (
    select
        product_id,
        batch_id,
        lot_expiry_date,
        datediff('day', current_date(), lot_expiry_date) as days_to_expiry,
        (datediff('day', current_date(), lot_expiry_date) <= {{ near_expiry_days }}) as is_near_expiry,
        (lot_expiry_date < current_date())                                            as is_expired
    from batch_expiry
)

select * from flagged
