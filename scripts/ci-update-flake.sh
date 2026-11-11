#!/usr/bin/env bash
set -euo pipefail

# --- 1. Secure SSH & Environment Setup ---
SSH_KEY_FILE="$(mktemp)"
trap 'rm -f "$SSH_KEY_FILE"' EXIT

export GIT_TERMINAL_PROMPT=0

if [ -n "${RUNNER_DEPLOY_KEY:-}" ]; then
  echo "=== Configuring SSH for flake update ==="
  echo "$RUNNER_DEPLOY_KEY" > "$SSH_KEY_FILE"
  chmod 600 "$SSH_KEY_FILE"
  export GIT_SSH_COMMAND="ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
fi

# --- 2. Configure Git ---
echo "=== Configuring Git User ==="
git config user.name "Forgejo Build Bot"
git config user.email "bot@simd.me"

# --- 3. Update and Commit ---
echo "=== Updating flake.lock (Silently) ==="
git checkout master >/dev/null 2>&1

if ! nix flake update \
  --extra-experimental-features "nix-command flakes" \
  --no-warn-dirty 2> nix-update-errors.log; then
  echo "=== ❌ FLAKE UPDATE FAILED ==="
  cat nix-update-errors.log
  rm -f nix-update-errors.log
  exit 1
fi
rm -f nix-update-errors.log

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
