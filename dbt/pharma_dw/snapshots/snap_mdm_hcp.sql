{% snapshot snap_mdm_hcp %}
{{
    config(
      target_schema='snapshots',
      unique_key='hcp_id',
      strategy='timestamp',
      updated_at='source_updated_at',
      invalidate_hard_deletes=True,
    )
}}
select * from {{ ref('stg_mdm__hcp') }}
{% endsnapshot %}
