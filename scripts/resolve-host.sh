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

ATTR="${FLAKE_URI}#nixosConfigurations.${HOST}.config.sensible.wireguard.wg0.topology.nodes.${HOST}.ip"

TARGET_IP=$(nix eval "$ATTR" --extra-experimental-features "nix-command flakes" $OVERRIDE_FLAG --raw 2>/dev/null || echo "")

if [ -z "$TARGET_IP" ]; then
    log_warn "Kunde inte slå upp WireGuard-IP för '$HOST', faller tillbaka på värdnamn. Kör 'just check' för att undersöka felet."
    TARGET_IP="$HOST"
fi

echo "${TARGET_USER}@${TARGET_IP}"
