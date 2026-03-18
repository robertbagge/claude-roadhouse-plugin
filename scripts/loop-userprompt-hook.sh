#!/usr/bin/env bash
set -euo pipefail

HOOK_INPUT=$(cat)

# Fast path: skip if prompt doesn't start with /bounce
PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty')
if [[ ! "$PROMPT" =~ ^/bounce($|[[:space:]]) ]]; then
  exit 0
fi

SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARG="${PROMPT#/bounce}"
ARG=$(echo "$ARG" | xargs)
COMMANDS="${ARG%% *}"
LOOP_ARG="${ARG#* }"
if [[ "$LOOP_ARG" == "$COMMANDS" ]]; then
  LOOP_ARG=""
fi
"$SCRIPT_DIR/loop-init.sh" "$SESSION_ID" "$LOOP_ARG" "$COMMANDS"
