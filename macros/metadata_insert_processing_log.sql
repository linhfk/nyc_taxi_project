{% macro metadata_insert_processing_log(table_name) %}
    {% set pipeline_run_id = invocation_id %}

    {% set check_log_query %}
        select count(*) from metadata.processing_log
        where table_processed = '{{table_name}}'
    {% endset %}
    {% set log_exist_result = run_query(check_log_query)%}
    {% set is_incremental_run = true %}
    {% set previous_total = 0 %}

    {% if log_exist_result and log_exist_result.rows and log_exist_result.rows[0][0]==0 %}
        {% set is_incremental_run = false %}
    {% else %}
        {% set get_previous_query %}
            select 
                total_rows_processed
            from 
                metadata.processing_log
            where 
                table_processed = '{{table_name}}'
            order by 
                latest_processed_pickup_date desc
            limit 1
        {% endset %}
        {% set previous_result = run_query(get_previous_query)%}
        {% if previous_result and previous_result.rows %} 
            {% set previous_total = previous_result.rows[0][0]%}
        {% endif %}
    {% endif %}

    {% set get_current_query %}
        select 
            count(*) as current_count,
            max(pickup_date) as max_pickup_date
        from
            {{ref(table_name)}}
    {% endset %}
    {% set current_result = run_query(get_current_query) %}
    {% set current_total = current_result.rows[0][0] if current_result and current_result.rows else 0 %}
    {% set max_pickup_date = current_result.rows[0][1] if current_result and current_result.rows else none %}

    {% if is_incremental_run %}
        {% set total_rows_processed = current_total + previous_total %}
    {% else %}
        {% set total_rows_processed = current_total %}
    {% endif %}

    {% set insert_query %}
        insert into metadata.processing_log(
            pipeline_run_id,
            table_processed,
            total_rows_processed,
            new_rows_processed,
            latest_processed_pickup_date,
            processed_datetime
        )
        values(
            '{{pipeline_run_id}}',
            '{{table_name}}',
            {{total_rows_processed}},
            {{current_total}},
            '{{max_pickup_date}}',
            CURRENT_TIMESTAMP()
        )
    {% endset %}
    {% do run_query(insert_query)%}
    {{ log("Inserted processing log:" ~ table_name ~ ", Run ID: " ~ pipeline_run_id ~", Total Rows: " ~ total_rows_processed ~ ", New Rows Processed: "~ current_total, info = True)}}

{% endmacro %}

