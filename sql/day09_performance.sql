-- =============================================================================
-- Day 09 — Performance Optimization, Query Profiling & Cost Monitoring
-- Worksheet: retail / e-commerce lakehouse cohort
-- Role: ACCOUNTADMIN (warehouse ALTER + query history)
-- Warehouse: LEARN_WH
--
-- Deliverable:
--   1. A deliberately slow query, profiled for the most expensive operator
--   2. Result-cache hit vs miss on identical SQL
--   3. A large sort that spills on XSMALL, then the same query on SMALL
--   4. On-the-fly warehouse resize (no downtime)
--
-- Snowsight: paste this worksheet, set role ACCOUNTADMIN + warehouse LEARN_WH,
-- Run All. Then open Monitoring → Query History → day09_spill_xsmall
-- (the CTAS ... ORDER BY) → Query Profile. Screenshot that graph as
-- screenshots/day09_query_profile.png.
--
-- Improvements over the raw lab steps:
--   * QUERY_TAG on every experiment so profiles are findable later
--   * Spill test is CTAS ... ORDER BY, not SELECT * to the client (SF10
--     LINEITEM is 59.9M rows). A window-function sort on this trial did
--     not spill; the wide-row CTAS sort did (~2.59 GB local).
--   * Operator stats are also pulled with GET_QUERY_OPERATOR_STATS so the
--     diagnosis is reproducible without Snowsight
--   * Warehouse is always reset to XSMALL at the end to protect trial credits
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE LEARN_WH;
USE DATABASE RETAIL_LAKEHOUSE;
USE SCHEMA BRONZE;

ALTER WAREHOUSE LEARN_WH SET WAREHOUSE_SIZE = 'XSMALL';


-- -----------------------------------------------------------------------------
-- 0. Three caches (read this before looking at any profile)
--
-- Result cache (Cloud Services, ~24 hours after last use, max 31 days):
--   Returns the exact previous result set. Requires identical SQL text,
--   unchanged underlying data, no non-deterministic functions
--   (CURRENT_TIMESTAMP, RANDOM, ...). Bytes scanned = 0 on a hit.
--
-- Metadata cache (Cloud Services):
--   Micro-partition stats (min/max, null counts, row counts). Powers
--   pruning and lets COUNT(*) / MIN / MAX skip the warehouse entirely
--   on some queries.
--
-- Warehouse cache (local SSD on the running warehouse):
--   Data previously read from remote storage. Survives while the
--   warehouse stays resumed; AUTO_SUSPEND flushes it. Helps repeat
--   scans of the same micro-partitions, not identical SQL.
-- -----------------------------------------------------------------------------


-- =============================================================================
-- 1. Profile a slow query
--    Unfiltered 3-way TPC-H join + ORDER BY on a string column.
--    Most expensive node is typically Sort (or Join) — confirm in the profile.
-- =============================================================================

ALTER SESSION SET USE_CACHED_RESULT = FALSE;
ALTER SESSION SET QUERY_TAG = 'day09_slow_unfiltered_join';

SELECT
    l.l_orderkey,
    o.o_orderdate,
    c.c_name,
    l.l_extendedprice,
    l.l_discount,
    l.l_comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM AS l
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
    ON l.l_orderkey = o.o_orderkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
    ON o.o_custkey = c.c_custkey
ORDER BY l.l_comment
LIMIT 1000;

SELECT LAST_QUERY_ID() AS slow_query_id;

SELECT
    operator_id,
    parent_operators,
    operator_type,
    operator_statistics,
    execution_time_breakdown
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
ORDER BY operator_id;


-- =============================================================================
-- 2. Hit the result cache
--    Run the exact same SQL twice. The second run should show
--    BYTES_SCANNED = 0 and a much smaller EXECUTION_TIME.
--    Cache only applies to identical SQL text over unchanged data.
-- =============================================================================

ALTER SESSION SET USE_CACHED_RESULT = TRUE;
ALTER SESSION SET QUERY_TAG = 'day09_result_cache_miss';

SELECT COUNT(*) AS filled_order_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
WHERE o_orderstatus = 'F';

ALTER SESSION SET QUERY_TAG = 'day09_result_cache_hit';

-- Identical SQL text on purpose — do not edit whitespace or comments here.
SELECT COUNT(*) AS filled_order_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
WHERE o_orderstatus = 'F';

SELECT
    query_id,
    query_tag,
    execution_status,
    total_elapsed_time,
    execution_time,
    compilation_time,
    bytes_scanned,
    rows_produced,
    warehouse_size
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_tag IN ('day09_result_cache_miss', 'day09_result_cache_hit')
ORDER BY start_time;


-- =============================================================================
-- 3. Make a query spill (XSMALL), then compare on SMALL
--    A window function over SF10.LINEITEM often fits in XS memory.
--    CTAS ... ORDER BY the wide row (VARCHAR comment + shipinstruct)
--    forces a full sort and is what actually spilled on this trial:
--    Sort node, bytes_spilled_local_storage ~ 2.59 GB on XSMALL.
--    Suspend first so the warehouse SSD cache does not hide the scan.
-- =============================================================================

ALTER WAREHOUSE LEARN_WH SUSPEND;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;
ALTER SESSION SET QUERY_TAG = 'day09_spill_xsmall';

CREATE OR REPLACE TRANSIENT TABLE RETAIL_LAKEHOUSE.BRONZE.DAY09_SPILL_SINK AS
SELECT
    l_orderkey, l_partkey, l_suppkey, l_linenumber,
    l_quantity, l_extendedprice, l_discount, l_tax,
    l_returnflag, l_linestatus,
    l_shipdate, l_commitdate, l_receiptdate,
    l_shipinstruct, l_shipmode, l_comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM
ORDER BY l_comment, l_shipinstruct, l_extendedprice, l_orderkey;

SELECT
    operator_id,
    operator_type,
    operator_statistics,
    execution_time_breakdown
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
ORDER BY operator_id;


-- =============================================================================
-- 4. Resize on the fly — any-time, no-downtime
--    ALTER WAREHOUSE ... SET WAREHOUSE_SIZE takes effect for subsequent
--    queries (in-flight queries finish on the old size).
-- =============================================================================

ALTER WAREHOUSE LEARN_WH SET WAREHOUSE_SIZE = 'SMALL';
ALTER WAREHOUSE LEARN_WH SUSPEND;
ALTER SESSION SET QUERY_TAG = 'day09_spill_small';

CREATE OR REPLACE TRANSIENT TABLE RETAIL_LAKEHOUSE.BRONZE.DAY09_SPILL_SINK AS
SELECT
    l_orderkey, l_partkey, l_suppkey, l_linenumber,
    l_quantity, l_extendedprice, l_discount, l_tax,
    l_returnflag, l_linestatus,
    l_shipdate, l_commitdate, l_receiptdate,
    l_shipinstruct, l_shipmode, l_comment
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM
ORDER BY l_comment, l_shipinstruct, l_extendedprice, l_orderkey;

SELECT
    operator_id,
    operator_type,
    operator_statistics,
    execution_time_breakdown
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
ORDER BY operator_id;

DROP TABLE IF EXISTS RETAIL_LAKEHOUSE.BRONZE.DAY09_SPILL_SINK;

-- Always put the trial warehouse back to XSMALL.
ALTER WAREHOUSE LEARN_WH SET WAREHOUSE_SIZE = 'XSMALL';

SELECT
    query_id,
    query_tag,
    warehouse_size,
    total_elapsed_time,
    execution_time,
    bytes_scanned,
    rows_produced
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_tag IN ('day09_spill_xsmall', 'day09_spill_small')
ORDER BY start_time;


-- =============================================================================
-- 5. Multi-cluster scaling policies (Standard vs Economy)
--
-- Standard: starts a new cluster as soon as a query is queued.
-- Economy:  keeps running clusters fully loaded and only starts a new
--           cluster when Snowflake estimates it can keep it busy for
--           at least ~6 minutes. Economy saves credits; Standard
--           favours latency.
--
-- LEARN_WH stays single-cluster (MAX_CLUSTER_COUNT = 1) on this trial.
-- The ALTER below is the documented syntax; it is a no-op on a
-- single-cluster warehouse besides recording the policy.
-- =============================================================================

ALTER WAREHOUSE LEARN_WH SET SCALING_POLICY = 'STANDARD';

SHOW WAREHOUSES LIKE 'LEARN_WH';


-- =============================================================================
-- 6. Query Acceleration Service vs Search Optimization (when, not now)
--
-- Query Acceleration Service (QAS):
--   Offloads portions of a scan-heavy / filter-heavy query to
--   serverless compute. Helps unpredictable, large-scan queries.
--   Enable with WAREHOUSE parameter ENABLE_QUERY_ACCELERATION = TRUE.
--   Skip on this trial — extra credits for a lab we can already
--   profile with warehouse size.
--
-- Search Optimization Service:
--   Maintains a search access path on a table for point lookups
--   (equality / IN / VARIANT paths). Helps SELECT ... WHERE id = ?.
--   Does NOT help large sorts, aggregations, or this TPC-H join.
--   ALTER TABLE ... ADD SEARCH OPTIMIZATION is a background credit
--   consumer — do not enable it on sample data.
-- =============================================================================


-- =============================================================================
-- 7. Cost review (warehouse credits for the program so far)
--    Admin → Cost Management is the UI view of the same meters.
--    INFORMATION_SCHEMA is current; ACCOUNT_USAGE lags up to ~45 min.
-- =============================================================================

ALTER SESSION SET QUERY_TAG = 'day09_cost_review';

SELECT
    warehouse_name,
    SUM(credits_used) AS credits_used,
    MIN(start_time) AS first_interval,
    MAX(end_time) AS last_interval
FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
    DATE_RANGE_START => DATEADD('day', -20, CURRENT_TIMESTAMP())
))
GROUP BY warehouse_name
ORDER BY credits_used DESC;

SELECT
    DATE_TRUNC('day', start_time) AS usage_day,
    warehouse_name,
    SUM(credits_used) AS credits_used
FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
    DATE_RANGE_START => DATEADD('day', -20, CURRENT_TIMESTAMP())
))
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


-- =============================================================================
-- 8. Slowest pipeline runs (Day 5 Dynamic Tables / Day 7 Task DAG)
--    Used as source material for docs/day09_performance_diagnosis.md
-- =============================================================================

ALTER SESSION SET QUERY_TAG = 'day09_pipeline_history';

SELECT
    query_id,
    LEFT(query_text, 180) AS query_text_preview,
    user_name,
    warehouse_name,
    warehouse_size,
    total_elapsed_time,
    execution_time,
    bytes_scanned,
    rows_produced,
    start_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_WAREHOUSE(
    WAREHOUSE_NAME => 'LEARN_WH',
    RESULT_LIMIT => 100
))
WHERE query_type NOT IN ('SHOW', 'DESCRIBE', 'USE', 'ALTER_SESSION', 'ALTER_WAREHOUSE')
  AND (
        query_text ILIKE '%DYNAMIC TABLE%'
     OR query_text ILIKE '%PRODUCTS_DT%'
     OR query_text ILIKE '%PRODUCT_SUMMARY%'
     OR query_text ILIKE '%DAY07%'
     OR query_text ILIKE '%CATEGORY_SUMMARY%'
     OR query_text ILIKE '%SYNC_PRODUCTS%'
     OR query_tag ILIKE 'day0%'
  )
ORDER BY total_elapsed_time DESC NULLS LAST
LIMIT 20;

ALTER SESSION UNSET QUERY_TAG;
