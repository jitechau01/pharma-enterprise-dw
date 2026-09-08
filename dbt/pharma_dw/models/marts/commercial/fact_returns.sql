{{
    config(
        materialized='incremental',
        unique_key='return_id',
        incremental_strategy='merge',
        merge_exclude_columns=['return_id'],
    )
}}

{#
    Grain: one row per return line. Joins the return-reason lookup seed for
    controllable/non-controllable classification, and links back to the
    originating order line for root-cause analysis.
#}
with returns as (
    select * from {{ ref('stg_erp__return') }}
    {% if is_incremental() %}
    where return_date >= (select dateadd('day', -7, max(return_date)) from {{ this }})
    {% endif %}
),

product_versions as (
    select * from {{ ref('dim_product') }}
),

joined as (
    select
        r.return_id,
        r.original_order_id,
        r.return_date,
        dd.date_key                        as return_date_key,
        dist.distributor_key,
        r.distributor_id,
        pv.product_key,
        r.product_id,
        r.batch_id,
        r.quantity,
        r.reason_code,
        rl.reason_category,
        rl.is_controllable,
        r.recall_flag
    from returns r
    left join {{ ref('dim_date') }} dd
        on r.return_date = dd.date_day
    left join {{ ref('dim_distributor') }} dist
        on r.distributor_id = dist.distributor_id
    left join {{ ref('seed_return_reason_lookup') }} rl
        on r.reason_code = rl.reason_code
    left join product_versions pv
        on r.product_id = pv.product_id
        and r.return_date >= pv.valid_from
        and r.return_date < coalesce(pv.valid_to, '9999-12-31'::timestamp_ntz)
)

select * from joined
