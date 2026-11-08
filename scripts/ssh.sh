#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

HOST="${1:-}"
ACTION="${2:-ssh}"
shift 2 || true
ARGS="$*"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=$("$ROOT_DIR/scripts/resolve-host.sh" "$HOST")

if [ "$ACTION" = "reboot" ]; then
    log_warn "Rebooting '$HOST' ($TARGET)..."
    ssh -t "$TARGET" "sudo reboot" || true
else
    log_info "Connecting to '$HOST' ($TARGET)"
    # shellcheck disable=SC2086
    ssh "$TARGET" $ARGS
fi
