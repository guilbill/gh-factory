# gh-factory design

Date: 2026-10-01

## Goal

Wire any GitHub repository, whatever its stack, onto the issue → triage → spec →
implement → review → fix factory proven in `guilbill/factory-bench`, with one
command: `gh factory init`.

## Decisions

- Skills and workflows live in one public repo, `guilbill/gh-factory`. Target repos
  only hold thin caller workflows.
- Skills are stack-agnostic. The agent discovers how to install, lint, typecheck and
  test a repo (`repo-toolchain` skill). The target repo's `AGENTS.md`/`CLAUDE.md`
  wins when it documents commands.
- Per-repo review learning goes to `.agents/review-lessons.md` in the target repo.
  `review-pr` reads it, `improve-review-pr` writes it through a PR.
- Agents get a broad but bounded Bash allowlist (common package managers and build
  tools), never unrestricted Bash, because write jobs hold `FACTORY_TOKEN`.
- No computer use: `verify-behavior` is dropped.

## Layout

```
gh-factory                    # gh extension entrypoint (bash)
.github/workflows/<x>.yml     # reusable workflows (on: workflow_call) + CI
templates/workflows/*.yml     # caller workflows written by init
skills/                       # agnostic skills and their scripts
LICENSE, THIRD_PARTY_NOTICES.md
```

Target repo after `init`:

```
.github/workflows/factory-{triage,spec,implement,review,address-review,improve-review}.yml
.agents/review-lessons.md
```

Plus labels (`Ready to implement`, `Ready to spec`, `Needs info`, `Wait to implement`)
and secrets (`CLAUDE_CODE_OAUTH_TOKEN`, `FACTORY_TOKEN`).

## Runtime

1. Caller workflows own the triggers (reusable workflows cannot) and call
   `guilbill/gh-factory/.github/workflows/<x>.yml@<ref>`. Secrets are passed
   explicitly: `secrets: inherit` only works inside one organization.
2. Each agent job checks out the target repo, then `gh-factory` at
   `job.workflow_repository`@`job.workflow_sha` (the called workflow's own commit)
   into `.factory/`, excluded through `.git/info/exclude` so it is never committed.
   Callers grant the maximum permissions; reusable jobs narrow them.
3. Prompts point at `.factory/skills/<x>/SKILL.md`; scripts run from
   `.factory/skills/<x>/scripts/`.
4. Read jobs (agent, read-only token) and write jobs (`FACTORY_TOKEN`) stay split.
5. `address-review` re-dispatches the caller workflow file
   (`factory-address-review.yml`), and listens to `workflow_run` of the caller named
   `Factory Review`. Template names are therefore fixed.

## Extension

`gh factory init [--ref v1] [--no-pr] [--skip-secrets] [--local] [--force]`

1. Refuses outside a git repo with a GitHub remote, without `gh` auth, or with a
   dirty tree.
2. Creates branch `chore/wire-factory` (unless `--local`).
3. Writes caller workflows from templates with the ref substituted. A differing
   existing file is shown as a diff and only overwritten after confirmation (or
   `--force`). Creates `.agents/review-lessons.md` only when absent.
4. Creates labels with `gh label create --force`.
5. For each missing secret: offers `claude setup-token` for
   `CLAUDE_CODE_OAUTH_TOKEN`, prints the fine-grained PAT creation link and
   required permissions for `FACTORY_TOKEN`, then reads the value through
   `gh secret set` (stdin, never echoed).
6. Commits, pushes and opens a "Wire the factory" PR (unless `--no-pr`).
7. Prints a summary and how to try it.

`--local` only writes files: no branch, labels, secrets, commit or PR.

`gh factory upgrade [ref]` rewrites `@<ref>` in `factory-*.yml`
(default: latest release tag), adds new templates, and opens a PR on
`chore/upgrade-factory-<ref>`.

Versioning: semver tags plus a moving major tag (`v1`). Callers default to `v1`.

## Skill changes

- `verify-behavior`: removed, with its references.
- `validate-changes-match-specs`: no Oz cloud validation, no Oz trailer, no
  interactive commit prompt.
- `write-product-spec`, `write-tech-spec`: Warp examples replaced by neutral ones.
- `implementation`, `address-review`: use the new `repo-toolchain` skill.
- `review-pr`: reads `.agents/review-lessons.md`.
- `improve-review-pr`: writes `.agents/review-lessons.md` instead of skill files.
- `triage`: `roadmap.md`/`vision.md` optional.

## Testing

1. gh-factory CI: `shellcheck` on the script, `actionlint` on workflows and templates.
2. Migrate `factory-bench`: remove its local factory, run `init`, replay
   issue → triage → PR → review → `/fix`.
3. Wire a non-JS repo and replay the same loop.
4. Re-run `init` on `factory-bench`: no changes expected.

Out of scope: per-repo setup actions, toolchain caching, Linear integration (the
native GitHub sync already covers it), PR previews.
