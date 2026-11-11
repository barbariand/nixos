#!/usr/bin/env bash

set -euo pipefail

NIX_ARGS=("$@")

exec nix flake check "${NIX_ARGS[@]}"
