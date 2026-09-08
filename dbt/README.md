# dbt project: `pharma_dw`

```
dbt/pharma_dw/
├── models/
│   ├── staging/        one model per raw table (crm/erp/mdm), views, deduped+typed+trimmed
│   ├── intermediate/    business logic (gross-to-net, engagement score, DOH, expiry flags)
│   └── marts/
│       ├── core/          dim_product/hcp/sales_rep (SCD2), dim_distributor/warehouse (SCD1), dim_date
│       └── commercial/     fact_sales_orders/hcp_visits/inventory_snapshot/returns
├── snapshots/            SCD2 mechanism: snap_mdm_product/hcp/sales_rep
├── seeds/                 static reference data (territory, therapeutic category grouping, return reasons)
├── macros/                 generate_schema_name override, surrogate key helpers, SCD1 merge helper
└── tests/generic/          no_expired_batch_shipped custom test
```

## Running it

```bash
cd dbt/pharma_dw
dbt deps
dbt seed        --target dev
dbt snapshot    --target dev
dbt run         --target dev
dbt test        --target dev
dbt docs generate --target dev && dbt docs serve
```

Order matters: `seed` before `run` (marts join against seeds), `snapshot`
before `run` (dims select from the snapshot tables), `run` before `test`
(most tests are against built relations). `airflow/dags/pharma_dbt_transform.py`
runs these as separate, individually-retryable Airflow tasks in this exact
order.

## Model count / DAG shape

- 9 sources -> 9 staging models (1:1)
- 3 SCD2 snapshots (product, HCP, sales rep)
- 4 intermediate models (business logic)
- 6 dimension marts (3 SCD2, 2 SCD1, 1 generated date)
- 4 fact marts (order line, visit event, daily inventory snapshot, return line)

Run `dbt docs generate && dbt docs serve` for the interactive lineage graph
(`dbt docs` is also how you'd browse the full column-level documentation and
test coverage generated from every `_*.yml` file in this project).

## Incremental strategy

All four facts are `incremental` + `merge`, re-processing a short trailing
window (`where <event_date> >= max(<event_date>) - N days`) each run rather
than a full rebuild, since MDM dimension attributes can retroactively change
which SCD2 version a *recent* fact row should point to (e.g., if yesterday's
files arrive late) but older fact rows never need re-resolving. `dbt run
--full-refresh` rebuilds everything from scratch (used the first time, or
after a snapshot/staging model's column shape changes).
