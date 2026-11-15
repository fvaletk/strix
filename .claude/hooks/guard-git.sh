#!/bin/bash
# PreToolUse hook (Bash): let agents branch, commit, push ticket branches and open PRs,
# but never touch protected branches, rewrite history, merge PRs, or discard work.
# Protected: main, master, and `base_branch` from CLAUDE.md `## Project config`.
# Exit 2 = block, stderr is shown to Claude.

if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: jq is not installed, so this safety hook cannot inspect the call (brew install jq)." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

block() {
  echo "Blocked: $1 This is the developer's call — stop and report instead." >&2
  exit 2
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BASE=$(grep -m1 -E '^base_branch:' "$PROJECT_DIR/CLAUDE.md" 2>/dev/null | sed -E 's/^base_branch:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]+$//')
PROTECTED="main|master"
[ -n "$BASE" ] && PROTECTED="$PROTECTED|$(printf '%s' "$BASE" | sed 's/[.[\*^$()+?{|]/\\&/g')"

# Inspect each sub-command of a compound command separately.
while IFS= read -r CMD; do
  CMD=$(echo "$CMD" | sed -E 's/^[[:space:]]+//')
  [ -z "$CMD" ] && continue

  if echo "$CMD" | grep -qE '^git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push\b'; then
    echo "$CMD" | grep -qE '(^|[[:space:]])(-f|--force|--force-with-lease|--force-if-includes)([[:space:]=]|$)|[[:space:]]\+[^[:space:]]+' \
      && block "force push."
    echo "$CMD" | grep -qE '(^|[[:space:]])(-d|--delete|--mirror|--all|--tags)([[:space:]]|$)|[[:space:]]:[^[:space:]]+' \
      && block "deleting or bulk-pushing remote refs."
    # Explicit refspec targeting a protected branch: `main`, `HEAD:main`, `x:refs/heads/main`
    echo "$CMD" | grep -qE "[[:space:]]([^[:space:]]*:)?(refs/heads/)?($PROTECTED)([[:space:]]|$)" \
      && block "push to a protected branch ($PROTECTED)."
    # Bare `git push` / `git push origin` while on a protected branch
    if ! echo "$CMD" | grep -qE '^git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]+-[^[:space:]]+)*[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+[^-[:space:]]'; then
      CURRENT=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
      echo "$CURRENT" | grep -qxE "$PROTECTED" && block "push while on protected branch '$CURRENT'."
    fi
  fi

  echo "$CMD" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(merge|close)\b' && block "merging or closing a PR."
  echo "$CMD" | grep -qE '^gh[[:space:]]+api\b.*(/merge|-X[[:space:]]*(DELETE|PUT)|--method[[:space:]]*(DELETE|PUT))' && block "merging or deleting via the GitHub API."
  echo "$CMD" | grep -qE '^gh[[:space:]]+(repo[[:space:]]+(delete|edit)|release[[:space:]]+delete)\b' && block "changing repository settings."

  echo "$CMD" | grep -qE '^git[[:space:]]+reset[[:space:]].*--hard' && block "git reset --hard discards work."
  echo "$CMD" | grep -qE '^git[[:space:]]+clean[[:space:]].*-[a-zA-Z]*f' && block "git clean deletes untracked files."
  echo "$CMD" | grep -qE '^git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)' && block "discarding all working-tree changes."
  echo "$CMD" | grep -qE '^git[[:space:]]+stash\b' && block "stashing hides work-in-progress."
  echo "$CMD" | grep -qE '^git[[:space:]]+(commit|push)\b.*--no-verify' && block "--no-verify skips git hooks."
  echo "$CMD" | grep -qE '^git[[:space:]]+commit\b.*--amend' && block "amending rewrites history."
  echo "$CMD" | grep -qE '^git[[:space:]]+(rebase|filter-branch|filter-repo)\b' && block "rewriting history."
  echo "$CMD" | grep -qE '^git[[:space:]]+branch[[:space:]]+.*-D\b' && block "force-deleting a branch."
done < <(echo "$COMMAND" | sed -E 's/(\&\&|\|\||;|\|)/\n/g')

exit 0
