{{ config(
    materialized='incremental',
    unique_key = 'trip_id',
    incremental_strategy = 'insert_overwrite',
    partition_by = {
        'field' : 'pickup_date',
        'date_type' : 'date',
        'granularity' : 'month'
    }
) }}
{% if is_incremental() %}
    {% set dates = get_dynamic_date_range() %}
{% else %}
    {% set dates = {
        'started_date':'2024-12-31',
        'ended_date':'2025-01-31'
    }%}
{% endif %}
with yellow_taxi AS
(
    select 
        VendorID,
        CAST(tpep_pickup_datetime AS DATE) as pickup_date,
        TO_TIMESTAMP(tpep_pickup_datetime) AS pickup_datetime,
        TO_TIMESTAMP(tpep_dropoff_datetime) as dropoff_datetime,
        passenger_count,
        trip_distance,
        RatecodeID,
        PULocationID,
        DOLocationID,
        payment_type,
        total_amount,
        tip_amount,
        tolls_amount,
        fare_amount,
        store_and_fwd_flag,
        extra,
        mta_tax,
        improvement_surcharge,
        congestion_surcharge,
        1 as service_type_id
    from 
        {{source('nyctaxi_raw','yellow_taxi')}}
    ),

green_taxi as 
(
    select 
        VendorID,
        CAST(lpep_pickup_datetime AS DATE) as pickup_date,
        TO_TIMESTAMP(lpep_pickup_datetime) AS pickup_datetime,
        TO_TIMESTAMP(lpep_dropoff_datetime) as dropoff_datetime,
        passenger_count,
        trip_distance,
        RatecodeID,
        PULocationID,
        DOLocationID,
        payment_type,
        total_amount,
        tip_amount,
        tolls_amount,
        fare_amount,
        store_and_fwd_flag,
        extra,
        mta_tax,
        improvement_surcharge,
        congestion_surcharge,
        2 as service_type_id
    from
        {{source('nyctaxi_raw','green_taxi')}}
)

select 
        {{ dbt_utils.generate_surrogate_key([
        'vendorid',
        'pickup_datetime', 
        'dropoff_datetime', 
        'pulocationid',
        'dolocationid',      
        'trip_distance',
        'service_type_id'  
    ]) }} as trip_id,
        *,
        CURRENT_TIMESTAMP() as load_timestamp
from
    (select 
        * 
    from 
        yellow_taxi
    union all
    select
        *
    from 
        green_taxi)a
where 
    pickup_date >  '{{ dates.started_date }}'
and 
    pickup_date <= '{{ dates.ended_date }}'
