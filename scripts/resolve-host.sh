#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

HOST="${1:-}"
[ -z "$HOST" ] && { log_error "Host parameter missing."; exit 1; }

FLAKE_URI="${FLAKE_URI:-.}"
TARGET_USER="${TARGET_USER:-root}"

OVERRIDE_FLAG=""
if [ "${HAS_OVERRIDE:-false}" == "true" ]; then
    OVERRIDE_FLAG="--override-input sensible ${SENSIBLE_OVERRIDE}"
fi

TARGET_IP=$(nix eval "${FLAKE_URI}#nixosConfigurations.${HOST}.config.sensible.wireguard.wg0.topology.nodes.${HOST}.ip" --extra-experimental-features "nix-command flakes" $OVERRIDE_FLAG --quiet --raw 2>/dev/null || echo "")

if [ -z "$TARGET_IP" ]; then
    TARGET_IP="$HOST"
fi

echo "${TARGET_USER}@${TARGET_IP}"
