{{
    config(
        materialized='table'
    )
}}

{#
    SCD2 dimension read straight from the dbt snapshot. product_key is
    versioned (natural key + dbt_valid_from) so a fact row joined to a
    specific version stays pinned to that version even after the product
    changes again. is_current is a convenience flag for "give me today's
    attributes" queries.
#}
with snap as (
    select * from {{ ref('snap_mdm_product') }}
)

select
    {{ scd2_surrogate_key('product_id') }}     as product_key,
    product_id,
    ndc_code,
    product_name,
    therapeutic_category,
    catgroup.category_group,
    formulation,
    list_price,
    price_tier,
    is_active,
    dbt_valid_from                              as valid_from,
    dbt_valid_to                                 as valid_to,
    (dbt_valid_to is null)                        as is_current
from snap
left join {{ ref('seed_therapeutic_category_group') }} as catgroup
    on snap.therapeutic_category = catgroup.therapeutic_category
