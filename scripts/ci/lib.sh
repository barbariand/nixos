#!/usr/bin/env bash
# lib.sh - Shared CI functions

# Sets up the SSH key and configures Git for private flakes
setup_ssh() {
  export GIT_TERMINAL_PROMPT=0
  if [ -n "${RUNNER_DEPLOY_KEY:-}" ]; then
    echo "=== Configuring SSH for private flake inputs ==="
    SSH_KEY_FILE="$(mktemp)"
    export SSH_KEY_FILE # Export so cleanup can access it
    echo "$RUNNER_DEPLOY_KEY" > "$SSH_KEY_FILE"
    chmod 600 "$SSH_KEY_FILE"
    export GIT_SSH_COMMAND="ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
  else
    echo "=== WARNING: RUNNER_DEPLOY_KEY is not set. Private inputs may fail ==="
  fi
}

# Cleans up the SSH key (linked to "trap EXIT" in the main scripts)
cleanup_ssh() {
  if [ -n "${SSH_KEY_FILE:-}" ] && [ -f "$SSH_KEY_FILE" ]; then
    rm -f "$SSH_KEY_FILE"
  fi
}

# Configures global Nix arguments and reads sensible-branch.txt if it exists
setup_nix_args() {
  # Define the array globally so it can be used in the sourcing script
  NIX_ARGS=(
    --extra-experimental-features "nix-command flakes pipe-operators"
    --no-warn-dirty
  )

  if [ -f "sensible-branch.txt" ]; then
    local sensible_branch
    sensible_branch=$(tr -d '[:space:]' < sensible-branch.txt)
    if [ -n "$sensible_branch" ]; then
      echo "=== Override active: Using sensible branch '$sensible_branch' ==="
      NIX_ARGS+=(--override-input "sensible" "git+ssh://git@git.urgobalt.dev/urgobalt/sensible-nix.git?ref=$sensible_branch")
    fi
  fi
}

# Runs a command silently. If it fails, stderr is printed.
# Usage: run_silent_on_success "Step name" command arg1 arg2...
run_silent_on_success() {
  local step_name="$1"
  shift
  local log_file="nix-${step_name}-errors.log"

  echo "=== Running $step_name ==="
  # stderr is logged to the file, stdout passes normally (can be redirected by the caller)
  if ! "$@" 2> "$log_file"; then
    echo "=== ❌ $step_name FAILED ==="
    cat "$log_file"
    rm -f "$log_file"
    return 1
  fi
  rm -f "$log_file"
  echo "=== $step_name completed successfully ==="
}
