#!/usr/bin/env bash
set -euo pipefail

# Roadhouse loop state initializer.
# Accepts up to three arguments: SESSION_ID, ARG (iteration argument), COMMANDS (comma-separated).
# Called by both the PreToolUse hook and UserPromptSubmit hook.

STATE_FILE=".claude/roadhouse-loop.local.json"
SESSION_ID="${1:?session_id required}"
ARG="${2:-}"
COMMANDS="${3:-proud,exquisite}"

# Validate commands: lowercase letters, digits, hyphens, separated by commas
if ! [[ "$COMMANDS" =~ ^[a-z][a-z0-9-]*(,[a-z][a-z0-9-]*)*$ ]]; then
  echo "Invalid commands: $COMMANDS" >&2
  exit 1
fi

# --- Cancel ---
if [[ "$ARG" == "cancel" ]]; then
  if [[ ! -f "$STATE_FILE" ]] || ! grep -q '"active": true' "$STATE_FILE"; then
    exit 0
  fi

  jq --arg sid "$SESSION_ID" '
    (
      ([to_entries[] | select(.value.active and .value.session_id == $sid)] | last | .key) //
      ([to_entries[] | select(.value.active)] | last | .key)
    ) as $idx |
    if $idx != null then .[$idx].active = false else . end
  ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  exit 0
fi

# --- Validate argument ---
MODE="count"
MAX_ITERATIONS=1

if [[ "$ARG" == "done" ]]; then
  MODE="done"
  MAX_ITERATIONS=50
elif [[ -n "$ARG" ]]; then
  if ! [[ "$ARG" =~ ^[0-9]+$ ]] || [[ "$ARG" -lt 1 ]]; then
    exit 1
  fi
  MAX_ITERATIONS="$ARG"
fi

# --- Setup ---
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CUTOFF=$(date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
  || date -u -d '7 days ago' +"%Y-%m-%dT%H:%M:%SZ")

if [[ -f "$STATE_FILE" ]]; then
  EXISTING=$(cat "$STATE_FILE")
else
  EXISTING="[]"
fi

# Replace this session's record, prune old entries, create new session
echo "$EXISTING" | jq \
  --arg cutoff "$CUTOFF" \
  --arg mode "$MODE" \
  --argjson max "$MAX_ITERATIONS" \
  --arg started "$STARTED_AT" \
  --arg sid "$SESSION_ID" \
  --arg cmds "$COMMANDS" \
  '
  [.[] | select(.started_at >= $cutoff and .session_id != $sid)] + [{
    session_id: $sid,
    active: true,
    iteration: 1,
    max_iterations: $max,
    mode: $mode,
    phase: ($cmds | split(",") | .[0]),
    started_at: $started,
    commands: [($cmds | split(","))[] | {command: ., iteration: -1, result: "not_run"}]
  }]
  ' > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
