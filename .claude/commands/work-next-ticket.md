---
description: Take the next ready-for-agent Linear ticket (or a given one) through implement → test → review → commit agents and open a PR
argument-hint: "[TICKET-ID]"
---

# /work-next-ticket

Runs one Linear ticket through the agent pipeline on its own branch and opens a PR into `base_branch` for the developer to review.

**You orchestrate; agents do the work.** You fetch tickets, run the preflight, spawn agents, and pass their reports along. Don't read app code, write code, or debug failures yourself — that's what the agents' context is for.

Read `CLAUDE.md` `## Project config`: `linear_team`, `linear_project`, `base_branch`, `run`. If a key is missing or still a `{{…}}` placeholder, say which and stop — the developer fills it in `CLAUDE.md`.

**Labels:** `ready-for-agent`, `needs-triage`, `bug` — or the strings mapped to those roles in `docs/agents/triage-labels.md`, if it exists. **States:** match by type, not name (Todo = unstarted, In Progress = started, Done = completed), since teams rename them.

## 1. WIP guard

One ticket in flight. Find tickets in `linear_project` assigned to me in a started state. For each, `gh pr list --head <gitBranchName> --state all --json number,state,url`:

- **No PR, last comment is a `Pipeline stopped` note** with no reply from the developer after it → report `Waiting on you: <ticket> — <reason>` and stop. With a reply → resume (§Resuming) and pass the reply to `implement`.
- **No PR otherwise** → resume (§Resuming).
- **PR open** → `gh pr checks <gitBranchName>`, report one line, stop:
  - passing → `Waiting for review: <PR URL> (CI ✓)`
  - pending → `Waiting for CI: <PR URL>`
  - failing → `CI failing on <PR URL>: <check names>` plus the failing step's last ~30 lines (`gh run view <run-id> --log-failed`). Don't fix it — the developer decides.
- **PR merged** → if the ticket isn't Done (the Linear GitHub integration usually moves it), mark it Done and comment the PR URL. Continue to step 2.
- **PR closed unmerged** → stop and ask.

`$ARGUMENTS` doesn't bypass the guard.

## 2. Pick the ticket

With `$ARGUMENTS` (e.g. `ABC-12`), fetch that ticket. Otherwise, from `linear_team` / `linear_project`, take tickets that are:

- in an unstarted state, labelled `ready-for-agent`, assigned to me or unassigned;
- not a spec — skip any ticket with sub-issues (`to-spec` labels the spec `ready-for-agent` too);
- unblocked — every "blocked by" relation is Done or Canceled.

Order: tickets labelled `bug` first; then Urgent → High → Medium → Low → No priority (Linear stores No priority as `0` — don't sort the raw number); then oldest. None left → report `Nothing ready for agent` and stop.

## 3. Read it

Title, description, acceptance criteria, labels, URL, `gitBranchName`, and its comments (an agent brief from `/triage` lives there). If it has a parent issue, that's the spec: read it and pull the seams from its **Testing Decisions**.

## 4. Validation gate

- Every acceptance criterion has a clear, testable definition of done.
- Single concern.
- Seams known: the spec's Testing Decisions name them — or it's a bug ticket, or labelled `no-test`.

Any fails → stop and ask. Don't start an ambiguous ticket.

## 5. Preflight

Check the dev environment before branching. Report only failures.

1. If `run` is set (Docker): `docker compose ps`. Services not running → `docker compose up -d`. One keeps restarting → `docker compose logs <service> --tail=50` and stop.
2. `<run> bundle check || <run> bundle install`
3. `<run> bin/rails db:migrate:status` — any `down` → `<run> bin/rails db:migrate`. Connection errors → ask the developer to check the database settings in `.env`; **don't open it**.
4. `<run> env RAILS_ENV=test bin/rails db:prepare`

Any step still failing → stop with its error output.

## 6. Branch and start

Working tree must be clean (`git status --porcelain` empty) — if not, stop and ask; never stash or discard.

```bash
git fetch origin
git switch -c <gitBranchName> origin/<base_branch>   # exists already → git switch <gitBranchName>
```

Mark the ticket In Progress (assign it to me if unassigned).

## 7. Pipeline

Spawn each agent with its handoff block (below). Up to **2 fix rounds** per ticket, counted across test and review.

1. **`implement`**. STOPPED → stop with its reason.
2. **`test`**. BLOCKED → fix round: spawn `implement` with the blockers as `Fix round:`, then `test` again.
3. **`review-standards` and `review-spec`**, in parallel (one message, two Agent calls).
   - Either has Fix items → fix round: `implement` with both Fix lists, then `test`, then both reviews again.
   - Both CLEAN → step 4.
4. **File existing bugs** both reviews listed under *Existing bugs* (merge duplicates): follow `.claude/commands/report-issue.md` Steps 3–4 with the finding as the source. Label `bug` + `needs-triage` (those that exist on the team) — **never `ready-for-agent`**; the developer promotes them after triage.
5. **`commit`**, with the union of files `implement` and `test` reported, and both reviews' Notes.
6. **Comment the PR URL on the ticket** and stop. The ticket stays started until the PR merges; the next run's WIP guard picks up from there.

## Stopping

Stop when: an agent reports STOPPED; `implement` marks a finding **disputed**; findings remain after 2 fix rounds; `commit` fails.

On a stop, the ticket stays In Progress. Comment on it — starting with `Pipeline stopped:` — the reason and the open findings (`file:line — source — problem`), then report the same here. The developer replies on the ticket; the next run resumes with that reply.

Never push to `base_branch`, never merge or close a PR. `.claude/hooks/guard-git.sh` enforces the git side.

## Agent handoff

Agents share no state — pass everything explicitly.

**implement:**
```
Ticket: <ID> — <title>
Labels: <labels>
Description: <full description, plus any agent brief from comments>
Acceptance Criteria:
- [ ] ...
Seams: <from the spec's Testing Decisions, or "none — bug ticket" / "none — no-test">
Fix round (only in a fix round):
- file:line — source — problem
Developer reply (only when resuming after a stop): <reply>
```

**test:**
```
Ticket: <ID> — <title>
Labels: <labels>
Description: <full description>
Acceptance Criteria:
- [ ] ...
Implement report: <files changed, behaviors → specs, notes>
```

**review-standards:**
```
Base: origin/<base_branch>
Branch: <gitBranchName>
```

**review-spec:**
```
Base: origin/<base_branch>
Branch: <gitBranchName>
Ticket: <ID> — <title>
Description: <full description>
Acceptance Criteria:
- [ ] ...
Parent spec: <full spec body, or "none">
```

**commit:**
```
Ticket: <ID> — <title>
Ticket URL: <url>
Branch: <gitBranchName>
Files changed: <union of implement's and test's lists>
Review notes: <both reviews' Notes, verbatim>
Test results: <test's verdict and suite summary>
```

## Resuming

A started ticket without a PR: check out its `gitBranchName` (no branch → step 5), run the preflight, then pick the step from the branch state:

| `git log origin/<base_branch>..HEAD` | `git status --porcelain` | Resume at |
|---|---|---|
| empty | empty | 7.1 `implement` |
| empty | changes | 7.2 `test` — it re-checks the work, then reviews follow |
| commits | — | 7.5 `commit` — it pushes and opens the PR |

Fix rounds restart at 0 on resume.

## Running continuously

```
/loop 30m /work-next-ticket
```

Each run resumes a ticket, reports what it's waiting on (a PR, CI, or your reply to a stop), or — once the previous PR merges — closes that ticket and starts the next one.
