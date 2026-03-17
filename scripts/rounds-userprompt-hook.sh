#!/usr/bin/env bash
set -euo pipefail

HOOK_INPUT=$(cat)

# Fast path: skip if prompt doesn't start with /rounds
PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty')
if [[ ! "$PROMPT" =~ ^/rounds($|[[:space:]]) ]]; then
  exit 0
fi

SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')

# Extract argument: everything after "/rounds"
ARG="${PROMPT#/rounds}"
ARG=$(echo "$ARG" | xargs) # trim whitespace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/rounds-init.sh" "$SESSION_ID" "$ARG"
