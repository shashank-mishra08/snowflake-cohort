# Day 01 — Snowflake architecture notes

SnowPro Core (COF-C03) — Architecture and Features (~31%).

## Three-layer architecture

Snowflake is a **multi-cluster shared data** platform: one copy of data, many independent compute clusters.

| Layer | What it is | What it does | How it is billed |
| --- | --- | --- | --- |
| **Database storage** | Compressed columnar micro-partitions in the cloud provider's object store (S3 / Blob / GCS) | Persists tables, Time Travel, cloning metadata | Storage (TB/month), independent of warehouses |
| **Compute** | Virtual warehouses — MPP clusters of VMs | Run SQL, Snowpark, DML | Credits while the warehouse is *running* |
| **Cloud services** | Coordination layer Snowflake operates | Auth, RBAC, metadata, query parsing/optimization, result cache, transactions | Mostly included; some services consume credits |

Storage is separate from compute so you can:

- Pause every warehouse and **pay only for stored bytes**
- Size compute per workload (XS for this cohort, larger for heavy transforms) without moving data
- Run warehouses in parallel against the **same** tables with no resource contention
- Clone databases in seconds (metadata-only; no data copy)

This is the hybrid of shared-disk (one central store) and shared-nothing (MPP nodes with local cache).

## Virtual warehouses

- Sizes: **XS → 6XL**. Each step up doubles servers and credits/hour (XS = 1 credit/hour).
- **Multi-cluster** (Enterprise+): `MIN_CLUSTER_COUNT` / `MAX_CLUSTER_COUNT` scale out for concurrency.
- **`AUTO_SUSPEND`**: seconds of idle time before Snowflake stops the warehouse so it **stops spending credits**. `0` or `NULL` means never suspend — do not use that on a trial.
- **`AUTO_RESUME`**: a submitted statement starts a suspended warehouse automatically.
- Default `AUTO_SUSPEND` is 600s (10 min). Day 1 uses **60s** to conserve the $400 / 30-day trial.

Day 1 warehouse: `RETAIL_WH`, X-Small, `AUTO_SUSPEND = 60`, `AUTO_RESUME = TRUE`.

## Object hierarchy

```
Organization
  └── Account          (cloud + region chosen at signup; cannot change)
        └── Database   (RETAIL_LAKEHOUSE, SNOWFLAKE_SAMPLE_DATA)
              └── Schema  (BRONZE / SILVER / GOLD, TPCH_SF1)
                    └── Objects (tables, views, stages, pipes, tasks, …)
```

Warehouses, users, and roles live at **account** scope, not inside a database.

## Editions (trial = Enterprise)

| Edition | Notable extras |
| --- | --- |
| Standard | Core platform |
| **Enterprise** (this trial) | Multi-cluster warehouses, 90-day Time Travel, materialized views, search optimization |
| Business Critical | Tri-Secret Secure, Private Link, HIPAA/PCI options |

Cloud provider and region are **fixed at signup**. AWS is the default for this cohort.

## SNOWFLAKE_SAMPLE_DATA

Read-only share present in every account. TPC-H schemas: `TPCH_SF1`, `TPCH_SF10`, `TPCH_SF100`, `TPCH_SF1000`.

TPC-H SF1 cardinalities (spec Table 3):

| Table | Rows |
| --- | ---: |
| REGION | 5 |
| NATION | 25 |
| SUPPLIER | 10,000 |
| CUSTOMER | 150,000 |
| PART | 200,000 |
| PARTSUPP | 800,000 |
| **ORDERS** | **1,500,000** |
| LINEITEM | 6,001,215 |

`SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS` → **1500000**.

## Snowsight map

- **Worksheets** — run `sql/day01_architecture_setup.sql`
- **Data → Databases** — confirm `RETAIL_LAKEHOUSE` and the sample share
- **Data Products** — listings / shares (sample data lives here as a share)
- **Monitoring → Query History / Query Profile** — compilation (cloud services) vs execution (warehouse)
- **Admin → Warehouses / Cost Management** — remaining trial credits
