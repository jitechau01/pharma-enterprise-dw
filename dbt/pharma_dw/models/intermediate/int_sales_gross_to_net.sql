{#
    Pharma commercial revenue is never reported at list/gross price alone --
    contract discounts, rebate accruals, and payer chargebacks all net down
    against gross before "net revenue" is meaningful. This model computes
    that waterfall at order-line grain; fact_sales_orders selects straight
    from here.
#}
with orders as (
    select * from {{ ref('stg_erp__sales_order') }}
),

waterfall as (
    select
        order_id,
        order_line_id,
        order_date,
        ship_date,
        distributor_id,
        product_id,
        batch_id,
        warehouse_id,
        quantity,
        list_price,
        discount_pct,
        rebate_pct,
        chargeback_amount,

        (quantity * list_price)::number(14,2)                                   as gross_amount,
        (quantity * list_price * discount_pct)::number(14,2)                     as discount_amount,
        ((quantity * list_price) - (quantity * list_price * discount_pct))
            * rebate_pct                                                          as rebate_amount_raw,
        chargeback_amount
    from orders
),

final as (
    select
        order_id,
        order_line_id,
        order_date,
        ship_date,
        distributor_id,
        product_id,
        batch_id,
        warehouse_id,
        quantity,
        list_price,
        discount_pct,
        rebate_pct,
        gross_amount,
        discount_amount,
        rebate_amount_raw::number(14,2)                                          as rebate_amount,
        chargeback_amount,
        (gross_amount - discount_amount - rebate_amount_raw - chargeback_amount)
            ::number(14,2)                                                        as net_revenue
    from waterfall
)

select * from final
