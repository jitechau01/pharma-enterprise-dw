with source as (
    select * from {{ source('mdm', 'hcp') }}
),

deduped as (
    select
        trim(hcp_id)                as hcp_id,
        trim(npi_number)              as npi_number,
        trim(first_name)               as first_name,
        trim(last_name)                 as last_name,
        trim(specialty)                  as specialty,
        trim(hcp_tier)                    as hcp_tier,
        trim(territory_id)                 as territory_id,
        trim(city)                          as city,
        trim(state)                          as state,
        trim(zip_code)                        as zip_code,
        source_updated_at::timestamp_ntz       as source_updated_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by hcp_id, source_updated_at
        order by _loaded_at desc
    ) = 1
)

select * from deduped
