# Day 12 — Feature Store, EDA, point-in-time training

## EDA (`GOLD.CUSTOMER_ORDER_EVENTS`)

Source: all TPC-H SF1 orders for `O_CUSTKEY` 1–400 — **3,926 rows, 267 customers**,
about 15 orders each. A random `SAMPLE` of orders collapses to ~1 order per
customer and makes prior-history features empty.

`df.describe()` / null counts:

| Column | Nulls | Notes |
| --- | ---: | --- |
| CUSTOMER_ID, ORDER_ID, TS, ORDER_PRIORITY, IS_FULFILLED | 0 | clean |
| ORDER_VALUE | 0 | skewed: min 1,131 · mean 151,821 · max 449,551 — log-scale |
| SHIP_PRIORITY | 0 | **constant 0** — drop, no signal |
| IS_FULFILLED | 0 | ~50/50 |

## Engineered features (version `customer_features` / `1`)

Computed with `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING` so the
**labeled order is not in its own features**.

| Feature | Type | Definition |
| --- | --- | --- |
| `LOG_PRIOR_SPEND` | numeric | `LN(1 + sum of prior ORDER_VALUE)` |
| `DAYS_SINCE_FIRST_ORDER` | time | days from the customer's first order to this timestamp |
| `PRIORITY_ORDINAL` | categorical | `OrdinalEncoder` of the **previous** order's `ORDER_PRIORITY` (`NONE` on the first order) |

Registered:

- **Entity** `CUSTOMER` join key `CUSTOMER_ID`
- **FeatureView** `customer_features` version `1`, `timestamp_col=TS`, `refresh_freq='1 day'`
- Schema `RETAIL_LAKEHOUSE.FEATURE_STORE` (Dynamic Table `CUSTOMER_FEATURES$1`)

## Point-in-time vs a plain join (no leakage)

`fs.generate_training_set(spine_timestamp_col='TS')` as-of joins each label to
the latest feature row with `feature.TS <= label.TS`.

A plain `JOIN ON CUSTOMER_ID` would attach the customer's **latest** spend
(including orders after the label) to historical labels — that is label leakage.
The Feature Store join never uses a feature snapshot from the future.

Saved as `FEATURE_STORE.PIT_TRAINING_SET` (3,926 rows).

## Before / after metric (RandomForestClassifier, 80/20, seed 42)

| Training columns | Accuracy |
| --- | ---: |
| Day 11 ad-hoc: current `ORDER_VALUE` + current priority (leaky same-row) | **0.515** |
| Majority class | 0.500 |
| Day 12 PIT: `LOG_PRIOR_SPEND` + `DAYS_SINCE_FIRST_ORDER` + `PRIORITY_ORDINAL` | **0.963** |
| `DAYS_SINCE_FIRST_ORDER` alone | 0.957 |
| `LOG_PRIOR_SPEND` + `PRIORITY_ORDINAL` (no recency) | 0.788 |

The jump is mostly TPC-H: `F` (fulfilled) vs `O` (open) tracks how old the order
is, so days-since-first is a near-proxy for the label. PIT is still the correct
join; we did **not** feed current `ORDER_VALUE` or `IS_FULFILLED` into the
feature row.
