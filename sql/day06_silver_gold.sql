-- ============================================================
-- Day 06: Data Modeling & Silver/Gold Transformations
-- Snowflake SQL implementation
-- ============================================================
--
-- Objectives:
--   1. Create a Bronze orders dataset for the lab
--   2. Build a cleaned and deduplicated Silver layer
--   3. Enrich orders through a product join
--   4. Demonstrate window functions
--   5. Build a Gold category-level aggregate
--
-- Architecture:
--   BRONZE.ORDERS
--        |
--        v
--   SILVER.ORDERS
--        |
--        +----> Product enrichment
--        |
--        v
--   GOLD.CATEGORY_SUMMARY
--
-- ============================================================


-- ------------------------------------------------------------
-- 1. Execution context
-- ------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_LAKEHOUSE;


-- ------------------------------------------------------------
-- 2. Create Bronze Orders lab dataset
-- ------------------------------------------------------------
--
-- The duplicate ORDER_ID = 1004 intentionally represents
-- multiple versions of the same order.
-- The latest ORDER_TS should be retained during deduplication.
--

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.BRONZE.ORDERS (
    ORDER_ID INTEGER,
    CUSTOMER_ID INTEGER,
    PRODUCT_ID INTEGER,
    QUANTITY INTEGER,
    ORDER_STATUS STRING,
    ORDER_TS TIMESTAMP_NTZ
);


INSERT INTO RETAIL_LAKEHOUSE.BRONZE.ORDERS
    (
        ORDER_ID,
        CUSTOMER_ID,
        PRODUCT_ID,
        QUANTITY,
        ORDER_STATUS,
        ORDER_TS
    )
VALUES
    (1001, 501, 101, 1, 'COMPLETED', '2026-09-15 10:00:00'),
    (1002, 502, 102, 2, 'COMPLETED', '2026-09-15 10:05:00'),
    (1003, 503, 103, 1, 'PENDING',   '2026-09-15 10:10:00'),
    (1004, 501, 104, 1, 'COMPLETED', '2026-09-15 10:15:00'),
    (1004, 501, 104, 2, 'COMPLETED', '2026-09-15 10:20:00'),
    (1005, 504, 107, 1, 'COMPLETED', '2026-09-15 10:25:00'),
    (1006, 505, 108, 1, 'CANCELLED', '2026-09-15 10:30:00'),
    (1007, 506, 101, 2, 'COMPLETED', '2026-09-15 10:35:00');


-- Verify Bronze source data.

SELECT
    *
FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS
ORDER BY ORDER_ID, ORDER_TS;


-- ------------------------------------------------------------
-- 3. Build Silver Orders
-- ------------------------------------------------------------
--
-- Transformations:
--   - Replace NULL quantities with 0
--   - Cast quantity to INTEGER
--   - Normalize order status
--   - Deduplicate by ORDER_ID
--   - Keep the latest version using QUALIFY + ROW_NUMBER
--

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.SILVER.ORDERS AS
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    PRODUCT_ID,
    COALESCE(QUANTITY, 0)::INTEGER AS QUANTITY,
    UPPER(TRIM(ORDER_STATUS)) AS ORDER_STATUS,
    ORDER_TS::TIMESTAMP_NTZ AS ORDER_TS
FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ORDER_ID
    ORDER BY ORDER_TS DESC
) = 1;


-- Verify Silver.

SELECT
    *
FROM RETAIL_LAKEHOUSE.SILVER.ORDERS
ORDER BY ORDER_ID;


-- ------------------------------------------------------------
-- 4. Enrich Silver Orders with Product data
-- ------------------------------------------------------------
--
-- Demonstrates a relational join between:
--   SILVER.ORDERS
--   BRONZE.PRODUCTS
--

SELECT
    o.ORDER_ID,
    o.CUSTOMER_ID,
    o.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.CATEGORY,
    o.QUANTITY,
    p.PRICE,
    o.QUANTITY * p.PRICE AS ORDER_VALUE,
    o.ORDER_STATUS,
    o.ORDER_TS
FROM RETAIL_LAKEHOUSE.SILVER.ORDERS AS o
INNER JOIN RETAIL_LAKEHOUSE.BRONZE.PRODUCTS AS p
    ON o.PRODUCT_ID = p.PRODUCT_ID
ORDER BY o.ORDER_ID;


-- ------------------------------------------------------------
-- 5. Window functions
-- ------------------------------------------------------------
--
-- Demonstrates:
--   - ROW_NUMBER() for customer order sequence
--   - SUM() OVER() for customer running revenue
--

SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_TS,
    ORDER_VALUE,

    ROW_NUMBER() OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_TS
    ) AS CUSTOMER_ORDER_NUMBER,

    SUM(ORDER_VALUE) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_TS
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CUSTOMER_RUNNING_TOTAL

FROM (
    SELECT
        o.ORDER_ID,
        o.CUSTOMER_ID,
        o.ORDER_TS,
        o.QUANTITY * p.PRICE AS ORDER_VALUE
    FROM RETAIL_LAKEHOUSE.SILVER.ORDERS AS o
    INNER JOIN RETAIL_LAKEHOUSE.BRONZE.PRODUCTS AS p
        ON o.PRODUCT_ID = p.PRODUCT_ID
)
ORDER BY CUSTOMER_ID, ORDER_TS;


-- ------------------------------------------------------------
-- 6. Build Gold Category Summary
-- ------------------------------------------------------------
--
-- Gold provides business-ready aggregated metrics:
--   - Total revenue
--   - Order count
--   - Approximate unique customer count
--
-- Cancelled orders are excluded from revenue metrics.
--

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY AS
SELECT
    p.CATEGORY,
    SUM(o.QUANTITY * p.PRICE) AS TOTAL_REVENUE,
    COUNT(*) AS ORDER_COUNT,
    APPROX_COUNT_DISTINCT(o.CUSTOMER_ID) AS UNIQUE_CUSTOMERS
FROM RETAIL_LAKEHOUSE.SILVER.ORDERS AS o
INNER JOIN RETAIL_LAKEHOUSE.BRONZE.PRODUCTS AS p
    ON o.PRODUCT_ID = p.PRODUCT_ID
WHERE o.ORDER_STATUS <> 'CANCELLED'
GROUP BY p.CATEGORY
ORDER BY p.CATEGORY;


-- Verify Gold.

SELECT
    *
FROM RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY
ORDER BY CATEGORY;


-- ------------------------------------------------------------
-- 7. Final verification
-- ------------------------------------------------------------

SELECT
    'BRONZE ORDERS' AS LAYER,
    COUNT(*) AS ROW_COUNT
FROM RETAIL_LAKEHOUSE.BRONZE.ORDERS

UNION ALL

SELECT
    'SILVER ORDERS' AS LAYER,
    COUNT(*) AS ROW_COUNT
FROM RETAIL_LAKEHOUSE.SILVER.ORDERS

UNION ALL

SELECT
    'GOLD CATEGORY SUMMARY' AS LAYER,
    COUNT(*) AS ROW_COUNT
FROM RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY;

-- ------------------------------------------------------------
-- 8. Stored Procedure Execution
-- ------------------------------------------------------------
--
-- Stored procedure command: CALL
--

CALL RETAIL_LAKEHOUSE.SILVER.BUILD_SILVER_ORDERS();