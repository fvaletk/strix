---
description: Run the project's quality checks (RuboCop, Brakeman, bundler-audit, …) on the current changes and report PASS / BLOCKED
argument-hint: "[--staged | --all | <paths>]"
---

# /quality-check

The project's quality gate. Run it by hand on any branch before a PR; the `test` agent also follows this file as its last step in `/work-next-ticket`. This file is the single source for what the checks are and what blocks.

Read `CLAUDE.md` `## Project config` for `run`, `base_branch`, and `checks`. Prefix every app command with `run`; `git` runs on the host.

## Scope

| `$ARGUMENTS` | Files in scope |
|---|---|
| *(none)* | Everything changed on this branch: committed since `base_branch` + uncommitted + untracked |
| `--staged` | `git diff --cached --name-only` |
| `--all` | Whole app — no "changed file" distinction, every finding is reported |
| `<paths>` | Those paths |

Default scope:

```bash
git fetch origin <base_branch> --quiet
{ git diff --name-only origin/<base_branch>...HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u
```

Drop deleted files (`test -e`). If nothing is in scope, say so and stop.

## Run the checks

Run each command in `checks`. Only tools the project has — if one isn't installed, note it and move on; never add gems.

| Tool | How to run | Blocking when |
|---|---|---|
| RuboCop | Pass the in-scope `.rb` files as arguments (whole app with `--all`) | Any offense |
| Brakeman | Whole app, `-q --no-pager`; respects `config/brakeman.ignore` | A warning in an in-scope file. Warnings elsewhere are pre-existing → note |
| bundler-audit | `check --update` | A vulnerability **and** `Gemfile.lock` is in scope. Otherwise pre-existing → note |
| erb_lint, i18n-tasks, database_consistency, others in `checks` | In-scope files where the tool accepts paths; otherwise whole app | A finding attributable to an in-scope file |

With `--all`, every finding is blocking — there is no "pre-existing".

**Never** edit `.rubocop.yml`, `config/brakeman.ignore`, `.bundler-audit.yml`, or add `# rubocop:disable` / Brakeman ignore entries to make a check pass. If a finding looks like a false positive, say why and leave the decision to the developer.

## Report

Lead with the verdict: **PASS** or **BLOCKED (n blockers)**.

```
BLOCKED (3 blockers)

RuboCop        2 blockers
  app/services/orders/cancel_service.rb:14 — Style/GuardClause — Use a guard clause …
  spec/services/orders/cancel_service_spec.rb:8 — RSpec/LetSetup — …
Brakeman       1 blocker, 2 pre-existing
  app/controllers/orders_controller.rb:31 — SQL Injection (High) — …
  (pre-existing) app/models/report.rb:88 — …
bundler-audit  pass (Gemfile.lock not changed; 1 pre-existing advisory: rack 2.2.6 CVE-…)
erb_lint       not installed
```

## Fixing

**Run by hand:** after the report, offer to fix. RuboCop: `rubocop -a` on the in-scope files, then fix what's left by hand. Brakeman/erb_lint: fix in code. Vulnerable gems: propose the version bump, don't run `bundle update` without approval. Re-run the checks after fixing and report again.

**From the `test` agent:** fix only files under `spec/` (RuboCop `-a` on in-scope spec files, then by hand). Everything else is a blocker for `implement` to fix — never touch implementation files.
