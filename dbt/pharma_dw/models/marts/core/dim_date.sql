{{ config(materialized='table') }}

{#
    Standard generated calendar dimension via dbt_utils.date_spine. Range
    controlled by vars.date_spine_start / date_spine_end in dbt_project.yml
    so it can be widened without touching this model.
#}
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('date_spine_start') ~ "' as date)",
        end_date="cast('" ~ var('date_spine_end') ~ "' as date)"
    ) }}
),

final as (
    select
        cast(date_day as date)                        as date_day,
        to_char(date_day, 'YYYYMMDD')::number            as date_key,
        year(date_day)                                     as year,
        quarter(date_day)                                    as quarter,
        month(date_day)                                        as month,
        monthname(date_day)                                      as month_name,
        day(date_day)                                              as day_of_month,
        dayofweek(date_day)                                          as day_of_week,
        dayname(date_day)                                              as day_name,
        weekofyear(date_day)                                             as week_of_year,
        (dayofweek(date_day) in (0, 6))                                    as is_weekend
    from spine
)

select * from final
