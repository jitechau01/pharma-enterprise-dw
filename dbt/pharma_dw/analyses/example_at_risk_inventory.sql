{#
    Example analysis (compiled with `dbt compile`, not built as a table):
    at-risk inventory = near-expiry batches that are also moving slowly
    (>60 days of stock on hand) -- exactly the report a pharma commercial
    ops / supply chain team would ask for first.
#}
select
    p.product_name,
    p.therapeutic_category,
    f.warehouse_key,
    f.batch_id,
    f.lot_expiry_date,
    f.days_to_expiry,
    f.qty_on_hand,
    f.days_on_hand
from {{ ref('fact_inventory_snapshot') }} f
join {{ ref('dim_product') }} p
    on f.product_key = p.product_key
where f.is_near_expiry
  and f.days_on_hand > 60
  and f.snapshot_date = (select max(snapshot_date) from {{ ref('fact_inventory_snapshot') }})
order by f.days_to_expiry asc
