# Roadhouse!

A Claude Code plugin that uses introspection to polish code to world-class standards. Run `/bounce` with any combination of review skills, or use `/rounds` for the built-in proud + exquisite loop.

<img src="https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExbXlwczRxYmpiemV0b3ozajFib2hlN2k3Y2Z2dWt1ejN5NmkxcHdlZiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/NCzhota4GsrKM/giphy.gif" width="355" height="150" alt="roadhouse"> <img src="https://media.tenor.com/2VXcRUPIy_EAAAAM/road-house-family-guy.gif" width="200" height="150" alt="road house">

## Installation

```bash
claude plugin marketplace add robertbagge/claude-registry
claude plugin install roadhouse@claude-registry
```

## `/bounce` — the review loop

`/bounce` runs any combination of review skills in a loop, fixing issues between each review until everything passes.

```
/bounce proud,exquisite 2       # 2 iterations of proud → exquisite
/bounce proud,security,exquisite done  # 3 reviews per iteration, until all pass
/bounce proud                   # single review, 1 iteration
/bounce proud,exquisite cancel  # cancel active loop
```

### Review skill contract

Any skill can be used with `/bounce` as long as it follows the review contract:

- Review the work and identify issues, but **do not edit files**
- Output `<verdict>needs-work</verdict>` when changes are needed
- Output `<verdict>roadhouse!</verdict>` when the review passes

The built-in [`/proud`](skills/proud/SKILL.md) and [`/exquisite`](skills/exquisite/SKILL.md) skills are examples of this contract. You can write your own review skills (e.g. `/security`, `/performance`) — just follow the contract above.

## `/rounds` — the default loop

*/rounds* runs `/bounce proud,exquisite` to tap into something models already have but rarely use unprompted: pride in craft.

- /proud asks: *"Are you proud of the work you have done in this session?"*
- /exquisite` asks: *"Would you call this work exquisite? Is it world class?"*

That's it. No elaborate rubrics, no checklists. Just a direct appeal to the engineer hiding inside the model. There is a world-class software engineer buried in there — one that catches copy-paste bugs, spots lazy placeholder code, flags missing edge cases, and calls out half-finished implementations. These prompts give it permission to speak up. The difference between code that "works" and code that's actually good often comes down to whether anyone bothered to look at it with a critical eye. `/proud` and `/exquisite` make that second look automatic.

```
/rounds          # 1 iteration (proud → exquisite)
/rounds N        # N iterations
/rounds done     # Loop until both return roadhouse! (max 50)
/rounds cancel   # Cancel active loop
```

After any task — whether completed by an agentic loop, manual prompting, or any other workflow — run `/rounds` and let Claude review its own work with a critical eye.

Claude Code allows you to use the shorthand `/rounds`, `/bounce`, `/proud`, and `/exquisite` unless you have another plugin with a conflicting skill name.

## Architecture

Two hooks drive the loop mechanically — Claude only needs to run the first review command once to start.

```
┌─────────────────────┐
│  PreToolUse hook     │  Fires on Skill() calls, filters for "bounce"
│  loop-pretool-hook   │  Handles: setup, cancel, argument validation
└────────┬────────────┘
         │ creates state record with session_id and commands list
         ▼
┌─────────────────────┐
│  SKILL.md            │  Runs first review command to begin
└────────┬────────────┘
         ▼
┌─────────────────────┐
│  Stop hook           │  Fires on every session stop
│  loop-stop-hook      │  Chains review -> fix -> review -> fix -> ...
└─────────────────────┘  Terminates on max iterations or all reviews returning roadhouse!
```

### Session isolation

Each record is stamped with `session_id` at creation (in the PreToolUse hook),
so the Stop hook only acts on its own session's record. Multiple concurrent
sessions in the same repo do not interfere with each other.

### Stale session cleanup

Records older than 7 days are pruned on every loop initialization (i.e. every `/bounce` or `/rounds` invocation).

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
    "started_at": "2026-03-16T10:00:00Z",
    "commands": [
      {"command": "proud", "iteration": -1, "result": "not_run"},
      {"command": "exquisite", "iteration": -1, "result": "not_run"}
    ]
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
| `phase`          | string  | Current review command name (cycles through `commands` array)|
| `started_at`     | string  | ISO 8601 UTC timestamp of loop creation                      |
| `commands`       | array   | Review commands with per-command iteration and result tracking|
| `commands[].command`   | string  | Skill name (e.g. `"proud"`, `"exquisite"`, `"security"`)  |
| `commands[].iteration` | integer | Last iteration this command ran in (`-1` = not yet run)    |
| `commands[].result`    | string  | `"not_run"`, `"needs-work"`, or `"roadhouse!"`             |

### Phase transitions

Phase cycles through the `commands` array in order. After the last command, iteration increments and phase wraps to the first command.

```
command[0] → command[1] → ... → command[N-1] → command[0] (iteration++)
    ↕              ↕                   ↕
  fix turn       fix turn           fix turn

terminate when: all commands return roadhouse!, or iteration >= max_iterations on last phase
```

## Files

```
claude-roadhouse-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── bounce/
│   │   └── SKILL.md
│   ├── rounds/
│   │   └── SKILL.md
│   ├── proud/
│   │   └── SKILL.md
│   └── exquisite/
│       └── SKILL.md
├── hooks/
│   └── hooks.json
└── scripts/
    ├── loop-init.sh
    ├── loop-pretool-hook.sh
    ├── loop-stop-hook.sh
    └── loop-userprompt-hook.sh
```

## Inspired by Ralph Wiggum

The agentic loop concept comes from the [Ralph Wiggum](https://ghuntley.com/ralph/) pattern by Geoffrey Huntley — at its core, just `while true; do claude; done`. Ralph loops until a *task is complete*: tests pass, code compiles, a completion promise is emitted. Anthropic ships an official implementation as a Claude Code plugin: [ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum).

Roadhouse is not a replacement for Ralph — it solves a different problem. Ralph gets the work *done*. Roadhouse makes sure the work is *good*. Run it after any task — whether that task was completed by Ralph, by you manually prompting Claude, or by any other workflow. `/rounds` asks the model to review what it built with a critical eye, iterate on what falls short, and only stop when the result meets its own standard for world class.

## Performance

Both hooks use tiered fast paths to minimize cost for non-loop work:

**PreToolUse** (fires on every Skill call):
1. `grep` stdin for `"bounce"` — no jq spawned for other skills

**Stop hook** (fires on every session stop):
1. No state file -> exit (no stdin read)
2. No `"active": true` in file -> exit
3. Session ID not in file -> exit (cheap grep)
4. Full jq processing only when this session has an active loop
