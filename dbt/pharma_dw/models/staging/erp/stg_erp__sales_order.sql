with source as (
    select * from {{ source('erp', 'sales_order') }}
),

deduped as (
    select
        trim(order_id)                as order_id,
        trim(order_line_id)             as order_line_id,
        order_date::date                 as order_date,
        trim(distributor_id)              as distributor_id,
        trim(product_id)                   as product_id,
        trim(batch_id)                       as batch_id,
        trim(warehouse_id)                    as warehouse_id,
        quantity::number(10,0)                 as quantity,
        list_price::number(12,2)                as list_price,
        discount_pct::number(6,4)                as discount_pct,
        rebate_pct::number(6,4)                   as rebate_pct,
        coalesce(chargeback_amount, 0)::number(12,2) as chargeback_amount,
        ship_date::date                            as ship_date,
        created_at::timestamp_ntz                    as created_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by order_line_id
        order by _loaded_at desc
    ) = 1
)

select * from deduped
