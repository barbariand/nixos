#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

trap cleanup_ssh EXIT
setup_ssh

echo "=== Configuring Git User ==="
git config user.name "Forgejo Build Bot"
git config user.email "bot@simd.me"

git checkout master >/dev/null 2>&1

run_silent_on_success "flake-update" nix flake update --extra-experimental-features "nix-command flakes" --no-warn-dirty

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
