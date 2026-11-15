---
paths:
  - "app/queries/**/*.rb"
  - "spec/queries/**/*.rb"
---

# Query Object Conventions

- Context (e.g. `user:`, or the record the query is scoped to) goes in the constructor; `#call` takes optional filters and returns an `ActiveRecord::Relation` for chaining, or a `Hash` for aggregations
- User input in `LIKE`/`ILIKE`: `sanitize_sql_like` plus bound parameters — `%` and `_` in raw input match everything
