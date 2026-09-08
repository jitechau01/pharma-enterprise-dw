{#
  SCD1 dims (dim_distributor, dim_warehouse) are materialized as
  `incremental` with `incremental_strategy='merge'`. This macro returns "all
  columns except the natural/surrogate key" so the merge's UPDATE SET clause
  doesn't have to be hand-maintained as columns are added -- pass it into
  `merge_update_columns` via config, e.g.:

      {{ config(
          materialized='incremental',
          unique_key='distributor_key',
          incremental_strategy='merge',
          merge_exclude_columns=['distributor_key', 'first_loaded_at'],
      ) }}

  (dbt-snowflake supports `merge_exclude_columns` natively as of dbt-core
  1.6+, so this macro is kept mainly for documentation / for adapters where
  it must be computed manually via `merge_update_columns`.)
#}
{% macro scd1_update_columns(all_columns, exclude=[]) -%}
    {%- set cols = [] -%}
    {%- for col in all_columns -%}
        {%- if col not in exclude -%}
            {%- do cols.append(col) -%}
        {%- endif -%}
    {%- endfor -%}
    {{ return(cols) }}
{%- endmacro %}
