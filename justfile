set unstable
import "hosts.justfile"

set shell := ["bash", "-uc"]

# Variabler
flake_uri := "."
user := "root"
override-input := "--override-input sensible ~/code_home/sensible-nix/"
jq := require("jq")

# Funktioner för att centralisera argumenthanteringen
nh(action, options, flags) := "nh os " + action + " " + flake_uri + " " + options + " -- " + override-input + " " + flags
nix(action, flags) := "nix " + action + " " + override-input + " " + flags

# Bygg nuvarande konfiguration lokalt
build *extra_flags:
    {{ nh("switch", "", extra_flags) }}

# Bygg nuvarande konfiguration för nästa uppstart
boot *extra_flags:
    {{ nh("boot", "", extra_flags) }}

# Kontrollera flake för syntaxfel
check *extra_flags:
    {{ nix("flake check", extra_flags) }}

# Deploy till en fjärrmaskin (t.ex. server eller hallonpaj)
deploy host *extra_flags:
    @echo "Building & Deploying Flake for host: {{ host }}"
    @TARGET_IP=$({{ nix("eval", ".#nixosConfigurations." + host + ".config.networking.wireguard.interfaces.wg0.ips --apply 'ips: builtins.head (builtins.split \"/\" (builtins.head ips))' --quiet --raw") }}); \
    {{ nh("switch", "--hostname " + host + " --target-host " + user + "@$TARGET_IP", extra_flags) }}

deploy_custom_ip host ip *extra_flags:
    @echo "Building & Deploying Flake for host: {{ host }}"
    {{ nh("switch", "--hostname " + host + " --target-host " + user + "@" + ip, extra_flags) }}
update:
  nix flake update --flake .
# Uppdatera dynamiska kommandon
update-hosts:
    @{{ nix("eval", ".#nixosConfigurations --apply 'builtins.attrNames' --json") }} | {{ jq }} -r '.[]' | \
    awk '{print $1 " *extra_flags:\n    @just deploy " $1 " {{ '{{' }}extra_flags{{ '}}' }}"}' > hosts.justfile
    @echo "Justfile updated. Run 'just --list' to see new hosts."

# Rensa den genererade host-filen
clean-hosts:
    @echo "" > hosts.justfile
