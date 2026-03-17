#!/usr/bin/env bash
set -euo pipefail

HOOK_INPUT=$(cat)

# Fast path: skip if not the rounds skill
if ! grep -q '"rounds"' <<< "$HOOK_INPUT"; then
  exit 0
fi

IFS=$'\t' read -r SKILL_NAME SESSION_ID ARG < <(
  jq -r '[.tool_input.skill // "", .session_id // "", .tool_input.args // ""] | join("\t")' <<< "$HOOK_INPUT"
)

if [[ "$SKILL_NAME" != "rounds" ]]; then
  exit 0
fi

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
"$SCRIPT_DIR/rounds-init.sh" "$SESSION_ID" "$ARG"
