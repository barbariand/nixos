#!/usr/bin/env bash
set -euo pipefail

# Source the library (works regardless of where the script is called from)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

trap cleanup_ssh EXIT
setup_ssh
setup_nix_args

# Run flake check with error handling
run_silent_on_success "flake-check" nix flake check "${NIX_ARGS[@]}"
