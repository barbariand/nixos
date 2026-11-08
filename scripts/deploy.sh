#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

ACTION="${1:-}"
HOST="${2:-}"
shift 2
ARGS="$*"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=$("$ROOT_DIR/scripts/resolve-host.sh" "$HOST")

OVERRIDE_FLAG=""
if [ "${HAS_OVERRIDE:-false}" == "true" ]; then
    log_debug "Using sensible override from: $SENSIBLE_OVERRIDE"
    OVERRIDE_FLAG="--override-input sensible $SENSIBLE_OVERRIDE"
fi

log_info "Running nh os $ACTION on '$HOST' ($TARGET)"
nh os "$ACTION" "$FLAKE_URI" --hostname "$HOST" --target-host "$TARGET" $OVERRIDE_FLAG $ARGS
