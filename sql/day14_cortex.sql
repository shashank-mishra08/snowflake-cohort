-- =============================================================================
-- Day 14 — Cortex AISQL, Cortex Search, Document AI
-- Role: ACCOUNTADMIN (CORTEX_USER + optional cross-region)
-- Warehouse: LEARN_WH
--
-- Trial accounts return 399258: COMPLETE / SEARCH embeddings / AI_EXTRACT
-- are not available. The DDL and function calls below are the production
-- path. Re-run after Cortex is enabled (or on a paid account).
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE LEARN_WH;
USE DATABASE RETAIL_LAKEHOUSE;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;
-- Uncomment if the model is not in your region:
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE SCHEMA IF NOT EXISTS RETAIL_LAKEHOUSE.CORTEX;
USE SCHEMA RETAIL_LAKEHOUSE.CORTEX;


-- -----------------------------------------------------------------------------
-- 1. AISQL on a real reviews column
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.CORTEX.PRODUCT_REVIEWS (
    REVIEW_ID     INTEGER,
    PRODUCT_NAME  STRING,
    REVIEW_TEXT   STRING
);

INSERT OVERWRITE INTO RETAIL_LAKEHOUSE.CORTEX.PRODUCT_REVIEWS VALUES
    (1, 'Laptop',   'The laptop is fast and the screen is sharp, but the fan is loud under load.'),
    (2, 'Mouse',    'Mouse arrived two days late and the scroll wheel already skips.'),
    (3, 'Desk',     'Standing desk assembly was easy and the motor is quiet at full height.'),
    (4, 'Keyboard', 'Keys feel mushy and two LEDs died in the first week. Requesting a replacement.'),
    (5, 'Webcam',   'Picture is clear in daylight. Night mode is grainy. Cable is too short.');

-- LLM generate (legacy name the quiz asks for)
SELECT
    REVIEW_ID,
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        'Summarize this in one sentence: ' || REVIEW_TEXT
    ) AS REVIEW_SUMMARY
FROM RETAIL_LAKEHOUSE.CORTEX.PRODUCT_REVIEWS
LIMIT 5;

-- Newer AISQL alias
SELECT AI_COMPLETE('llama3.1-8b', 'Summarize this in one sentence: ' || REVIEW_TEXT)
FROM RETAIL_LAKEHOUSE.CORTEX.PRODUCT_REVIEWS
LIMIT 5;

SELECT
    REVIEW_ID,
    AI_CLASSIFY(REVIEW_TEXT, ['shipping', 'quality', 'assembly', 'support']) AS TOPIC
FROM RETAIL_LAKEHOUSE.CORTEX.PRODUCT_REVIEWS;

SELECT SNOWFLAKE.CORTEX.SUMMARIZE(REVIEW_TEXT) AS BLURB
FROM RETAIL_LAKEHOUSE.CORTEX.PRODUCT_REVIEWS;


-- -----------------------------------------------------------------------------
-- 2. Document corpus (synthetic FAQs + policies — no real customer data)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.CORTEX.PRODUCT_DOCS (
    ID     STRING,
    TEXT   STRING,
    SOURCE STRING
);

INSERT OVERWRITE INTO RETAIL_LAKEHOUSE.CORTEX.PRODUCT_DOCS (ID, TEXT, SOURCE) VALUES
    ('faq-returns',
     'Returns are accepted within 30 days of delivery if the item is unused and in original packaging. Opened electronics may be restocked for a 10 percent fee. Refunds go to the original payment method within 5 business days.',
     'faq'),
    ('faq-warranty',
     'Every laptop includes a 12-month limited hardware warranty covering manufacturing defects. Accidental damage, liquid spills, and lost chargers are not covered. Extended Care can be added at checkout for 24 months.',
     'faq'),
    ('faq-shipping',
     'Standard shipping takes 3 to 5 business days. Express shipping arrives in 1 to 2 business days. Orders placed after 3pm local warehouse time ship the next business day. We do not ship to PO boxes for furniture.',
     'faq'),
    ('policy-privacy',
     'We store account email, shipping address, and order history. We do not sell personal data. You may request deletion of your account from Settings. Order records are retained for 7 years for tax compliance.',
     'policy'),
    ('policy-masking',
     'Customer email and phone are protected by a Snowflake masking policy. ANALYST roles see masked values. ACCOUNTADMIN may unmask for support tickets. Cortex queries run as the caller role so masking still applies.',
     'policy'),
    ('faq-battery',
     'Laptop batteries are rated for 8 to 10 hours of mixed use. Fast charging reaches 50 percent in 30 minutes. If runtime drops below 4 hours in the first year, contact warranty support for a replacement pack.',
     'faq'),
    ('faq-desk',
     'The standing desk ships in two boxes. Assembly takes about 40 minutes with the included hex key. Maximum load is 80 kilograms. The motor warranty is 5 years. Do not place liquids on the control panel.',
     'faq'),
    ('policy-security',
     'Passwords are hashed. Sessions expire after 12 hours of inactivity. Multi-factor authentication is required for ACCOUNTADMIN. API keys must be rotated every 90 days. Report incidents to security@retail.example.',
     'policy');

ALTER TABLE RETAIL_LAKEHOUSE.CORTEX.PRODUCT_DOCS SET CHANGE_TRACKING = TRUE;


-- -----------------------------------------------------------------------------
-- 3. Cortex Search Service
-- -----------------------------------------------------------------------------

CREATE OR REPLACE CORTEX SEARCH SERVICE product_search
    ON text
    ATTRIBUTES source
    WAREHOUSE = learn_wh
    TARGET_LAG = '1 hour'
AS (
    SELECT id, text, source
    FROM RETAIL_LAKEHOUSE.CORTEX.PRODUCT_DOCS
);


-- -----------------------------------------------------------------------------
-- 4. Retrieval preview (do this before RAG)
-- -----------------------------------------------------------------------------

SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'RETAIL_LAKEHOUSE.CORTEX.PRODUCT_SEARCH',
        '{
            "query": "How long do I have to return a laptop?",
            "columns": ["ID", "TEXT", "SOURCE"],
            "limit": 3
        }'
    )
)['results'] AS RESULTS;


-- -----------------------------------------------------------------------------
-- 6. Document AI / AI_EXTRACT
--    Trial blocks AI_EXTRACT. The call is the production path.
--    The REGEXP query is the trial stand-in on synthetic invoice text.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.CORTEX.INVOICE_DOCS (
    DOC_ID   STRING,
    DOC_TEXT STRING
);

INSERT OVERWRITE INTO RETAIL_LAKEHOUSE.CORTEX.INVOICE_DOCS VALUES
    ('inv-1001',
     'INVOICE INV-1001
Bill To: Northwind Retail
Due Date: 2026-10-15
Amount Due: 1280.00 USD
Line: 2x Laptop stand @ 640.00');

SELECT
    DOC_ID,
    AI_EXTRACT(
        DOC_TEXT,
        PARSE_JSON('{"schema":{"type":"object","properties":{"invoice_id":{"type":"string"},"due_date":{"type":"string"},"amount_due":{"type":"number"}}}}')
    ) AS EXTRACTED
FROM RETAIL_LAKEHOUSE.CORTEX.INVOICE_DOCS;

CREATE OR REPLACE TABLE RETAIL_LAKEHOUSE.GOLD.INVOICE_EXTRACT AS
SELECT
    DOC_ID,
    REGEXP_SUBSTR(DOC_TEXT, 'INVOICE[[:space:]]+(INV-[0-9]+)', 1, 1, 'e', 1) AS INVOICE_ID,
    REGEXP_SUBSTR(DOC_TEXT, 'Due Date:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2})', 1, 1, 'e', 1) AS DUE_DATE,
    TRY_TO_NUMBER(REGEXP_SUBSTR(DOC_TEXT, 'Amount Due:[[:space:]]*([0-9.]+)', 1, 1, 'e', 1)) AS AMOUNT_DUE
FROM RETAIL_LAKEHOUSE.CORTEX.INVOICE_DOCS;

SELECT * FROM RETAIL_LAKEHOUSE.GOLD.INVOICE_EXTRACT;

GRANT USAGE ON SCHEMA RETAIL_LAKEHOUSE.CORTEX TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_LAKEHOUSE.CORTEX TO ROLE DATA_ANALYST;
