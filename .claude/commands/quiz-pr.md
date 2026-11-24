---
description: Quiz the developer on how and why the current branch's PR was built, teaching the gaps — read-only, conversation only
argument-hint: "[PR-number]"
---

# /quiz-pr

An interview on one PR built by `/work-next-ticket`. The goal: the developer understands why the ticket exists and why the solution is shaped the way it is — the design choices and the concepts behind them, not line-by-line code. Don't assume the agent was right: the quiz is also a check on its decisions.

Read `CLAUDE.md` `## Project config`: `base_branch`, `linear_team`. If one is missing or still a `{{…}}` placeholder, say which and stop.

## 1. Gather

- **PR:** with `$ARGUMENTS`, `gh pr view <number> --json title,body,url,headRefName`; otherwise the PR for the current branch. No PR → use the current branch alone (not `base_branch`).
- **Ticket:** the `[ID]` in the PR title, or the branch name. Read its description, acceptance criteria, and its parent spec if it has one.
- **Code:** `git diff origin/<base_branch>...<branch>` and `git log origin/<base_branch>..<branch>`. Read surrounding code where a change only makes sense in context.
- **Decisions:** the PR body's `## Decisions` bullets — the agent's own record of its choices.

## 2. Map (hidden)

Build a list of what the developer must understand. Don't show it.

1. **Purpose** — the problem the ticket solves and for whom. Always first.
2. **Decisions** — 3–6 items, the ones that shape the solution: data model, where logic lives, sync vs background job, a library, a constraint, an integration boundary. Start from `## Decisions` (*stated*); add what the diff shows but the record missed (*inferred*). Skip anything a reader gets at first glance.

For each item, judge it yourself against the code, the ticket, and Rails practice: **sound** or **questionable** (one-line reason). Never take the agent's "why" as proof.

## 3. Quiz

Open with one line — `<N> things to cover. Answer, say "skip", or "stop" anytime.` — then the first question.

**Questions:** one at a time, each pointing at something in this PR. Two kinds only:
- **Why** — why does this exist, why is it built this way?
- **Role** — what does this piece do in the flow, what goes wrong without it?

No hypotheticals beyond this code, no "where else would you use this", no trivia (method names, line numbers).

**After each answer**, one of:
- **Right** — confirm in one line, add the missing nuance if any, next question.
- **Partial** — say what's missing in one line, one follow-up on that gap only.
- **Wrong / don't know** — teach: the concept in 2–4 plain sentences, then how it applies in this PR. Then one short rephrased question to check it landed.

Max two rounds per item; after that, give the answer in two lines and move on.

**Questionable items:** once the developer has answered, say what looks off and why, in one or two lines. If they push back on any decision, weigh it on the merits — agree when they're right.

**Length:** every reply under ~6 lines. Teach only as deep as this PR needs; no tangents into related topics.

## 4. Close

When every item is done or the developer says stop:

- **Solid** — items answered right, one line.
- **Review** — weak spots, one line each.
- **Questionable** — decisions that look wrong, one line each, with `/report-issue` as the way to file one. Omit if none.

## Rules

- Read-only: no edits, no git changes, no Linear or GitHub writes. Nothing saved — the quiz lives in this conversation.
- No `## Decisions` in the PR body (older PRs) → infer every item and say so in the opening line.
