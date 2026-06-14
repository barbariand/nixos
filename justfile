# Automatically generated host commands
import "hosts.justfile"
set shell := ["bash", "-uc"]
override-input := "--override-input sensible-nix ~/code_home/old-sensible-nix/"
# Variables
flake_uri := "."
user := "root"

# build the current config lokalt
build *extra_flags:
    nh os switch {{flake_uri}} --  {{override-input}} {{extra_flags}}

# build the current config locally for boot
boot *extra_flags:
    nh os boot {{flake_uri}} --  {{override-input}} {{extra_flags}}

# Check flake for syntax errors
check *extra_flags:
    nix flake check {{override-input}} {{extra_flags}}

# Deploy till en fjärrmaskin (t.ex. server eller hallonpaj)
deploy host *extra_flags:
    @echo "Building & Deploying Flake for host: {{host}}"
    @TARGET_IP=$(nix eval .#nixosConfigurations.{{host}}.config.networking.wireguard.interfaces.wg0.ips  --apply 'ips: builtins.head (builtins.split "/" (builtins.head ips))' --quiet --raw -- ); \
    nh os switch {{flake_uri}} \
        --hostname {{host}} \
        --target-host {{user}}@$TARGET_IP \
        -- {{override-input}}\
        {{extra_flags}}

deploy_custom_ip host ip *extra_flags:
    @echo "Building & Deploying Flake for host: {{host}}"
    nh os switch {{flake_uri}} \
        --hostname {{host}} \
        --target-host {{user}}@{{ip}} \
        -- {{override-input}}\
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
