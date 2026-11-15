#!/bin/bash
# PreToolUse hook: keep Claude away from credential files.
# Blocks file tools (Read/Edit/Write/MultiEdit/NotebookEdit/Grep/Glob) on .env* (except .env.example) and Rails key files,
# and Bash commands that touch them. Exit 2 = block, stderr is shown to Claude.

if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: jq is not installed, so this safety hook cannot inspect the call (brew install jq)." >&2
  exit 2
fi

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // empty')
GLOB=$(echo "$INPUT" | jq -r '.tool_input.glob // empty')

block() {
  echo "Blocked: $1 Credentials are managed by the developer — say which variable is needed and stop." >&2
  exit 2
}

if [ "$TOOL" != "Bash" ] && [ -n "$FILE" ]; then
  BASENAME=$(basename "$FILE")
  if echo "$BASENAME" | grep -qE '^\.env(\.|$)' && [ "$BASENAME" != ".env.example" ]; then
    block "$FILE is a credentials file."
  fi
  if echo "$FILE" | grep -qE '(^|/)config/(master\.key|credentials/[^/]+\.key)$'; then
    block "$FILE is a Rails encryption key."
  fi
fi

# Grep's file filter, e.g. glob: ".env*"
if [ -n "$GLOB" ] && echo "$GLOB" | grep -qE '(^|[/{,*])\.env' && [ "$GLOB" != ".env.example" ]; then
  block "search filter $GLOB targets credentials files."
fi

if [ "$TOOL" = "Bash" ] && [ -n "$COMMAND" ]; then
  # Drop .env.example mentions, then look for any remaining .env file reference.
  STRIPPED=$(echo "$COMMAND" | sed -E 's/\.env\.example//g')
  if echo "$STRIPPED" | grep -qE '(^|[^A-Za-z0-9_])\.env([^A-Za-z0-9_]|$)'; then
    block "command references a .env file."
  fi
  if echo "$COMMAND" | grep -qE 'master\.key|credentials/[^ ]+\.key|RAILS_MASTER_KEY|credentials:show'; then
    block "command references Rails credentials or keys."
  fi
fi

exit 0
