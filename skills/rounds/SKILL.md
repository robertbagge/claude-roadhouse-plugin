---
name: rounds
description: Iterative code improvement loop using /proud and /exquisite introspection.
  Use when asked to run improvement loops on current work. Supports `/rounds` (1 loop),
  `/rounds N` (N loops), `/rounds done` (until exquisite says roadhouse!), `/rounds cancel`.
argument-hint: "[N | done | cancel]"
---

You are running the roadhouse loop. The hooks have already initialized the loop state.

Run `/proud` to begin the first iteration.
This is a roadhouse loop — apply any improvements directly, then output your verdict.

The stop hook will mechanically chain `/proud` and `/exquisite` in a loop, handling
iteration counting and termination.
You do not need to manage the loop yourself — just start it by running `/proud`.
