set unstable := true
set dotenv-load := true
set shell := ["bash", "-uc"]

export FLAKE_URI := "."
export TARGET_USER := "root"

# Optional import of the generated host targets
import? ".just/hosts.justfile"

[group("local")]
default:
    @just --list

[group("local")]
check *args:
    nix flake check {{ FLAKE_URI }} {{ args }} --override-input sensible ../sensible-nix/

[group("local")]
fmt:
    alejandra .

[group("local")]
boot:
    nh os boot {{FLAKE_URI}} -- --override-input sensible ../sensible-nix/

[group("local")]
switch:
    nh os switch {{FLAKE_URI}} -- --override-input sensible ../sensible-nix/

[group("local")]
update:
    nix flake update --flake {{ FLAKE_URI }}

[group("tools")]
update-hosts:
    python3 -m scripts.update_hosts

[group("tools")]
clean-hosts:
    @rm -rf .just
