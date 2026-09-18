# Day 15 — Cost review

Source: `INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY` (last 30 days) plus
`SHOW RESOURCE MONITORS` / `SHOW WAREHOUSES`. Account `PAYDEGL-YJ88482`.

## Spend so far

| Warehouse | Credits | Notes |
| --- | ---: | --- |
| `COMPUTE_WH` | **4.16** | Default warehouse; `AUTO_SUSPEND=300`; **no** resource monitor; QAS on |
| `LEARN_WH` | **1.48** | Cohort warehouse; `AUTO_SUSPEND=60`; monitor **TRIAL_BUDGET** |
| Cloud Services only | 0.003 | Result-cache hits |
| **Total** | **~5.65** | Well under the $400 / 50-credit trial |

By day (largest first):

| Day | Warehouse | Credits | Why |
| --- | --- | ---: | --- |
| 2026-09-15 | `COMPUTE_WH` | **1.83** | Day 1–2 setup + Snowsight on the default WH |
| 2026-09-16 | `COMPUTE_WH` | 1.46 | Ingest / RBAC while still on default WH |
| 2026-09-17 | `LEARN_WH` | **1.01** | Day 9 SF10 spill, Feature Store DT, ML, Registry |
| 2026-09-17 | `COMPUTE_WH` | 0.76 | Residual default-WH traffic |

`TRIAL_BUDGET`: quota **50**, used **0.57** (only meters `LEARN_WH` after 2026-09-17 attach), notify 75%, **SUSPEND at 100%**.

Idle warehouses that still exist: `SNOWFLAKE_LEARNING_WH` (300s suspend, no monitor), `SYSTEM$STREAMLIT_NOTEBOOK_WH`.

## Three production savings

1. **Stop using `COMPUTE_WH` as the daily driver.** Set `AUTO_SUSPEND=60`, attach `TRIAL_BUDGET` (or a 10-credit weekly monitor), and `ENABLE_QUERY_ACCELERATION=FALSE`. Most of the 4.16 credits were this warehouse sitting at 5-minute suspend plus QAS headroom.
2. **Keep `LEARN_WH` X-Small; do not leave it on SMALL.** Day 9 spill lab needed SMALL once; it was reset. A forgotten SMALL is 2× credits. Feature Store `refresh_freq='1 day'` is already cheap — do not drop TARGET_LAG to minutes in prod unless the agent is live.
3. **Serverless Tasks + result cache for dashboards; suspend unused WHs.** Day 7 DAG can be serverless so it does not hold `LEARN_WH`. Streamlit/Cortex Analyst should hit Gold tables that fit in result cache (24h). Drop or suspend `SNOWFLAKE_LEARNING_WH` and never query TPC-H SF10 in CI.

Do **not** enable Cortex COMPLETE / Search embeddings on the trial — they are blocked (`399258`) and would be a new credit line (Cortex services, not warehouse) in production. Put a separate spend cap on Cortex before opening CoWork to the business.
