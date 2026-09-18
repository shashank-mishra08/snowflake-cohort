-- =============================================================================
-- Day 10 — Snowsight Dashboard tiles (Gold only)
-- Role: ACCOUNTADMIN (create Gold time series + grants)
-- Warehouse: LEARN_WH
--
-- Tiles:
--   1. KPI     total revenue from GOLD.CATEGORY_SUMMARY
--   2. Bar     revenue by category from GOLD.CATEGORY_SUMMARY
--   3. Line    orders over time from GOLD.ORDERS_OVER_TIME
--
-- CATEGORY_SUMMARY has no date column, so a line chart cannot be built
-- from it. ORDERS_OVER_TIME is the Gold grain for time. Do not point a
-- "Gold dashboard" tile at SILVER.ORDERS.
--
-- Snowsight: Projects → Dashboards → New. Add 3 tiles, paste the
-- SELECT under each heading, pick Bar / Line / Scorecard.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE LEARN_WH;
USE DATABASE RETAIL_LAKEHOUSE;
USE SCHEMA GOLD;


-- -----------------------------------------------------------------------------
-- Gold time series for the line tile
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.GOLD.ORDERS_OVER_TIME AS
SELECT
    DATE_TRUNC('DAY', o.ORDER_TS)::DATE AS ORDER_DATE,
    COUNT(*) AS ORDER_COUNT,
    SUM(IFF(o.ORDER_STATUS <> 'CANCELLED', o.QUANTITY * p.PRICE, 0)) AS TOTAL_REVENUE
FROM RETAIL_LAKEHOUSE.SILVER.ORDERS AS o
INNER JOIN RETAIL_LAKEHOUSE.BRONZE.PRODUCTS AS p
    ON o.PRODUCT_ID = p.PRODUCT_ID
GROUP BY 1
ORDER BY 1;

-- Order-level Gold facts for the Streamlit filter (one row per order)
CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.GOLD.ORDER_FACTS AS
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
    ON o.PRODUCT_ID = p.PRODUCT_ID;

GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_LAKEHOUSE.GOLD TO ROLE DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_LAKEHOUSE.GOLD TO ROLE DATA_ANALYST;


-- =============================================================================
-- Tile 1 — KPI: total revenue (Scorecard)
-- =============================================================================

SELECT
    SUM(TOTAL_REVENUE) AS TOTAL_REVENUE
FROM RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY;


-- =============================================================================
-- Tile 2 — Bar: revenue by category
-- =============================================================================

SELECT
    CATEGORY,
    TOTAL_REVENUE,
    ORDER_COUNT,
    UNIQUE_CUSTOMERS
FROM RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY
ORDER BY TOTAL_REVENUE DESC;


-- =============================================================================
-- Tile 3 — Line: orders over time
-- =============================================================================

SELECT
    ORDER_DATE,
    ORDER_COUNT,
    TOTAL_REVENUE
FROM RETAIL_LAKEHOUSE.GOLD.ORDERS_OVER_TIME
ORDER BY ORDER_DATE;


-- Sanity check (not a dashboard tile)
SELECT * FROM RETAIL_LAKEHOUSE.GOLD.ORDER_FACTS ORDER BY ORDER_TS;
