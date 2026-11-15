---
paths:
  - "db/migrate/**/*.rb"
---

# Migration Conventions

- `null: false` on every column the model validates for presence
- A unique index behind every uniqueness validation
- Associations: `references` with `foreign_key: true`
- Zero-downtime changes: add the column, backfill, then add the constraint — in separate migrations
- Indexes on large tables: `add_index ..., algorithm: :concurrently` with `disable_ddl_transaction!` — a plain `add_index` locks writes to the table
