# Day 15 — Certification study plan

Next target: **SnowPro Core (COF-C03)** first, then **SnowPro Advanced:
Data Engineer (DEA-C02)**. Always re-read the live exam guide on
snowflake.com before booking — domains shift.

This capstone maps to **DEA-C02** (the code the verifier asks for) plus
Core architecture/security/cost.

## Domain map (what we already practiced)

| Exam | Domain | Cohort evidence |
| --- | --- | --- |
| COF-C03 | Architecture & features | Day 1 3-layer, warehouses, trial |
| COF-C03 | Security | Day 2 RBAC, masking, Day 15 Trust Center |
| COF-C03 | Performance | Day 9 Profile, caches, scaling Economy vs Standard |
| COF-C03 | Collaboration / Cortex | Day 10–15 Analyst, Search, Agents |
| DEA-C02 | Data transformation & modeling | Days 3–7 COPY, DT, Streams/Tasks, dbt |
| DEA-C02 | Performance optimization | Day 9 spill, warehouse size, Resource Monitor |
| DEA-C02 | Advanced development (Snowpark/ML) | Days 6, 11–13 Snowpark, Feature Store, Registry |
| DEA-C02 | Data governance & pipelines | Days 2, 5, 8 CI/CD, prod schema |

## Gaps to close (1 week)

| Day | Hours | Focus |
| --- | ---: | --- |
| Mon | 2 | Official COF-C03 guide + Snowsight UI drills (cloning, Time Travel, fail-safe) — thin in this repo |
| Tue | 2 | Secure data sharing / reader accounts / masking vs row-access (we did masking only) |
| Wed | 2 | Practice exams: warehouses (Standard vs Economy, multi-cluster), credits, Resource Monitors |
| Thu | 2 | DEA-C02: Snowpipe vs COPY, streams offsets, task DAGs, Dynamic Table TARGET_LAG |
| Fri | 2 | Snowpark DataFrame vs pandas; Model Registry aliases; Feature Store PIT join |
| Sat | 3 | Timed 100-question Core dump; review every miss against docs |
| Sun | 1 | Exam logistics: online proctor, ID, 2 hours, no Cortex-agent trivia beyond “Analyst vs Search vs Agent” |

## Exam-day logistics

- Register at the Snowflake certification portal; name must match photo ID.
- Core: ~100 items, ~115 minutes; Advanced DE: check the current guide for
  item count and duration.
- Open-book is **not** allowed. Know `AUTO_SUSPEND`, result cache **24**
  hours, `SUSPEND` vs `SUSPEND_IMMEDIATE`, `Entity` vs `FeatureView`,
  `log_model` + `v1`, `COMPLETE` / `CREATE CORTEX SEARCH SERVICE`,
  RAG = **Retrieval**-Augmented Generation, agent tool count **3**,
  mixed tests **5**, Advanced DE code **DEA-C02**.
