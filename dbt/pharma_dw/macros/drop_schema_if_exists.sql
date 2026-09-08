{#
  Used by .github/workflows/dbt_ci.yml to clean up the ephemeral
  `ci_pr_<number>` schema after each CI run, so short-lived PR schemas don't
  accumulate in the CI Snowflake database.

  Usage: dbt run-operation drop_schema_if_exists --args '{schema_name: ci_pr_123}'
#}
{% macro drop_schema_if_exists(schema_name) %}
    {% set drop_sql %}
        drop schema if exists {{ target.database }}.{{ schema_name }} cascade
    {% endset %}
    {% do log('Dropping CI schema: ' ~ schema_name, info=True) %}
    {% do run_query(drop_sql) %}
{% endmacro %}
