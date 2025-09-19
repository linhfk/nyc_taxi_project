{% macro end_date(start_date, months_to_add = 1) -%}
         dateadd(
            month, {{months_to_add}},
            to_char(
                DATE_TRUNC('month', {{ start_date }}),
                'YYYY-MM-DD'   
            )
        )| string
{% endmacro -%}