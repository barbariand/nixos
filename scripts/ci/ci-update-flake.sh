#!/usr/bin/env bash
set -uo pipefail

CI_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$CI_DIR/lib.sh"

trap cleanup_ssh EXIT
setup_ssh

echo "=== Configuring Git User ==="
git config user.name "Forgejo Build Bot"
git config user.email "bot@simd.me"

git checkout master >/dev/null 2>&1

echo "=== Updating flake.lock ==="
log_file="flake-update.log"
nix flake update --extra-experimental-features "nix-command flakes" --no-warn-dirty 2> "$log_file"
status=$?

if [ $status -ne 0 ]; then
  echo "=== ❌ Flake update failed (Exit code: $status) ==="
  cat "$log_file"
  rm -f "$log_file"
  exit "$status"
fi
rm -f "$log_file"

if ! git diff --quiet flake.lock; then
  echo "=== Committing dependency updates ==="
  git add flake.lock
  git commit -m "chore(flake): weekly flake lock update" >/dev/null
  git push origin master >/dev/null 2>&1
else
  echo "=== No dependency updates detected in flake.lock ==="
fi

echo "=== Advancing staging branch ==="
git push origin HEAD:staging --force >/dev/null 2>&1
