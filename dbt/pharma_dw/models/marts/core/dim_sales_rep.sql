{{ config(materialized='table') }}

{#
    Self-join to the *current* row per manager so every historical rep
    version shows who their manager currently is by name -- if you instead
    need "who was their manager as of this version," join on
    manager.valid_from/valid_to bracketing rep.valid_from, which is the same
    as-of pattern used in the fact models.
#}
with snap as (
    select * from {{ ref('snap_mdm_sales_rep') }}
),

current_managers as (
    select rep_id, first_name, last_name
    from snap
    where dbt_valid_to is null
)

select
    {{ scd2_surrogate_key('rep.rep_id') }}   as rep_key,
    rep.rep_id,
    rep.first_name,
    rep.last_name,
    rep.hire_date,
    rep.territory_id,
    terr.territory_name,
    terr.region,
    rep.manager_rep_id,
    mgr.first_name || ' ' || mgr.last_name    as manager_name,
    rep.dbt_valid_from                          as valid_from,
    rep.dbt_valid_to                             as valid_to,
    (rep.dbt_valid_to is null)                     as is_current
from snap as rep
left join current_managers as mgr
    on rep.manager_rep_id = mgr.rep_id
left join {{ ref('seed_territory') }} as terr
    on rep.territory_id = terr.territory_id
