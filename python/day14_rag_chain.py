"""Day 14 — minimal RAG: Cortex Search retrieve → prompt → COMPLETE.

Retrieve top-k chunks, build a grounded prompt, generate with
SNOWFLAKE.CORTEX.COMPLETE. On trial accounts COMPLETE and Search
embeddings are blocked (error 399258); retrieval then falls back to
SQL keyword search and generation falls back to quoting the top chunk
so answers stay grounded instead of hallucinated.
"""

from __future__ import annotations

import json
import re

from snowflake.snowpark.context import get_active_session

MODEL = "llama3.1-8b"
SEARCH_SERVICE = "RETAIL_LAKEHOUSE.CORTEX.PRODUCT_SEARCH"
DOCS_TABLE = "RETAIL_LAKEHOUSE.CORTEX.PRODUCT_DOCS"
TOP_K = 3

SYSTEM = (
    "You answer only from the retrieved context. "
    "If the context does not contain the answer, say you do not know. "
    "Cite the document id in brackets, for example [faq-returns]."
)


def _session():
    try:
        return get_active_session()
    except Exception:
        from snowflake.snowpark import Session

        try:
            return Session.builder.config("connection_name", "dev").create()
        except Exception:
            return Session.builder.getOrCreate()


def retrieve(session, question: str, k: int = TOP_K) -> list[dict]:
    """Cortex Search first; keyword ILIKE if embeddings are unavailable."""
    payload = json.dumps(
        {"query": question, "columns": ["ID", "TEXT", "SOURCE"], "limit": k}
    )
    try:
        raw = session.sql(
            "SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(?, ?))['results'] AS R",
            params=[SEARCH_SERVICE, payload],
        ).collect()[0]["R"]
        rows = json.loads(raw) if isinstance(raw, str) else raw
        if rows:
            return [
                {
                    "id": r.get("ID") or r.get("id"),
                    "text": r.get("TEXT") or r.get("text"),
                    "source": r.get("SOURCE") or r.get("source"),
                }
                for r in rows
            ]
    except Exception as exc:  # noqa: BLE001 — trial 399258
        print("SEARCH_PREVIEW unavailable, using keyword retrieve:", exc)

    tokens = [t for t in re.findall(r"[a-zA-Z0-9]+", question.lower()) if len(t) > 3]
    if not tokens:
        tokens = ["policy"]
    like = " OR ".join([f"LOWER(TEXT) LIKE '%{t}%'" for t in tokens[:6]])
    hits = session.sql(
        f"""
        SELECT ID, TEXT, SOURCE
        FROM {DOCS_TABLE}
        WHERE {like}
        LIMIT {k}
        """
    ).collect()
    return [{"id": r["ID"], "text": r["TEXT"], "source": r["SOURCE"]} for r in hits]


def _prompt(question: str, chunks: list[dict]) -> str:
    context = "\n\n".join(f"[{c['id']}] ({c['source']}) {c['text']}" for c in chunks)
    return (
        f"{SYSTEM}\n\nContext:\n{context}\n\n"
        f"Question: {question}\nAnswer:"
    )


def generate_with_complete(session, question: str, chunks: list[dict]) -> str:
    """Always call SNOWFLAKE.CORTEX.COMPLETE; quote the top chunk if blocked."""
    prompt = _prompt(question, chunks)
    try:
        out = session.sql(
            "SELECT SNOWFLAKE.CORTEX.COMPLETE(?, ?) AS ANSWER",
            params=[MODEL, prompt],
        ).collect()[0]["ANSWER"]
        return str(out)
    except Exception as exc:  # noqa: BLE001 — trial 399258
        print("COMPLETE unavailable:", exc)
        if not chunks:
            return "I do not know. No retrieved context."
        top = chunks[0]
        return (
            f"{top['text']} [{top['id']}] "
            "(extractive fallback; Cortex COMPLETE not enabled on this account)"
        )


def answer(question: str, session=None) -> dict:
    session = session or _session()
    chunks = retrieve(session, question)
    text = generate_with_complete(session, question, chunks)
    return {"question": question, "chunks": chunks, "answer": text}


if __name__ == "__main__":
    tests = [
        "How long do I have to return a laptop?",
        "What does the laptop hardware warranty cover?",
        "Do analysts see unmasked customer emails?",
    ]
    for q in tests:
        result = answer(q)
        print("\nQ:", result["question"])
        print("retrieved:", [c["id"] for c in result["chunks"]])
        print("A:", result["answer"][:400])
