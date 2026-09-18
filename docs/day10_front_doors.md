# Day 10 — Dashboards, Streamlit, Cortex Analyst

Gold tables used:

- `GOLD.CATEGORY_SUMMARY` — bar + KPI
- `GOLD.ORDERS_OVER_TIME` — line (new; category_summary has no date)
- `GOLD.ORDER_FACTS` — Streamlit live filter

## Share safely

Dashboard / Streamlit / Cortex Analyst should be granted to `DATA_ANALYST`
(`GRANT SELECT ON ALL TABLES IN SCHEMA GOLD TO ROLE DATA_ANALYST`). Analysts
see Gold; they do not need ACCOUNTADMIN.

Cortex Analyst answers are governed by the same RBAC and masking policies as
any other Snowflake query: the LLM only runs SQL as the current role, so it
cannot read columns or rows that role cannot select.

## Cortex Analyst — extra questions (not in verified_queries)

Ask these in the Cortex Analyst chat after registering
`semantic_models/retail_semantic_model.yaml`. Check the generated SQL uses
Gold tables and existing columns only.

| Question | Expected tables / columns | Expected answer |
| --- | --- | --- |
| Which category has the most unique customers? | `CATEGORY_SUMMARY.CATEGORY`, `UNIQUE_CUSTOMERS` | Electronics (6) |
| What was revenue on 17 September 2026? | `ORDERS_OVER_TIME.ORDER_DATE`, `TOTAL_REVENUE` | 92,400 |
| Average order value for Electronics, excluding cancelled? | `ORDER_FACTS.CATEGORY`, `ORDER_STATUS`, `ORDER_VALUE` | 44,842.86 |

Reject any SQL that invents columns (`REGION`, `PROFIT`, `STORE_ID`) or reads
`BRONZE` / `SILVER` when the model only exposes Gold.
