{#
  Standard dbt override: ignore the `schema:` value in profiles.yml/target
  and use ONLY the schema set via `+schema:` config in dbt_project.yml
  (staging / snapshots / intermediate / marts). Without this override, dbt's
  default behavior would concatenate target.schema + custom schema
  (e.g. "staging_staging"), which we don't want here since the *database*
  already encodes the environment (PHARMA_DBT_DEV / _STAGING / _PROD).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
