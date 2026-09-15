# Day 3 — Data Protection, Time Travel & Zero-Copy Cloning

## Overview

Day 3 focused on how Snowflake protects, recovers, copies, and works with data.

The main concepts covered were:

- Micro-partitions
- Time Travel
- `AT` and `BEFORE` queries
- `UNDROP`
- Fail-safe
- Zero-copy cloning
- Copy-on-write behavior
- `VARIANT` for semi-structured data
- JSON dot notation
- `FLATTEN`
- Clustering keys and when they are worth using

---

## 1. Time Travel

Snowflake Time Travel allows historical versions of data to be queried or recovered within the object's configured retention period.

It is useful for:

- Recovering accidentally deleted or changed data
- Investigating previous versions of a table
- Comparing current and historical data
- Undoing accidental table drops

### Historical queries

Snowflake supports `AT` and `BEFORE` clauses for querying historical data.

Example:

```sql
SELECT *
FROM retail_lakehouse.silver.tt_customers
AT (OFFSET => -300);
```

This queries the table as it existed approximately five minutes earlier.

A statement can also be used as the historical point:

```sql
SELECT *
FROM retail_lakehouse.silver.tt_customers
BEFORE (STATEMENT => LAST_QUERY_ID());
```

In this lab, `BEFORE` was used immediately after an `UPDATE` to view the state of the table before that update.

### Recovery with UNDROP

The lab intentionally dropped the table:

```sql
DROP TABLE retail_lakehouse.silver.tt_customers;
```

The table was then recovered with:

```sql
UNDROP TABLE retail_lakehouse.silver.tt_customers;
```

This demonstrated that Time Travel is not only for querying historical data; it can also support recovery from accidental object deletion.

---

## 2. Time Travel vs Fail-safe

These two concepts are related but serve different purposes.

### Time Travel

Time Travel is a user-facing feature used to:

- Query historical data
- Recover dropped objects
- Restore data after accidental changes

The available retention period depends on the Snowflake edition and object configuration.

### Fail-safe

Fail-safe is a separate Snowflake-managed recovery period that follows the Time Travel period for permanent tables.

It is intended for disaster-recovery situations and is **not** a general-purpose historical querying mechanism.

A key distinction:

> **Time Travel is for customer-controlled historical access and recovery; Fail-safe is Snowflake-managed disaster recovery.**

For the course example, a permanent table has a **7-day Fail-safe period** after Time Travel.

---

## 3. Zero-Copy Cloning

Snowflake supports zero-copy cloning of databases, schemas, and tables.

In this lab, the Silver schema was cloned:

```sql
CREATE OR REPLACE SCHEMA retail_lakehouse.silver_clone
CLONE retail_lakehouse.silver;
```

The clone initially shared the underlying micro-partition data with the source rather than creating a full physical copy immediately.

This makes cloning useful for:

- Development environments
- Testing
- Experimentation
- Temporary analysis
- Creating isolated copies of production-like data

---

## 4. Copy-on-Write and Clone Independence

Zero-copy does **not** mean that the source and clone remain permanently linked.

After cloning, changes to the clone are handled independently.

In the lab, the clone was modified:

```sql
UPDATE retail_lakehouse.silver_clone.tt_customers
SET region = 'SOUTH'
WHERE customer_id = 1;
```

The clone then contained:

- Alice → SOUTH
- Bob → NORTH
- Charlie → EAST

while the original Silver table still contained:

- Alice → EAST
- Bob → NORTH
- Charlie → EAST

This demonstrates **copy-on-write** behavior: shared data can remain shared until a modification requires separate storage.

---

## 5. Micro-partitions

Snowflake automatically stores table data in **micro-partitions**.

Micro-partitions are a fundamental part of Snowflake's storage and query-processing architecture.

Snowflake uses metadata about these partitions to help eliminate partitions that do not contain relevant data for a query. This is commonly called **partition pruning**.

For large tables, good data organization can therefore improve query performance by reducing the amount of data that needs to be scanned.

The `TT_CUSTOMERS` table in this lab was intentionally tiny, containing only three rows. Snowflake reported:

```text
total_partition_count : 1
```

Therefore, there was no meaningful partitioning problem to solve.

---

## 6. Clustering and When to Use It

Snowflake can use clustering keys to influence how table data is organized over micro-partitions.

A clustering key can be useful when:

- A table is large
- Queries repeatedly filter or join on particular columns
- Micro-partitions have significant overlap
- Better pruning can justify the additional compute/storage maintenance cost

Clustering is **not automatically beneficial for every table**.

For the lab table, we evaluated hypothetical clustering on `CUSTOMER_ID`:

```sql
SELECT SYSTEM$CLUSTERING_INFORMATION(
    'RETAIL_LAKEHOUSE.SILVER.TT_CUSTOMERS',
    '(CUSTOMER_ID)'
);
```

The result was:

```text
total_partition_count : 1
average_overlaps      : 0.0
average_depth         : 1.0
clustering_errors     : []
```

This is a healthy result for such a small table.

### Important lesson

The query above **did not create a clustering key**. It only evaluated clustering information for the specified expression.

Because the table is tiny and already consists of one micro-partition, adding a clustering key would provide little or no practical benefit and could introduce unnecessary maintenance cost.

> **Clustering should be driven by table size, workload, and measurable pruning problems—not added just to check a box.**

---

## 7. Semi-Structured Data with VARIANT

Snowflake's `VARIANT` data type can store semi-structured data such as JSON.

The lab created:

```sql
CREATE OR REPLACE TABLE retail_lakehouse.silver.customer_events (
    event_id INTEGER,
    event_data VARIANT
);
```

The `event_data` column stored nested JSON containing:

- Customer information
- Region
- An array of orders
- Order IDs
- Order amounts

Example structure:

```json
{
  "customer": {
    "name": "Alice",
    "region": "EAST"
  },
  "orders": [
    {"id": 101, "amount": 500},
    {"id": 102, "amount": 300}
  ]
}
```

---

## 8. Querying Nested JSON

Snowflake supports path-based access into `VARIANT` values.

For example:

```sql
SELECT
    event_data:customer:name::STRING AS customer_name,
    event_data:customer:region::STRING AS region
FROM retail_lakehouse.silver.customer_events;
```

This uses:

- `:` to navigate through JSON fields
- `::STRING` to cast the extracted value to a normal SQL string

This allows nested JSON to be queried without first flattening the entire document.

---

## 9. FLATTEN

JSON arrays often contain multiple elements.

Snowflake's `FLATTEN` table function converts elements of an array or object into rows.

The lab used:

```sql
SELECT
    e.event_id,
    e.event_data:customer:name::STRING AS customer_name,
    f.value:id::INTEGER AS order_id,
    f.value:amount::NUMBER AS amount
FROM retail_lakehouse.silver.customer_events AS e,
LATERAL FLATTEN(
    INPUT => e.event_data:orders
) AS f
ORDER BY e.event_id, order_id;
```

The result turned the nested order arrays into individual rows:

| Customer | Order ID | Amount |
|---|---:|---:|
| Alice | 101 | 500 |
| Alice | 102 | 300 |
| Bob | 103 | 750 |

This is a common pattern when transforming semi-structured event data into relational-style rows.

---

## 10. Key Day 3 Takeaways

### Data protection

- **Time Travel** → query and recover historical data
- **UNDROP** → recover dropped objects within the applicable retention period
- **Fail-safe** → Snowflake-managed disaster recovery after Time Travel

### Data copying

- **Zero-copy clone** → create a fast logical copy without immediately duplicating all underlying storage
- **Copy-on-write** → source and clone become independently stored where modifications require it

### Data storage and performance

- **Micro-partitions** → Snowflake's automatic storage units
- **Partition pruning** → avoids scanning irrelevant micro-partitions
- **Clustering** → can improve organization and pruning for suitable large workloads
- **Avoid premature clustering** → small tables generally do not justify the extra maintenance

### Semi-structured data

- **VARIANT** → stores semi-structured data such as JSON
- **Dot notation / path expressions** → access nested fields
- **FLATTEN** → turns nested arrays/objects into rows

---

## 11. Lab Evidence

The Day 3 lab successfully demonstrated:

1. Created `SILVER` and `GOLD` schemas.
2. Created and modified `SILVER.TT_CUSTOMERS`.
3. Queried the table before an update using `BEFORE (STATEMENT => LAST_QUERY_ID())`.
4. Dropped and recovered the table using `UNDROP`.
5. Created `SILVER_CLONE` using zero-copy cloning.
6. Modified the clone and verified that the original remained unchanged.
7. Created a `VARIANT`-based `CUSTOMER_EVENTS` table.
8. Queried nested JSON using dot notation.
9. Exploded the orders array using `FLATTEN`.
10. Aggregated order amounts by customer.
11. Inspected hypothetical clustering on `CUSTOMER_ID` and confirmed that clustering was not necessary for this tiny table.

---

## Final Principle

The main Day 3 lesson is not simply learning Snowflake commands.

It is learning to choose the right Snowflake capability for the problem:

> **Recover with Time Travel, isolate with cloning, store flexible event data with VARIANT, flatten arrays when relational analysis is needed, and use clustering only when the workload and table size justify it.**
