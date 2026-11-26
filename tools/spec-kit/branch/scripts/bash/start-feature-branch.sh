#!/usr/bin/env bash
# Create a YYYY-MM-DD-<short-name> branch from an up-to-date main.
# Usage: start-feature-branch.sh [--json] <short-name>
set -euo pipefail

json=false
if [ "${1:-}" = "--json" ]; then json=true; shift; fi
short_name="${1:-}"

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -n "$short_name" ] || fail "missing short name. Usage: $0 [--json] <short-name>"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository."

slug=$(printf '%s' "$short_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
[ -n "$slug" ] || fail "short name '$short_name' contains no usable characters."
branch="$(date +%Y-%m-%d)-$slug"

[ -z "$(git status --porcelain)" ] || fail "the working tree has uncommitted changes. Commit or stash them first."
git show-ref --verify --quiet "refs/heads/$branch" && fail "branch '$branch' already exists."

git switch --quiet main
if git remote get-url origin >/dev/null 2>&1; then
  git pull --quiet --ff-only origin main || fail "could not fast-forward main from origin."
fi
git switch --quiet -c "$branch"

if $json; then
  printf '{"BRANCH_NAME":"%s","BASE":"main","BASE_COMMIT":"%s"}\n' "$branch" "$(git rev-parse --short main)"
else
  echo "Created $branch from main ($(git rev-parse --short main))."
fi
