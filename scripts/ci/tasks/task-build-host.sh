#!/usr/bin/env bash
set -euo pipefail

HOST="${1:?Host parameter is required}"
shift
NIX_ARGS=("$@")

TARGET=".#nixosConfigurations.\"${HOST}\".config.system.build.toplevel"

# Builds system derivation, returns out-paths to stdout
exec nix build "$TARGET" --no-link --print-out-paths "${NIX_ARGS[@]}"
