select
    trip_id,
    trip_distance,
    total_amount
from {{ref('fact_trip')}}
where total_amount between 0 and 500
and trip_distance > 0