{#
  Thin wrapper around dbt_utils.generate_surrogate_key so every mart uses
  the same null-safe, delimiter-safe hashing approach, and so the hash
  algorithm can be swapped project-wide in one place if needed.
#}
{% macro pharma_surrogate_key(column_list) -%}
    {{ dbt_utils.generate_surrogate_key(column_list) }}
{%- endmacro %}

{#
  For SCD2 dims built from a dbt snapshot: the surrogate key must be unique
  per *version* of the row, not just per natural key, so it includes
  dbt_valid_from. This is what fact tables join against for as-of accuracy.
#}
{% macro scd2_surrogate_key(natural_key_column) -%}
    {{ dbt_utils.generate_surrogate_key([natural_key_column, 'dbt_valid_from']) }}
{%- endmacro %}
