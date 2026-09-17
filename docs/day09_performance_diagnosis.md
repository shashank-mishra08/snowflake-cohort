# Day 9 — Performance diagnosis

Account `PAYDEGL-YJ88482`. Warehouse `LEARN_WH`. All times from
`INFORMATION_SCHEMA.QUERY_HISTORY` and `GET_QUERY_OPERATOR_STATS`.

## Slow query profile (before / after)

Deliberately slow statement: `CREATE TRANSIENT TABLE ... AS SELECT ... FROM
SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM ORDER BY l_comment, l_shipinstruct,
l_extendedprice, l_orderkey` (59,986,052 rows). Result cache off. Warehouse
suspended first so SSD cache would not hide the scan.

| | X-Small (before) | Small (after) |
| --- | --- | --- |
| Query ID | `01c721f3-0002-9f2c-000e-da0600027e9a` | `01c721f4-0002-a059-000e-da060002f8a6` |
| Elapsed | **29.826 s** (exec 29.497 s) | **16.575 s** (exec 16.055 s) |
| Most expensive node | CreateTableAsSelect **40.6%** | CreateTableAsSelect **44.7%** |
| Sort node | **38.6%** | **35.7%** |
| Bytes spilled to local storage | **2,782,392,320 (2.59 GB)** | **0** |
| Bytes spilled to remote | 0 | 0 |
| TableScan | 20.5%, 2.54 GB, 37% warehouse cache | 18.5%, 2.54 GB, 37% warehouse cache |

**What was slow.** The Sort operator. It ingested 119,972,104 rows (build +
probe of the 59.9M LINEITEM rows) and spilled 2.59 GB to local SSD on X-Small.

**Why.** X-Small is one node. Sorting a wide row (VARCHAR `L_COMMENT` +
`L_SHIPINSTRUCT` plus numerics) does not fit in memory, so Snowflake pages the
sort to local storage. Local spill is cheaper than remote spill, but it still
dominates elapsed time. CreateTableAsSelect is the single largest slice only
because it then writes 1.27 GB to `BRONZE.DAY09_SPILL_SINK`.

**What changed.** `ALTER WAREHOUSE LEARN_WH SET WAREHOUSE_SIZE = 'SMALL'` (no
downtime). The identical CTAS on Small finished in 16.6 s and the Sort node
**did not spill**. Memory doubled with the warehouse size; the sort stayed
in-memory. Warehouse was set back to X-Small afterwards.

Screenshot: [`screenshots/day09_query_profile.png`](../screenshots/day09_query_profile.png).

A window-function `ROW_NUMBER() OVER (ORDER BY ...)` over the same table did
**not** spill on X-Small (10.6 s, WindowFunction 59%). The lab step is
therefore the CTAS sort, not `SELECT *` into the worksheet.

## Result cache

Identical SQL:

```sql
SELECT COUNT(*) AS filled_order_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
WHERE o_orderstatus = 'F';
```

| | Query ID | Elapsed | Bytes scanned | Warehouse |
| --- | --- | ---: | ---: | --- |
| Miss | `01c721ed-0002-9e9b-000e-da0600029bf6` | 1,064 ms | 42,282,736 | X-Small |
| Hit | `01c721ed-0002-9e9b-000e-da0600029bfa` | 217 ms | **0** | none (Cloud Services) |

The hit served the persisted result. Cache applies only to **identical SQL
text** over **unchanged data**, with no non-deterministic functions. Results
are kept **24 hours** after last use (reset on each hit, max 31 days).

Unfiltered 3-way TPC-H SF1 join + `ORDER BY l_comment LIMIT 1000`
(`01c721ec-0002-9e9b-000e-da0600029bc2`, 3.577 s): most expensive operators
were TableScan LINEITEM 36.8% (100 MB) and TableScan ORDERS 35.6%. The LIMIT
became SortWithLimit (1.1%) — it did not spill.

## Slowest pipeline run (Day 5 Dynamic Tables)

Picked from `QUERY_HISTORY_BY_WAREHOUSE('LEARN_WH')` excluding this lab's
TPC-H sorts.

- **What was slow.** `REFRESH DYNAMIC TABLE` of
  `RETAIL_LAKEHOUSE.GOLD.PRODUCT_SUMMARY_DT`
  (`01c721ed-0002-9e9b-000e-da0600029bee`) at **1,798 ms**, just after
  `SILVER.PRODUCTS_DT` at 1,581 ms. These are the slowest Day 5/7 pipeline
  statements still in history. Day 7 task DAG rows were smaller (tiny
  `ORDERS_LANDING` inserts).
- **Why.** `GET_QUERY_OPERATOR_STATS` for the gold refresh is a single
  **METADATA-BASED RESULT** node (100%). Bronze did not change, so Snowflake
  skipped a data refresh and still paid Cloud Services + warehouse resume
  overhead because `TARGET_LAG = '5 minutes'` keeps scheduling the graph.
  Gold is downstream of silver, so a silver refresh unblocks a gold refresh
  even when the gold aggregate would be identical.
- **What I'd change.** Raise `TARGET_LAG` (or use `DOWNSTREAM` on gold so it
  only refreshes when silver actually produced new rows). `ALTER DYNAMIC TABLE
  ... SUSPEND` outside demo windows. Do **not** turn on Query Acceleration or
  Search Optimization here — the table is tiny; those services help large
  scans and point lookups, not metadata-only refreshes. If product volume
  grew into millions of rows, I would cluster `BRONZE.PRODUCTS` on
  `CATEGORY` and keep gold as an incremental DT rather than
  `INSERT OVERWRITE`.

## Cost so far (Admin → Cost Management equivalent)

`INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY` for the last 20 days:

| Warehouse | Credits |
| --- | ---: |
| `COMPUTE_WH` | 4.16 |
| `LEARN_WH` | 0.79 |
| Cloud Services only | 0.002 |

Heaviest calendar day: **2026-09-15 on `COMPUTE_WH` (1.83 credits)** — Day 1–2
setup, first TPC-H probes, and Snowsight exploration on the default warehouse.
`LEARN_WH` peaked on **2026-09-17 (0.56 credits)** because of this Day 9 spill
lab (SF10 LINEITEM sort twice) plus Dynamic Table refreshes.

Resource monitor `TRIAL_BUDGET`: quota **50 credits / month**, **NOTIFY at
75%**, **SUSPEND at 100%**, assigned to `LEARN_WH`.
