set unstable := true
set dotenv-load := true
set shell := ["bash", "-uc"]

export GUM_SPIN_SPINNER_FOREGROUND := "#D6B97F"
export YELLOW := "\\033[1;33m"
export RED    := "\\033[1;31m"
export GREEN  := "\\033[1;32m"
export BLUE   := "\\033[1;34m"
export NORMAL := "\\033[0m"

export FLAKE_URI := "."
export TARGET_USER := "root"
export DEFAULT_DEVICE := "/dev/sda"

export HOME_DIR := env_var_or_default("HOME", "")
export SENSIBLE_OVERRIDE := env_var_or_default("SENSIBLE_OVERRIDE", HOME_DIR + "/code_home/sensible-nix")
export HAS_OVERRIDE := path_exists(SENSIBLE_OVERRIDE)

export OVERRIDE_FLAG := if HAS_OVERRIDE == "true" { "--override-input sensible " + SENSIBLE_OVERRIDE } else { "" }
export NH_OPTS := if HAS_OVERRIDE == "true" { "-- " + OVERRIDE_FLAG } else { "" }

[group("core")]
mod core "core.just"

import? ".just/hosts.justfile"

[group("local")]
default:
    @just --list

[group("local")]
check *args:
    nix flake check {{ FLAKE_URI }} {{ args }} {{ OVERRIDE_FLAG }}

[group("local")]
fmt:
    alejandra .

[group("local")]
switch *args:
    nh os switch {{ FLAKE_URI }} {{ args }} {{ NH_OPTS }}

[group("local")]
boot *args:
    nh os boot {{ FLAKE_URI }} {{ args }} {{ NH_OPTS }}

[group("local")]
update:
    nix flake update --flake {{ FLAKE_URI }}

[group("tools")]
update-hosts:
    @./scripts/update-hosts.sh

[group("tools")]
clean-hosts:
    @rm -rf .just
