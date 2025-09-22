# NYC Taxi Trip End to End Cloud Data Pipeline and Data Analysis Project

## Introduction
This NYC Taxi Trip Analytics project is an innovative end-to-end Data Engineering pipeline designed to transform urban mobility data into actionable business intelligence. The workflow begins by sourcing Yellow Taxi and Green Taxi data from NYC TLC, followed by storing raw data efficiently in AWS S3 buckets. The data is then meticulously transformed using dbt to ensure accuracy and completeness before being loaded into Snowflake for advanced analytics and querying. To orchestrate the entire process, Apache Airflow automates the data pipeline, while Looker Studio creates visually compelling dashboards that reveal urban movement patterns.

With its well-orchestrated cloud-native architecture, this project exemplifies modern data engineering practices by seamlessly integrating data ingestion, transformation, storage, and visualization into a unified solution. The pipeline processes millions of daily trips to uncover hidden insights about New York City's transportation dynamics, pricing optimization opportunities, and temporal-spatial demand patterns.

## Project Description

## Dataset Description
The TLC Trip Record Data is a comprehensive and publicly available dataset curated by the New York City Taxi and Limousine Commission. It contains detailed information for hundreds of millions of individual trips taken in Yellow Taxis, Green Taxis, and For-Hire Vehicles (FHVs) like those from Uber and Lyft. For each trip, the data typically includes precise timestamps for pickup and drop-off, the geographic locations (as taxi zone IDs or latitude/longitude coordinates), the trip distance and duration, the itemized fare and toll amounts, the number of passengers, and the method of payment. [Dataset](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)

## Technical Architecture:

* Data Storage: Raw trip data stored in AWS S3 buckets partitioned by month

* Data Warehouse: Snowflake for scalable data processing and analysis

* Transformation: dbt (Data Build Tool) for modular SQL transformations

* Orchestration: Airflow for workflow automation and monitoring

* Visualization: Looker Studio for interactive dashboards and analytics

### Key Features:

Data Processing Pipeline:

* Implemented incremental loading to handle monthly data updates

* Built slowly changing dimensions (SCD) for location and date data

* Created fact and dimension tables following star schema design

* Automated data quality checks and validation rules
