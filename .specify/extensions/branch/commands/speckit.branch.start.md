---
description: "Update main and create the feature branch before writing a specification"
---

# Start a feature branch

Every specification starts on a new branch created from an up-to-date `main`. This command only
creates the branch; the specification itself is written by `__SPECKIT_COMMAND_SPECIFY__`.

## User Input

```text
$ARGUMENTS
```

## Steps

1. Choose a short name for the feature: 2 to 4 lowercase words in English separated by hyphens,
   action-noun when possible (`contact-list`, `sign-in`, `reminder-notifications`). Do not include
   the date, the script adds it.
2. Run, from the repository root:

   ```bash
   .specify/extensions/branch/scripts/bash/start-feature-branch.sh --json "<short-name>"
   ```

3. The script refuses to run when the working tree has uncommitted changes, when `main` cannot be
   fast-forwarded, or when the branch already exists. In that case, STOP: show the error to the
   user and ask how to proceed. Never stash, reset, discard, or commit their changes yourself, and
   never write the specification on `main` or on another feature's branch.
4. On success, the JSON output contains `BRANCH_NAME`. Report it, then continue with the
   specification.
