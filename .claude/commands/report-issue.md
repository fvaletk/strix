---
description: Capture the issue from this conversation as a Linear triage issue — capture only, no fixes
---

# /report-issue

Capture the issue or finding **from this conversation**, so it isn't lost and doesn't derail the current work.

**Takes no arguments.** The source is what we've been discussing. Don't ask the user to describe it — they already have. If arguments are passed, treat them as a hint about *which* thread to capture, not as the content.

Read `CLAUDE.md` `## Project config` for `linear_team`, `linear_project`, and `github_repo`. If `linear_team` is missing or still a `{{…}}` placeholder, say so and stop.

## Step 1 — Find what to capture

Identify the problem, bug, surprise, or risk under discussion — usually the most recent substantial thread.

- **Several distinct issues?** List them one line each and ask which to file, offering "all". One issue per problem.
- **No issue in the conversation?** Say so and stop. Don't invent one, and don't go scanning the codebase for problems.

## Step 2 — Preserve, don't re-derive

The investigation already happened here. Your job is to not lose it — not to redo it. Pull from what was established:

- The symptom, in the terms it was actually described
- The root cause **if it was found** — if not, say so rather than guessing one now
- Exact file paths and line numbers, relevant code in fenced blocks
- How it was reproduced or observed
- **What was ruled out** — wrong theories stop the next person re-walking them
- What's still unknown

Only read files to confirm a path or line number you're unsure of. Don't open a fresh investigation.

Anything asserted but never verified goes in **labelled as unverified**. Don't launder a hypothesis into a fact by writing it down.

## Step 3 — Check for duplicates

Search open issues in `linear_project` for the same problem by key terms, class names, error message. If one exists, say so with its ID and URL and stop. Offer to add this conversation's new details to it instead.

## Step 4 — Create the issue

**Title:** one line, specific and outcome-shaped — "Report job retries forever when the store returns 404", not "Bug in jobs".

**Description:**

```markdown
## What
The problem, as established in the conversation.

## Where
File paths with line numbers (link as `https://github.com/<github_repo>/blob/<commit>/<path>#L<line>`). Relevant code in fenced blocks.

## Why it matters
The consequence. If a user would never notice, say so — it changes the priority.

## What we found
The reasoning from the conversation. Root cause if identified.

## Ruled out
Theories eliminated, and why. Omit if none.

## Still unknown
Open questions. Omit if none.

## Suggested action
A recommendation, not a decision.

---
Found on branch `<branch>` at `<short sha>`.
```

Fill branch and commit from `git branch --show-current` and `git rev-parse --short HEAD`. Use a commit that's been pushed for the GitHub links; if HEAD isn't on the remote, link against `<base_branch>` and say so.

Create it with the Linear MCP tools:


- **Team:** `linear_team`. **Project:** `linear_project`.
- **State:** the team's Triage state if it has one, else Backlog. Never Todo or In Progress — prioritizing is the developer's call.
- **Labels:** only labels that already exist on the team (list them first) — e.g. `Bug` / `Improvement`, plus an area label if one fits. Don't create labels.
- **Priority:** leave unset unless the conversation established severity (data loss, security, production breakage → suggest Urgent/High in the body, still don't set it).
- **Assignee:** none.

## Step 5 — Report back

One line: issue ID, title, URL. Nothing more — this runs mid-work.

## Rules

- Capture only. No code changes, no fixes — not even trivial ones.
- Never change the current ticket's status, and never link the new issue to it as a blocker unless the user asks.
- Never paste secrets, `.env` values, tokens, or personal data from logs into the issue.
