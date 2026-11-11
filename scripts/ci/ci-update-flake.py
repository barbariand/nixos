#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

# Insert scripts root into sys.path to resolve the lib module
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from .lib.ci_env import setup_ssh_context
from .lib.logger import log_error, log_info


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def main() -> int:
    with setup_ssh_context():
        log_info("ci-update", "Configuring Git User")
        run(["git", "config", "user.name", "Forgejo Build Bot"])
        run(["git", "config", "user.email", "bot@simd.me"])
        run(["git", "checkout", "master"])

        log_info("ci-update", "Updating flake.lock")
        cmd = [
            "nix",
            "flake",
            "update",
            "--extra-experimental-features",
            "nix-command flakes",
            "--no-warn-dirty",
        ]

        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            log_error("ci-update", f"Flake update failed (Exit code: {res.returncode})")
            print(res.stderr, file=sys.stderr)
            return res.returncode

        diff = subprocess.run(["git", "diff", "--quiet", "flake.lock"]).returncode
        if diff != 0:
            log_info("ci-update", "Committing dependency updates")
            run(["git", "add", "flake.lock"])
            run(["git", "commit", "-m", "chore(flake): weekly flake lock update"])
            run(["git", "push", "origin", "master"])
        else:
            log_info("ci-update", "No dependency updates detected in flake.lock")

        log_info("ci-update", "Advancing staging branch")
        run(["git", "push", "origin", "HEAD:staging", "--force"])
        return 0


if __name__ == "__main__":
    sys.exit(main())
