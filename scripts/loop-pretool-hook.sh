#!/usr/bin/env bash
set -euo pipefail

HOOK_INPUT=$(cat)

# Fast path: skip if not the bounce skill
if ! grep -q 'bounce' <<< "$HOOK_INPUT"; then
  exit 0
fi

IFS=$'\t' read -r SKILL_NAME SESSION_ID ARG < <(
  jq -r '[.tool_input.skill // "", .session_id // "", .tool_input.args // ""] | join("\t")' <<< "$HOOK_INPUT"
)

# Strip plugin prefix (e.g. "roadhouse:bounce" → "bounce")
SKILL_NAME="${SKILL_NAME##*:}"
if [[ "$SKILL_NAME" != "bounce" ]]; then
  exit 0
fi

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
COMMANDS="${ARG%% *}"
LOOP_ARG="${ARG#* }"
# If no space found, ARG == COMMANDS — no loop arg
if [[ "$LOOP_ARG" == "$COMMANDS" ]]; then
  LOOP_ARG=""
fi
"$SCRIPT_DIR/loop-init.sh" "$SESSION_ID" "$LOOP_ARG" "$COMMANDS"
