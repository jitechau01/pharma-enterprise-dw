with source as (
    select * from {{ source('erp', 'return') }}
),

deduped as (
    select
        trim(return_id)                as return_id,
        trim(original_order_id)          as original_order_id,
        trim(product_id)                   as product_id,
        trim(batch_id)                       as batch_id,
        trim(distributor_id)                  as distributor_id,
        return_date::date                      as return_date,
        quantity::number(10,0)                  as quantity,
        trim(reason_code)                        as reason_code,
        coalesce(recall_flag, false)::boolean      as recall_flag,
        created_at::timestamp_ntz                   as created_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by return_id
        order by _loaded_at desc
    ) = 1
)

select * from deduped
