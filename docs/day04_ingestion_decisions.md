# Day 4 — Data Ingestion Decisions

## Overview

Day 4 focuses on Snowflake data loading and connectivity patterns.

The main ingestion methods covered are:

1. `COPY INTO`
2. Snowpipe
3. Snowpipe Streaming
4. Openflow
5. External Tables

The key decision is not simply which method is "better", but which ingestion pattern matches the source, latency requirement, operational model, and whether data should physically reside in Snowflake.

---

## 1. COPY INTO

### What it is

`COPY INTO` is Snowflake's SQL command for loading data from staged files into tables.

Typical flow:

```text
Source Files
     ↓
Internal / External Stage
     ↓
COPY INTO
     ↓
Snowflake Table