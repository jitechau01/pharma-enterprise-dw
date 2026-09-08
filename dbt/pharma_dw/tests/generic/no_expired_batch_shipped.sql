{#
  Regulatory-flavored data-quality guardrail: a batch/lot must never be
  shipped (fact_sales_orders.ship_date) after its lot_expiry_date. This is
  applied as a generic test on fact_sales_orders in
  models/marts/commercial/_commercial__models.yml:

      - dbt_utils.expression_is_true / no_expired_batch_shipped:
          arguments: {}

  A generic test takes `model` implicitly and receives `column_name` if
  attached to a column; this one is model-level (attached with no
  column_name), so it queries the fact directly.
#}
{% test no_expired_batch_shipped(model) %}

with joined as (
    select
        f.order_line_id,
        f.ship_date,
        f.lot_expiry_date
    from {{ model }} f
    where f.lot_expiry_date is not null
)

select *
from joined
where ship_date > lot_expiry_date

{% endtest %}
