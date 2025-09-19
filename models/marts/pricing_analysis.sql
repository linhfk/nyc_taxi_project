{{
    config(
        materialized='table',
        partition_by={'field': 'pickup_date', 'data_type': 'date', 'granularity': 'month'}
    )
}}

WITH pricing_metrics AS (
    SELECT
        DATE(t.pickup_datetime) as pickup_date,
        EXTRACT(HOUR FROM t.pickup_datetime) as hour_of_day,
        d.day_of_week,
        d.is_weekend,
        d.is_holiday,
        p.borough as pickup_borough,
        d_loc.borough as dropoff_borough,
        COUNT(*) as trip_count,
        AVG(t.fare_amount) as avg_base_fare,
        AVG(t.extra_charge) as avg_extra_charge,
        AVG(t.tip_amount) as avg_tip,
        AVG(t.total_amount) as avg_total_fare,
        AVG(t.total_amount / NULLIF(t.trip_distance, 0)) as revenue_per_mile,
        AVG(t.tip_amount / NULLIF(t.total_amount, 0)) as tip_rate,
        AVG(t.passenger_count) as avg_passengers,
        AVG(TIMEDIFF(minute, t.pickup_datetime, t.dropoff_datetime)) as avg_duration,
        AVG(t.congestion_surcharge) as avg_congestion_charge,
        COUNT(CASE WHEN t.congestion_surcharge > 0 THEN 1 END) as congestion_trip_count
    FROM {{ ref('fact_trip') }} t
    JOIN {{ ref('dim_date') }} d ON DATE(t.pickup_datetime) = d.full_date
    LEFT JOIN {{ ref('dim_location') }} p ON t.pulocationid = p.locationid
    LEFT JOIN {{ ref('dim_location') }} d_loc ON t.dolocationid = d_loc.locationid
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),

percentile_calc AS (
    SELECT
        pickup_borough,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_total_fare) as p25_fare,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_total_fare) as p75_fare
    FROM pricing_metrics
    GROUP BY pickup_borough
)

SELECT
    pm.*,
    pm.avg_total_fare / NULLIF(pm.avg_base_fare, 0) as premium_multiplier,
    CASE 
        WHEN pm.avg_total_fare > pc.p75_fare THEN 'High Price Segment'
        WHEN pm.avg_total_fare < pc.p25_fare THEN 'Low Price Segment'
        ELSE 'Medium Price Segment'
    END as price_segment
    
FROM pricing_metrics pm
LEFT JOIN percentile_calc pc ON pm.pickup_borough = pc.pickup_borough