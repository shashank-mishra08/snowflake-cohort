# snowflake-cohort

15-day Snowflake project: a **retail / e-commerce lakehouse** from raw files to governed Bronze / Silver / Gold tables, orchestrated pipelines, dashboards, a registered ML model, and a Cortex AI agent.

Everything runs on a Snowflake **free trial** (30 days or $400 credits, no credit card) using the built-in `SNOWFLAKE_SAMPLE_DATA` share and small synthetic files — never real customer data.

Repo: [github.com/shashank-mishra08/snowflake-cohort](https://github.com/shashank-mishra08/snowflake-cohort)

## Repo layout

```
.
├── README.md
├── sql/              one worksheet export per day (dayNN_*.sql)
├── python/           Snowpark scripts, UDFs, the RAG chain
├── notebooks/        Snowflake Notebook exports (.ipynb)
├── streamlit/        Streamlit in Snowflake app (Day 10)
├── semantic_models/  Cortex Analyst YAML (Day 10)
├── dbt/              dbt project (Day 7)
├── migrations/       versioned SQL scripts (Day 8)
├── .github/workflows GitHub Actions (Day 8)
├── screenshots/      PNG evidence
└── docs/             notes, decision tables, reviews
```

Folders appear when files are committed. Verifier paths are relative to this repo root on `main`.

## Day 01 — Architecture & free trial setup

Exam alignment: SnowPro Core (COF-C03) — Architecture and Features (31%).

### What this day produces

- Snowflake trial account, **Enterprise Edition** (cloud + region cannot be changed later; AWS is the safe default)
- Virtual warehouse `RETAIL_WH`: X-Small, `AUTO_SUSPEND = 60`, `AUTO_RESUME = TRUE`
- First query against TPC-H sample data
- Database `RETAIL_LAKEHOUSE` with `BRONZE`, `SILVER`, `GOLD` schemas

### Sign up (Snowsight)

1. Open [snowflake.com/en/snowflake-trial](https://www.snowflake.com/en/snowflake-trial/) — no credit card.
2. Pick **Enterprise**, a cloud (AWS recommended), and a nearby region.
3. Activate from the email, land in **Snowsight**.
4. Worksheets → New → paste [`sql/day01_architecture_setup.sql`](sql/day01_architecture_setup.sql) → set role `SYSADMIN` → Run All.
5. Monitoring → Query History → open the `COUNT(*)` query → **Query Profile**.

A previous trial on this Gmail (`NLKGXOF-PU32141`) ended 2025-12-12 and is suspended. Use a **new** trial for this cohort (a different email if Snowflake blocks a second trial on the same address).

### Verifier answers

| # | Question | Answer |
| --- | --- | --- |
| Q1 | `SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;` | **1500000** |
| Q2 | How many layers make up Snowflake's architecture? | **3** |
| Q3 | Warehouse parameter that stops credit spend while idle | **AUTO_SUSPEND** |

Notes: [`docs/day01_architecture.md`](docs/day01_architecture.md) · [`docs/day01_quiz.md`](docs/day01_quiz.md)

## 15-day arc

| Days | Focus |
| ---: | --- |
| 1 | Account, architecture, warehouse, TPC-H, `RETAIL_LAKEHOUSE` |
| 2–6 | Ingest → Bronze / Silver / Gold |
| 7–8 | dbt, migrations, GitHub Actions |
| 9 | Query Profile, caches, warehouse resize, Resource Monitor |
| 10 | Dashboards, Streamlit, Cortex Analyst |
| 11–15 | ML model, governed Cortex agent |

## Day 09 — Performance, Query Profile & cost

Exam alignment: SnowPro Core — Performance (21%); SnowPro Advanced: Data Engineer — Performance Optimization and Monitoring.

### What this day produces

- Query Profile of a spilling sort on `LEARN_WH` X-Small (`TPCH_SF10.LINEITEM` CTAS `ORDER BY`)
- Result-cache miss vs hit on identical SQL (24-hour persisted results)
- Same sort on SMALL with **zero spill**, then warehouse reset to X-Small
- Resource monitor `TRIAL_BUDGET` (50 credits, notify 75%, suspend 100%) on `LEARN_WH`

Worksheet: [`sql/day09_performance.sql`](sql/day09_performance.sql) · monitor: [`sql/day09_resource_monitor.sql`](sql/day09_resource_monitor.sql) · diagnosis: [`docs/day09_performance_diagnosis.md`](docs/day09_performance_diagnosis.md) · profile: [`screenshots/day09_query_profile.png`](screenshots/day09_query_profile.png)

### Verifier answers

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Hours a query result stays in the result cache after last use | **24** |
| Q2 | Multi-cluster scaling policy that keeps clusters fully loaded before starting new ones | **Economy** |
| Q3 | `trial_budget` action at 100 percent of the credit quota | **SUSPEND** |






