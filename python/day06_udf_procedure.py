# ============================================================
# Day 06: Python UDF & Stored Procedure
# ============================================================
#
# Objectives:
#   1. Register a Python UDF for reusable text cleaning
#   2. Demonstrate calling the UDF from SQL
#   3. Register a Snowpark Python stored procedure
#   4. Encapsulate Bronze -> Silver transformation logic
#
# ============================================================


from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import (
    udf,
    col,
    coalesce,
    lit,
    row_number,
    upper,
    trim,
)
from snowflake.snowpark.types import StringType
from snowflake.snowpark.window import Window


# ------------------------------------------------------------
# 1. Get active Snowflake session
# ------------------------------------------------------------

session = get_active_session()

session.sql("USE DATABASE RETAIL_LAKEHOUSE").collect()
session.sql("USE SCHEMA RETAIL_LAKEHOUSE.SILVER").collect()


# ------------------------------------------------------------
# 2. Register Python UDF
# ------------------------------------------------------------
#
# CLEAN_TEXT:
#   - Handles NULL values
#   - Removes leading/trailing whitespace
#   - Converts text to uppercase
#

@udf(
    name="CLEAN_TEXT",
    input_types=[StringType()],
    return_type=StringType(),
    replace=True,
)
def clean_text(value: str) -> str:
    if value is None:
        return None

    return value.strip().upper()


print("CLEAN_TEXT UDF registered successfully.")


# ------------------------------------------------------------
# 3. Example SQL usage
# ------------------------------------------------------------

udf_test = session.sql("""
    SELECT
        PRODUCT_NAME,
        CLEAN_TEXT(PRODUCT_NAME) AS CLEANED_PRODUCT_NAME
    FROM RETAIL_LAKEHOUSE.BRONZE.PRODUCTS
    ORDER BY PRODUCT_ID
""")

udf_test.show()


# ------------------------------------------------------------
# 4. Stored procedure transformation
# ------------------------------------------------------------
#
# The procedure reads Bronze Orders, cleans the data,
# deduplicates ORDER_ID using the latest ORDER_TS,
# and writes the result to a Silver table.
#

def build_silver_orders(session):

    orders_df = session.table(
        "RETAIL_LAKEHOUSE.BRONZE.ORDERS"
    )

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

    silver_df.write.mode("overwrite").save_as_table(
        "RETAIL_LAKEHOUSE.SILVER.ORDERS_PROCEDURE"
    )

    return (
        "Silver orders transformation "
        "completed successfully"
    )


# ------------------------------------------------------------
# 5. Register stored procedure
# ------------------------------------------------------------

build_silver_orders_proc = session.sproc.register(
    func=build_silver_orders,
    name="BUILD_SILVER_ORDERS",
    return_type=StringType(),
    input_types=[],
    replace=True,
)

print(
    "BUILD_SILVER_ORDERS procedure "
    "registered successfully."
)


# ------------------------------------------------------------
# 6. Execute the stored procedure
# ------------------------------------------------------------

result = session.sql("""
    CALL RETAIL_LAKEHOUSE.SILVER.BUILD_SILVER_ORDERS()
""")

result.show()


# ------------------------------------------------------------
# 7. Verify procedure output
# ------------------------------------------------------------

verification = session.sql("""
    SELECT
        *
    FROM RETAIL_LAKEHOUSE.SILVER.ORDERS_PROCEDURE
    ORDER BY ORDER_ID
""")

verification.show()


# ============================================================
# End of Day 06 UDF & Stored Procedure
# ============================================================