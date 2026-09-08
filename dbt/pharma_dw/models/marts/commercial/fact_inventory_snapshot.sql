{{
    config(
        materialized='incremental',
        unique_key=['snapshot_date', 'warehouse_id', 'product_id', 'batch_id'],
        incremental_strategy='merge',
    )
}}

{#
    Grain: one row per warehouse/product/batch/day. Carries days-on-hand and
    expiry flags so "at-risk inventory" (near-expiry AND slow-moving) can be
    queried directly without re-joining three tables downstream.
#}
with inv as (
    select * from {{ ref('int_inventory_days_on_hand') }}
    {% if is_incremental() %}
    where snapshot_date >= (select dateadd('day', -3, max(snapshot_date)) from {{ this }})
    {% endif %}
),

expiry as (
    select * from {{ ref('int_batch_expiry_flags') }}
),

product_versions as (
    select * from {{ ref('dim_product') }}
),

joined as (
    select
        inv.snapshot_date,
        dd.date_key                       as snapshot_date_key,
        wh.warehouse_key,
        inv.warehouse_id,
        pv.product_key,
        inv.product_id,
        inv.batch_id,
        inv.lot_expiry_date,
        inv.qty_on_hand,
        inv.avg_daily_consumption,
        inv.days_on_hand,
        exp.days_to_expiry,
        exp.is_near_expiry,
        exp.is_expired
    from inv
    left join {{ ref('dim_date') }} dd
        on inv.snapshot_date = dd.date_day
    left join {{ ref('dim_warehouse') }} wh
        on inv.warehouse_id = wh.warehouse_id
    left join expiry exp
        on inv.batch_id = exp.batch_id
    left join product_versions pv
        on inv.product_id = pv.product_id
        and inv.snapshot_date >= pv.valid_from
        and inv.snapshot_date < coalesce(pv.valid_to, '9999-12-31'::timestamp_ntz)
)

select * from joined
