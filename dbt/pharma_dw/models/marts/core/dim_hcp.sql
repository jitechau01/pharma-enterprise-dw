{{ config(materialized='table') }}

with snap as (
    select * from {{ ref('snap_mdm_hcp') }}
)

select
    {{ scd2_surrogate_key('hcp_id') }}      as hcp_key,
    snap.hcp_id,
    snap.npi_number,
    snap.first_name,
    snap.last_name,
    snap.specialty,
    snap.hcp_tier,
    snap.territory_id,
    terr.territory_name,
    terr.region,
    snap.city,
    snap.state,
    snap.zip_code,
    snap.dbt_valid_from                       as valid_from,
    snap.dbt_valid_to                          as valid_to,
    (snap.dbt_valid_to is null)                  as is_current
from snap
left join {{ ref('seed_territory') }} as terr
    on snap.territory_id = terr.territory_id
