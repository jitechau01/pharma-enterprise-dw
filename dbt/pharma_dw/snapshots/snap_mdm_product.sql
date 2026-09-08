{% snapshot snap_mdm_product %}
{{
    config(
      target_schema='snapshots',
      unique_key='product_id',
      strategy='timestamp',
      updated_at='source_updated_at',
      invalidate_hard_deletes=True,
    )
}}
select * from {{ ref('stg_mdm__product') }}
{% endsnapshot %}
