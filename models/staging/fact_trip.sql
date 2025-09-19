{{
    config(
        materialized='incremental',
        unique_key = 'trip_id',
        incremental_strategy = 'merge',
        partition_by = {
            'field': 'pickup_date',
            'data_type':'date',
            'granularity':'month'
        }
    )
}}

select
    trip_id,
    vendorid,
    pickup_date,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    cast(trip_distance as float) as trip_distance,
    service_type_id,
    ratecodeid,
    pulocationid,
    dolocationid,
    payment_type,
    cast(total_amount as float) as total_amount,
    cast(tip_amount as float) as tip_amount,
    cast(tolls_amount as float) as tolls_amount,
    cast(fare_amount as float) as fare_amount,
    cast(extra as float) as extra_charge,
    cast(mta_tax as float) as tax,
    cast(improvement_surcharge as float) as improvement_surcharge,
    cast(congestion_surcharge as float) as congestion_surcharge
from
    {{ ref('stg_taxi') }}
where 
{% if is_incremental() %}
    pickup_date > (
        select
            case when max(pickup_date) is not null then max(pickup_date)
            else '2024-12-31':: date
            end
        from {{this}})
{% endif %}


