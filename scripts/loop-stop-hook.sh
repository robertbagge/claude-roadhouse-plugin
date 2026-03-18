#!/usr/bin/env bash
set -euo pipefail

STATE_FILE=".claude/roadhouse-loop.local.json"

# Fast path: no state file or no active sessions
if [[ ! -f "$STATE_FILE" ]] || ! grep -q '"active": true' "$STATE_FILE"; then
  cat > /dev/null
  exit 0
fi

HOOK_INPUT=$(cat)

# --- READ (1 jq spawn) ---
# Extract session_id from hook input, find active record in state file,
# return index + all fields as TSV. Empty output = no matching session.
RECORD=$(jq -r --slurpfile state "$STATE_FILE" '
  (.session_id // "") as $sid |
  if $sid == "" then ""
  else
    first($state[0] | to_entries[] | select(.value.active and .value.session_id == $sid)) //
    null |
    if . == null then ""
    else
      .value as $v | .value.commands as $cmds |
      ($cmds | map(.command)) as $names |
      ($names | index($v.phase)) as $cur_idx |
      (if $cur_idx == (($names | length) - 1) then $names[0] else $names[$cur_idx + 1] end) as $next_phase |
      (if $cur_idx == (($names | length) - 1) then "true" else "false" end) as $is_last |
      ([$cmds[] | select(.command != $v.phase) | .result == "roadhouse!"] | all) as $others_ok |
      [.key, $v.phase, $v.iteration, $v.max_iterations, $next_phase, $is_last, $others_ok] | @tsv
    end
  end
' <<< "$HOOK_INPUT")

if [[ -z "$RECORD" ]]; then
  exit 0
fi

IFS=$'\t' read -r IDX PHASE ITERATION MAX_ITERATIONS NEXT_PHASE IS_LAST_PHASE OTHERS_ALL_ROADHOUSE <<< "$RECORD"

# --- DECIDE (pure bash) ---

# If review said needs-work, inject a fix turn and return early.
# The fix turn will have no verdict tag, so it falls through to
# normal transition logic on the next stop.
if grep -qF '<verdict>needs-work</verdict>' <<< "$HOOK_INPUT"; then
  echo '{"decision":"block","reason":"Run /autofix now."}'
  exit 0
fi

# Verdict: grep directly on hook input (avoids jq for last_assistant_message)
if grep -qF '<verdict>roadhouse!</verdict>' <<< "$HOOK_INPUT"; then
  VERDICT="roadhouse!"
else
  VERDICT="needs-work"
fi

# Determine transition action
ACTION="none"
NEXT=0
if [[ "$VERDICT" == "roadhouse!" ]] && [[ "$OTHERS_ALL_ROADHOUSE" == "true" ]]; then
  ACTION="deactivate"
elif [[ "$IS_LAST_PHASE" == "true" ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  ACTION="deactivate"
elif [[ "$IS_LAST_PHASE" == "true" ]]; then
  ACTION="to_next_iteration"
  NEXT=$((ITERATION + 1))
else
  ACTION="to_next_phase"
fi

# --- WRITE (1 jq spawn) ---
# Update command row + apply transition, read from file, write atomically
jq --argjson i "$IDX" --arg cmd "$PHASE" --argjson iter "$ITERATION" --arg v "$VERDICT" \
  --arg action "$ACTION" --argjson next "$NEXT" --arg next_phase "$NEXT_PHASE" '
  .[$i].commands |= map(
    if .command == $cmd then .iteration = $iter | .result = $v else . end
  ) |
  if $action == "deactivate" then .[$i].active = false
  elif $action == "to_next_phase" then .[$i].phase = $next_phase
  elif $action == "to_next_iteration" then .[$i].iteration = $next | .[$i].phase = $next_phase
  else . end
' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Output block decision for phase transitions
case "$ACTION" in
  to_next_phase)
    echo "{\"decision\":\"block\",\"reason\":\"Run /${NEXT_PHASE} now. Review only — identify issues but do NOT edit any files.\"}"
    ;;
  to_next_iteration)
    echo "{\"decision\":\"block\",\"reason\":\"Starting iteration ${NEXT}/${MAX_ITERATIONS}. Run /${NEXT_PHASE} now. Review only — identify issues but do NOT edit any files.\"}"
    ;;
esac
