#!/usr/bin/env python3
import sys
from pathlib import Path

# Insert scripts root into sys.path to resolve the lib module
sys.path.insert(0, str(Path(__file__).resolve().parent))

from .lib.nix import NixContext, eval_target_hosts
from .lib.logger import log_debug, log_info


def main() -> int:
    ctx = NixContext.from_env()
    root_dir = Path(__file__).resolve().parent.parent
    just_dir = root_dir / ".just"
    hosts_file = just_dir / "hosts.justfile"

    log_info("update-hosts", f"Scanning for nixosConfigurations in '{root_dir}'")
    just_dir.mkdir(parents=True, exist_ok=True)

    try:
        hosts = eval_target_hosts(ctx)
    except Exception as e:
        log_info("update-hosts", f"Failed to evaluate hosts: {e}")
        return 1

    # We will write all host targets into a single justfile
    content = ["# AUTO-GENERATED FILE - DO NOT EDIT\n"]

    for host in hosts:
        log_debug("update-hosts", f"Generating forwarding target for '{host}'")

        # Creates a target named exactly as the host.
        # Usage: just <host> <command> [args...]
        # Defaults to passing "--help" to the CLI if no command is given.
        recipe = f"""[group("systems")]
{host} command="--help" *args:
    @./scripts/cli.py {host} {{{{ command }}}} {{{{ args }}}}
"""
        content.append(recipe)

    hosts_file.write_text("\n".join(content), encoding="utf-8")
    log_info(
        "update-hosts",
        f"Successfully generated {len(hosts)} host targets in {hosts_file.relative_to(root_dir)}",
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
