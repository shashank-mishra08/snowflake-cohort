# Day 15 — Cortex Agent tool tests

Agent: `RETAIL_LAKEHOUSE.AGENTS.RETAIL_AGENT` (created 2026-09-17).
**Three tools:**

| Tool | Type | Resource |
| --- | --- | --- |
| `gold_analyst` | `cortex_analyst_text_to_sql` | staged `retail_semantic_model.yaml` |
| `product_search` | `cortex_search` | `CORTEX.PRODUCT_SEARCH` (Day 14; embeddings blocked on trial) |
| `category_revenue` | custom UDF | `GOLD.GET_CATEGORY_REVENUE(STRING)` |

`SNOWFLAKE.CORTEX.DATA_AGENT_RUN` returns **399504 Access denied for trial accounts**. Orchestration LLM cannot run here. Each question was executed on the **tool that the spec says to pick**, and the live result is recorded. Re-run `DATA_AGENT_RUN` on a paid account to confirm the orchestrator agrees.

## Five mixed questions

| # | Question | Expected tool(s) | Live tool result | Verdict |
| --- | --- | --- | --- | --- |
| 1 | What is total revenue by category? | `gold_analyst` | `GOLD.CATEGORY_SUMMARY`: Electronics **313,900** (7 orders, 6 customers); Furniture **30,000** (2 orders, 2 customers) | **Pass** — structured Gold, not docs |
| 2 | How long do I have to return a laptop? | `product_search` | Keyword retrieve `faq-returns`: **30 days**, unused, original packaging | **Pass** — FAQ, not SQL |
| 3 | What is Electronics revenue? | `category_revenue` | `GET_CATEGORY_REVENUE('Electronics')` = **313900.00** | **Pass** — named category → UDF |
| 4 | Do analysts see unmasked customer emails? | `product_search` | `policy-masking`: ANALYST sees **masked** email/phone; Cortex runs as caller role | **Pass** — policy doc |
| 5 | What is Furniture revenue, and how long does desk assembly take? | `category_revenue` **and** `product_search` | UDF Furniture = **30000.00**; `faq-desk`: assembly **~40 minutes** | **Pass** — metric + FAQ |

Wrong tool would be: answering (2) from `CATEGORY_SUMMARY`, or answering (1) from FAQs.

## Snowflake Intelligence / CoWork (trial)

`DATA_AGENT_RUN` is blocked, so CoWork chat will not answer until Cortex Agents is enabled.

Exact steps when the account allows it:

1. Role with `USAGE` on `RETAIL_LAKEHOUSE.AGENTS.RETAIL_AGENT` (already granted to `DATA_ANALYST`).
2. Snowsight → **AI & ML** → **Agents** (or **Snowflake Intelligence / CoWork**).
3. Open **Retail Gold Agent**.
4. Ask the five questions above; confirm tool chips match the table.
5. Share the agent with a business role (`GRANT USAGE ON AGENT … TO ROLE DATA_ANALYST`). No SQL required for that user.
