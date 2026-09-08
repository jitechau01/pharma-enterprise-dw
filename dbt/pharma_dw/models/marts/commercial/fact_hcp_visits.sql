{{
    config(
        materialized='incremental',
        unique_key='visit_id',
        incremental_strategy='merge',
        merge_exclude_columns=['visit_id'],
    )
}}

{#
    Grain: one row per rep<->HCP visit event. hcp_key and rep_key are
    resolved as-of visit_date against their SCD2 dimensions, so a visit
    logged before an HCP's territory reassignment still reports the
    territory that was active at the time of the visit.
#}
with visits as (
    select * from {{ ref('int_hcp_engagement_score') }}
    {% if is_incremental() %}
    where visit_date >= (select dateadd('day', -7, max(visit_date)) from {{ this }})
    {% endif %}
),

joined as (
    select
        v.visit_id,
        v.visit_date,
        dd.date_key                          as visit_date_key,
        hcp.hcp_key,
        v.hcp_id,
        rep.rep_key,
        v.rep_id,
        pv.product_key                          as sample_product_key,
        v.sample_product_id,
        v.visit_type,
        v.duration_minutes,
        v.samples_dropped_qty,
        v.visits_trailing_window,
        v.samples_trailing_window,
        v.days_since_prior_visit,
        v.engagement_score
    from visits v
    left join {{ ref('dim_date') }} dd
        on v.visit_date = dd.date_day
    left join {{ ref('dim_hcp') }} hcp
        on v.hcp_id = hcp.hcp_id
        and v.visit_date >= hcp.valid_from
        and v.visit_date < coalesce(hcp.valid_to, '9999-12-31'::timestamp_ntz)
    left join {{ ref('dim_sales_rep') }} rep
        on v.rep_id = rep.rep_id
        and v.visit_date >= rep.valid_from
        and v.visit_date < coalesce(rep.valid_to, '9999-12-31'::timestamp_ntz)
    left join {{ ref('dim_product') }} pv
        on v.sample_product_id = pv.product_id
        and v.visit_date >= pv.valid_from
        and v.visit_date < coalesce(pv.valid_to, '9999-12-31'::timestamp_ntz)
)

select * from joined
