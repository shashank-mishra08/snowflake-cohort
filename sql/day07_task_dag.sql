-- ============================================================
-- Day 7 — Orchestration: Task DAGs & Serverless Tasks
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_LAKEHOUSE;

-- ============================================================
-- 1. Create a Bronze landing table for the Day 7 DAG
-- ============================================================

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.BRONZE.ORDERS_LANDING (
    ORDER_ID INTEGER,
    CUSTOMER_ID INTEGER,
    PRODUCT_ID INTEGER,
    QUANTITY INTEGER,
    ORDER_STATUS STRING,
    ORDER_TS TIMESTAMP_NTZ
);

INSERT INTO RETAIL_LAKEHOUSE.BRONZE.ORDERS_LANDING
    (
        ORDER_ID,
        CUSTOMER_ID,
        PRODUCT_ID,
        QUANTITY,
        ORDER_STATUS,
        ORDER_TS
    )
VALUES
    (2001, 601, 101, 1, 'COMPLETED', '2026-09-17 10:00:00'),
    (2002, 602, 102, 2, 'COMPLETED', '2026-09-17 10:05:00'),
    (2003, 603, 103, 1, 'PENDING',   '2026-09-17 10:10:00');


-- ============================================================
-- 2. Bronze → Silver → Gold Task DAG
--
-- All tasks are created in the SILVER schema because Snowflake
-- requires predecessor tasks in the same schema.
-- ============================================================

-- ------------------------------------------------------------
-- Bronze ingestion task
-- ------------------------------------------------------------

CREATE OR REPLACE TASK RETAIL_LAKEHOUSE.SILVER.DAY07_BRONZE_INGESTION_TASK
    WAREHOUSE = LEARN_WH
AS
INSERT INTO RETAIL_LAKEHOUSE.BRONZE.ORDERS
    (
        ORDER_ID,
        CUSTOMER_ID,
        PRODUCT_ID,
        QUANTITY,
        ORDER_STATUS,
        ORDER_TS
    )
SELECT
    l.ORDER_ID,
    l.CUSTOMER_ID,
    l.PRODUCT_ID,
    l.QUANTITY,
    l.ORDER_STATUS,
    l.ORDER_TS
FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS_LANDING AS l
WHERE NOT EXISTS (
    SELECT 1
    FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS AS b
    WHERE b.ORDER_ID = l.ORDER_ID
);


-- ------------------------------------------------------------
-- Silver merge task
-- Runs AFTER Bronze ingestion
-- ------------------------------------------------------------

CREATE OR REPLACE TASK RETAIL_LAKEHOUSE.SILVER.DAY07_SILVER_MERGE_TASK
    WAREHOUSE = LEARN_WH
    AFTER RETAIL_LAKEHOUSE.SILVER.DAY07_BRONZE_INGESTION_TASK
AS
MERGE INTO RETAIL_LAKEHOUSE.SILVER.ORDERS AS tgt
USING (
    SELECT
        ORDER_ID,
        CUSTOMER_ID,
        PRODUCT_ID,
        COALESCE(QUANTITY, 0)::INTEGER AS QUANTITY,
        UPPER(TRIM(ORDER_STATUS)) AS ORDER_STATUS,
        ORDER_TS
    FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ORDER_ID
        ORDER BY ORDER_TS DESC
    ) = 1
) AS src
ON tgt.ORDER_ID = src.ORDER_ID

WHEN MATCHED THEN UPDATE SET
    CUSTOMER_ID = src.CUSTOMER_ID,
    PRODUCT_ID = src.PRODUCT_ID,
    QUANTITY = src.QUANTITY,
    ORDER_STATUS = src.ORDER_STATUS,
    ORDER_TS = src.ORDER_TS

WHEN NOT MATCHED THEN INSERT (
    ORDER_ID,
    CUSTOMER_ID,
    PRODUCT_ID,
    QUANTITY,
    ORDER_STATUS,
    ORDER_TS
)
VALUES (
    src.ORDER_ID,
    src.CUSTOMER_ID,
    src.PRODUCT_ID,
    src.QUANTITY,
    src.ORDER_STATUS,
    src.ORDER_TS
);


-- ------------------------------------------------------------
-- Gold refresh task
-- Runs AFTER Silver merge
-- ------------------------------------------------------------

CREATE OR REPLACE TASK RETAIL_LAKEHOUSE.SILVER.DAY07_GOLD_REFRESH_TASK
    WAREHOUSE = LEARN_WH
    AFTER RETAIL_LAKEHOUSE.SILVER.DAY07_SILVER_MERGE_TASK
AS
INSERT OVERWRITE INTO RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY
SELECT
    p.CATEGORY,
    SUM(o.QUANTITY * p.PRICE) AS TOTAL_REVENUE,
    COUNT(*) AS ORDER_COUNT,
    APPROX_COUNT_DISTINCT(o.CUSTOMER_ID) AS UNIQUE_CUSTOMERS
FROM RETAIL_LAKEHOUSE.SILVER.ORDERS AS o
INNER JOIN RETAIL_LAKEHOUSE.BRONZE.PRODUCTS AS p
    ON o.PRODUCT_ID = p.PRODUCT_ID
WHERE o.ORDER_STATUS <> 'CANCELLED'
GROUP BY p.CATEGORY;


-- ============================================================
-- 3. Inspect the Task DAG
-- ============================================================

SHOW TASKS IN DATABASE RETAIL_LAKEHOUSE;


-- ============================================================
-- 4. Verify Task History
-- ============================================================

SELECT
    NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME IN (
    'DAY07_BRONZE_INGESTION_TASK',
    'DAY07_SILVER_MERGE_TASK',
    'DAY07_GOLD_REFRESH_TASK'
)
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;


-- ============================================================
-- 5. Run the complete DAG manually
--
-- Child tasks must be resumed before executing the root.
-- ============================================================

ALTER TASK RETAIL_LAKEHOUSE.SILVER.DAY07_GOLD_REFRESH_TASK RESUME;

ALTER TASK RETAIL_LAKEHOUSE.SILVER.DAY07_SILVER_MERGE_TASK RESUME;

EXECUTE TASK RETAIL_LAKEHOUSE.SILVER.DAY07_BRONZE_INGESTION_TASK;


-- ============================================================
-- 6. Verify the complete DAG execution
-- ============================================================

SELECT
    NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME IN (
    'DAY07_BRONZE_INGESTION_TASK',
    'DAY07_SILVER_MERGE_TASK',
    'DAY07_GOLD_REFRESH_TASK'
)
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;


-- ============================================================
-- 7. Serverless Task
--
-- No WAREHOUSE clause = Snowflake-managed/serverless compute.
-- This task is separate from the main DAG so the working DAG
-- remains intact.
-- ============================================================

GRANT EXECUTE MANAGED TASK
ON ACCOUNT
TO ROLE ACCOUNTADMIN;


CREATE OR REPLACE TASK
    RETAIL_LAKEHOUSE.SILVER.DAY07_BRONZE_INGESTION_SERVERLESS_TASK
AS
INSERT INTO RETAIL_LAKEHOUSE.BRONZE.ORDERS
    (
        ORDER_ID,
        CUSTOMER_ID,
        PRODUCT_ID,
        QUANTITY,
        ORDER_STATUS,
        ORDER_TS
    )
SELECT
    l.ORDER_ID,
    l.CUSTOMER_ID,
    l.PRODUCT_ID,
    l.QUANTITY,
    l.ORDER_STATUS,
    l.ORDER_TS
FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS_LANDING AS l
WHERE NOT EXISTS (
    SELECT 1
    FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS AS b
    WHERE b.ORDER_ID = l.ORDER_ID
);


-- ============================================================
-- 8. Verify the Serverless Task
-- ============================================================

SHOW TASKS IN DATABASE RETAIL_LAKEHOUSE;


-- ============================================================
-- 9. Execute the Serverless Task
-- ============================================================

EXECUTE TASK
    RETAIL_LAKEHOUSE.SILVER.DAY07_BRONZE_INGESTION_SERVERLESS_TASK;


-- ============================================================
-- 10. Verify Serverless Task History
-- ============================================================

SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'DAY07_BRONZE_INGESTION_SERVERLESS_TASK'
ORDER BY SCHEDULED_TIME DESC
LIMIT 1;


-- ============================================================
-- 11. Create DBT target schema
-- ============================================================

CREATE SCHEMA IF NOT EXISTS RETAIL_LAKEHOUSE.DBT;


-- ============================================================
-- 12. Final DAG verification
-- ============================================================

SHOW TASKS IN DATABASE RETAIL_LAKEHOUSE;

SELECT
    NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME IN (
    'DAY07_BRONZE_INGESTION_TASK',
    'DAY07_SILVER_MERGE_TASK',
    'DAY07_GOLD_REFRESH_TASK',
    'DAY07_BRONZE_INGESTION_SERVERLESS_TASK'
)
ORDER BY SCHEDULED_TIME DESC
LIMIT 20;