# Day 11 — Why train inside Snowflake

Snowpark ML's `StandardScaler`, `OneHotEncoder`, and `RandomForestClassifier`
use the same `.fit()` / `.predict()` surface as scikit-learn, but the work
runs as Snowflake warehouse jobs next to `GOLD.ML_ORDERS` / `GOLD.DAILY_REVENUE`.
A plain `df.to_pandas()` + local sklearn path copies the table to the client:
that breaks on large Gold tables (memory, network, warehouse idle while the
laptop trains) and it also copies data *out* of the account, so RBAC, masking,
and the `TRIAL_BUDGET` monitor no longer wrap the training step.

Keeping training in-platform matters for two reasons: **scale** (encoders and
forests scale with warehouse size, not laptop RAM) and **governance** (the
model only sees rows the current role can `SELECT`; nothing lands in a CSV on
disk). Built-in `SNOWFLAKE.ML.FORECAST` goes further — no Python environment
at all. We trained `GOLD.DAILY_REVENUE_FORECAST` on 2,406 daily TPC-H points
and produced 14 days of forecasts (1998-08-03 .. 1998-08-16, ~94.16M/day)
with `CALL`/`TABLE(...!FORECAST(FORECASTING_PERIODS => 14))`.

Do **not** train `SNOWFLAKE.ML.FORECAST` on `GOLD.ORDERS_OVER_TIME` (2 days).
That series is too short; the worksheet builds `GOLD.DAILY_REVENUE` from
TPC-H SF1 order dates instead.
