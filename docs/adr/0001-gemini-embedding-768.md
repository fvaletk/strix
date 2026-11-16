# Embeddings: gemini-embedding-2 at 768 dimensions

Status: Replaced by [ADR 0003](0003-gemini-embedding-1536.md).

Articles are embedded with `gemini-embedding-2`, truncated to 768 dimensions (Matryoshka), and stored in a pgvector `vector(768)` column with an HNSW index. The model's 3072-dimension default exceeds pgvector's 2,000-dimension HNSW limit for `vector`, and 768 keeps storage at a quarter with little expected loss in retrieval quality. Gemini was chosen over Voyage and OpenAI embeddings so one provider and one API key cover both text and embeddings, not on price — all three cost well under $1 per 1,000 Articles (pricing checked 2026-11-15).

## Consequences

Changing the model or the dimension means re-embedding every Article and migrating the column. Vectors from different models or dimensions are not comparable and must never share a column.
