---
name: bounce
description: Generic review loop with configurable review commands. Takes a comma-separated
  list of review skills that output <verdict> tags. Supports N (count), done (until all
  pass), cancel.
argument-hint: "<commands> [N | done | cancel]"
---

You are running a review loop. The hooks have already initialized the loop state.

Your first argument is a comma-separated list of review commands. Parse it and run
the first one to begin.

Reviews identify issues without editing files. If a review finds issues, the hook will
instruct you to fix them before the next review runs.

The stop hook will mechanically chain reviews and fixes, handling
iteration counting and termination.
You do not need to manage the loop yourself — just start it by running the first review.
