# Day 01 verifier answers

Run `sql/day01_architecture_setup.sql` in Snowsight, then submit:

## Q1) What does `SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;` return? (number, no commas)

**1500000**

TPC-H scale factor 1 defines 1,500,000 rows in `ORDERS`. Snowflake's `TPCH_SF1` share is that dataset.

## Q2) How many layers make up Snowflake's architecture? (number)

**3**

Storage, compute (virtual warehouses), and cloud services.

## Q3) Which warehouse parameter stops a warehouse from spending credits while it sits idle? (parameter name)

**AUTO_SUSPEND**

Seconds of inactivity after which the warehouse suspends. `AUTO_RESUME` starts it again when a query arrives; it does not stop idle spend by itself.
