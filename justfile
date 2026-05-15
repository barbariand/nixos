# Automatically generated host commands
import "hosts.justfile"
set shell := ["bash", "-uc"]

# Variables
flake_uri := "."
user := "root"

# Build the current config lokalt
build *extra_flags:
    nh os switch {{flake_uri}} {{extra_flags}}

# Check flake for syntax errors
check *extra_flags:
    nix flake check {{extra_flags}}

# Deploy till en fjärrmaskin (t.ex. server eller hallonpaj)
deploy host *extra_flags:
    @echo "Building & Deploying Flake for host: {{host}}"
    @TARGET_IP=$(nix eval .#nixosConfigurations.{{host}}.config.networking.wireguard.interfaces.wg0.ips --apply 'ips: builtins.head (builtins.split "/" (builtins.head ips))' --quiet --raw); \
    nh os switch {{flake_uri}} \
        --hostname {{host}} \
        --target-host {{user}}@$TARGET_IP \
        {{extra_flags}}

deploy_custom_ip host ip *extra_flags:
    @echo "Building & Deploying Flake for host: {{host}}"
    nh os switch {{flake_uri}} \
        --hostname {{host}} \
        --target-host {{user}}@{{ip}} \
        {{extra_flags}}
jq := require("jq")
# Refresh the dynamic commands
update:
    @nix eval .#nixosConfigurations --apply "builtins.attrNames" --json | {{jq}} -r '.[]' | \
    awk '{print $1 " *extra_flags:\n    @just deploy " $1 " {{ '{{' }}extra_flags{{ '}}' }}"}' > hosts.justfile
    @echo "Justfile updated. Run 'just --list' to see new hosts."

# Clean the generated hosts file
clean-hosts:
    echo "" > hosts.justfile
