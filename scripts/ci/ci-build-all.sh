#!/usr/bin/env bash
set -uo pipefail

CI_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$CI_DIR/lib.sh"

ATTIC_CACHE="simd"
ATTIC_SERVER="https://cache.simd.me"

trap cleanup_ssh EXIT
setup_ssh
setup_nix_args

# --- 1. Attic authentication ---
if [ -n "${ATTIC_TOKEN:-}" ]; then
  echo "=== Authenticating with Attic ($ATTIC_SERVER) ==="
  attic login local "$ATTIC_SERVER" "$ATTIC_TOKEN" >/dev/null 2>&1 || true
fi

# --- 2. Query target hosts ---
echo "=== Querying target hosts from nixosConfigurations ==="
HOSTS_JSON=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json "${NIX_ARGS[@]}" 2>/dev/null)
eval_status=$?

if [ $eval_status -ne 0 ] || [ -z "$HOSTS_JSON" ]; then
  echo "❌ Failed to evaluate nixosConfigurations attribute set."
  exit 1
fi

HOSTS=$(echo "$HOSTS_JSON" | jq -r '.[]')
echo "Discovered targets: ${HOSTS//$'\n'/ }"

FAILED_HOSTS=()
SUCCESS_HOSTS=()

# --- 3. Execute builds per host ---
for host in $HOSTS; do
  echo ""
  echo "=================================================="
  echo ">>> [BUILDING] Host: ${host}"
  echo "=================================================="

  log_file="build-${host}.log"
  start_time=$(date +%s)

  # Execute subscript task and capture output
  out_path=$("$CI_DIR/tasks/task-build-host.sh" "$host" "${NIX_ARGS[@]}" 2> "$log_file")
  status=$?
  elapsed=$(( $(date +%s) - start_time ))

  if [ $status -ne 0 ]; then
    echo "❌ Build FAILED for '${host}' after ${elapsed}s (Exit code: $status)"
    echo "------------------ Build Log Tail (last 80 lines) ------------------"
    tail -n 80 "$log_file"
    echo "--------------------------------------------------------------------"
    rm -f "$log_file"
    FAILED_HOSTS+=("$host")
    continue
  fi

  rm -f "$log_file"
  SUCCESS_HOSTS+=("$host")
  echo "✅ Built ${host} in ${elapsed}s"
  echo "   Output: ${out_path}"

  # Push immediately to Attic so caching survives downstream errors
  if [ -n "${ATTIC_TOKEN:-}" ] && [ -n "$out_path" ]; then
    echo "Pushing ${host} store path to Attic (${ATTIC_CACHE})..."
    attic push "local:${ATTIC_CACHE}" "$out_path" >/dev/null 2>&1
    push_status=$?
    if [ $push_status -ne 0 ]; then
      echo "⚠️  Attic push failed for ${host} with exit code $push_status"
    else
      echo "Cached ${host} in Attic successfully."
    fi
  fi
done

# --- 4. Final summary and error reporting ---
echo ""
echo "=================================================="
echo "=== Build Execution Summary ==="
echo "=================================================="
if [ ${#SUCCESS_HOSTS[@]} -ne 0 ]; then
  echo "Successfully built: ${SUCCESS_HOSTS[*]}"
fi

if [ ${#FAILED_HOSTS[@]} -ne 0 ]; then
  echo "❌ Failed targets: ${FAILED_HOSTS[*]}"
  exit 1
fi

echo "✅ All machine configurations built and cached successfully."
