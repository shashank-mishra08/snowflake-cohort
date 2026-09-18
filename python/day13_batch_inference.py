"""Day 13 — batch score GOLD via the Model Registry champion.

Run inside a Snowflake Notebook / stored procedure (get_active_session),
or from a warehouse-attached client. Scores FEATURE_STORE.PIT_TRAINING_SET
with churn_model default version and writes GOLD.CHURN_SCORES.
"""

from snowflake.snowpark.context import get_active_session
from snowflake.ml.registry import Registry

FEATURE_COLS = [
    "LOG_PRIOR_SPEND",
    "DAYS_SINCE_FIRST_ORDER",
    "PRIORITY_ORDINAL",
]


def score_pit_table(session=None):
    session = session or get_active_session()
    reg = Registry(
        session=session,
        database_name="RETAIL_LAKEHOUSE",
        schema_name="ML_MODELS",
    )
    # .default is the champion alias — do not hard-code v1 here.
    source = session.table("RETAIL_LAKEHOUSE.FEATURE_STORE.PIT_TRAINING_SET").select(
        "CUSTOMER_ID",
        "TS",
        "IS_FULFILLED",
        *FEATURE_COLS,
    )
    preds = (
        reg.get_model("churn_model")
        .default.run(source, function_name="predict")
    )
    preds.write.mode("overwrite").save_as_table(
        "RETAIL_LAKEHOUSE.GOLD.CHURN_SCORES"
    )
    return session.table("RETAIL_LAKEHOUSE.GOLD.CHURN_SCORES")


if __name__ == "__main__":
    out = score_pit_table()
    print("scored rows", out.count())
    out.limit(8).show()
