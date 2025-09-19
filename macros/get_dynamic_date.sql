
{% macro get_dynamic_date_range() %}
    {% set latest_date_query %}
        select 
            latest_processed_pickup_date
        from 
            metadata.processing_log
        where 
            table_processed = 'stg_taxi'
        order by 
            latest_processed_pickup_date desc
        limit 1
    {% endset %}
    
    {% set latest_date = run_query(latest_date_query) %}
    
    {% if latest_date and latest_date.rows and latest_date.rows[0][0] is not none %}
        {% set started_date = latest_date.rows[0][0] %}
        {% set ended_date = get_end_date(started_date, 1) %}
        {{ return({'started_date': started_date, 'ended_date': ended_date}) }}
    {% else %}
        {{ return({'started_date': '2024-12-31', 'ended_date': '2025-01-31'}) }}
    {% endif %}
{% endmacro %}
