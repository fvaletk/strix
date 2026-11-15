---
name: security-audit
description: >-
  Audits a whole Rails app for security holes — access control, injection,
  XSS, SSRF, secrets, configuration — with Brakeman and bundler-audit plus a
  manual review, and reports findings without changing code. Use when the user
  wants a security audit, vulnerability scan, or asks whether the app is
  secure. WHEN NOT: reviewing only the current diff (use /security-review),
  fixing a known vulnerability, or setting up authentication.
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
argument-hint: "[file or directory path]"
---

# Security Audit

Read-only: you report findings, the developer fixes them. Read `CLAUDE.md` `## Project config` for `run` and prefix app commands with it.

## Step 1 — Tools

```bash
<run> bin/brakeman -q --no-pager
<run> bundle exec bundler-audit check --update
```

Skip a tool that isn't installed and say so. Brakeman findings are leads — confirm each one in the code before reporting it.

## Step 2 — Manual review

Work through every check below across `app/`, `config/`, and `lib/` (or the path given). Each check names what to grep for; read the hits.

**Access control** — the most common real hole in Rails apps.
- Records loaded by ID without scoping: `Model.find(params[:id])` where the record belongs to a user or account. Must be `current_user.things.find(...)`, a `policy_scope`, or followed by `authorize`.
- Controllers missing `authorize` / `before_action :authenticate_user!`; `skip_before_action` that's broader than intended.
- Strong params permitting `role`, `admin`, `account_id`, `user_id`, or other ownership fields.
- Admin and internal routes (`/sidekiq`, admin namespaces) mounted without an authentication constraint.

**Injection and XSS**
- String-built SQL: `where("... #{`, `order(params[`, `find_by_sql`, `.pluck("#{`. Must use bound parameters or an allow-list for column/direction.
- Shell: `system`, backticks, `%x`, `Open3`, `IO.popen` with interpolated input.
- `html_safe`, `raw`, `<%==` on anything user-controlled; `sanitize` with a widened allow-list; user input in `link_to` hrefs (`javascript:` URLs).
- `constantize`, `send`, `public_send` with user input.

**Redirects, files, outbound requests**
- `redirect_to params[...]` or `request.referer` without `allow_other_host: false` / an allow-list.
- `send_file` / `File.read` / `File.open` with a user-supplied path.
- SSRF: Faraday / Net::HTTP / HTTParty calls whose URL or host comes from user input or stored user data — must be allow-listed, and must not reach internal addresses.

**Secrets and data exposure**
- Hardcoded keys or tokens in code or `config/` (credentials belong in ENV or encrypted credentials).
- `config.filter_parameters` covers passwords, tokens, secrets, and any PII the app stores.
- JSON responses that serialize whole records (`render json: @user`) and leak tokens or digests.
- Tokens compared with `==` instead of `ActiveSupport::SecurityUtils.secure_compare`, or stored in plaintext.

**Configuration**
- `config.force_ssl = true` in production; secure, httponly, same-site session cookies.
- CSRF protection on for HTML controllers; `skip_forgery_protection` only on token-authenticated API controllers.
- Content Security Policy configured (`config/initializers/content_security_policy.rb`).
- `YAML.load` / `Marshal.load` on untrusted input (use `YAML.safe_load`).

## Step 3 — Report

Lead with a one-line posture summary and the count per priority. Then each finding:

**Vulnerability** → **Location** (`file:line`) → **How it's exploited** (one sentence, concrete) → **Fix** (code example) → OWASP Top 10 category.

Priorities: **P0** exploitable now without special access (IDOR, SQL injection, auth bypass) · **P1** exploitable with some precondition · **P2** hardening gaps · **P3** hygiene.

Say what you checked and found clean, so the absence of findings means something.
