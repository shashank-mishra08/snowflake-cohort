-- =============================================================================
-- Day 09 — Resource Monitor (trial credit cap)
-- Role: ACCOUNTADMIN (required to create monitors)
-- Warehouse: LEARN_WH
--
-- Deliverable:
--   Resource monitor TRIAL_BUDGET with CREDIT_QUOTA = 50
--   Notify at 75%, SUSPEND at 100%, assigned to LEARN_WH
--
-- Snowsight: paste, set role ACCOUNTADMIN, Run All.
-- Then open Admin → Cost Management → Resource Monitors and confirm
-- TRIAL_BUDGET is attached to LEARN_WH.
--
-- Actions:
--   NOTIFY             — email account admins; queries keep running
--   SUSPEND            — warehouse finishes in-flight queries, then
--                        suspends. New queries are blocked until the
--                        quota resets or a higher quota is set.
--   SUSPEND_IMMEDIATE  — kill in-flight queries and suspend now
--
-- At 100% of trial_budget the action is SUSPEND (not SUSPEND_IMMEDIATE).
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE LEARN_WH;


-- Recreate so this worksheet is safe to re-run.
-- A warehouse cannot reference a monitor while we drop it, so detach first.
ALTER WAREHOUSE LEARN_WH UNSET RESOURCE_MONITOR;

DROP RESOURCE MONITOR IF EXISTS trial_budget;

CREATE RESOURCE MONITOR trial_budget
    WITH CREDIT_QUOTA = 50
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE LEARN_WH SET RESOURCE_MONITOR = trial_budget;


SHOW RESOURCE MONITORS LIKE 'TRIAL_BUDGET';

SHOW WAREHOUSES LIKE 'LEARN_WH';

SELECT
    "name" AS warehouse_name,
    "size" AS warehouse_size,
    "resource_monitor" AS resource_monitor
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
