#!/usr/bin/env python3
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ..lib.ci_env import setup_ssh_context
from ..lib.nix import NixContext, eval_target_hosts
from ..lib.logger import log_error, log_info, log_warn

ATTIC_CACHE = "simd"
ATTIC_SERVER = "https://cache.simd.me"


def main() -> int:
    ctx = NixContext.from_env()
    
    with setup_ssh_context():
        nix_args = ctx.get_ci_args()
        attic_token = os.getenv("ATTIC_TOKEN")

        if attic_token:
            log_info("ci-build", f"Authenticating with Attic ({ATTIC_SERVER})")
            subprocess.run(
                ["attic", "login", "local", ATTIC_SERVER, attic_token],
                capture_output=True,
            )

        log_info("ci-build", "Querying target hosts from nixosConfigurations")
        try:
            hosts = eval_target_hosts(ctx)
        except subprocess.CalledProcessError as exc:
            log_error("ci-build", "Failed to evaluate nixosConfigurations attribute set.")
            print(exc.stderr, file=sys.stderr)
            return 1

        log_info("ci-build", f"Discovered targets: {' '.join(hosts)}")

        success_hosts = []
        failed_hosts = []

        for host in hosts:
            print(f"\n{'=' * 50}\n>>> [BUILDING] Host: {host}\n{'=' * 50}")
            target = f'{ctx.flake_uri}#nixosConfigurations."{host}".config.system.build.toplevel'
            cmd = ["nix", "build", target, "--no-link", "--print-out-paths"] + nix_args

            start = time.time()
            res = subprocess.run(cmd, capture_output=True, text=True)
            elapsed = int(time.time() - start)

            if res.returncode != 0:
                log_error("ci-build", f"Build FAILED for '{host}' after {elapsed}s (Exit code: {res.returncode})")
                print("------------------ Build Log Tail (last 80 lines) ------------------")
                lines = res.stderr.splitlines()
                print("\n".join(lines[-80:]))
                print("-" * 68)
                failed_hosts.append(host)
                continue

            out_path = res.stdout.strip()
            success_hosts.append(host)
            log_info("ci-build", f"Successfully built {host} in {elapsed}s")
            print(f"   Output Path: {out_path}")

            if attic_token and out_path:
                log_info("ci-build", f"Pushing {host} store path to Attic ({ATTIC_CACHE})...")
                push = subprocess.run(
                    ["attic", "push", f"local:{ATTIC_CACHE}", out_path],
                    capture_output=True,
                )
                if push.returncode != 0:
                    log_warn("ci-build", f"Attic push failed for {host} with exit code {push.returncode}")
                else:
                    log_info("ci-build", f"Cached {host} in Attic successfully.")

        print(f"\n{'=' * 50}\n=== Build Execution Summary ===\n{'=' * 50}")
        if success_hosts:
            log_info("ci-build", f"Successfully built: {' '.join(success_hosts)}")
        if failed_hosts:
            log_error("ci-build", f"Failed targets: {' '.join(failed_hosts)}")
            return 1

        log_info("ci-build", "All machine configurations built and cached successfully.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
