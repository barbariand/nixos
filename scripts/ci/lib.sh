#!/usr/bin/env bash
# lib.sh - Shared CI functions

setup_ssh() {
  export GIT_TERMINAL_PROMPT=0
  if [ -n "${RUNNER_DEPLOY_KEY:-}" ]; then
    echo "=== Configuring SSH for private flake inputs ==="
    SSH_KEY_FILE="$(mktemp)"
    export SSH_KEY_FILE
    echo "$RUNNER_DEPLOY_KEY" > "$SSH_KEY_FILE"
    chmod 600 "$SSH_KEY_FILE"
    export GIT_SSH_COMMAND="ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
  else
    echo "=== WARNING: RUNNER_DEPLOY_KEY is not set. Private inputs may fail ==="
  fi
}

cleanup_ssh() {
  if [ -n "${SSH_KEY_FILE:-}" ] && [ -f "$SSH_KEY_FILE" ]; then
    rm -f "$SSH_KEY_FILE"
  fi
}

setup_nix_args() {
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
