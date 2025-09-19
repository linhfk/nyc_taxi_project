{% macro get_end_date(start_date, months_to_add = 1) -%}
    {% set start_date_str = start_date|string -%}
    {% set start_date_obj = modules.datetime.datetime.strptime(start_date_str, '%Y-%m-%d') -%}
    {% set next_month = (start_date_obj.month % 12) + 1 -%}
    {% set next_year = start_date_obj.year + (start_date_obj.month // 12) -%}
    {% set next_next_month = (next_month % 12) + 1 -%}
    {% set next_next_year = next_year + (next_month // 12) -%}
    {% set next_next_month_first = modules.datetime.datetime(next_next_year, next_next_month, 1) -%}
    {% set next_month_last = next_next_month_first - modules.datetime.timedelta(days=1) -%}
    {{ "%04d-%02d-%02d"|format(next_month_last.year, next_month_last.month, next_month_last.day) }}
{%- endmacro %}