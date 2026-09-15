-- ============================================================
-- Day 3: Semi-Structured Data
-- VARIANT, JSON, Dot Notation & FLATTEN
-- ============================================================

USE ROLE ACCOUNTADMIN;


-- ============================================================
-- STEP 1: Create a table with a VARIANT column
-- ============================================================
-- VARIANT allows Snowflake to store an entire semi-structured
-- document such as JSON in a single column.
--
-- We are intentionally using synthetic customer data.
-- ============================================================

CREATE OR REPLACE TABLE retail_lakehouse.silver.customer_events (
    event_id INTEGER,
    event_data VARIANT
);


-- ============================================================
-- STEP 2: Insert nested JSON documents
-- ============================================================
-- PARSE_JSON converts a JSON string into Snowflake's VARIANT
-- representation.
--
-- Each document contains:
--   customer
--      ├── name
--      └── region
--
--   orders
--      └── an array of order objects
-- ============================================================

INSERT INTO retail_lakehouse.silver.customer_events
    (event_id, event_data)

SELECT
    1,
    PARSE_JSON('{
        "customer": {
            "name": "Alice",
            "region": "EAST"
        },
        "orders": [
            {"id": 101, "amount": 500},
            {"id": 102, "amount": 300}
        ]
    }')

UNION ALL

SELECT
    2,
    PARSE_JSON('{
        "customer": {
            "name": "Bob",
            "region": "WEST"
        },
        "orders": [
            {"id": 103, "amount": 750}
        ]
    }');

-- ============================================================
-- STEP 3: View the complete JSON documents
-- ============================================================
-- This shows that the complete nested JSON document is stored
-- inside the VARIANT column without first flattening it.
-- ============================================================

SELECT
    event_id,
    event_data
FROM retail_lakehouse.silver.customer_events
ORDER BY event_id;


-- ============================================================
-- STEP 4: Inspect the VARIANT data type
-- ============================================================
-- TYPEOF() shows the Snowflake data type of the value.
-- ============================================================

SELECT
    event_id,
    TYPEOF(event_data) AS data_type
FROM retail_lakehouse.silver.customer_events
ORDER BY event_id;


-- ============================================================
-- STEP 5: Query nested JSON using DOT NOTATION
-- ============================================================
-- Snowflake lets us navigate inside a VARIANT value directly.
--
-- event_data:customer:name
--      ↓
-- customer object
--      ↓
-- name field
--
-- ::STRING converts the extracted value into a normal STRING.
-- ============================================================

SELECT
    event_id,
    event_data:customer:name::STRING AS customer_name,
    event_data:customer:region::STRING AS region
FROM retail_lakehouse.silver.customer_events
ORDER BY event_id;


-- ============================================================
-- STEP 6: Access the nested orders array
-- ============================================================
-- Here we access the complete orders array without flattening it.
-- ============================================================

SELECT
    event_id,
    event_data:customer:name::STRING AS customer_name,
    event_data:orders AS orders
FROM retail_lakehouse.silver.customer_events
ORDER BY event_id;


-- ============================================================
-- STEP 7: Explode the orders array with FLATTEN
-- ============================================================
-- FLATTEN converts elements of a nested array into rows.
--
-- Before FLATTEN:
--
-- Alice
--   ├── Order 101
--   └── Order 102
--
-- After FLATTEN:
--
-- Alice | 101 | 500
-- Alice | 102 | 300
--
-- This is useful when we need to analyze each nested array
-- element as an individual row.
-- ============================================================

SELECT
    e.event_id,
    e.event_data:customer:name::STRING AS customer_name,
    f.value:id::INTEGER AS order_id,
    f.value:amount::NUMBER AS amount
FROM retail_lakehouse.silver.customer_events AS e,
LATERAL FLATTEN(
    INPUT => e.event_data:orders
) AS f
ORDER BY e.event_id, order_id;


-- ============================================================
-- STEP 8: FLATTEN with additional customer information
-- ============================================================
-- This combines values from the parent JSON object with the
-- individual elements produced by FLATTEN.
-- ============================================================

SELECT
    e.event_id,
    e.event_data:customer:name::STRING AS customer_name,
    e.event_data:customer:region::STRING AS region,
    f.value:id::INTEGER AS order_id,
    f.value:amount::NUMBER AS amount
FROM retail_lakehouse.silver.customer_events AS e,
LATERAL FLATTEN(
    INPUT => e.event_data:orders
) AS f
ORDER BY e.event_id, order_id;


-- ============================================================
-- STEP 9: Calculate order totals from nested JSON
-- ============================================================
-- Once FLATTEN has turned the nested orders into rows,
-- normal SQL aggregation can be used.
-- ============================================================

SELECT
    e.event_data:customer:name::STRING AS customer_name,
    SUM(f.value:amount::NUMBER) AS total_order_amount
FROM retail_lakehouse.silver.customer_events AS e,
LATERAL FLATTEN(
    INPUT => e.event_data:orders
) AS f
GROUP BY customer_name
ORDER BY customer_name;


-- ============================================================
-- STEP 10: Final verification
-- ============================================================
-- This final query demonstrates both major techniques:
--
-- 1. Dot notation → extract nested customer information
-- 2. FLATTEN      → turn nested orders into individual rows
-- ============================================================

SELECT
    e.event_id,
    e.event_data:customer:name::STRING AS customer_name,
    e.event_data:customer:region::STRING AS region,
    f.value:id::INTEGER AS order_id,
    f.value:amount::NUMBER AS amount
FROM retail_lakehouse.silver.customer_events AS e,
LATERAL FLATTEN(
    INPUT => e.event_data:orders
) AS f
ORDER BY e.event_id, order_id;