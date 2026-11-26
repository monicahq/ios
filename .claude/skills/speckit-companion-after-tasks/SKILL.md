---
name: speckit-companion-after-tasks
description: Record the tasks finish in .spec-context.json for the Companion GUI
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  source: companion:commands/speckit.companion.after-tasks.md
user-invocable: true
disable-model-invocation: false
---

# Capture Tasks Finish

Run this from the repository root to record that tasks finished; if `python3` is missing, say the step was not recorded and carry on.

```bash
python3 .specify/extensions/companion/scripts/write-context.py --hook finish --step tasks
```
