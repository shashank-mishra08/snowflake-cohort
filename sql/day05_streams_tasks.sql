-- ============================================================
-- DAY 5 — STREAMS & TASKS
-- Change Data Capture + Automated Task Pipeline
-- ============================================================
--
-- Architecture:
--
--   BRONZE.PRODUCTS
--          |
--          v
--   PRODUCTS_STREAM
--          |
--          v
--   SYNC_PRODUCTS_TASK
--          |
--          v
--   SILVER.PRODUCTS
--          |
--          v
--   GOLD_REFRESH_TASK
--          |
--          v
--   GOLD.PRODUCT_SUMMARY
--
-- Concepts demonstrated:
--   1. Streams for Change Data Capture (CDC)
--   2. METADATA$ACTION and METADATA$ISUPDATE
--   3. MERGE-based CDC processing
--   4. SYSTEM$STREAM_HAS_DATA
--   5. Scheduled Tasks
--   6. Task dependency / DAG
--   7. Gold aggregation
--
-- NOTE:
-- The child task is created in the SILVER schema because
-- Snowflake requires tasks in a graph to have the appropriate
-- predecessor relationship within the same schema.
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
-- Bronze is the source table for our CDC pipeline.

SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.bronze.products
ORDER BY product_id;


-- ============================================================
-- STEP 3 — Create Stream
-- ============================================================
-- A Stream records changes made to the source table.
--
-- Important metadata columns:
--
--   METADATA$ACTION
--       INSERT or DELETE
--
--   METADATA$ISUPDATE
--       TRUE when the change is part of an UPDATE operation
--
-- An UPDATE is represented as:
--
--   DELETE old version + INSERT new version
--
-- with METADATA$ISUPDATE = TRUE.
-- ============================================================

CREATE OR REPLACE STREAM retail_lakehouse.bronze.products_stream
ON TABLE retail_lakehouse.bronze.products;


-- Verify Stream

SHOW STREAMS IN SCHEMA retail_lakehouse.bronze;


-- ============================================================
-- STEP 4 — Verify Stream Before Changes
-- ============================================================
-- Immediately after creation, the stream should contain
-- no changes because no changes have occurred since creation.

SELECT *
FROM retail_lakehouse.bronze.products_stream;


-- ============================================================
-- STEP 5 — Generate CDC Changes
-- ============================================================
-- These changes are intentionally made AFTER the Stream
-- has been created so the Stream can capture them.
--
-- 1. INSERT a new product
-- 2. UPDATE an existing product
-- 3. DELETE an existing product
-- ============================================================

INSERT INTO retail_lakehouse.bronze.products
    (product_id, product_name, category, price)
VALUES
    (106, 'Monitor', 'Electronics', 12000);


UPDATE retail_lakehouse.bronze.products
SET price = 2700
WHERE product_id = 104;


DELETE FROM retail_lakehouse.bronze.products
WHERE product_id = 105;


-- ============================================================
-- STEP 6 — Inspect CDC Records
-- ============================================================
-- Expected behavior:
--
-- INSERT:
--   METADATA$ACTION = INSERT
--   METADATA$ISUPDATE = FALSE
--
-- DELETE:
--   METADATA$ACTION = DELETE
--   METADATA$ISUPDATE = FALSE
--
-- UPDATE:
--   old row -> DELETE + TRUE
--   new row -> INSERT + TRUE
-- ============================================================

SELECT
    product_id,
    product_name,
    category,
    price,
    METADATA$ACTION,
    METADATA$ISUPDATE
FROM retail_lakehouse.bronze.products_stream
ORDER BY product_id, METADATA$ACTION;


-- ============================================================
-- STEP 7 — Create Silver Target Table
-- ============================================================
-- Silver receives the processed CDC changes from Bronze.

CREATE OR REPLACE TABLE retail_lakehouse.silver.products (
    product_id INTEGER,
    product_name STRING,
    category STRING,
    price NUMBER(10,2)
);


-- ============================================================
-- STEP 8 — Initialize Silver
-- ============================================================
-- The Stream only captures changes AFTER it was created.
-- Therefore, initialize Silver with the current Bronze state
-- before using the Stream for subsequent CDC processing.

INSERT INTO retail_lakehouse.silver.products
    (product_id, product_name, category, price)
SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.bronze.products;


-- Verify Silver

SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.silver.products
ORDER BY product_id;


-- ============================================================
-- STEP 9 — Create Root CDC Task
-- ============================================================
-- This Task:
--
--   1. Runs every 5 minutes.
--   2. Checks whether the Stream has data.
--   3. MERGEs CDC changes into Silver.
--
-- SYSTEM$STREAM_HAS_DATA() prevents the Task from executing
-- the MERGE when there are no new Stream records.
--
-- IMPORTANT:
-- For a genuine DELETE event, we only INSERT when the
-- source action is INSERT. This prevents deleted records
-- from being accidentally reinserted when no target row
-- exists.
-- ============================================================

CREATE OR REPLACE TASK retail_lakehouse.silver.sync_products_task
    WAREHOUSE = learn_wh
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA(
        'RETAIL_LAKEHOUSE.BRONZE.PRODUCTS_STREAM'
    )
AS
MERGE INTO retail_lakehouse.silver.products AS tgt

USING (
    SELECT
        product_id,
        product_name,
        category,
        price,
        METADATA$ACTION,
        METADATA$ISUPDATE
    FROM retail_lakehouse.bronze.products_stream

    -- Ignore the DELETE half of an UPDATE.
    -- The INSERT half contains the new version.
    WHERE NOT (
        METADATA$ACTION = 'DELETE'
        AND METADATA$ISUPDATE = TRUE
    )

) AS src

ON tgt.product_id = src.product_id


-- ------------------------------------------------------------
-- DELETE
-- ------------------------------------------------------------

WHEN MATCHED
     AND src.METADATA$ACTION = 'DELETE'
THEN DELETE


-- ------------------------------------------------------------
-- UPDATE
-- ------------------------------------------------------------

WHEN MATCHED
THEN UPDATE SET
    product_name = src.product_name,
    category = src.category,
    price = src.price


-- ------------------------------------------------------------
-- INSERT
-- ------------------------------------------------------------
-- Only INSERT when the Stream explicitly reports INSERT.
-- This prevents DELETE events from creating new rows.
-- ------------------------------------------------------------

WHEN NOT MATCHED
     AND src.METADATA$ACTION = 'INSERT'
THEN INSERT (
    product_id,
    product_name,
    category,
    price
)
VALUES (
    src.product_id,
    src.product_name,
    src.category,
    src.price
);


-- ============================================================
-- STEP 10 — Inspect Root Task
-- ============================================================

SHOW TASKS IN SCHEMA retail_lakehouse.silver;


-- ============================================================
-- STEP 11 — Resume Root Task
-- ============================================================
-- Newly created Tasks are suspended by default.
-- RESUME enables the scheduled Task.

ALTER TASK retail_lakehouse.silver.sync_products_task RESUME;


-- Verify Task State

SHOW TASKS IN SCHEMA retail_lakehouse.silver;


-- ============================================================
-- STEP 12 — Create Gold Target Table
-- ============================================================
-- Gold contains an aggregated business-level summary.

CREATE OR REPLACE TABLE retail_lakehouse.gold.product_summary (
    category STRING,
    product_count INTEGER,
    total_value NUMBER(18,2)
);


-- ============================================================
-- STEP 13 — Create Child Task
-- ============================================================
-- This Task runs AFTER the root CDC Task succeeds.
--
-- It rebuilds the Gold summary from the current Silver state.
--
-- IMPORTANT:
-- The child Task is intentionally stored in the SILVER schema.
-- Snowflake does not allow the predecessor relationship used
-- here when the predecessor Task is in a different schema.
-- ============================================================

CREATE OR REPLACE TASK retail_lakehouse.silver.gold_refresh_task
    WAREHOUSE = learn_wh
    AFTER retail_lakehouse.silver.sync_products_task
AS
INSERT OVERWRITE INTO retail_lakehouse.gold.product_summary
SELECT
    category,
    COUNT(*) AS product_count,
    SUM(price) AS total_value
FROM retail_lakehouse.silver.products
GROUP BY category;


-- ============================================================
-- STEP 14 — Inspect Task DAG
-- ============================================================
-- Expected:
--
--   SYNC_PRODUCTS_TASK
--          |
--          v
--   GOLD_REFRESH_TASK
--
-- GOLD_REFRESH_TASK should show
-- SYNC_PRODUCTS_TASK as its predecessor.
-- ============================================================

SHOW TASKS IN SCHEMA retail_lakehouse.silver;


-- ============================================================
-- STEP 15 — Resume Child Task
-- ============================================================
-- The child is part of the root Task graph.

ALTER TASK retail_lakehouse.silver.gold_refresh_task RESUME;


-- Resume root again to ensure the complete graph is active.

ALTER TASK retail_lakehouse.silver.sync_products_task RESUME;


-- Verify both Tasks

SHOW TASKS IN SCHEMA retail_lakehouse.silver;


-- ============================================================
-- STEP 16 — Execute Root Task for Lab Verification
-- ============================================================
-- EXECUTE TASK can be used on the root Task.
--
-- The child Task is triggered through the DAG dependency.
--
-- We do NOT execute the child directly.
-- ============================================================

EXECUTE TASK retail_lakehouse.silver.sync_products_task;


-- ============================================================
-- STEP 17 — Verify Stream Consumption
-- ============================================================
-- After the root Task successfully processes the Stream,
-- the Stream should have no remaining unconsumed changes.

SELECT SYSTEM$STREAM_HAS_DATA(
    'RETAIL_LAKEHOUSE.BRONZE.PRODUCTS_STREAM'
);


-- ============================================================
-- STEP 18 — Verify Silver
-- ============================================================
-- Silver should now reflect the CDC changes.

SELECT
    product_id,
    product_name,
    category,
    price
FROM retail_lakehouse.silver.products
ORDER BY product_id;


-- ============================================================
-- STEP 19 — Verify Gold
-- ============================================================
-- The child Task updates the Gold aggregation after
-- the root Task completes.

SELECT
    category,
    product_count,
    total_value
FROM retail_lakehouse.gold.product_summary
ORDER BY category;


-- ============================================================
-- STEP 20 — Inspect Root Task History
-- ============================================================

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME =>
            'RETAIL_LAKEHOUSE.SILVER.SYNC_PRODUCTS_TASK',
        SCHEDULED_TIME_RANGE_START =>
            DATEADD('hour', -2, CURRENT_TIMESTAMP())
    )
)
ORDER BY SCHEDULED_TIME DESC;


-- ============================================================
-- STEP 21 — Inspect Child Task History
-- ============================================================
-- This confirms that the downstream Task was triggered
-- through the Task DAG.

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME =>
            'RETAIL_LAKEHOUSE.SILVER.GOLD_REFRESH_TASK',
        SCHEDULED_TIME_RANGE_START =>
            DATEADD('hour', -2, CURRENT_TIMESTAMP())
    )
)
ORDER BY SCHEDULED_TIME DESC;


-- ============================================================
-- STEP 22 — Final Task State
-- ============================================================
-- Tasks consume compute credits when they execute.
-- Suspend them when the lab is finished so they do not
-- continue running unnecessarily.
-- ============================================================

ALTER TASK retail_lakehouse.silver.sync_products_task SUSPEND;

ALTER TASK retail_lakehouse.silver.gold_refresh_task SUSPEND;


-- ============================================================
-- STEP 23 — Final Verification
-- ============================================================

SHOW TASKS IN SCHEMA retail_lakehouse.silver;


-- ============================================================
-- END OF DAY 5 — STREAMS & TASKS
-- ============================================================