---
paths:
  - "app/controllers/**/*.rb"
  - "spec/requests/**/*.rb"
---

# Controller Conventions

- If Pundit is used: `authorize` on every action, and `policy_scope(Model)` instead of `Model.all` in index actions
- REST actions only (index, show, new, create, edit, update, destroy) — a non-REST action is usually a new resource controller
- Service results: `if result.success?` redirect or render; on failure re-render the form with `status: :unprocessable_entity` (Turbo shows nothing without it). Branch on `result.code` only where codes need different responses — e.g. `:not_found` → 404, `:forbidden` → 403, `:conflict` → 409
- Request specs: cover unauthenticated and unauthorized access, asserting the status or redirect the app already returns for them (check `ApplicationController`'s rescue)
