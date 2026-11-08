#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JUST_DIR="$ROOT_DIR/.just"
HOSTS_FILE="$JUST_DIR/hosts.justfile"
HOSTS_DIR="$JUST_DIR/hosts"

log_info "Scanning for nixosConfigurations in '$ROOT_DIR'"
mkdir -p "$HOSTS_DIR"

cat << 'EOF' > "$HOSTS_FILE"
EOF

HOSTS=$(nix eval "${ROOT_DIR}#nixosConfigurations" --apply 'builtins.attrNames' --json 2>/dev/null | jq -r '.[]')

for host in $HOSTS; do
    log_debug "Generating justfile module for '$host'"
    echo "[group(\"hosts\")]" >> "$HOSTS_FILE"
    echo "mod $host \"hosts/$host.just\"" >> "$HOSTS_FILE"

    cat << EOF > "$HOSTS_DIR/$host.just"
[group("$host")]
default:
    @just --list $host

[group("$host")]
deploy *args:
    @just core deploy $host {{ args }}

[group("$host")]
boot *args:
    @just core boot $host {{ args }}

[group("$host")]
build-sd *args:
    @just core build-sd $host {{ args }}

[group("$host")]
ssh *args:
    @just core ssh $host {{ args }}

[group("$host")]
reboot *args:
    @just core boot $host {{ args }}
    @just core reboot $host
EOF
done

log_info "Host justfiles updated successfully"
