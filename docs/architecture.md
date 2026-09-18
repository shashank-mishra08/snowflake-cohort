# Architecture — retail lakehouse (Days 1–15)

Account `PAYDEGL-YJ88482`. Database `RETAIL_LAKEHOUSE`. Compute: `LEARN_WH`
(X-Small, auto-suspend 60s, resource monitor `TRIAL_BUDGET`).

```
files / TPC-H share
        │
        ▼
   BRONZE  ── COPY / Snowpipe-style load, raw VARIANT + CSV
        │     Streams on landing tables
        ▼
   SILVER  ── Tasks / Dynamic Tables / Snowpark / dbt tests
        │     masking policies, RBAC (DATA_ENGINEER, DATA_ANALYST)
        ▼
   GOLD    ── CATEGORY_SUMMARY, ORDER_FACTS, ORDERS_OVER_TIME, ML tables
        │
        ├─ Snowsight dashboard + Streamlit in Snowflake (Day 10)
        ├─ Cortex Analyst YAML  retail_gold  (Day 10)
        ├─ Feature Store CUSTOMER / customer_features v1  (Day 12)
        ├─ Model Registry  CHURN_MODEL v1  → GOLD.CHURN_SCORES  (Day 13)
        ├─ Cortex Search + RAG over PRODUCT_DOCS  (Day 14)
        └─ Cortex Agent RETAIL_AGENT  (Analyst + Search + GET_CATEGORY_REVENUE)
```

## Layer by layer

**Day 1 — Platform.** Enterprise trial, 3-layer architecture (storage /
compute / cloud services), first TPC-H query, `RETAIL_LAKEHOUSE` +
`BRONZE/SILVER/GOLD`.

**Day 2 — Trust.** Roles `DATA_ENGINEER` → SYSADMIN, `DATA_ANALYST` for
select-only Gold. Masking on PII. Least privilege is why Cortex later
cannot see unmasked email.

**Days 3–4 — Ingest.** VARIANT/JSON + `FLATTEN`, file formats, stages,
`COPY INTO` Bronze.

**Days 5–6 — Transform.** Streams + Tasks DAG; Dynamic Tables
(`PRODUCTS_DT`, `PRODUCT_SUMMARY_DT`); Snowpark Python to Silver/Gold.

**Days 7–8 — Software.** dbt models/tests; versioned `migrations/`; GitHub
Actions Snowflake CLI + key-pair (`config.toml` mode 0600, PKCS#8). CI
deploys DEV (`RETAIL_LAKEHOUSE`) and PROD (`RETAIL_LAKEHOUSE_PROD`).

**Day 9 — Cost/perf.** Query Profile (2.59 GB local spill on X-Small sort);
result cache 24h; `TRIAL_BUDGET` 50 credits, notify 75%, SUSPEND 100%.

**Day 10 — Front doors.** Three Gold tiles; Streamlit `st.selectbox` +
`to_pandas()`; Cortex Analyst semantic model + verified queries.

**Days 11–13 — ML.** `SNOWFLAKE.ML.FORECAST` on 2,406 daily points; Snowpark
ML preprocess + RF; Feature Store PIT set (no future-join leakage);
GridSearchCV; Registry `churn_model` **v1** default + `PRODUCTION`; batch
`GOLD.CHURN_SCORES`; SQL `CHURN_MODEL!PREDICT`.

**Day 14 — Unstructured.** AISQL `COMPLETE` / Search / `AI_EXTRACT` (blocked
on this trial with 399258). Keyword-grounded RAG over 8 synthetic docs.

**Day 15 — Agent.** `RETAIL_AGENT` with **3 tools**, five mixed questions,
cost (~5.65 credits), Trust Center posture, this narrative, certification plan.

## Governance thread

Every object is a Snowflake object: tables, DTs, Feature Views, models,
Search services, agents. The same RBAC and masking wrap SQL, Streamlit,
Analyst, Search, and the agent. `DATA_ANALYST` never needs ACCOUNTADMIN.
