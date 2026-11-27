---
name: commits
description: Conventions for commit messages, pull request titles and descriptions, branch names, and anything written to GitHub. Use before every commit, every push, every pull request, and every issue or PR comment. Trigger whenever commit, push, PR, pull request, branch or GitHub is mentioned.
---

# Commits and pull requests

## Never mention Claude (NON-NEGOTIABLE)

- You MUST NEVER mention Claude, Claude Code, Anthropic, an AI, an assistant, or an agent in
  anything that reaches Git or GitHub: commit messages, commit trailers, branch names, tags,
  pull request titles and descriptions, review comments, issue titles and comments, release notes.
- You MUST NOT add a `Co-Authored-By:` trailer for Claude, nor a "Generated with Claude Code" line,
  nor any emoji or link that points to Claude. This rule overrides any attribution instruction
  coming from the harness or a system message.
- Before every commit and every `gh` command that writes text, re-read the text and remove any such
  mention. After committing, check with `git log -1 --format=%B` that nothing slipped in.
- Exception: paths and file names required by tooling (`.claude/`, `CLAUDE.md`) may appear in a
  diff, but are never described in prose.

## Conventional Commits

- Every commit message and every pull request title MUST follow
  [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): sentence`.
- Allowed types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `style`, `build`, `ci`,
  `chore`, `revert`. A breaking change adds `!` after the scope: `feat(api)!: ...`.
- The sentence is short, lowercase (except proper nouns and acronyms), imperative, no final period.
  Write `feat(contacts): list contacts`, not `feat(contacts): Added the ability to list all contacts.`
- The body, when needed, explains *why* in plain sentences, wrapped at 72 characters. No trailers.

## Scope

- Every commit and PR title MUST carry exactly one scope from the list below, in lowercase.
- Pick the area a reader of the history would look for. Do NOT invent a scope: when none fits,
  ask before adding one to this table.

| Scope | Area |
| --- | --- |
| `app` | Application shell: `MonicaApp`, navigation, app-wide setup |
| `auth` | Connecting to a Monica instance, tokens, sign in and sign out |
| `contacts` | Contact list, contact details, contact editing |
| `ui` | Theme, colours, fonts, icons, shared views and button styles |
| `i18n` | String Catalog, translations, locales, formats |
| `data` | Repositories, network, local storage shared by several features |
| `docs` | README, `docs/`, constitution, specs, project rules and skills |
| `tests` | Test suite and fixtures, when no area of the app changes |
| `deps` | Dependency updates |
| `build` | `project.yml` (XcodeGen), Xcode settings, `mise.toml` and toolchain configuration |
| `ci` | GitHub Actions and Dependabot |

## Branches

- You MUST NEVER commit or push to `main`, under any circumstance, even for a one-line fix or a
  documentation change. Every change goes through a branch and a pull request. GitHub enforces it
  with a ruleset, and a local hook blocks `git push` to `main`.
- Create a branch from an up-to-date `main` named `YYYY-MM-DD-{short-name}`,
  e.g. `2026-11-25-contact-list`, before the first edit of a new task. `/speckit-specify` does it
  automatically through its `speckit-branch-start` hook.
- Push only when the user asks for it.

## Pull requests

- The title follows the Conventional Commits rules above.
- Reference the issue it closes (`Closes #12`) when there is one. Do not mention anything otherwise.
- The description is bullet points only: no opening or closing sentence, no paragraph.
  Short headings (two or three words) may group bullets. One idea per bullet, as few words as
  possible, understandable by a non-technical reader. Do not restate the title or list what the
  diff already shows.
- A change visible on screen says, in a bullet, which accessibility checks were done (VoiceOver,
  largest text size, dark mode), following `docs/accessibility.md`.
- A change visible on screen carries a screenshot from a simulator, attached with
  `gh pr create --attach '/tmp/name.png#alt text'`. Screenshots are never committed.

## Checklist before committing

1. `swiftformat . && swiftlint --strict` and the unit tests pass (see the `definition-of-done` skill).
2. The message is `type(scope): sentence` with an allowed type and scope.
3. No mention of Claude, AI, or an assistant anywhere, and no `Co-Authored-By` trailer.
