{{
  config(
    materialized='view',
    unique_key='date_id'
  )
}}

WITH date_spine AS (
  {{ dbt_utils.date_spine(
      datepart="day",
      start_date="to_date('01/01/1980', 'mm/dd/yyyy')",
      end_date="dateadd(year, 50, current_date())"
     )
  }}
),

date_attributes AS (
  SELECT
    date_day as full_date,
    
    -- Date parts using Snowflake's native functions
    DATE_TRUNC('week', date_day) as week_start_date,
    DATE_TRUNC('month', date_day) as month_start_date,
    DATE_TRUNC('quarter', date_day) as quarter_start_date,
    DATE_TRUNC('year', date_day) as year_start_date,
    
    -- Day attributes
    DAYOFWEEK(date_day) as day_of_week,
    DAYNAME(date_day) as day_name,
    DAYOFMONTH(date_day) as day_of_month,
    DAYOFYEAR(date_day) as day_of_year,
    
    -- Week attributes
    WEEKOFYEAR(date_day) as week_of_year,
    DATE_TRUNC('week', date_day) as iso_week_start_date,
    
    -- Month attributes
    MONTH(date_day) as month_number,
    MONTHNAME(date_day) as month_name,
    
    -- Quarter attributes
    QUARTER(date_day) as quarter,
    
    -- Year attributes
    YEAR(date_day) as year,
    
    -- Flags
    CASE WHEN DAYOFWEEK(date_day) IN (0, 6) THEN TRUE ELSE FALSE END as is_weekend,
    FALSE as is_holiday,
    CASE 
      WHEN MONTH(date_day) = 1 AND DAYOFMONTH(date_day) = 1 THEN TRUE
      WHEN MONTH(date_day) = 12 AND DAYOFMONTH(date_day) = 25 THEN TRUE
      ELSE FALSE
    END as is_major_holiday,
    
    -- Fiscal periods (adjust as needed)
    CASE 
      WHEN MONTH(date_day) BETWEEN 1 AND 3 THEN 3
      WHEN MONTH(date_day) BETWEEN 4 AND 6 THEN 4
      WHEN MONTH(date_day) BETWEEN 7 AND 9 THEN 1
      ELSE 2
    END as fiscal_quarter,
    
    CASE 
      WHEN MONTH(date_day) BETWEEN 1 AND 3 THEN YEAR(date_day)
      ELSE YEAR(date_day) + 1
    END as fiscal_year

  FROM date_spine
)

SELECT
  {{ dbt_utils.generate_surrogate_key(['full_date']) }} as date_key,
  TO_NUMBER(TO_VARCHAR(full_date, 'YYYYMMDD')) as date_id,
  *,
  CURRENT_TIMESTAMP() as dbt_updated_at
FROM date_attributes