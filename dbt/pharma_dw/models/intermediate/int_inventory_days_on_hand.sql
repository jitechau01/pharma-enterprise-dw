{#
    Days-of-inventory-on-hand per warehouse/product/batch/day: trailing
    average daily consumption (var: consumption_lookback_days) divided into
    current qty_on_hand. NULL/very-high DOH when a product/warehouse
    combination hasn't shipped recently (avoids divide-by-zero and avoids
    implying "infinite" runway is meaningful).
#}
{% set consumption_window = var('consumption_lookback_days') %}

with inventory as (
    select * from {{ ref('stg_erp__inventory_snapshot') }}
),

orders as (
    select * from {{ ref('stg_erp__sales_order') }}
),

daily_consumption as (
    select
        warehouse_id,
        product_id,
        ship_date,
        sum(quantity) as qty_shipped
    from orders
    group by 1, 2, 3
),

trailing_avg_consumption as (
    select
        inv.snapshot_date,
        inv.warehouse_id,
        inv.product_id,
        inv.batch_id,
        inv.lot_expiry_date,
        inv.qty_on_hand,
        (
            select avg(dc.qty_shipped)
            from daily_consumption dc
            where dc.warehouse_id = inv.warehouse_id
              and dc.product_id = inv.product_id
              and dc.ship_date between dateadd('day', -{{ consumption_window }}, inv.snapshot_date) and inv.snapshot_date
        ) as avg_daily_consumption
    from inventory inv
),

final as (
    select
        snapshot_date,
        warehouse_id,
        product_id,
        batch_id,
        lot_expiry_date,
        qty_on_hand,
        avg_daily_consumption,
        case
            when avg_daily_consumption is null or avg_daily_consumption = 0 then null
            else round(qty_on_hand / avg_daily_consumption, 1)
        end as days_on_hand
    from trailing_avg_consumption
)

select * from final
