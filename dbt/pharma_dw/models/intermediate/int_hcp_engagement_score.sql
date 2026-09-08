{#
    Rolling engagement score per HCP per visit, based on trailing-window
    (var: engagement_lookback_days) visit frequency, sample volume, and
    recency as of each visit_date. Intentionally a simple, transparent
    weighted formula (not a black-box model) -- commercial ops teams need to
    be able to explain "why is this HCP's score X" in plain English.
#}
{% set lookback = var('engagement_lookback_days') %}

with visits as (
    select * from {{ ref('stg_crm__hcp_visit') }}
),

visit_window_stats as (
    select
        v.visit_id,
        v.hcp_id,
        v.rep_id,
        v.visit_date,
        v.visit_type,
        v.duration_minutes,
        v.samples_dropped_qty,
        v.sample_product_id,

        count(*) over (
            partition by v.hcp_id
            order by v.visit_date
            range between interval '{{ lookback }} days' preceding and current row
        ) as visits_trailing_window,

        sum(v.samples_dropped_qty) over (
            partition by v.hcp_id
            order by v.visit_date
            range between interval '{{ lookback }} days' preceding and current row
        ) as samples_trailing_window,

        datediff(
            'day',
            lag(v.visit_date) over (partition by v.hcp_id order by v.visit_date),
            v.visit_date
        ) as days_since_prior_visit
    from visits v
),

scored as (
    select
        *,
        -- weighted, capped 0-100 engagement score:
        --   40% visit frequency (relative to a 12-visit/window ceiling)
        --   30% sample volume (relative to a 150-unit/window ceiling)
        --   30% recency (full credit if <=7 days since prior visit, decaying to 0 at 60+ days)
        least(
            100,
            round(
                (least(visits_trailing_window, 12) / 12.0) * 40
                + (least(coalesce(samples_trailing_window, 0), 150) / 150.0) * 30
                + (
                    case
                        when days_since_prior_visit is null then 0.5
                        when days_since_prior_visit <= 7 then 1.0
                        when days_since_prior_visit >= 60 then 0.0
                        else 1.0 - ((days_since_prior_visit - 7) / 53.0)
                    end
                ) * 30
            , 1)
        ) as engagement_score
    from visit_window_stats
)

select * from scored
