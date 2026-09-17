-- ============================================================
-- DAY 5 — DYNAMIC TABLES
-- Declarative Incremental Data Pipeline
-- ============================================================
--
-- Architecture:
--
--   BRONZE.PRODUCTS
--          |
--          v
--   SILVER.PRODUCTS_DT
--          |
--          v
--   GOLD.PRODUCT_SUMMARY_DT
--
-- Concepts demonstrated:
--   1. Dynamic Tables
--   2. Declarative data transformation
--   3. TARGET_LAG
--   4. Incremental refresh
--   5. Layered Bronze → Silver → Gold pipeline
--   6. Dynamic Table refresh history
--
-- Dynamic Tables differ from Streams + Tasks:
--
--   Streams + Tasks:
--       Developer defines HOW and WHEN changes are processed.
--
--   Dynamic Tables:
--       Developer defines WHAT the desired result should be.
--       Snowflake manages the refresh process based on TARGET_LAG.
--
-- ============================================================


-- ============================================================
-- STEP 1 — Execution Context
-- ============================================================

USE ROLE ACCOUNTADMIN;

USE DATABASE retail_lakehouse;

USE SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 2 — Verify Bronze Source
-- ============================================================
-- Bronze is the source for the Dynamic Table pipeline.

SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.bronze.products
ORDER BY product_id;


-- ============================================================
-- STEP 3 — Create Silver Dynamic Table
-- ============================================================
-- This Dynamic Table creates the Silver layer from Bronze.
--
-- TARGET_LAG = '5 minutes'
--
-- This specifies the freshness target for the Dynamic Table.
-- It is NOT an exact five-minute execution schedule.
--
-- Snowflake determines when the Dynamic Table needs to refresh
-- in order to maintain the configured freshness target.
-- ============================================================

CREATE OR REPLACE DYNAMIC TABLE retail_lakehouse.silver.products_dt
    TARGET_LAG = '5 minutes'
    WAREHOUSE = learn_wh
AS
SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.bronze.products;


-- ============================================================
-- STEP 4 — Verify Silver Dynamic Table
-- ============================================================
-- The Dynamic Table should contain the current Bronze data
-- after initialization.

SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.silver.products_dt
ORDER BY product_id;


-- ============================================================
-- STEP 5 — Create Gold Dynamic Table
-- ============================================================
-- Gold is built declaratively from the Silver Dynamic Table.
--
-- The query defines the desired result:
--
--   category
--   product count
--   total product value
--
-- Snowflake manages the refresh of this Dynamic Table.
-- ============================================================

CREATE OR REPLACE DYNAMIC TABLE retail_lakehouse.gold.product_summary_dt
    TARGET_LAG = '5 minutes'
    WAREHOUSE = learn_wh
AS
SELECT
    category,
    COUNT(*) AS product_count,
    SUM(price) AS total_value
FROM retail_lakehouse.silver.products_dt
GROUP BY category;


-- ============================================================
-- STEP 6 — Verify Gold Dynamic Table
-- ============================================================

SELECT
    category,
    product_count,
    total_value
FROM retail_lakehouse.gold.product_summary_dt
ORDER BY category;


-- ============================================================
-- STEP 7 — Inspect Dynamic Table Configuration
-- ============================================================
-- Check both Dynamic Tables.
--
-- Important columns to inspect:
--
--   TARGET_LAG
--   REFRESH_MODE
--   WAREHOUSE
--   SCHEDULING_STATE
--   DATA_TIMESTAMP
--
-- Expected:
--
--   TARGET_LAG       = 5 minutes
--   REFRESH_MODE     = INCREMENTAL
--   SCHEDULING_STATE = ACTIVE
-- ============================================================

SHOW DYNAMIC TABLES IN SCHEMA retail_lakehouse.silver;

SHOW DYNAMIC TABLES IN SCHEMA retail_lakehouse.gold;


-- ============================================================
-- STEP 8 — Generate a Source Data Change
-- ============================================================
-- Change the price of an existing Bronze product.
--
-- This demonstrates that Dynamic Tables can propagate source
-- changes through the declarative pipeline.
-- ============================================================

UPDATE retail_lakehouse.bronze.products
SET price = 2800
WHERE product_id = 104;


-- ============================================================
-- STEP 9 — Verify the Bronze Change
-- ============================================================
-- Confirm that the source table now contains the new price.

SELECT
    product_id,
    product_name,
    price
FROM retail_lakehouse.bronze.products
WHERE product_id = 104;


-- ============================================================
-- STEP 10 — Verify Silver After Refresh
-- ============================================================
-- Once the Dynamic Table refreshes, Silver should reflect
-- the updated Bronze value.
--
-- Because TARGET_LAG is a freshness target rather than an
-- immediate-refresh command, the result may not change
-- immediately after the Bronze UPDATE.
-- ============================================================

SELECT
    product_id,
    product_name,
    price
FROM retail_lakehouse.silver.products_dt
WHERE product_id = 104;


-- ============================================================
-- STEP 11 — Inspect Silver Dynamic Table Status
-- ============================================================
-- This allows us to verify whether the Dynamic Table is:
--
--   ACTIVE
--   INCREMENTAL
--   configured with a 5-minute target lag
--   using LEARN_WH
--
-- DATA_TIMESTAMP indicates the timestamp of the data currently
-- materialized by the Dynamic Table.
-- ============================================================

SHOW DYNAMIC TABLES IN SCHEMA retail_lakehouse.silver;


-- ============================================================
-- STEP 12 — Inspect Refresh History
-- ============================================================
-- Refresh history provides details about Dynamic Table
-- refresh attempts.
--
-- Useful fields include:
--
--   STATE
--   STATE_MESSAGE
--   REFRESH_ACTION
--   REFRESH_TRIGGER
--   DATA_TIMESTAMP
--   REFRESH_START_TIME
--   REFRESH_END_TIME
--
-- This is useful for troubleshooting refresh behavior.
-- ============================================================

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'RETAIL_LAKEHOUSE.SILVER.PRODUCTS_DT'
    )
)
ORDER BY REFRESH_START_TIME DESC
LIMIT 10;


-- ============================================================
-- STEP 13 — Verify Silver After Refresh
-- ============================================================
-- After the refresh has completed, the updated Keyboard
-- price should be visible here.

SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.silver.products_dt
WHERE product_id = 104;


-- ============================================================
-- STEP 14 — Verify Gold After Refresh
-- ============================================================
-- The price change should propagate into the Gold aggregation.
--
-- Electronics total should increase by ₹100:
--
--   Previous total = ₹86,900
--   Updated total  = ₹87,000
-- ============================================================

SELECT
    category,
    product_count,
    total_value
FROM retail_lakehouse.gold.product_summary_dt
ORDER BY category;


-- ============================================================
-- STEP 15 — Final Dynamic Table Status
-- ============================================================
-- Final inspection of the Silver Dynamic Table.

SHOW DYNAMIC TABLES IN SCHEMA retail_lakehouse.silver;


-- Final inspection of the Gold Dynamic Table.

SHOW DYNAMIC TABLES IN SCHEMA retail_lakehouse.gold;


-- ============================================================
-- END OF DAY 5 — DYNAMIC TABLES
-- ============================================================