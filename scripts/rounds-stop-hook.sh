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
      .value.commands as $cmds |
      [.key, .value.phase, .value.iteration, .value.max_iterations,
       ($cmds[] | select(.command == "proud") | .result),
       ($cmds[] | select(.command == "exquisite") | .result)] | @tsv
    end
  end
' <<< "$HOOK_INPUT")

if [[ -z "$RECORD" ]]; then
  exit 0
fi

IFS=$'\t' read -r IDX PHASE ITERATION MAX_ITERATIONS PROUD_RESULT EXQUISITE_RESULT <<< "$RECORD"

# --- DECIDE (pure bash) ---

# If review said needs-work, inject a fix turn and return early.
# The fix turn will have no verdict tag, so it falls through to
# normal transition logic on the next stop.
if grep -qF '<verdict>needs-work</verdict>' <<< "$HOOK_INPUT"; then
  echo '{"decision":"block","reason":"The review found issues. Fix them now — apply the changes described above. Do not run /proud or /exquisite. Just make the edits and stop."}'
  exit 0
fi

# Verdict: grep directly on hook input (avoids jq for last_assistant_message)
if grep -qF '<verdict>roadhouse!</verdict>' <<< "$HOOK_INPUT"; then
  VERDICT="roadhouse!"
else
  VERDICT="needs-work"
fi

# Compute post-update command results
if [[ "$PHASE" == "proud" ]]; then
  NEW_PROUD="$VERDICT"; NEW_EXQUISITE="$EXQUISITE_RESULT"
else
  NEW_PROUD="$PROUD_RESULT"; NEW_EXQUISITE="$VERDICT"
fi

# Determine transition action
ACTION="none"
NEXT=0
if [[ "$NEW_PROUD" == "roadhouse!" ]] && [[ "$NEW_EXQUISITE" == "roadhouse!" ]]; then
  ACTION="deactivate"
elif [[ "$PHASE" == "exquisite" ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  ACTION="deactivate"
elif [[ "$PHASE" == "proud" ]]; then
  ACTION="to_exquisite"
elif [[ "$PHASE" == "exquisite" ]]; then
  ACTION="to_proud"
  NEXT=$((ITERATION + 1))
fi

# --- WRITE (1 jq spawn) ---
# Update command row + apply transition, read from file, write atomically
jq --argjson i "$IDX" --arg cmd "$PHASE" --argjson iter "$ITERATION" --arg v "$VERDICT" \
  --arg action "$ACTION" --argjson next "$NEXT" '
  .[$i].commands |= map(
    if .command == $cmd then .iteration = $iter | .result = $v else . end
  ) |
  if $action == "deactivate" then .[$i].active = false
  elif $action == "to_exquisite" then .[$i].phase = "exquisite"
  elif $action == "to_proud" then .[$i].iteration = $next | .[$i].phase = "proud"
  else . end
' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Output block decision for phase transitions
case "$ACTION" in
  to_exquisite)
    echo '{"decision":"block","reason":"Run /exquisite now. Review only — identify issues but do NOT edit any files."}'
    ;;
  to_proud)
    echo "{\"decision\":\"block\",\"reason\":\"Starting iteration ${NEXT}/${MAX_ITERATIONS}. Run /proud now. Review only — identify issues but do NOT edit any files.\"}"
    ;;
esac
