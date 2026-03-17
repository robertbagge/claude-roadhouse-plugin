---
name: rounds
description: Iterative code improvement loop using /proud and /exquisite introspection.
  Use when asked to run improvement loops on current work. Supports `/rounds` (1 loop),
  `/rounds N` (N loops), `/rounds done` (until exquisite says roadhouse!), `/rounds cancel`.
argument-hint: "[N | done | cancel]"
---

You are running the roadhouse loop. The hooks have already initialized the loop state.

Run `/proud` to begin the first iteration.
Reviews identify issues without editing files. If a review finds issues, the hook will
instruct you to fix them before the next review runs.

The stop hook will mechanically chain reviews and fixes, handling
iteration counting and termination.
You do not need to manage the loop yourself — just start it by running `/proud`.
