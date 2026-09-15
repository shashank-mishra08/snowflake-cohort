-- ============================================================
-- Day 3: Time Travel & Zero-Copy Cloning
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- Step 1: Create Silver and Gold schemas
-- ============================================================

CREATE SCHEMA IF NOT EXISTS retail_lakehouse.silver;
CREATE SCHEMA IF NOT EXISTS retail_lakehouse.gold;

-- Verify medallion schemas
SHOW SCHEMAS IN DATABASE retail_lakehouse;


-- ============================================================
-- Step 2: Time Travel
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Create a small table for the Time Travel exercise
CREATE OR REPLACE TABLE retail_lakehouse.silver.tt_customers (
    customer_id INTEGER,
    name STRING,
    region STRING
);

-- Insert initial data
INSERT INTO retail_lakehouse.silver.tt_customers
    (customer_id, name, region)
VALUES
    (1, 'Alice', 'EAST'),
    (2, 'Bob', 'WEST'),
    (3, 'Charlie', 'EAST');

-- Verify initial state
SELECT *
FROM retail_lakehouse.silver.tt_customers
ORDER BY customer_id;


-- ------------------------------------------------------------
-- Change the data
-- ------------------------------------------------------------

UPDATE retail_lakehouse.silver.tt_customers
SET region = 'NORTH'
WHERE customer_id = 2;


-- ------------------------------------------------------------
-- Query the state immediately BEFORE the UPDATE
-- LAST_QUERY_ID() refers to the UPDATE above because this
-- statement is executed immediately after it.
-- ------------------------------------------------------------

SELECT *
FROM retail_lakehouse.silver.tt_customers
BEFORE (STATEMENT => LAST_QUERY_ID())
ORDER BY customer_id;


-- ------------------------------------------------------------
-- Verify the current state after the UPDATE
-- ------------------------------------------------------------

SELECT *
FROM retail_lakehouse.silver.tt_customers
ORDER BY customer_id;


-- ------------------------------------------------------------
-- Query historical data using an OFFSET
-- 5 minutes in the past gives enough time for this exercise.
-- ------------------------------------------------------------

SELECT *
FROM retail_lakehouse.silver.tt_customers
AT (OFFSET => -300)
ORDER BY customer_id;


-- ------------------------------------------------------------
-- Drop the table intentionally
-- ------------------------------------------------------------

DROP TABLE retail_lakehouse.silver.tt_customers;


-- Verify the table is no longer present
SHOW TABLES IN SCHEMA retail_lakehouse.silver;


-- ------------------------------------------------------------
-- Recover the dropped table using UNDROP
-- ------------------------------------------------------------

UNDROP TABLE retail_lakehouse.silver.tt_customers;


-- Verify the recovered table
SELECT *
FROM retail_lakehouse.silver.tt_customers
ORDER BY customer_id;


-- ============================================================
-- Step 3: Zero-Copy Cloning
-- ============================================================

-- Create a clone of the Silver schema
CREATE OR REPLACE SCHEMA retail_lakehouse.silver_clone
CLONE retail_lakehouse.silver;


-- Verify the cloned schema exists
SHOW SCHEMAS IN DATABASE retail_lakehouse;


-- Verify the cloned table exists
SHOW TABLES IN SCHEMA retail_lakehouse.silver_clone;


-- Query the cloned table
SELECT *
FROM retail_lakehouse.silver_clone.tt_customers
ORDER BY customer_id;


-- ------------------------------------------------------------
-- Prove that the clone is independent from the source
-- ------------------------------------------------------------

UPDATE retail_lakehouse.silver_clone.tt_customers
SET region = 'SOUTH'
WHERE customer_id = 1;


-- Clone now contains the changed value
SELECT *
FROM retail_lakehouse.silver_clone.tt_customers
ORDER BY customer_id;


-- Original source remains unchanged
SELECT *
FROM retail_lakehouse.silver.tt_customers
ORDER BY customer_id;




-- ============================================================
-- Step 11: Inspect Micro-Partition Clustering
-- ============================================================

SELECT SYSTEM$CLUSTERING_INFORMATION(
    'RETAIL_LAKEHOUSE.SILVER.TT_CUSTOMERS',
    '(CUSTOMER_ID)'
);