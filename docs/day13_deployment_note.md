# Day 13 — Registry, batch inference, drift

`churn_model` version **`v1`** (Snowflake: `CHURN_MODEL` / `V1`) lives in
`RETAIL_LAKEHOUSE.ML_MODELS`. Champion: `model.default = "v1"` plus alias
`PRODUCTION`. Batch scores: `GOLD.CHURN_SCORES` (3,926 rows).

Tuned with GridSearchCV on Day 12 PIT features
(`LOG_PRIOR_SPEND`, `DAYS_SINCE_FIRST_ORDER`, `PRIORITY_ORDINAL`).
`best_params_`: `max_depth=8`, `min_samples_leaf=4`, `n_estimators=10`.
Test **F1 0.959 · AUC 0.990**. F1 is the business metric: classes are balanced
and both a missed fulfilled order and a false open-order flag cost ops.

Real-time: `SELECT CHURN_MODEL!PREDICT(12.11::FLOAT, 7::NUMBER, 2.0::FLOAT)`
returned `{"output_feature_0": 1}` on this trial.

## Drift monitoring (production)

1. **Feature drift** — weekly PSI / KS on `LOG_PRIOR_SPEND`,
   `DAYS_SINCE_FIRST_ORDER`, `PRIORITY_ORDINAL` vs the `v1` training window.
   Alert if PSI > 0.2. Recency dominates this model; a shift in order age mix
   will move scores even if spend is stable.
2. **Prediction drift** — compare the live distribution of
   `PREDICT_PROBA` / `output_feature_0` to training-time scores (same bins).
   A sudden jump in predicted-1 rate without a matching label shift is a
   serving bug or a population change.
3. **Performance drift** — once labels arrive (order status settles), compute
   trailing-30-day F1/AUC on `GOLD.CHURN_SCORES` vs `IS_FULFILLED`. Drop of
   5+ F1 points from 0.959 triggers a challenger retrain.
4. **Champion / challenger** — log `v2` without flipping `.default`. Score both
   on a holdout slice; promote with `model.default = "v2"` only after F1 holds.
   Keep `v1` for rollback (`ALTER MODEL … SET DEFAULT_VERSION = V1`).
5. **Freshness** — FeatureView `customer_features` refreshes daily; if the
   Dynamic Table lags, PIT features go stale and look like drift. Monitor
   `LAST_COMPLETED_REFRESH` alongside PSI.
