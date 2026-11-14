# Strix

Personal reading assistant. Save URLs, get summaries and tags,
ask questions over what you've saved, receive a weekly digest.

## Project config

Read by the agents and commands. Edit here, nowhere else.

```yaml
linear_team: Brain Spark
linear_project: Strix
github_repo: fvaletk/strix
base_branch: main                      # PRs target this; never pushed to directly
run: docker compose exec web           # prefix for every app command
test: bundle exec rspec
lint: bin/rubocop -a                   # autocorrect, run by implement on touched files
checks:                                # quality gate: /quality-check, and the test agent
  - bin/rubocop
  - bin/brakeman -q --no-pager
  - bundle exec bundler-audit check --update
stub_in_specs: [Llm::Client]           # never called for real from specs
```

Every app command runs as `<run> <command>`.

## Stack

Rails 8, Postgres + pgvector (neighbor), Tailwind, Hotwire,
ViewComponent, Sidekiq, RSpec, Kamal.

## Commands

- Dev: `docker compose up`
- Test, lint, and checks: see Project config. Single spec: `<run> bundle exec rspec spec/path_spec.rb:25`
- Migrate: `<run> bin/rails db:migrate`

## Conventions

- Conventions live in `.claude/rules/`. Read the ones matching the files you touch.
- `db/schema.rb` is the source of truth for the schema.
- LLM calls go through `Llm::Client` only. Never call a provider SDK directly.
- Never make real HTTP or LLM calls in specs. Stub at the service boundary.

## Workflow

- One Linear issue per branch. Branch name comes from Linear.
- Tests first. Don't mark work done with a red suite.
- Never commit `.env`, never push to `main`, never force-push.
- If the ticket is ambiguous, stop and ask. Don't guess.
