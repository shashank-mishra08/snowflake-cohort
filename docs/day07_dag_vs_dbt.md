# Day 7 — Task DAGs vs dbt on Snowflake

## Task DAG

The Day 7 Task DAG implements an imperative orchestration pattern:

Bronze Ingestion → Silver Merge → Gold Refresh

### Bronze Ingestion
Loads records from the Bronze landing table into the Bronze orders table.

### Silver Merge
Runs AFTER the Bronze ingestion task and cleans/deduplicates orders into Silver.

### Gold Refresh
Runs AFTER the Silver merge and rebuilds the category revenue summary.

The complete three-task DAG was manually executed and verified through
`INFORMATION_SCHEMA.TASK_HISTORY()`.

All three tasks completed successfully in dependency order.

## Serverless Task

A separate Bronze ingestion task was created without a `WAREHOUSE` clause.

The required account privilege was granted:

```sql
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE ACCOUNTADMIN;