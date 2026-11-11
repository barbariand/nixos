#!/usr/bin/env bash
set -euo pipefail

ATTIC_CACHE="simd"
ATTIC_SERVER="https://cache.simd.me"

# --- 1. Secure SSH Setup ---
SSH_KEY_FILE="$(mktemp)"
# Trap ensures the key is safely deleted when the script exits (success or failure)
trap 'rm -f "$SSH_KEY_FILE"' EXIT

if [ -n "${RUNNER_DEPLOY_KEY:-}" ]; then
  echo "=== Configuring SSH for private flake inputs ==="
  echo "$RUNNER_DEPLOY_KEY" > "$SSH_KEY_FILE"
  chmod 600 "$SSH_KEY_FILE"
  export GIT_SSH_COMMAND="ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=accept-new"
else
  echo "=== WARNING: RUNNER_DEPLOY_KEY is not set. Private inputs may fail ==="
fi

# --- 2. Configure Nix Arguments & Overrides ---
NIX_ARGS=(--extra-experimental-features "nix-command flakes pipe-operators")

if [ -f "sensible-branch.txt" ]; then
  SENSIBLE_BRANCH=$(tr -d '[:space:]' < sensible-branch.txt)
  if [ -n "$SENSIBLE_BRANCH" ]; then
    echo "=== Override active: Using sensible branch '$SENSIBLE_BRANCH' ==="
    NIX_ARGS+=(--override-input "sensible" "git+ssh://git@git.urgobalt.dev/urgobalt/sensible-nix.git?ref=$SENSIBLE_BRANCH")
  fi
fi

# --- 3. Fetch Targets ---
echo "=== Fetching target hosts from nixosConfigurations ==="
HOSTS=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json "${NIX_ARGS[@]}" | jq -r '.[]')

TARGETS=()
for host in $HOSTS; do
  TARGETS+=(".#nixosConfigurations.\"${host}\".config.system.build.toplevel")
done

echo "Building system derivations for: ${HOSTS//$'\n'/ }"

# --- 4. Build Systems ---
# NIX_ARGS is expanded safely as individual arguments
BUILD_OUTPUTS=$(nix build "${TARGETS[@]}" \
  --no-link \
  --print-out-paths \
  "${NIX_ARGS[@]}")

echo "=== Build completed successfully ==="

# --- 5. Push to Attic ---
if [ -n "${ATTIC_TOKEN:-}" ]; then
  echo "=== Authenticating with local Attic server ==="
  attic login local "$ATTIC_SERVER" "$ATTIC_TOKEN" 2>/dev/null || true
fi

echo "=== Pushing store paths to Attic ($ATTIC_CACHE) ==="
# Using a while-read loop avoids subshell issues and handles multi-line outputs perfectly
while read -r out_path; do
  if [ -n "$out_path" ]; then
    echo "Pushing $out_path..."
    attic push "local:${ATTIC_CACHE}" "$out_path"
  fi
done <<< "$BUILD_OUTPUTS"

echo "=== All machine configurations successfully built and cached in Attic ==="
