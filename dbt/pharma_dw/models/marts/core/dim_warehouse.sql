{{
    config(
        materialized='incremental',
        unique_key='warehouse_key',
        incremental_strategy='merge',
        merge_exclude_columns=['warehouse_key', 'first_loaded_at'],
    )
}}

{#
    SCD1, same pattern as dim_distributor -- see that model's header comment.
#}
select
    {{ pharma_surrogate_key(['warehouse_id']) }}  as warehouse_key,
    warehouse_id,
    warehouse_name,
    region,
    city,
    state,
    source_updated_at,
    {% if is_incremental() %}
        coalesce(
            (select min(first_loaded_at) from {{ this }} d where d.warehouse_id = s.warehouse_id),
            current_timestamp()
        )
    {% else %}
        current_timestamp()
    {% endif %} as first_loaded_at
from {{ ref('stg_erp__warehouse') }} as s
