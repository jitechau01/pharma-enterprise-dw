{% snapshot snap_mdm_sales_rep %}
{{
    config(
      target_schema='snapshots',
      unique_key='rep_id',
      strategy='timestamp',
      updated_at='source_updated_at',
      invalidate_hard_deletes=True,
    )
}}
select * from {{ ref('stg_mdm__sales_rep') }}
{% endsnapshot %}
