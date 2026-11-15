---
paths:
  - "app/models/**/*.rb"
  - "spec/models/**/*.rb"
  - "spec/factories/**/*.rb"
---

# Model Conventions

- Defaults: `attribute :status, default: "draft"` or a database default — not `after_initialize`
- Always specify `dependent:` on `has_many`/`has_one` associations
- Enums: `enum :status, { draft: 0, published: 1 }` (hash syntax, explicit integers)
- Every model has a factory in `spec/factories/` with a trait per state
