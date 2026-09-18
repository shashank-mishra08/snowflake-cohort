"""Day 10 — Streamlit in Snowflake app.

Open Projects → Streamlit → + Streamlit App, paste this file, set
database RETAIL_LAKEHOUSE / warehouse LEARN_WH. It uses the active
Snowpark session — no external host.

The selectbox re-queries GOLD.ORDER_FACTS live (Snowpark filter),
it does not only slice a cached pandas frame.
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col

st.set_page_config(page_title="Retail Gold", layout="wide")
st.title("Retail Gold — category explorer")
st.caption("Gold tables only. Filter re-runs the Snowflake query.")

session = get_active_session()

summary = (
    session.table("RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY")
    .to_pandas()
)
categories = ["All"] + sorted(summary["CATEGORY"].dropna().astype(str).unique().tolist())
choice = st.selectbox("Category", categories)

facts = session.table("RETAIL_LAKEHOUSE.GOLD.ORDER_FACTS")
if choice != "All":
    facts = facts.filter(col("CATEGORY") == choice)

df = facts.to_pandas()

kpi1, kpi2, kpi3 = st.columns(3)
completed = df[df["ORDER_STATUS"] != "CANCELLED"] if not df.empty else df
kpi1.metric("Orders", int(len(df)))
kpi2.metric(
    "Revenue",
    f"${completed['ORDER_VALUE'].sum():,.0f}" if not completed.empty else "$0",
)
kpi3.metric(
    "Customers",
    int(completed["CUSTOMER_ID"].nunique()) if not completed.empty else 0,
)

st.subheader("Revenue by product")
if df.empty:
    st.info("No orders for this category.")
else:
    by_product = (
        completed.groupby("PRODUCT_NAME", as_index=False)["ORDER_VALUE"]
        .sum()
        .sort_values("ORDER_VALUE", ascending=False)
        .set_index("PRODUCT_NAME")[["ORDER_VALUE"]]
    )
    st.bar_chart(by_product)
    st.dataframe(df.sort_values("ORDER_TS"), use_container_width=True)
