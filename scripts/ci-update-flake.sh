#!/usr/bin/env bash
set -euo pipefail

# --- 1. Secure SSH Setup ---
SSH_KEY_FILE="$(mktemp)"
trap 'rm -f "$SSH_KEY_FILE"' EXIT

if [ -n "${RUNNER_DEPLOY_KEY:-}" ]; then
  echo "=== Configuring SSH for flake update ==="
  echo "$RUNNER_DEPLOY_KEY" > "$SSH_KEY_FILE"
  chmod 600 "$SSH_KEY_FILE"
  export GIT_SSH_COMMAND="ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=accept-new"
fi

# --- 2. Configure Git ---
echo "=== Configuring Git User ==="
git config user.name "Forgejo Build Bot"
git config user.email "bot@simd.me"

# --- 3. Update and Commit ---
echo "=== Updating flake.lock ==="
git checkout master
nix flake update --extra-experimental-features "nix-command flakes"

if ! git diff --quiet flake.lock; then
  echo "=== Committing dependency updates ==="
  git add flake.lock
  git commit -m "chore(flake): weekly flake lock update"
  git push origin master
else
  echo "=== No dependency updates detected in flake.lock ==="
fi

echo "=== Advancing staging branch ==="
git push origin HEAD:staging --force
