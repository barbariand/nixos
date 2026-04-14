# Automatically generated host commands
import "hosts.justfile"
set shell := ["bash", "-uc"]

# Variables
flake_uri := "."
user := "root"


# Build the current config
build:
    nixos-rebuild switch --sudo

# Check flake for syntax errors
check:
    nix flake check

# Internal deploy
deploy host *extra_flags:
    @echo "Building Flake: {{flake_uri}}#{{host}}"
    @TARGET_IP=$(nix eval .#nixosConfigurations.{{host}}.config.networking.wireguard.interfaces.wg0.ips --apply 'ips: builtins.head (builtins.split "/" (builtins.head ips))' --quiet --raw); \
    echo "Deploying to:   {{user}}@$TARGET_IP"; \
    nixos-rebuild switch --flake {{flake_uri}}#{{host}} \
        --target-host {{user}}@$TARGET_IP \
        --sudo {{extra_flags}}
# Refresh the dynamic commands
update:
    @command -v jq >/dev/null 2>&1 || { echo >&2 "Error: 'jq' is not installed."; exit 1; }
    @nix eval .#nixosConfigurations --apply "builtins.attrNames" --json | jq -r '.[]' | \
    awk '{print $1 " *extra_flags:\n    @just deploy " $1 " {{ '{{' }}extra_flags{{ '}}' }}"}' > hosts.justfile
    @echo "Justfile updated. Run 'just --list' to see new hosts."

# Clean the generated hosts file
clean-hosts:
    echo "" > justfile.hosts
