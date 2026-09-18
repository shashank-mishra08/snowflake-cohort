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

## Day 10 — Dashboards, Streamlit, Cortex Analyst

Exam alignment: SnowPro Core — Collaboration (10%).

### What this day produces

- Snowsight dashboard with 3 Gold tiles (KPI, bar, line)
- Streamlit in Snowflake app with `st.selectbox` + `session.table(...).to_pandas()`
- Cortex Analyst YAML semantic model with 3 verified queries

App: [`streamlit/day10_app.py`](streamlit/day10_app.py) · model: [`semantic_models/retail_semantic_model.yaml`](semantic_models/retail_semantic_model.yaml) · tiles: [`sql/day10_dashboard.sql`](sql/day10_dashboard.sql) · screenshot: [`screenshots/day10_dashboard.png`](screenshots/day10_dashboard.png) · notes: [`docs/day10_front_doors.md`](docs/day10_front_doors.md)

### Verifier answers

| # | Question | Answer |
| --- | --- | --- |
| Q1 | File format of a Cortex Analyst semantic model | **YAML** |
| Q2 | Streamlit dropdown widget (`st.___`) | **selectbox** |
| Q3 | Snowpark method that returns a pandas DataFrame | **to_pandas** |

## Day 11 — Snowpark ML, Notebooks, ML Functions

Exam alignment: SnowPro Advanced Data Engineer — Snowpark / Snowflake ML.

### What this day produces

- Built-in `SNOWFLAKE.ML.FORECAST` on 2,406 daily revenue points, 14-day horizon
- Snowflake Notebook: Snowpark ML `StandardScaler` + `OneHotEncoder` + `RandomForestClassifier` + `accuracy_score`
- Notes on in-platform training vs `to_pandas()` + sklearn

Notebook: [`notebooks/day11_snowpark_ml.ipynb`](notebooks/day11_snowpark_ml.ipynb) · SQL: [`sql/day11_ml_functions.sql`](sql/day11_ml_functions.sql) · notes: [`docs/day11_training_notes.md`](docs/day11_training_notes.md)

## Day 12 — Feature Store & point-in-time training

Exam alignment: SnowPro Advanced Data Engineer — transformation / Snowpark.

### What this day produces

- EDA on `GOLD.CUSTOMER_ORDER_EVENTS` (`describe()`, null counts)
- Entity `CUSTOMER` + FeatureView `customer_features` v1 (`refresh_freq='1 day'`)
- Point-in-time training set vs Day 11 ad-hoc columns (0.515 → 0.963 accuracy)

Notebook: [`notebooks/day12_feature_store.ipynb`](notebooks/day12_feature_store.ipynb) · notes: [`docs/day12_features.md`](docs/day12_features.md)

### Verifier answers

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Feature Store object that defines the join key | **Entity** |
| Q2 | Class that registers engineered features with a refresh frequency | **FeatureView** |
| Q3 | DataFrame method for count/mean/stddev/min/max | **describe** |

## Day 13 — Model Registry & deployment

Exam alignment: SnowPro Advanced Data Engineer — Snowpark / ML deployment.

### What this day produces

- GridSearchCV on Day 12 PIT features (`best_params_`: depth 8, leaf 4, 10 trees)
- `churn_model` **v1** in `RETAIL_LAKEHOUSE.ML_MODELS` with default + `PRODUCTION` alias
- Batch scores in `GOLD.CHURN_SCORES`; SQL `CHURN_MODEL!PREDICT(...)` works on this trial

Notebook: [`notebooks/day13_registry.ipynb`](notebooks/day13_registry.ipynb) · batch: [`python/day13_batch_inference.py`](python/day13_batch_inference.py) · notes: [`docs/day13_deployment_note.md`](docs/day13_deployment_note.md)

### Verifier answers

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Snowpark ML class that tries every grid combination | **GridSearchCV** |
| Q2 | Registry method that stores a trained model | **log_model** |
| Q3 | First `version_name` for `churn_model` | **v1** |

## Day 14 — Cortex AISQL, Search, RAG

Exam alignment: SnowPro Core — Cortex AI.

### What this day produces

- AISQL worksheet: `COMPLETE`, `AI_CLASSIFY`, `SUMMARIZE`, `AI_EXTRACT`
- `CREATE CORTEX SEARCH SERVICE product_search` over 8 synthetic docs
- RAG: retrieve → prompt → `SNOWFLAKE.CORTEX.COMPLETE`
- This trial returns **399258** (COMPLETE / embeddings / EXTRACT blocked); SQL + Python still contain the production calls and a grounded keyword fallback

SQL: [`sql/day14_cortex.sql`](sql/day14_cortex.sql) · RAG: [`python/day14_rag_chain.py`](python/day14_rag_chain.py) · eval: [`docs/day14_rag_eval.md`](docs/day14_rag_eval.md)

### Verifier answers

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Cortex function that generates text (`SNOWFLAKE.CORTEX.___`) | **COMPLETE** |
| Q2 | `CREATE CORTEX ___ SERVICE` | **SEARCH** |
| Q3 | The R in RAG | **Retrieval** |






