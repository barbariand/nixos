#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ATTIC_CACHE="simd"
ATTIC_SERVER="https://cache.simd.me"

trap cleanup_ssh EXIT
setup_ssh
setup_nix_args

echo "=== Fetching target hosts from nixosConfigurations ==="
HOSTS=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json "${NIX_ARGS[@]}" 2>/dev/null | jq -r '.[]')

TARGETS=()
for host in $HOSTS; do
  TARGETS+=(".#nixosConfigurations.\"${host}\".config.system.build.toplevel")
done

echo "Building system derivations for: ${HOSTS//$'\n'/ } (This might take a while...)"

# Redirect stdout to a temporary file to easily iterate through the paths later
run_silent_on_success "build-systems" nix build "${TARGETS[@]}" --no-link --print-out-paths "${NIX_ARGS[@]}" > build_outputs.txt

if [ -n "${ATTIC_TOKEN:-}" ]; then
  echo "=== Authenticating with local Attic server ==="
  attic login local "$ATTIC_SERVER" "$ATTIC_TOKEN" >/dev/null 2>&1 || true
fi

echo "=== Pushing store paths to Attic ($ATTIC_CACHE) ==="
while read -r out_path; do
  if [ -n "$out_path" ]; then
    attic push "local:${ATTIC_CACHE}" "$out_path" >/dev/null 2>&1
  fi
done < build_outputs.txt
rm -f build_outputs.txt

echo "=== All machine configurations successfully built and cached in Attic ==="
