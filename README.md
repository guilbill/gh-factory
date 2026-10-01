# gh-factory

A software factory on GitHub Actions, driven by Claude Code skills. Open an issue and
agents triage it, write specs when needed, implement it, review the PR, fix the review
and learn from your feedback. Works on any stack: the agent reads your repo to find how
to install, lint and test it.

```
issue opened ─▶ triage ─▶ Ready to spec ─▶ spec PR
                       └▶ Ready to implement ─▶ implementation PR ─▶ review ─▶ fix (2 rounds max, or /fix)
daily: human reactions to reviews ─▶ .agents/review-lessons.md PR
```

## Wire a repository

```bash
gh extension install guilbill/gh-factory
cd path/to/your-repo
gh factory init
```

`init` creates a `chore/wire-factory` branch with six small `factory-*.yml` workflows
and an empty `.agents/review-lessons.md`. It also creates the triage labels, asks for the
two secrets and opens a PR. Merge it, open an issue, and watch the **Factory Triage** run.

You need admin access to the repository to set secrets and labels. `gh factory init
--local` only writes the files, if you prefer to review and commit them yourself.

### Secrets

| Secret | What it is |
|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude subscription token, from `claude setup-token` |
| `FACTORY_TOKEN` | Fine-grained PAT on this repository with Contents, Issues, Pull requests and Actions in read and write. Without it, labels and pushes made by the factory do not trigger the next workflow. |

## Tune it for your repository

- **Commands**: the agent follows `AGENTS.md` or `CLAUDE.md` when they say how to
  install, lint and test. Otherwise it reads your CI and manifests. If it guesses
  wrong, write the commands down in `AGENTS.md`.
- **Extra tools**: the agent may only run common package managers and build tools.
  Uncomment `extra_allowed_tools` in `factory-implement.yml` and
  `factory-address-review.yml` to allow more, e.g. `Bash(docker:*)`.
- **Review conventions**: edit `.agents/review-lessons.md`. The daily
  `Factory Improve Review` run proposes additions from your reactions to review comments.
- **Ask for a fix**: comment `/fix <instructions>` on a factory PR.

## Upgrade

Callers pin the moving major tag (`@v1`), so fixes arrive on their own. To move to a new
major version:

```bash
gh extension upgrade factory
gh factory upgrade
```

## How it works

The `factory-*.yml` files in your repository only hold triggers. They call the reusable
workflows in this repository, which check out your code, then this repository's
`skills/` into `.factory/` (never committed), and run
[claude-code-action](https://github.com/anthropics/claude-code-action) with a skill.
Agents that read run with read-only tokens; writing (labels, comments, review) happens
in separate jobs.

| Workflow | Trigger | Skill |
|---|---|---|
| `triage.yml` | issue opened | `triage` |
| `spec.yml` | `Ready to spec` label | `spec`, `write-product-spec`, `write-tech-spec` |
| `implement.yml` | `Ready to implement` label | `implementation`, `repo-toolchain`, `validate-changes-match-specs` |
| `review.yml` | PR opened or updated | `review-pr` |
| `address-review.yml` | changes requested, `/fix`, conflicts after a push | `address-review`, `repo-toolchain` |
| `improve-review.yml` | daily | `improve-review-pr` |

No computer use: UI changes are not checked visually, and PRs say so.

## Develop

```bash
scripts/lint.sh
scripts/test.sh
```

`lint.sh` runs shellcheck and actionlint (natively or through Docker). `test.sh`
exercises `init --local` and `upgrade --local` in a throwaway repository.

## License

MIT. Adapted from Warp's MIT-licensed factory skills, see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
