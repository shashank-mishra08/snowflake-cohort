-- =============================================================================
-- Day 15 — Cortex Agent (Analyst + Search + custom tool)
-- Role: ACCOUNTADMIN
-- Warehouse: LEARN_WH
--
-- Trial: CREATE AGENT / Cortex Search / Analyst REST may fail (no Cortex AI
-- credits). The custom UDF always works. Re-run CREATE AGENT on a paid account.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE LEARN_WH;
USE DATABASE RETAIL_LAKEHOUSE;
USE SCHEMA GOLD;

CREATE SCHEMA IF NOT EXISTS RETAIL_LAKEHOUSE.AGENTS;
CREATE STAGE IF NOT EXISTS RETAIL_LAKEHOUSE.GOLD.SEMANTIC_MODELS;

CREATE OR REPLACE FUNCTION RETAIL_LAKEHOUSE.GOLD.GET_CATEGORY_REVENUE(CAT STRING)
RETURNS NUMBER(38, 2)
LANGUAGE SQL
AS
$$
    SELECT SUM(TOTAL_REVENUE)
    FROM RETAIL_LAKEHOUSE.GOLD.CATEGORY_SUMMARY
    WHERE UPPER(CATEGORY) = UPPER(CAT)
$$;

GRANT USAGE ON FUNCTION RETAIL_LAKEHOUSE.GOLD.GET_CATEGORY_REVENUE(STRING) TO ROLE DATA_ANALYST;

-- Smoke the custom tool
SELECT RETAIL_LAKEHOUSE.GOLD.GET_CATEGORY_REVENUE('Electronics') AS ELECTRONICS_REVENUE;
SELECT RETAIL_LAKEHOUSE.GOLD.GET_CATEGORY_REVENUE('Furniture') AS FURNITURE_REVENUE;


CREATE OR REPLACE AGENT RETAIL_LAKEHOUSE.AGENTS.RETAIL_AGENT
    COMMENT = 'Retail lakehouse agent: Gold Analyst, FAQ Search, category revenue UDF'
    PROFILE = '{"display_name": "Retail Gold Agent", "avatar": "shopping-icon.png", "color": "blue"}'
    FROM SPECIFICATION
$$
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 30
    tokens: 16000
  tool_not_accessible: accept
instructions:
  response: "Answer concisely. Cite Gold tables or document ids. Do not invent columns."
  orchestration: >
    Use gold_analyst for structured Gold metrics (revenue, orders, categories).
    Use product_search for FAQs and policies.
    Use category_revenue when the user asks for total revenue of one named category.
    Use both gold_analyst (or category_revenue) and product_search when the
    question mixes a metric with a policy or product FAQ.
  sample_questions:
    - question: "What is total revenue by category?"
    - question: "How long do I have to return a laptop?"
    - question: "What is Electronics revenue?"
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: gold_analyst
      description: Natural-language SQL over RETAIL_LAKEHOUSE Gold tables via the retail_gold semantic model.
  - tool_spec:
      type: cortex_search
      name: product_search
      description: Hybrid search over product FAQs and policies in CORTEX.PRODUCT_DOCS.
  - tool_spec:
      type: generic
      name: category_revenue
      description: Returns SUM(TOTAL_REVENUE) for one product category from GOLD.CATEGORY_SUMMARY.
      input_schema:
        type: object
        properties:
          category:
            type: string
            description: Category name such as Electronics or Furniture.
        required:
          - category
tool_resources:
  gold_analyst:
    semantic_model_file: "@RETAIL_LAKEHOUSE.GOLD.SEMANTIC_MODELS/retail_semantic_model.yaml"
    execution_warehouse: LEARN_WH
  product_search:
    search_service: RETAIL_LAKEHOUSE.CORTEX.PRODUCT_SEARCH
    max_results: "3"
    id_column: ID
    title_column: SOURCE
  category_revenue:
    identifier: RETAIL_LAKEHOUSE.GOLD.GET_CATEGORY_REVENUE
    execution_warehouse: LEARN_WH
$$;

GRANT USAGE ON SCHEMA RETAIL_LAKEHOUSE.AGENTS TO ROLE DATA_ANALYST;
GRANT USAGE ON AGENT RETAIL_LAKEHOUSE.AGENTS.RETAIL_AGENT TO ROLE DATA_ANALYST;
