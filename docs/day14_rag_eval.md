# Day 14 — RAG eval and grounding

Corpus: `CORTEX.PRODUCT_DOCS` (8 synthetic FAQ/policy snippets). Search
service DDL: `CREATE CORTEX SEARCH SERVICE product_search`. This **trial
account blocks Cortex AI** (`399258`: COMPLETE, EMBED_TEXT_768 / Search,
AI_CLASSIFY, AI_EXTRACT, SUMMARIZE). Retrieval below used keyword `ILIKE`
on the same table the Search Service indexes. Generation used the extractive
fallback in `python/day14_rag_chain.py` (the script still **calls**
`SNOWFLAKE.CORTEX.COMPLETE`).

## Test questions

| # | Question | Retrieved ids | Grounded? | Answer (from chunk, not invented) |
| --- | --- | --- | --- | --- |
| 1 | How long do I have to return a laptop? | `faq-returns` | **Yes** | Returns within **30 days** of delivery if unused / original packaging. Restocking 10% on opened electronics. `[faq-returns]` |
| 2 | What does the laptop hardware warranty cover? | `faq-warranty`, `faq-battery`, `faq-desk` | **Yes** | **12-month** limited hardware warranty for manufacturing defects. Spills, accidental damage, lost chargers not covered. `[faq-warranty]` |
| 3 | Do analysts see unmasked customer emails? | `policy-masking` | **Yes** | **No.** Masking policy: ANALYST sees masked email/phone; ACCOUNTADMIN may unmask. Cortex runs as the caller role. `[policy-masking]` |

No hallucinated numbers (for example a 14-day return window or 24-month
default warranty) appeared because the fallback **quotes the retrieved
chunk**. If COMPLETE were enabled and an answer cited a fact not in the
top-k texts, we would: drop that answer, add the missing FAQ to
`PRODUCT_DOCS`, tighten the system prompt (“answer only from context”),
and re-check `SEARCH_PREVIEW` before regenerating.

## Governance

Cortex Search, AISQL, and Document AI objects are Snowflake objects. The
same Day 2 RBAC and masking apply: `DATA_ANALYST` only sees what `GRANT
SELECT` allows, and COMPLETE runs as the current role.

## Trial vs paid

After Cortex is enabled, re-run `sql/day14_cortex.sql` (Search index +
`SEARCH_PREVIEW` + `AI_EXTRACT`) and `python/day14_rag_chain.py` without
the fallbacks. Keep the same 3 questions and require each answer to cite
a retrieved `id`.
