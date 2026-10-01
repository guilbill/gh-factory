---
name: repo-toolchain
description: Find out how to install, lint, typecheck, test and build the current repository, whatever its stack, then run those checks. Use before validating any code change made by an automated agent, when the repository's commands are not given in the prompt.
---

# Repo toolchain

Work out the repository's own commands from what is checked in. Never assume a stack.

## 1. Read what the maintainers wrote

Check these first, in order. The first one that documents commands wins over anything you infer later:

1. `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`
2. `CONTRIBUTING.md`, `README.md` (sections such as Development, Testing, Getting started)
3. `Makefile`, `justfile`, `Taskfile.yml`: targets like `install`, `lint`, `test`, `check`

## 2. Read the CI

Open the workflows under `.github/workflows/` that run on `pull_request` (skip the `factory-*` ones). Their `run:` steps are the checks a PR must pass, and their `setup-*` steps tell you the runtime and version. Mirror them.

## 3. Infer from manifests

When steps 1 and 2 are silent, use the manifest and lock file at the repository root (or the package being changed in a monorepo):

| Manifest | Install | Usual checks |
|---|---|---|
| `package.json` + `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` / `bun.lockb` | `npm ci` / `pnpm install --frozen-lockfile` / `yarn install --frozen-lockfile` / `bun install` | the `lint`, `typecheck`, `test`, `build` scripts in `package.json` |
| `pyproject.toml` + `uv.lock` / `poetry.lock`, `requirements*.txt` | `uv sync` / `poetry install` / `pip install -r ...` | `ruff`, `mypy`, `pytest` when configured |
| `composer.json` | `composer install` | the `scripts` in `composer.json`, `phpunit`, `phpstan`, `php-cs-fixer` |
| `go.mod` | `go mod download` | `go vet ./...`, `go test ./...`, `golangci-lint run` when configured |
| `Cargo.toml` | `cargo fetch` | `cargo clippy`, `cargo test` |
| `Gemfile` | `bundle install` | `bundle exec rake`, `rspec`, `rubocop` |
| `pom.xml` / `build.gradle*` | `./mvnw -q -DskipTests install` / `./gradlew assemble` | `./mvnw test` / `./gradlew check` |

Respect pinned runtime versions (`.nvmrc`, `.node-version`, `.python-version`, `.tool-versions`, `engines`). If the runner has a different version and the checks fail because of it, say so rather than rewriting the pin.

## 4. Run the checks

- Install dependencies once, before the first check.
- Run the narrowest useful set: tests for the changed area first, then lint, typecheck and build if they exist.
- Use the repository's formatter in check mode when CI runs it, and apply it to the files you changed.
- Skip commands that need services you do not have (database, Docker, secrets). Name them in your report instead of faking a pass.

## 5. Report

List each command you ran with its result (pass, fail, skipped and why). Never claim a check passed if you did not run it.

If you had to guess the commands, end your report with one sentence suggesting the maintainers document them in `AGENTS.md`.
