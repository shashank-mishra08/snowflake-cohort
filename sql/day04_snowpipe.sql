-- ============================================================
-- Day 4: Snowpipe — Continuous Ingestion
-- ============================================================
-- Goal:
-- Demonstrate Snowpipe using an internal stage and a separate
-- folder for incoming files.
--
-- Important:
-- products.csv was already loaded into PRODUCTS using COPY INTO.
-- Snowpipe will use a separate /pipe/ folder so the same file
-- is not loaded twice.
-- ============================================================


-- ============================================================
-- STEP 1 — Set execution context
-- ============================================================

USE ROLE ACCOUNTADMIN;

USE DATABASE retail_lakehouse;

USE SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 2 — Verify the existing Bronze table and file format
-- ============================================================

DESC TABLE retail_lakehouse.bronze.products;

SHOW FILE FORMATS IN SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 3 — Verify the internal stage
-- ============================================================

SHOW STAGES IN SCHEMA retail_lakehouse.bronze;

LIST @retail_lakehouse.bronze.bronze_stage;


-- ============================================================
-- STEP 4 — Create the Snowpipe
-- ============================================================
-- Snowpipe defines the COPY INTO statement that will be used
-- for continuous ingestion.
--
-- The /pipe/ path is intentionally separate from the existing
-- products.csv file at the stage root.
-- ============================================================

CREATE OR REPLACE PIPE retail_lakehouse.bronze.bronze_pipe
AS
COPY INTO retail_lakehouse.bronze.products
FROM @retail_lakehouse.bronze.bronze_stage/pipe/
FILE_FORMAT = (
    FORMAT_NAME = retail_lakehouse.bronze.csv_ff
);


-- ============================================================
-- STEP 5 — Inspect the Snowpipe definition
-- ============================================================

SHOW PIPES IN SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 6 — Check Snowpipe status
-- ============================================================

SELECT SYSTEM$PIPE_STATUS(
    'RETAIL_LAKEHOUSE.BRONZE.BRONZE_PIPE'
);


-- ============================================================
-- STEP 7 — Upload a NEW CSV file into the /pipe/ folder
-- ============================================================
-- Use Snowsight to upload a second CSV file into:
--
-- @retail_lakehouse.bronze.bronze_stage/pipe/
--
-- Example:
-- products_pipe.csv
--
-- Example contents:
--
-- product_id,product_name,category,price
-- 104,Keyboard,Electronics,2500
-- 105,Chair,Furniture,8000
--
-- Do NOT upload the original products.csv again.
-- ============================================================


-- ============================================================
-- STEP 8 — Verify the new file exists in the pipe folder
-- ============================================================

LIST @retail_lakehouse.bronze.bronze_stage/pipe/;


-- ============================================================
-- STEP 9 — Manually trigger Snowpipe file discovery
-- ============================================================
-- REFRESH tells Snowpipe to scan the stage path for files
-- that have not yet been loaded by the pipe.
--
-- In a cloud-storage production setup, event notifications
-- can trigger Snowpipe automatically.
-- ============================================================

ALTER PIPE retail_lakehouse.bronze.bronze_pipe
REFRESH;


-- ============================================================
-- STEP 10 — Check Snowpipe status again
-- ============================================================

SELECT SYSTEM$PIPE_STATUS(
    'RETAIL_LAKEHOUSE.BRONZE.BRONZE_PIPE'
);


-- ============================================================
-- STEP 11 — Verify the Bronze table
-- ============================================================

SELECT *
FROM retail_lakehouse.bronze.products
ORDER BY product_id;


-- ============================================================
-- STEP 12 — Verify Snowpipe load history
-- ============================================================

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME => 'RETAIL_LAKEHOUSE.BRONZE.PRODUCTS',
        START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
)
ORDER BY LAST_LOAD_TIME DESC;


-- ============================================================
-- STEP 13 — Understand AUTO_INGEST
-- ============================================================
-- For an external cloud stage, Snowpipe can be configured with
-- AUTO_INGEST = TRUE and cloud event notifications.
--
-- Example pattern only — do NOT execute without a configured
-- external stage + notification integration:
--
-- CREATE PIPE retail_lakehouse.bronze.external_bronze_pipe
-- AUTO_INGEST = TRUE
-- AS
-- COPY INTO retail_lakehouse.bronze.products
-- FROM @external_bronze_stage/pipe/
-- FILE_FORMAT = (
--     FORMAT_NAME = retail_lakehouse.bronze.csv_ff
-- );
--
-- This is the production-style event-driven Snowpipe pattern.
-- ============================================================


-- ============================================================
-- STEP 14 — Final verification
-- ============================================================

SELECT COUNT(*) AS total_products
FROM retail_lakehouse.bronze.products;

SHOW PIPES IN SCHEMA retail_lakehouse.bronze;