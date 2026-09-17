# ============================================================
# Day 06: Snowpark Python Transformations
# ============================================================
#
# Objectives:
#   1. Read Bronze orders using Snowpark
#   2. Clean and deduplicate orders
#   3. Save the Silver transformation as a table
#   4. Join orders with product data
#   5. Demonstrate Snowpark window functions
#   6. Build and save a Gold category summary
#
# Architecture:
#
#   BRONZE.ORDERS
#        |
#        v
#   Snowpark DataFrame
#        |
#        v
#   SILVER.ORDERS_SNOWPARK
#        |
#        +----> Product enrichment
#        |
#        v
#   GOLD.CATEGORY_SUMMARY_SNOWPARK
#
# Snowpark pushes DataFrame operations to Snowflake for
# execution rather than pulling the data into the client.
# ============================================================


from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import (
    col,
    coalesce,
    lit,
    row_number,
    upper,
    trim,
    sum as snow_sum,
    count,
    approx_count_distinct,
)
from snowflake.snowpark.window import Window


# ------------------------------------------------------------
# 1. Get active Snowflake session
# ------------------------------------------------------------

session = get_active_session()

session.sql("USE DATABASE RETAIL_LAKEHOUSE").collect()
session.sql("USE SCHEMA RETAIL_LAKEHOUSE.SILVER").collect()


# ------------------------------------------------------------
# 2. Read Bronze Orders
# ------------------------------------------------------------

orders_df = session.table(
    "RETAIL_LAKEHOUSE.BRONZE.ORDERS"
)


# ------------------------------------------------------------
# 3. Build Silver Orders
# ------------------------------------------------------------
#
# Transformations:
#   - Replace NULL quantities with 0
#   - Cast quantity to INTEGER
#   - Normalize order status
#   - Deduplicate ORDER_ID
#   - Keep the latest record for each order
#

order_window = (
    Window
    .partition_by("ORDER_ID")
    .order_by(col("ORDER_TS").desc())
)

silver_df = (
    orders_df
    .with_column(
        "QUANTITY",
        coalesce(
            col("QUANTITY"),
            lit(0)
        ).cast("INTEGER")
    )
    .with_column(
        "ORDER_STATUS",
        upper(trim(col("ORDER_STATUS")))
    )
    .with_column(
        "ROW_NUM",
        row_number().over(order_window)
    )
    .filter(
        col("ROW_NUM") == 1
    )
    .drop("ROW_NUM")
)


# ------------------------------------------------------------
# 4. Save Snowpark Silver table
# ------------------------------------------------------------

silver_df.write.mode("overwrite").save_as_table(
    "RETAIL_LAKEHOUSE.SILVER.ORDERS_SNOWPARK"
)


# ------------------------------------------------------------
# 5. Enrich Orders with Product data
# ------------------------------------------------------------

products_df = session.table(
    "RETAIL_LAKEHOUSE.BRONZE.PRODUCTS"
)

enriched_df = (
    silver_df
    .join(
        products_df,
        silver_df["PRODUCT_ID"] == products_df["PRODUCT_ID"],
        "inner"
    )
    .select(
        silver_df["ORDER_ID"],
        silver_df["CUSTOMER_ID"],
        silver_df["PRODUCT_ID"],
        products_df["PRODUCT_NAME"],
        products_df["CATEGORY"],
        silver_df["QUANTITY"],
        products_df["PRICE"],
        (
            silver_df["QUANTITY"] * products_df["PRICE"]
        ).alias("ORDER_VALUE"),
        silver_df["ORDER_STATUS"],
        silver_df["ORDER_TS"],
    )
)


# ------------------------------------------------------------
# 6. Snowpark window functions
# ------------------------------------------------------------
#
# Demonstrates:
#   - ROW_NUMBER() equivalent
#   - Running SUM() equivalent
#

customer_order_window = (
    Window
    .partition_by("CUSTOMER_ID")
    .order_by("ORDER_TS")
)

running_total_window = (
    Window
    .partition_by("CUSTOMER_ID")
    .order_by("ORDER_TS")
    .rows_between(
        Window.UNBOUNDED_PRECEDING,
        Window.CURRENT_ROW
    )
)

windowed_df = (
    enriched_df
    .with_column(
        "CUSTOMER_ORDER_NUMBER",
        row_number().over(customer_order_window)
    )
    .with_column(
        "CUSTOMER_RUNNING_TOTAL",
        snow_sum("ORDER_VALUE").over(
            running_total_window
        )
    )
)


# ------------------------------------------------------------
# 7. Build Gold Category Summary
# ------------------------------------------------------------
#
# Cancelled orders are excluded from business metrics.
#

gold_df = (
    enriched_df
    .filter(
        col("ORDER_STATUS") != "CANCELLED"
    )
    .group_by("CATEGORY")
    .agg(
        snow_sum("ORDER_VALUE").alias(
            "TOTAL_REVENUE"
        ),
        count("*").alias(
            "ORDER_COUNT"
        ),
        approx_count_distinct(
            "CUSTOMER_ID"
        ).alias(
            "UNIQUE_CUSTOMERS"
        ),
    )
)


# ------------------------------------------------------------
# 8. Save Snowpark Gold table
# ------------------------------------------------------------

gold_df.write.mode("overwrite").save_as_table(
    "RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY_SNOWPARK"
)


# ------------------------------------------------------------
# 9. Verification
# ------------------------------------------------------------

print(
    "Snowpark Silver table created: "
    "RETAIL_LAKEHOUSE.SILVER.ORDERS_SNOWPARK"
)

print(
    "Snowpark Gold table created: "
    "RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY_SNOWPARK"
)