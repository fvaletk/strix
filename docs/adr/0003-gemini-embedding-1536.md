# Embeddings: gemini-embedding-2 at 1536 dimensions

Status: Accepted. Replaces [ADR 0001](0001-gemini-embedding-768.md).

Articles are embedded with `gemini-embedding-2`, truncated to 1536 dimensions (Matryoshka), and stored in a pgvector `vector(1536)` column with an HNSW index. The model's 3072-dimension default exceeds pgvector's 2,000-dimension HNSW limit for `vector`; 1536 is under that limit and gives better retrieval quality than 768. Storage at 1536 is double 768, which is trivial at this scale. Gemini was chosen over Voyage and OpenAI embeddings so one provider and one API key cover both text and embeddings, not on price — all three cost well under $1 per 1,000 Articles (pricing checked 2026-11-15).

`gemini-embedding-2` auto-normalizes truncated dimensions (768 and 1536 among them), so vectors at 1536 are unit length without extra work. `Llm::Client#embed` still normalizes defensively.

`gemini-embedding-2` rejects a `task_type` field, so the task is a text prefix instead: documents use `title: none | text: …` and queries use `task: question answering | query: …` (decided 2026-11-16, BRA-126). `embed` sends at most 100 texts per `batchEmbedContents` request.

The dimension is read from `config/strix.yml` (`llm.embedding_dimensions`). No Chunks existed when it moved from 768 to 1536, so nothing needed re-embedding.

## Consequences

Changing the model or the dimension means re-embedding every Article and migrating the column. Vectors from different models or dimensions are not comparable and must never share a column.
