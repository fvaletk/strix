# Strix

Personal reading assistant. Save URLs, get summaries and tags,
ask questions over what you've saved, receive a weekly digest.

## Stack
Rails 8, Postgres + pgvector (neighbor), Tailwind, Hotwire,
ViewComponent, Sidekiq, RSpec, Kamal.

## Commands
- Test: `bin/rspec`      - Lint: `bin/rubocop -a`
- Dev: `bin/dev`         - Migrate: `bin/rails db:migrate`

## Conventions
- Conventions live in `.claude/rules/`. Read the ones matching the files you touch.
- `db/schema.rb` is the source of truth for the schema.
- LLM calls go through `Llm::Client` only. Never call a provider SDK directly.
- Never make real HTTP or LLM calls in specs. Stub at the service boundary.

## Workflow
- One Linear issue per branch per session. Branch name comes from Linear.
- Tests first. Don't mark work done with a red suite.
- Never commit `.env`, never push to `main`, never force-push.
- If the ticket is ambiguous, stop and ask. Don't guess.