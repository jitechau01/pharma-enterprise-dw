{#
    One row per (product_id, source_updated_at). MDM sends a full
    current-state extract every day, so the same product_id/source_updated_at
    pair can legitimately appear in multiple daily files (unchanged rows are
    re-sent) -- dedupe on (natural key, source_updated_at) and keep the most
    recently *loaded* copy, which is what snap_mdm_product's timestamp
    strategy needs to see exactly one row per real change.
#}
with source as (
    select * from {{ source('mdm', 'product') }}
),

deduped as (
    select
        trim(product_id)              as product_id,
        trim(ndc_code)                 as ndc_code,
        trim(product_name)              as product_name,
        trim(therapeutic_category)       as therapeutic_category,
        trim(formulation)                 as formulation,
        list_price::number(12,2)           as list_price,
        trim(price_tier)                    as price_tier,
        is_active::boolean                   as is_active,
        source_updated_at::timestamp_ntz      as source_updated_at,
        _loaded_at
    from source
    qualify row_number() over (
        partition by product_id, source_updated_at
        order by _loaded_at desc
    ) = 1
)

select * from deduped
