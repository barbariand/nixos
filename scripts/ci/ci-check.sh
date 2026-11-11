#!/usr/bin/env bash
set -uo pipefail

CI_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$CI_DIR/lib.sh"

trap cleanup_ssh EXIT
setup_ssh
setup_nix_args

echo "=== Running nix flake check ==="
log_file="flake-check.log"

"$CI_DIR/tasks/task-flake-check.sh" "${NIX_ARGS[@]}" 2> "$log_file"
status=$?

if [ $status -ne 0 ]; then
  echo "=== ❌ Flake check failed (Exit code: $status) ==="
  echo "------------------ Check Log Tail ------------------"
  cat "$log_file"
  echo "----------------------------------------------------"
  rm -f "$log_file"
  exit "$status"
fi

rm -f "$log_file"
echo "=== Flake check completed successfully ==="
