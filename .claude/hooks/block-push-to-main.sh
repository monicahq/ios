#!/usr/bin/env bash
# Refuse any git push that lands on main. Work always goes through a branch and a pull request.
#
# A push that names what it pushes (`git push origin my-branch`, `HEAD:main`, `--set-upstream
# origin x`) is judged by that destination. A bare push (`git push`, `git push origin`) pushes the
# current branch, so it is judged by the branch checked out, or by the branch an earlier
# `git checkout -b` / `git switch -c` of the same command creates (the hook runs before the
# command, while the old branch is still checked out).
input=$(cat)
branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)

HOOK_INPUT="$input" CURRENT_BRANCH="$branch" python3 - <<'PY'
import json, os, re, shlex, sys

command = json.loads(os.environ["HOOK_INPUT"]).get("tool_input", {}).get("command", "")
branch = os.environ.get("CURRENT_BRANCH", "")


def is_main(ref):
    return re.sub(r"^\+?(refs/heads/)?", "", ref) == "main"


def block():
    print("Blocked: never push to main. Create a dated branch (YYYY-MM-DD-name) and open a pull request.",
          file=sys.stderr)
    sys.exit(2)


# Segments of a compound command, in order (split on ; & | and newlines).
for segment in re.split(r"[;&|\n]+", command):
    try:
        words = shlex.split(segment)
    except ValueError:
        words = segment.split()
    if "git" not in words:
        continue
    words = words[words.index("git") + 1:]
    while words[:1] == ["-C"]:
        words = words[2:]
    if not words:
        continue
    verb, args = words[0], words[1:]

    # A branch created and checked out before the push becomes the current branch.
    if (verb == "checkout" and args[:1] == ["-b"]) or (verb == "switch" and args[:1] in (["-c"], ["-C"])):
        if len(args) > 1:
            branch = args[1]
        continue
    if verb in ("checkout", "switch") and args and not args[0].startswith("-"):
        branch = args[0]
        continue
    if verb != "push":
        continue

    # Options taking a value as the next word; everything else starting with - is a flag.
    with_value = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
    positional, skip = [], False
    for arg in args:
        if skip:
            skip = False
        elif arg in with_value:
            skip = True
        elif not arg.startswith("-"):
            positional.append(arg)
    refspecs = positional[1:]  # the first one is the remote

    if not refspecs:
        if branch == "main" or "--all" in args or "--mirror" in args:
            block()
        continue
    for refspec in refspecs:
        destination = refspec.split(":", 1)[1] if ":" in refspec else refspec
        if destination == "HEAD":
            destination = branch
        if is_main(destination):
            block()
PY
