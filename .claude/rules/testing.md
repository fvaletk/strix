---
paths:
  - "spec/**/*.rb"
---

# Testing Conventions

- Specs describe the requirement (acceptance criteria), not the implementation. List the behaviors from the ticket before reading the code
- `let` (lazy) by default; `let!` only when records must exist before the example runs (e.g., scope specs)
- FactoryBot: `build` over `create` when persistence isn't needed; `subject { build(:entity) }` for validation specs
- Shoulda Matchers for validations and associations
- Request specs (`spec/requests/`), never controller specs
- If Pundit is used: policy specs cover every action for every role the app has, plus a visitor / non-member
- Stub external services and HTTP — specs never make real network calls (`stub_in_specs` in `CLAUDE.md` lists the clients)

## What gets no spec

- `config/`, `db/` (migrations, schema, seeds), `Dockerfile`, `docker-compose*.yml`, `Gemfile*`, `.env*`, assets. Test the behavior they enable, never the file: no `spec/config/` or `spec/db/`, no checks that a file exists or what `.env.example` contains.
- UI-only changes: views, partials, styles, or Stimulus — or a controller touched only to pass a variable to a view — when the acceptance criteria have no backend logic, validation, scope, or authorization rule.
