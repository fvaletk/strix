---
description: Explain a Linear ticket in plain words, answer questions about it, and fix the ticket where it's wrong — read-only on code
argument-hint: "[TICKET-ID]"
---

# /explain-ticket

A conversation about one ticket before `/work-next-ticket` runs it. Start with a short, plain explanation; the developer asks questions from there. Not an interview — answer, don't question the developer.

Read `CLAUDE.md` `## Project config`: `linear_team`, `linear_project`. If one is missing or still a `{{…}}` placeholder, say which and stop.

## 1. Find the ticket

With `$ARGUMENTS` (e.g. `ABC-12`), fetch that ticket. Otherwise pick the one `/work-next-ticket` would take next — follow `.claude/commands/work-next-ticket.md` §2. None → say `Nothing ready for agent` and stop.

Read its title, description, acceptance criteria, labels, and comments. If it has a parent issue, read that spec too.

## 2. Ground it

Read just enough app code to explain the ticket against how the app works today: where the change lands, what already exists, what it touches. Don't plan the implementation.

## 3. Open short

First reply, readable in under a minute:

- **What it does** — one or two sentences, in terms of behavior, not code.
- **How it'll work** — the flow in a few plain steps. Name a class or service only where it makes the flow clearer.
- **Worth a look** — only if something in the ticket is unclear, contradicts the current code, or seems out of date. One line each. Omit if none.

No code, no file lists, no full approach. Detail comes when the developer asks for it.

## 4. Conversation

Answer what the developer asks, at the depth they ask. Read more code when a question needs it.

When it turns out the ticket is wrong or missing something, propose the change: the exact lines of the description or acceptance criteria, before → after. Write only after the developer approves (Linear `save_issue`, patching those lines). Only this ticket.

## 5. Close

When the developer says they're done: one line listing what changed on the ticket (or `No changes`), and whether it looks ready for `/work-next-ticket` — against the validation gate in `.claude/commands/work-next-ticket.md` §4.

## Rules

- Read-only on code and git: no edits, no branches.
- Never change the ticket's state, labels, assignee, or priority.
- No ticket text changes without approval.
