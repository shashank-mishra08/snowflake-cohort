-- ============================================================
-- Day 4: Batch Data Loading with COPY INTO
-- ============================================================
-- Objective:
-- Load a CSV file into a Bronze table using:
--   1. Internal stage
--   2. CSV file format
--   3. COPY INTO
--   4. Load-history based idempotency
--
-- Execution:
-- Run each numbered section one at a time and verify the
-- result before moving to the next section.
-- ============================================================


-- ============================================================
-- STEP 1: Set the execution context
-- ============================================================
-- We use ACCOUNTADMIN for this learning lab so that object
-- creation and access privileges do not distract from the
-- ingestion concepts being learned.

USE ROLE ACCOUNTADMIN;

USE DATABASE retail_lakehouse;

USE SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 2: Create an internal stage
-- ============================================================
-- An internal stage is Snowflake-managed storage where files
-- can be temporarily stored before being loaded into tables.
--
-- Our flow will be:
--
-- Local CSV → Internal Stage → COPY INTO → Bronze Table

CREATE STAGE IF NOT EXISTS retail_lakehouse.bronze.bronze_stage;


-- Verify that the stage exists
SHOW STAGES IN SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 3: Inspect the stage
-- ============================================================
-- LIST shows the files currently stored in the stage.
--
-- At this point the stage may be empty because we have not
-- uploaded our CSV yet.

LIST @retail_lakehouse.bronze.bronze_stage;


-- ============================================================
-- STEP 4: Create the Bronze products table
-- ============================================================
-- This table represents our Bronze layer.
--
-- The structure should match the CSV we will upload.
--
-- Example CSV:
--
-- product_id,product_name,category,price
-- 101,Laptop,Electronics,75000
-- 102,Mouse,Electronics,1200
-- 103,Desk,Furniture,15000
--
-- Bronze data is kept relatively close to the source format.

CREATE OR REPLACE TABLE retail_lakehouse.bronze.products (
    product_id INTEGER,
    product_name STRING,
    category STRING,
    price NUMBER(10,2)
);


-- Verify the table definition
DESC TABLE retail_lakehouse.bronze.products;


-- ============================================================
-- STEP 5: Create a CSV file format
-- ============================================================
-- A file format tells Snowflake how to interpret the staged
-- file.
--
-- TYPE = CSV
--   The source file is comma-separated.
--
-- SKIP_HEADER = 1
--   The first row contains column names and should not be
--   inserted as data.

CREATE FILE FORMAT IF NOT EXISTS retail_lakehouse.bronze.csv_ff
    TYPE = CSV
    SKIP_HEADER = 1;


-- Verify the file format
SHOW FILE FORMATS IN SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 6: Upload the CSV file
-- ============================================================
-- Upload a small synthetic products CSV to the internal stage.
--
-- You can use either:
--
--   A) Snowsight upload interface
--   B) Snowflake CLI PUT command
--
-- Example Snowflake CLI command:
--
-- PUT file:///path/to/products.csv
--     @retail_lakehouse.bronze.bronze_stage;
--
-- Do NOT execute the example command until the local file
-- path has been replaced with the actual path to your CSV.
--
-- Expected CSV structure:
--
-- product_id,product_name,category,price
-- 101,Laptop,Electronics,75000
-- 102,Mouse,Electronics,1200
-- 103,Desk,Furniture,15000


-- ============================================================
-- STEP 7: Verify the uploaded file
-- ============================================================
-- After uploading the CSV, run LIST again.
--
-- We should now see the uploaded file in the stage.

LIST @retail_lakehouse.bronze.bronze_stage;


-- ============================================================
-- STEP 8: Load the staged file with COPY INTO
-- ============================================================
-- COPY INTO reads the file from the stage and inserts the
-- records into the Bronze PRODUCTS table.
--
-- Snowflake also records load metadata for files processed
-- through COPY INTO.

COPY INTO retail_lakehouse.bronze.products
FROM @retail_lakehouse.bronze.bronze_stage
FILE_FORMAT = (
    FORMAT_NAME = retail_lakehouse.bronze.csv_ff
);


-- ============================================================
-- STEP 9: Verify the loaded data
-- ============================================================
-- Confirm that the CSV records are now present in Bronze.

SELECT *
FROM retail_lakehouse.bronze.products
ORDER BY product_id;


-- ============================================================
-- STEP 10: Run COPY INTO a second time
-- ============================================================
-- Run the exact same COPY INTO statement again.
--
-- Snowflake should recognize that the same file has already
-- been loaded and should not insert duplicate rows.
--
-- This demonstrates idempotent/incremental file loading.

COPY INTO retail_lakehouse.bronze.products
FROM @retail_lakehouse.bronze.bronze_stage
FILE_FORMAT = (
    FORMAT_NAME = retail_lakehouse.bronze.csv_ff
);


SELECT COUNT(*) AS row_count
FROM retail_lakehouse.bronze.products;

-- ============================================================
-- STEP 11: Verify idempotency
-- ============================================================
-- The table should still contain the original number of rows.
--
-- No duplicate records should have appeared.

SELECT *
FROM retail_lakehouse.bronze.products
ORDER BY product_id;


-- ============================================================
-- STEP 12: Inspect COPY INTO load history
-- ============================================================
-- Snowflake records information about files loaded into tables.
--
-- This helps explain why the second COPY INTO did not reload
-- the same file.

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME => 'RETAIL_LAKEHOUSE.BRONZE.PRODUCTS',
        START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
);


-- ============================================================
-- DAY 4 FILE 1 COMPLETE
-- ============================================================
-- We have demonstrated:
--
-- ✓ Internal stage
-- ✓ CSV file format
-- ✓ Bronze table
-- ✓ File upload
-- ✓ COPY INTO
-- ✓ Verification of loaded data
-- ✓ Idempotent repeated COPY INTO
-- ✓ COPY load history
--
-- Next file:
-- sql/day04_snowpipe.sql
-- ============================================================