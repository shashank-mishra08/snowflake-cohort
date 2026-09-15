USE ROLE ACCOUNTADMIN;

GRANT USAGE ON SCHEMA retail_lakehouse.bronze TO ROLE data_engineer;
GRANT USAGE ON SCHEMA retail_lakehouse.bronze TO ROLE data_analyst;

CREATE OR REPLACE TABLE retail_lakehouse.bronze.customers (
    customer_id INTEGER,
    name STRING,
    email STRING,
    region STRING
);

INSERT INTO retail_lakehouse.bronze.customers
    (customer_id, name, email, region)
VALUES
    (1, 'Alice', 'alice@example.com', 'EAST'),
    (2, 'Bob', 'bob@example.com', 'WEST'),
    (3, 'Charlie', 'charlie@example.com', 'EAST'),
    (4, 'David', 'david@example.com', 'NORTH');


    CREATE OR REPLACE MASKING POLICY retail_lakehouse.bronze.mask_email
AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() = 'DATA_ENGINEER' THEN val
        ELSE '***MASKED***'
    END;



    ALTER TABLE retail_lakehouse.bronze.customers
MODIFY COLUMN email
SET MASKING POLICY retail_lakehouse.bronze.mask_email;


USE ROLE DATA_ENGINEER;

SELECT customer_id, name, email, region
FROM retail_lakehouse.bronze.customers;

USE ROLE DATA_ANALYST;

SELECT customer_id, name, email, region
FROM retail_lakehouse.bronze.customers;

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE ROW ACCESS POLICY retail_lakehouse.bronze.region_policy
AS (region STRING)
RETURNS BOOLEAN ->
    CURRENT_ROLE() = 'DATA_ENGINEER'
    OR region = 'EAST';

ALTER TABLE retail_lakehouse.bronze.customers
ADD ROW ACCESS POLICY retail_lakehouse.bronze.region_policy
ON (region);

SHOW ROW ACCESS POLICIES
IN SCHEMA retail_lakehouse.bronze;

DESC ROW ACCESS POLICY retail_lakehouse.bronze.region_policy;

USE ROLE DATA_ENGINEER;

SELECT COUNT(*) AS visible_rows
FROM retail_lakehouse.bronze.customers;


USE ROLE DATA_ANALYST;

SELECT COUNT(*) AS visible_rows
FROM retail_lakehouse.bronze.customers;


USE ROLE DATA_ANALYST;

SELECT customer_id, name, email, region
FROM retail_lakehouse.bronze.customers
ORDER BY customer_id;