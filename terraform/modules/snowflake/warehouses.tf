# Three warehouses separate cost/contention by workload: loading is
# lightweight and constant, transforming is bursty and needs more compute
# during dbt runs, reporting is BI query traffic that shouldn't compete with
# either.

# resource "snowflake_resource_monitor" "monthly" {
#   name            = "PHARMA_MONTHLY_MONITOR_${upper(var.env)}"
#   credit_quota    = var.monthly_credit_quota
#   frequency       = "MONTHLY"
#   start_timestamp = "IMMEDIATELY"

#   notify_triggers           = [70, 90]
#   suspend_trigger           = 100
#   suspend_immediate_trigger = 110

#   set_for_account = false
# }

resource "snowflake_warehouse" "loading" {
  name                = "PHARMA_LOADING_WH_${upper(var.env)}"
  warehouse_size      = var.loading_warehouse_size
#  resource_monitor    = snowflake_resource_monitor.monthly.name
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Used by the Airflow ingestion DAG for COPY INTO RAW."
}

resource "snowflake_warehouse" "transforming" {
  name                = "PHARMA_TRANSFORMING_WH_${upper(var.env)}"
  warehouse_size      = var.transforming_warehouse_size
#  resource_monitor    = snowflake_resource_monitor.monthly.name
  auto_suspend        = 120
  auto_resume         = true
  initially_suspended = true
  comment             = "Used by dbt (snapshot/run/test) via the Airflow transform DAG and CI."
}

resource "snowflake_warehouse" "reporting" {
  name                = "PHARMA_REPORTING_WH_${upper(var.env)}"
  warehouse_size      = var.reporting_warehouse_size
#  resource_monitor    = snowflake_resource_monitor.monthly.name
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  comment             = "BI/reporting query traffic against PHARMA_ANALYTICS."
}
