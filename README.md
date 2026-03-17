# Roadhouse!

A Claude Code plugin that uses introspection to polish code to world-class standards. After any task — whether completed by an agentic loop, manual prompting, or any other workflow — run `/rounds` and let Claude review its own work until it's genuinely proud of the result.

<img src="https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExbXlwczRxYmpiemV0b3ozajFib2hlN2k3Y2Z2dWt1ejN5NmkxcHdlZiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/NCzhota4GsrKM/giphy.gif" width="355" height="150" alt="roadhouse"> <img src="https://media.tenor.com/2VXcRUPIy_EAAAAM/road-house-family-guy.gif" width="200" height="150" alt="road house">

## `/proud` and `/exquisite`

Two deceptively simple prompts that tap into something models already have but rarely use unprompted: pride in craft.

`/proud` asks: *"Are you proud of the work you have done in this session?"*

`/exquisite` asks: *"Would you call this work exquisite? Is it world class?"*

That's it. No elaborate rubrics, no checklists. Just a direct appeal to the engineer hiding inside the model. There is a world-class software engineer buried in there — one that catches copy-paste bugs, spots lazy placeholder code, flags missing edge cases, and calls out half-finished implementations. These prompts give it permission to speak up. The difference between code that "works" and code that's actually good often comes down to whether anyone bothered to look at it with a critical eye. `/proud` and `/exquisite` make that second look automatic.

## Installation

```bash
claude plugin marketplace add robertbagge/claude-registry
claude plugin install roadhouse@claude-registry
```

## Usage

```
/roadhouse:rounds          # 1 iteration (proud -> exquisite)
/roadhouse:rounds N        # N iterations
/roadhouse:rounds done     # Loop until both return roadhouse! (max 50)
/roadhouse:rounds cancel   # Cancel active loop

/roadhouse:proud            # Standalone pride check
/roadhouse:exquisite        # Standalone world-class check
```

Claude Code allows you to use the shorthand `/rounds`, `/proud`, and `/exquisite` unless you have another plugin with a conflicting skill name.

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
proud/exquisite ──► needs-work ──► fix ───┐
       │                                  │
       └──► roadhouse! ──► terminate?     │
              │ no                         │
              ▼                            ▼
           next review ◄──────────────────┘

terminate when: both proud & exquisite return roadhouse!, or iteration >= max_iterations
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

## Inspired by Ralph Wiggum

The agentic loop concept comes from the [Ralph Wiggum](https://ghuntley.com/ralph/) pattern by Geoffrey Huntley — at its core, just `while true; do claude; done`. Ralph loops until a *task is complete*: tests pass, code compiles, a completion promise is emitted. Anthropic ships an official implementation as a Claude Code plugin: [ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum).

Roadhouse is not a replacement for Ralph — it solves a different problem. Ralph gets the work *done*. Roadhouse makes sure the work is *good*. Run it after any task — whether that task was completed by Ralph, by you manually prompting Claude, or by any other workflow. `/rounds` asks the model to review what it built with a critical eye, iterate on what falls short, and only stop when the result meets its own standard for world class.

## Performance

Both hooks use tiered fast paths to minimize cost for non-rounds work:

**PreToolUse** (fires on every Skill call):
1. `grep` stdin for `"rounds"` — no jq spawned for other skills

**Stop hook** (fires on every session stop):
1. No state file -> exit (no stdin read)
2. No `"active": true` in file -> exit
3. Session ID not in file -> exit (cheap grep)
4. Full jq processing only when this session has an active loop
