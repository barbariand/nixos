#!/usr/bin/env bash
set -euo pipefail

ATTIC_CACHE="simd"
ATTIC_SERVER="http://127.0.0.1:5000"

echo "=== Fetching target hosts from nixosConfigurations ==="
# Dynamically extract all hostnames declared in flake.nix
HOSTS=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]')

TARGETS=()
for host in $HOSTS; do
  TARGETS+=(".#nixosConfigurations.\"${host}\".config.system.build.toplevel")
done

echo "Building system derivations for: ${HOSTS//$'\n'/ }"

# Build all systems without creating GC roots or symlinks in the workspace
BUILD_OUTPUTS=$(nix build "${TARGETS[@]}" \
  --no-link \
  --print-out-paths \
  --extra-experimental-features "nix-command flakes pipe-operators")

echo "=== Build completed successfully ==="

# Authenticate against local Attic endpoint if token is provided
if [ -n "${ATTIC_TOKEN:-}" ]; then
  attic login local "$ATTIC_SERVER" "$ATTIC_TOKEN" 2>/dev/null || true
fi

echo "=== Pushing store paths to Attic ($ATTIC_CACHE) ==="
echo "$BUILD_OUTPUTS" | while read -r out_path; do
  if [ -n "$out_path" ]; then
    echo "Pushing $out_path..."
    attic push "local:${ATTIC_CACHE}" "$out_path"
  fi
done

echo "All machine configurations successfully built and cached in Attic."
