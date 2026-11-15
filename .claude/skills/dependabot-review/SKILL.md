---
name: dependabot-review
description: >-
  Reviews Dependabot gem upgrade PRs for breaking changes, codebase impact, and
  merge readiness — one PR, or every open one as a triage report. Use when the
  user pastes a Dependabot PR URL, asks about a gem version bump, or asks which
  dependency PRs are safe to merge. WHEN NOT: non-Dependabot PRs, npm/yarn
  upgrades, or general code review.
allowed-tools: Read, Bash, WebFetch, Grep, Glob
model: sonnet
effort: high
context: fork
agent: general-purpose
---

# Dependabot Gem Upgrade Review

Current repo: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "(unknown — run from inside the repo)"`

Give the developer a scannable verdict per PR: what changed upstream, what could break here and how to fix it, what the gem touches, and whether to merge.

**Mode:** a specific PR URL or number → **single-PR**. "All", "open", "which are safe", or ambiguous → **audit**: discover the PRs yourself, don't ask for URLs.

## Per-PR analysis

Both modes run these three steps for each PR.

### 1. Fetch

```bash
gh pr view <NUMBER> --repo <OWNER/REPO> --json title,body,url,files,headRefName,createdAt
gh pr diff <NUMBER> --repo <OWNER/REPO>
```

For each gem in the diff: name, old → new version, bump type (patch / minor / major). Multi-gem PRs get one section per gem.

### 2. Changelog

Sources in order: the gem repo's `CHANGELOG.md` / `Changes.md` / `HISTORY.md`, its GitHub Releases, then rubygems.org for the source link. Say so if none exists.

- **Patch / minor:** read the sections for the version range in full.
- **Major:** don't read the whole file — big gems' changelogs exhaust context. Find section offsets (`grep -n "^## " CHANGELOG.md`), read only the range, and within it only lines about *breaking, removed, renamed, dropped, changed default, incompatible*. Cross-check the major release's notes.

Collect, in priority order: breaking changes (each checked against this codebase, with a concrete fix if affected), deprecations, security fixes, and other changes only if they touch code here.

### 3. Codebase impact

- `Gemfile` entry: version constraint and group (`:development` / `:test` are lower risk).
- Usages of the gem's constants in `app/`, `lib/`, `config/`, `spec/`; its initializer in `config/initializers/`.
- Group hits by feature area in plain language ("Payments: captures charges in two jobs") — one line per area, not a file list.
- Dependent gems (e.g. `sentry-sidekiq` on `sidekiq`): check their constraints in the `Gemfile.lock` diff.

### Verdict

| Lower risk | Higher risk |
|---|---|
| Patch, dev/test only, 1–2 files, no breaking changes | Major, widespread production use, payments/auth, API changes |

A security fix raises urgency. Verdicts: **Merge** · **Verify** (list what to check) · **Investigate** (list the concerns) · **Hold** (code changes needed first). CI runs the suite — name what a human should verify that specs won't catch (production Redis version, runtime behavior, new deprecation warnings).

## Single-PR output

```
## Dependabot Review: `gem` (old -> new)

### Bump Type
patch/minor/major — one line on what it means for risk

### What Changed
Breaking changes (with fixes), deprecations, security fixes, relevant changes. Or "No breaking changes or deprecations."

### Breaking Changes in This Codebase
Each affected file and its fix. Omit the section if none.

### Codebase Impact
One line per feature area.

### Recommendation
Verdict + 1–3 sentences: why, and what to verify.
```

## Audit mode

```bash
gh pr list --author "app/dependabot" --state open \
  --json number,title,url,createdAt,headRefName,labels --limit 50
```

The `app/` prefix is required. Empty → "No open Dependabot PRs in <repo>." and stop. Otherwise say "Found N open Dependabot PRs. Analyzing each now…" and run the per-PR analysis for each (in parallel where you can).

Report, in order:
1. "Reviewed N open Dependabot PRs in <repo>."
2. Summary table — exactly these columns:

| # | Gem | Bump | Type | Age | Verdict | Why |
|---|---|---|---|---|---|---|
| `[#9170](url)` | comma-separated for multi-gem | `7.2.4 → 8.0.10` | patch/minor/major, `🔒` prefix for a security advisory | days since `createdAt` | Merge / Verify / Investigate / Hold | ≤ 10 concrete words |

   Sort by verdict (Merge → Verify → Investigate → Hold), then by age, oldest first. Rows marked 🔒 go to the top regardless.
3. **Details** — one section per PR in the single-PR format, condensed to 15–25 lines.
4. **Overall recommendation** — PRs grouped by verdict: merge now, investigate, hold.

## Posting to the PR

After the review, ask once — single-PR: "Post this review as a comment on #<n>? (yes / no)"; audit: "Post each review on its PR? (yes / no / selective)". Never post without a yes.

Before posting, look for this skill's earlier comment:

```bash
gh api repos/<OWNER>/<REPO>/issues/<NUMBER>/comments --paginate \
  --jq '.[] | select(.body | contains("dependabot-audit:v1")) | .id'
```

If one exists, ask whether to update it (default: skip). Write each body to a temp file (`mktemp`), then:

```bash
gh pr comment <NUMBER> --repo <OWNER/REPO> --body-file <file>                    # new
gh api --method PATCH repos/<OWNER>/<REPO>/issues/comments/<ID> -F body=@<file>  # update
```

Comment body — no signature or attribution line:

```markdown
## Dependabot review

**Verdict:** <Merge / Verify / Investigate / Hold>

<one-line reason>

<details>
<summary>Full review</summary>

<the single-PR review>

</details>

<!-- dependabot-audit:v1 -->
```

If a post fails (permissions, locked PR, rate limit), report it and continue with the rest. Finish with one line: "Posted N comments: [#…]. Skipped M: [#… (reason)]."
