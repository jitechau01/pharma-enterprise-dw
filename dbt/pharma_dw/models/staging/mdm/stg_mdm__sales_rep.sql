with source as (
    select * from {{ source('mdm', 'sales_rep') }}
),

deduped as (
    select
        trim(rep_id)                  as rep_id,
        trim(first_name)                as first_name,
        trim(last_name)                  as last_name,
        hire_date::date                   as hire_date,
        trim(territory_id)                 as territory_id,
        nullif(trim(manager_rep_id), '')    as manager_rep_id,
        trim(region)                          as region,
        source_updated_at::timestamp_ntz       as source_updated_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by rep_id, source_updated_at
        order by _loaded_at desc
    ) = 1
)

select * from deduped
