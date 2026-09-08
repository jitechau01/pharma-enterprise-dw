{{
    config(
        materialized='incremental',
        unique_key='distributor_key',
        incremental_strategy='merge',
        merge_exclude_columns=['distributor_key', 'first_loaded_at'],
    )
}}

{#
    SCD1: current-state-only dimension. Every run re-selects the latest
    staging row per distributor_id and merges it in place -- no history is
    kept (contrast with dim_product/dim_hcp/dim_sales_rep, which are SCD2
    via dbt snapshot). first_loaded_at is preserved across merges via
    merge_exclude_columns so it reflects true first-seen date, not
    last-run date.
#}
select
    {{ pharma_surrogate_key(['distributor_id']) }}  as distributor_key,
    distributor_id,
    distributor_name,
    distributor_tier,
    city,
    state,
    zip_code,
    source_updated_at,
    {% if is_incremental() %}
        coalesce(
            (select min(first_loaded_at) from {{ this }} d where d.distributor_id = s.distributor_id),
            current_timestamp()
        )
    {% else %}
        current_timestamp()
    {% endif %} as first_loaded_at
from {{ ref('stg_erp__distributor') }} as s
