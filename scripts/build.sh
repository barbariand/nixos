#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

TYPE="${1:-}"
HOST="${2:-}"
shift 2
ARGS="$*"

OVERRIDE_FLAG=""
if [ "${HAS_OVERRIDE:-false}" == "true" ]; then
    log_debug "Using sensible override from: $SENSIBLE_OVERRIDE"
    OVERRIDE_FLAG="--override-input sensible $SENSIBLE_OVERRIDE"
fi

NIX_ARGS="--show-trace $OVERRIDE_FLAG $ARGS"

case "$TYPE" in
    sd)
        log_info "Building SD image for '$HOST'..."
        nix build "${FLAKE_URI}#nixosConfigurations.${HOST}.config.system.build.sdImage" $NIX_ARGS
        log_info "SD image build finished"
        ;;
    iso)
        log_info "Building ISO image for '$HOST'..."
        nix build "${FLAKE_URI}#nixosConfigurations.${HOST}.config.system.build.isoImage" $NIX_ARGS
        log_info "ISO image build finished"
        ;;
    netboot)
        log_info "Building Netboot image for '$HOST'..."
        nix build "${FLAKE_URI}#nixosConfigurations.${HOST}.config.system.build.netboot-prebuilt" $NIX_ARGS
        log_info "Netboot image build finished"
        ;;
    *)
        log_error "Usage: $0 {sd|iso|netboot} host [args...]"
        exit 1
        ;;
esac
