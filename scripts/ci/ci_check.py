#!/usr/bin/env python3
import subprocess
import sys

from ..lib.ci_env import setup_ssh_context
from ..lib.nix import NixContext
from ..lib.logger import log_error, log_info


def main() -> int:
    ctx = NixContext.from_env()

    with setup_ssh_context():
        nix_args = ctx.get_ci_args()
        cmd = ["nix", "flake", "check"] + nix_args

        log_info("ci-check", "Executing nix flake check")
        res = subprocess.run(cmd, capture_output=True, text=True)

        if res.returncode != 0:
            log_error("ci-check", f"Flake check failed (Exit code: {res.returncode})")
            print("------------------ Check Log Tail ------------------")
            print(res.stderr)
            print("----------------------------------------------------")
            return res.returncode

        log_info("ci-check", "Flake check completed successfully")
        return 0


if __name__ == "__main__":
    sys.exit(main())
