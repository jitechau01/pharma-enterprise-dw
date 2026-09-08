with source as (
    select * from {{ source('erp', 'distributor') }}
),

deduped as (
    select
        trim(distributor_id)         as distributor_id,
        trim(distributor_name)         as distributor_name,
        trim(distributor_tier)           as distributor_tier,
        trim(city)                        as city,
        trim(state)                        as state,
        trim(zip_code)                      as zip_code,
        source_updated_at::timestamp_ntz     as source_updated_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by distributor_id
        order by _loaded_at desc
    ) = 1
)

select * from deduped
