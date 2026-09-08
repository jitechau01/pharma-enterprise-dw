with source as (
    select * from {{ source('crm', 'hcp_visit') }}
),

deduped as (
    select
        trim(visit_id)                 as visit_id,
        trim(rep_id)                     as rep_id,
        trim(hcp_id)                       as hcp_id,
        visit_date::date                    as visit_date,
        trim(visit_type)                     as visit_type,
        duration_minutes::number(6,0)         as duration_minutes,
        coalesce(samples_dropped_qty, 0)::number(8,0) as samples_dropped_qty,
        nullif(trim(sample_product_id), '')    as sample_product_id,
        created_at::timestamp_ntz               as created_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by visit_id
        order by _loaded_at desc
    ) = 1
)

select * from deduped
