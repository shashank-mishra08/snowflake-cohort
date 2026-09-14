-- =============================================================================
-- Day 01 — Snowflake Architecture & Free Trial Setup
-- Worksheet: retail/e-commerce lakehouse cohort
-- Role: SYSADMIN (ACCOUNTADMIN also works on a trial)
--
-- Deliverable:
--   1. X-Small warehouse with AUTO_SUSPEND + AUTO_RESUME
--   2. First query against built-in TPC-H sample data
--   3. RETAIL_LAKEHOUSE database for the 15-day project
--
-- Snowsight: paste this worksheet, set role + warehouse, Run All.
-- Then open Monitoring → Query History and click the COUNT(*) query
-- to inspect Query Profile (compilation vs execution, partitions scanned).
-- =============================================================================

-- Session context
USE ROLE SYSADMIN;

-- -----------------------------------------------------------------------------
-- 1. Right-sized virtual warehouse
--    X-Small (1 credit/hour) is enough for TPC-H SF1 and this cohort's
--    synthetic files. AUTO_SUSPEND = 60 stops credit burn after 1 minute
--    idle. AUTO_RESUME = TRUE starts compute only when a statement arrives.
--    INITIALLY_SUSPENDED = TRUE avoids spinning compute at CREATE time.
-- -----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS RETAIL_WH
  WAREHOUSE_SIZE        = XSMALL
  AUTO_SUSPEND          = 60
  AUTO_RESUME           = TRUE
  INITIALLY_SUSPENDED   = TRUE
  COMMENT               = 'Day 1 warehouse for retail_lakehouse. XS + 60s auto-suspend to conserve trial credits.';

USE WAREHOUSE RETAIL_WH;

-- Confirm warehouse parameters (look for size, auto_suspend, auto_resume)
SHOW WAREHOUSES LIKE 'RETAIL_WH';

-- -----------------------------------------------------------------------------
-- 2. First query against built-in TPC-H sample data
--    SNOWFLAKE_SAMPLE_DATA is a share present in every account.
--    TPCH_SF1 is scale factor 1. TPC-H spec cardinality for ORDERS at SF=1
--    is 1,500,000 rows. This COUNT is the Day 1 verifier check.
-- -----------------------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'day01_tpch_orders_count';

SELECT COUNT(*) AS order_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;
-- Expected result: 1500000

-- Quick sanity peek (does not change the COUNT)
SELECT
    O_ORDERKEY,
    O_CUSTKEY,
    O_ORDERSTATUS,
    O_TOTALPRICE,
    O_ORDERDATE,
    O_ORDERPRIORITY
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
LIMIT 10;

-- TPC-H SF1 table sizes (for architecture notes / SnowPro Core)
SELECT 'ORDERS'   AS table_name, COUNT(*) AS row_count FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
UNION ALL
SELECT 'LINEITEM', COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
UNION ALL
SELECT 'CUSTOMER', COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
UNION ALL
SELECT 'PART',     COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART
UNION ALL
SELECT 'PARTSUPP', COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP
UNION ALL
SELECT 'SUPPLIER', COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER
UNION ALL
SELECT 'NATION',   COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION
UNION ALL
SELECT 'REGION',   COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
ORDER BY 1;

-- -----------------------------------------------------------------------------
-- 3. Project database for the 15-day retail/e-commerce lakehouse
--    Bronze / Silver / Gold schemas land later as tables are built.
--    Creating the three schemas now keeps object hierarchy consistent.
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RETAIL_LAKEHOUSE
  COMMENT = 'Retail/e-commerce lakehouse — 15-day Snowflake cohort. Bronze/Silver/Gold medallion.';

CREATE SCHEMA IF NOT EXISTS RETAIL_LAKEHOUSE.BRONZE
  COMMENT = 'Raw landing zone — files as ingested, no business transforms.';

CREATE SCHEMA IF NOT EXISTS RETAIL_LAKEHOUSE.SILVER
  COMMENT = 'Cleansed, typed, deduplicated tables.';

CREATE SCHEMA IF NOT EXISTS RETAIL_LAKEHOUSE.GOLD
  COMMENT = 'Business-ready marts for dashboards, ML, and Cortex agents.';

USE DATABASE RETAIL_LAKEHOUSE;

SHOW DATABASES LIKE 'RETAIL_LAKEHOUSE';
SHOW SCHEMAS IN DATABASE RETAIL_LAKEHOUSE;

-- -----------------------------------------------------------------------------
-- 4. Query History / Query Profile (do this in Snowsight UI)
--    Monitoring → Query History → filter QUERY_TAG = day01_tpch_orders_count
--    Open the COUNT(*) statement → Query Profile
--    You should see: compilation in Cloud Services, execution on RETAIL_WH,
--    storage scan of SNOWFLAKE_SAMPLE_DATA (shared, no local copy).
-- -----------------------------------------------------------------------------
SELECT
    QUERY_ID,
    QUERY_TEXT,
    WAREHOUSE_NAME,
    EXECUTION_STATUS,
    TOTAL_ELAPSED_TIME,
    COMPILATION_TIME,
    EXECUTION_TIME,
    BYTES_SCANNED,
    ROWS_PRODUCED,
    QUERY_TAG
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TAG = 'day01_tpch_orders_count'
ORDER BY START_TIME DESC
LIMIT 5;

-- Conserves remaining trial credits immediately after the worksheet
ALTER WAREHOUSE RETAIL_WH SUSPEND;
