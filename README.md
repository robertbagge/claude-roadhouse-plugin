# roadhouse

Iterative code improvement loop using `/proud` and `/exquisite` introspection. Run `/rounds` to polish your code until it's world class.

## Installation

```bash
claude plugin add robertbagge/claude-roadhouse-plugin
```

## Usage

```
/rounds          # 1 iteration (proud -> exquisite)
/rounds N        # N iterations
/rounds done     # Loop until /exquisite returns <verdict>roadhouse!</verdict> (max 50)
/rounds cancel   # Cancel active loop
```

## Architecture

Two hooks drive the loop mechanically — Claude only needs to run `/proud` once to start.

```
┌─────────────────────┐
│  PreToolUse hook     │  Fires on Skill() calls, filters for "rounds"
│  rounds-pretool-hook │  Handles: setup, cancel, argument validation
└────────┬────────────┘
         │ creates state record with session_id
         ▼
┌─────────────────────┐
│  SKILL.md            │  Runs /proud to begin first iteration
└────────┬────────────┘
         ▼
┌─────────────────────┐
│  Stop hook           │  Fires on every session stop
│  rounds-stop-hook    │  Chains /proud -> /exquisite -> /proud -> ...
└─────────────────────┘  Terminates on max iterations or both commands returning roadhouse!
```

### Session isolation

Each record is stamped with `session_id` at creation (in the PreToolUse hook),
so the Stop hook only acts on its own session's record. Multiple concurrent
sessions in the same repo do not interfere with each other.

### Stale session cleanup

The PreToolUse hook prunes records older than 7 days on every `/rounds` invocation.

## State file

**Path:** `.claude/roadhouse-loop.local.json` (gitignored)

JSON array of session records:

```json
[
  {
    "session_id": "f5ac8f63-602c-4f47-a41d-f9dd67238388",
    "active": true,
    "iteration": 1,
    "max_iterations": 3,
    "mode": "count",
    "phase": "proud",
    "started_at": "2026-03-16T10:00:00Z"
  }
]
```

### Schema

| Field            | Type    | Description                                                  |
|------------------|---------|--------------------------------------------------------------|
| `session_id`     | string  | Claude Code session UUID, stamped at creation                |
| `active`         | boolean | `true` while loop is running, `false` when complete/cancelled|
| `iteration`      | integer | Current iteration (1-indexed)                                |
| `max_iterations` | integer | Limit. `1` for `/rounds`, `N` for `/rounds N`, `50` for `done` |
| `mode`           | string  | `"count"` (fixed iterations) or `"done"` (until roadhouse!) |
| `phase`          | string  | `"proud"` or `"exquisite"` — current phase within iteration |
| `started_at`     | string  | ISO 8601 UTC timestamp of loop creation                      |

### Phase transitions

```
proud ──(stop hook)──► exquisite ──(stop hook)──► proud (next iteration)
                                  │
                                  ├── both proud & exquisite return roadhouse! -> active=false
                                  └── iteration >= max_iterations -> active=false
```

## Files

```
claude-roadhouse-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── rounds/
│   │   └── SKILL.md
│   ├── proud/
│   │   └── SKILL.md
│   └── exquisite/
│       └── SKILL.md
├── hooks/
│   └── hooks.json
└── scripts/
    ├── rounds-init.sh
    ├── rounds-pretool-hook.sh
    ├── rounds-stop-hook.sh
    └── rounds-userprompt-hook.sh
```

## Performance

Both hooks use tiered fast paths to minimize cost for non-rounds work:

**PreToolUse** (fires on every Skill call):
1. `grep` stdin for `"rounds"` — no jq spawned for other skills

**Stop hook** (fires on every session stop):
1. No state file -> exit (no stdin read)
2. No `"active": true` in file -> exit
3. Session ID not in file -> exit (cheap grep)
4. Full jq processing only when this session has an active loop
