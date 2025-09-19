{{
    config(
        materialized='table',
        partition_by={'field': 'pickup_date', 'data_type': 'date', 'granularity': 'month'}
    )
}}

WITH trip_details AS (
    SELECT
        t.trip_id,
        t.pickup_datetime,
        t.dropoff_datetime,
        d.date_key,
        d.day_of_week,
        d.day_name,
        d.month_name,
        d.quarter,
        d.year,
        d.is_weekend,
        d.is_holiday,
        EXTRACT(HOUR FROM t.pickup_datetime) as hour_of_day,
        CASE 
            WHEN EXTRACT(HOUR FROM t.pickup_datetime) BETWEEN 6 AND 9 THEN 'Morning Peak'
            WHEN EXTRACT(HOUR FROM t.pickup_datetime) BETWEEN 17 AND 20 THEN 'Evening Peak'
            ELSE 'Off-Peak'
        END as time_period,
        p.borough as pickup_borough,
        p.zone as pickup_zone,
        d_loc.borough as dropoff_borough,
        d_loc.zone as dropoff_zone,
        s.service_type_name,
        r.rate_code_name,
        py.payment_type,
        t.trip_distance,
        t.passenger_count,
        TIMEDIFF(minute, t.pickup_datetime, t.dropoff_datetime) as duration_minutes,
        t.fare_amount,
        t.extra_charge,
        t.tax,
        t.tip_amount,
        t.tolls_amount,
        t.improvement_surcharge,
        t.congestion_surcharge,
        t.total_amount,
        t.tip_amount / NULLIF(t.total_amount, 0) as tip_ratio,
        t.total_amount / NULLIF(t.trip_distance, 0) as revenue_per_mile,
        DATE(t.pickup_datetime) as pickup_date

    FROM {{ ref('fact_trip') }} t
    JOIN {{ ref('dim_date') }} d ON DATE(t.pickup_datetime) = d.full_date
    LEFT JOIN {{ ref('dim_location') }} p ON t.pulocationid = p.locationid
    LEFT JOIN {{ ref('dim_location') }} d_loc ON t.dolocationid = d_loc.locationid
    LEFT JOIN {{ ref('dim_servicetype') }} s ON t.service_type_id = s.service_type_id
    LEFT JOIN {{ ref('dim_ratecode') }} r ON t.ratecodeid = r.rate_code_id
    LEFT JOIN {{ ref('dim_paymenttype') }} py ON t.payment_type = py.paymentid
    where 
    t.total_amount between 0 and 500
    and t.trip_distance > 0
),

pattern_analysis AS (
    SELECT
        pickup_date,
        hour_of_day,
        time_period,
        day_of_week,
        day_name,
        month_name,
        quarter,
        year,
        is_weekend,
        is_holiday,
        pickup_borough,
        dropoff_borough,
        service_type_name,
        rate_code_name,
        payment_type,
        
        -- Aggregration
        COUNT(*) as trip_count,
        AVG(trip_distance) as avg_distance,
        AVG(passenger_count) as avg_passengers,
        AVG(duration_minutes) as avg_duration,
        SUM(trip_distance) as total_distance,
        
        -- Income analysis
        SUM(fare_amount) as total_fare,
        SUM(extra_charge) as total_extra,
        SUM(tax) as total_tax,
        SUM(tip_amount) as total_tips,
        SUM(tolls_amount) as total_tolls,
        SUM(improvement_surcharge) as total_surcharge,
        SUM(congestion_surcharge) as total_congestion,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_revenue_per_trip,
        AVG(tip_ratio) as avg_tip_ratio,
        AVG(revenue_per_mile) as avg_revenue_per_mile,
        
        -- Model analysis
        STDDEV(total_amount) as revenue_volatility,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount) as median_revenue,
        CORR(trip_distance, total_amount) as distance_revenue_correlation,
        
        -- Demand analysis
        CASE 
            WHEN COUNT(*) > 100 THEN 'High Demand'
            WHEN COUNT(*) > 50 THEN 'Medium Demand'
            ELSE 'Low Demand'
        END as demand_segment,

        -- Revenue analysis
        CASE 
            WHEN AVG(total_amount) > 30 THEN 'Premium'
            WHEN AVG(total_amount) > 15 THEN 'Standard'
            ELSE 'Economy'
        END as price_segment,
        
        -- Distance analysis
        CASE 
            WHEN AVG(trip_distance) < 1 THEN 'Very Short Trip(<1mi)'
            WHEN AVG(trip_distance) < 2 THEN 'Short Trip(1-2mi)'
            WHEN AVG(trip_distance) < 3 THEN 'Medium Trip(2-3mi)'
            ELSE 'Long Trip(3+mi)'
        END as distance_segment,

        -- Duration analysis
        CASE 
            WHEN avg_duration < 10 THEN 'Extremely fast (<10 min)'
            WHEN avg_duration < 20 THEN 'Fast (10-20 min)'
            WHEN avg_duration < 30 THEN 'Standard (20-30 min)'
            ELSE 'Slow (30+ min)'
        END as duration_segment

    FROM trip_details
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
)

SELECT
    *,
    -- Efficiency Metrics
    total_revenue / NULLIF(trip_count, 0) as revenue_per_trip,
    total_revenue / NULLIF(total_distance, 0) as revenue_per_mile_total,
    
    -- Pricing Strategy Metrics
    total_extra / NULLIF(total_fare, 0) as extra_charge_ratio,
    total_congestion / NULLIF(total_fare, 0) as congestion_charge_ratio,
    
    -- Preliminary Analysis of Price Elasticity of Demand
    CASE 
        WHEN trip_count > AVG(trip_count) OVER (PARTITION BY pickup_borough) 
             AND avg_revenue_per_trip < AVG(avg_revenue_per_trip) OVER (PARTITION BY pickup_borough)
        THEN 'Potential Price Increase Opportunity'
        WHEN trip_count < AVG(trip_count) OVER (PARTITION BY pickup_borough) 
             AND avg_revenue_per_trip > AVG(avg_revenue_per_trip) OVER (PARTITION BY pickup_borough)
        THEN 'Potential Price Decrease Opportunity'
        ELSE 'Price Level Appropriate'
    END as pricing_opportunity

FROM pattern_analysis
