#!/usr/bin/env bash

C_RESET="\033[0m"
C_INFO="\033[1;32m"  # Green
C_WARN="\033[1;33m"  # Yellow
C_ERR="\033[1;31m"   # Red
C_DEBUG="\033[1;34m" # Blue
C_DIM="\033[2m"      # Dim

# Extracts the calling script's name (e.g., 'deploy' from 'deploy.sh')
CTX=$(basename "${0}" .sh)

# >&2 targets stderr to avoid corrupting stdout in data-returning scripts
log_info()  { echo -e "${C_INFO}INFO${C_RESET}  ${C_DIM}${CTX}:${C_RESET} $*" >&2; }
log_warn()  { echo -e "${C_WARN}WARN${C_RESET}  ${C_DIM}${CTX}:${C_RESET} $*" >&2; }
log_error() { echo -e "${C_ERR}ERROR${C_RESET} ${C_DIM}${CTX}:${C_RESET} $*" >&2; }
log_debug() { echo -e "${C_DEBUG}DEBUG${C_RESET} ${C_DIM}${CTX}:${C_RESET} $*" >&2; }
