{% macro insert_processing_log(table_name) %}
    {% set pipeline_run_id = invocation_id %}
    {% set processed_date = modules.datetime.datetime.now() %}

    {% set insert_query %}
        insert into metadata.processing_log(
        pipeline_run_id,
        table_processed,
        total_rows_processed,
        new_rows_processed,
        latest_processed_pickup_date,
        processed_datetime
        )
        With current_run as(
            select 
            count(*) as total_processed_rows,
            max(pickup_date) AS max_pickup_date,
            count(case 
                when load_timestamp >= dateadd(hour,-24,CURRENT_TIMESTAMP())
                then 1 end) as new_processed_rows
            from
            {{ ref(table_name) }}
        )
        select 
        '{{pipeline_run_id}}',
        '{{table_name}}',
        total_processed_rows,
        new_processed_rows,
        max_pickup_date,
        CURRENT_TIMESTAMP()
        from current_run
        {% endset %}
        {% do run_query(insert_query) %}
        {{ log("Inserted processing log:" ~ table_name ~ ", Run ID: " ~ pipeline_run_id, info = True)}}

{% endmacro %}

{{
    config(
        materialized='table'
    )
}}

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
    t.total_amount / NULLIF(t.trip_distance, 0) as revenue_per_mile

FROM {{ ref('fact_trip') }} t
JOIN {{ ref('dim_date') }} d ON DATE(t.pickup_datetime) = d.full_date
LEFT JOIN {{ ref('dim_location') }} p ON t.pulocationid = p.locationid
LEFT JOIN {{ ref('dim_location') }} d_loc ON t.dolocationid = d_loc.locationid
LEFT JOIN {{ ref('dim_servicetype') }} s ON t.service_type_id = s.service_type_id
LEFT JOIN {{ ref('dim_ratecode') }} r ON t.ratecodeid = r.rate_code_id
LEFT JOIN {{ ref('dim_paymenttype') }} py ON t.payment_type = py.paymentid