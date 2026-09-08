{{
    config(
        materialized='incremental',
        unique_key='order_line_id',
        incremental_strategy='merge',
        merge_exclude_columns=['order_line_id'],
    )
}}

{#
    Grain: one row per order line. product_key is resolved "as-of the order
    date" against the SCD2 dim_product -- this is the whole point of
    versioning the dimension: a $1,200 order placed before a price change
    stays joined to the $1,200-list-price version of the product, not
    whatever the price is today. distributor_key/warehouse_key are SCD1 so
    there's only ever one version to join to.
#}
with orders as (
    select * from {{ ref('int_sales_gross_to_net') }}
    {% if is_incremental() %}
    where order_date >= (select dateadd('day', -7, max(order_date)) from {{ this }})
    {% endif %}
),

batch_expiry as (
    select * from {{ ref('int_batch_expiry_flags') }}
),

product_versions as (
    select * from {{ ref('dim_product') }}
),

joined as (
    select
        o.order_line_id,
        o.order_id,
        o.order_date,
        o.ship_date,
        d.distributor_key,
        wh.warehouse_key,
        dd.date_key                                        as order_date_key,
        pv.product_key,
        o.product_id,
        o.batch_id,
        be.lot_expiry_date,
        be.is_expired                                        as batch_is_expired_today,
        (o.ship_date > be.lot_expiry_date)                     as is_expired_at_ship,
        o.quantity,
        o.list_price,
        o.discount_pct,
        o.rebate_pct,
        o.gross_amount,
        o.discount_amount,
        o.rebate_amount,
        o.chargeback_amount,
        o.net_revenue
    from orders o
    left join {{ ref('dim_distributor') }} d
        on o.distributor_id = d.distributor_id
    left join {{ ref('dim_warehouse') }} wh
        on o.warehouse_id = wh.warehouse_id
    left join {{ ref('dim_date') }} dd
        on o.order_date = dd.date_day
    left join batch_expiry be
        on o.batch_id = be.batch_id
    left join product_versions pv
        on o.product_id = pv.product_id
        and o.order_date >= pv.valid_from
        and o.order_date < coalesce(pv.valid_to, '9999-12-31'::timestamp_ntz)
)

select * from joined
