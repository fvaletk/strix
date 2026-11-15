# pgvector in every environment, no dedicated vector database

Chunks and their embeddings live in Postgres via pgvector, in development, test, CI and production alike (`pgvector/pgvector:pg16`). We considered Chroma locally with Pinecone in production, and Pinecone everywhere. Splitting engines by environment means retrieval results differ between where we build and where we run; a hosted vector database adds cost, a network hop on every search, and a second copy of the data whose User, Article and Tag metadata must be kept in sync for filtering. At the expected scale — about one Article a day, a few thousand Chunks a year — pgvector is far within its limits, and keeping Chunks beside Articles makes filtered retrieval a single SQL query.

## Consequences

Revisit only past roughly a million Chunks, or if retrieval latency becomes a problem. pgvector's HNSW index caps `vector` at 2,000 dimensions (see ADR 0001).
