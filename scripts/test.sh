#!/usr/bin/env bash
# Smoke-tests `gh-factory init --local` and `upgrade --local` in a throwaway repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GH_FACTORY_REPO="acme/gh-factory"

fail() { echo "FAIL: $*" >&2; exit 1; }

cd "$tmp"
git init -q -b trunk target
cd target
git commit -q --allow-empty -m init
git remote add origin "$tmp/remote.git"
git init -q --bare -b trunk "$tmp/remote.git"
git push -q origin trunk
git remote set-head origin trunk

echo "init --local"
"$ROOT/gh-factory" init --local --ref v1 > "$tmp/init.log" 2>&1
for name in triage spec implement review address-review improve-review; do
  file=".github/workflows/factory-$name.yml"
  [ -f "$file" ] || fail "$file was not written"
  grep -q "uses: acme/gh-factory/.github/workflows/$name.yml@v1" "$file" || fail "$file does not call $name.yml@v1"
  ! grep -q "__" "$file" || fail "$file still has a placeholder"
done
grep -q "branches: \[trunk\]" .github/workflows/factory-address-review.yml || fail "default branch not substituted"
[ -f .agents/review-lessons.md ] || fail "lessons file missing"

echo "init --local again is a no-op"
"$ROOT/gh-factory" init --local --ref v1 > "$tmp/init2.log" 2>&1
! grep -qE "created|updated" "$tmp/init2.log" || fail "second init changed files: $(cat "$tmp/init2.log")"

echo "init --local keeps hand edits without --force"
echo "# local tweak" >> .github/workflows/factory-review.yml
"$ROOT/gh-factory" init --local --ref v1 < /dev/null > "$tmp/init3.log" 2>&1
grep -q "local tweak" .github/workflows/factory-review.yml || fail "hand edit was overwritten"
"$ROOT/gh-factory" init --local --ref v1 --force > "$tmp/init4.log" 2>&1
! grep -q "local tweak" .github/workflows/factory-review.yml || fail "--force did not overwrite"

echo "upgrade --local v2 (and a transferred factory repo)"
rm .github/workflows/factory-improve-review.yml
GH_FACTORY_REPO="marmelab/gh-factory" "$ROOT/gh-factory" upgrade --local v2 > "$tmp/upgrade.log" 2>&1
for name in triage spec implement review address-review improve-review; do
  grep -q "uses: marmelab/gh-factory/.github/workflows/$name.yml@v2" ".github/workflows/factory-$name.yml" \
    || fail "factory-$name.yml was not upgraded"
done

echo "test ok"
