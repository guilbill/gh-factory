#!/usr/bin/env bash
# Lints the extension script, the reusable workflows and the caller templates.
# Caller templates are rendered against local copies of the reusable workflows,
# so actionlint also checks their inputs and secrets.
set -euo pipefail

cd "$(dirname "$0")/.."
ACTIONLINT_IMAGE="rhysd/actionlint:1.7.12"
SHELLCHECK_IMAGE="koalaman/shellcheck:stable"

run_shellcheck() {
  if command -v shellcheck >/dev/null; then
    shellcheck "$@"
  else
    docker run --rm -v "$PWD:/mnt" -w /mnt "$SHELLCHECK_IMAGE" "$@"
  fi
}

run_actionlint() {
  local dir="$1"
  if command -v actionlint >/dev/null; then
    (cd "$dir" && actionlint -no-color -oneline)
  else
    docker run --rm -v "$dir:/repo" -w /repo "$ACTIONLINT_IMAGE" -no-color -oneline
  fi
}

echo "shellcheck"
run_shellcheck gh-factory scripts/*.sh

echo "actionlint: reusable workflows"
run_actionlint "$PWD"

echo "actionlint: caller templates"
# Inside the repo, so a dockerized actionlint can mount it.
tmp="$(mktemp -d "$PWD/.lint.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
chmod 755 "$tmp" # readable by the container user
mkdir -p "$tmp/.github/workflows"
cp .github/actionlint.yaml "$tmp/.github/"
cp .github/workflows/*.yml "$tmp/.github/workflows/"
for template in templates/workflows/*.yml; do
  sed -e 's|uses: __FACTORY_REPO__/|uses: ./|' -e 's|@__FACTORY_REF__||' -e 's|__DEFAULT_BRANCH__|main|g' \
    "$template" > "$tmp/.github/workflows/$(basename "$template")"
done
git -C "$tmp" init -q
run_actionlint "$tmp"

echo "lint ok"
