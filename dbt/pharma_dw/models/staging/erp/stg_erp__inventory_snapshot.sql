with source as (
    select * from {{ source('erp', 'inventory_snapshot') }}
),

deduped as (
    select
        snapshot_date::date              as snapshot_date,
        trim(warehouse_id)                 as warehouse_id,
        trim(product_id)                     as product_id,
        trim(batch_id)                         as batch_id,
        lot_expiry_date::date                    as lot_expiry_date,
        qty_on_hand::number(12,0)                  as qty_on_hand,
        created_at::timestamp_ntz                    as created_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by snapshot_date, warehouse_id, product_id, batch_id
        order by _loaded_at desc
    ) = 1
)

select * from deduped
