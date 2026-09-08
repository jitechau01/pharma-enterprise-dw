with source as (
    select * from {{ source('erp', 'warehouse') }}
),

deduped as (
    select
        trim(warehouse_id)          as warehouse_id,
        trim(warehouse_name)          as warehouse_name,
        trim(region)                    as region,
        trim(city)                        as city,
        trim(state)                        as state,
        source_updated_at::timestamp_ntz    as source_updated_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by warehouse_id
        order by _loaded_at desc
    ) = 1
)

select * from deduped
