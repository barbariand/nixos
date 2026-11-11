#!/usr/bin/env python3
import argparse
import sys
from lib.nix import NixContext
from lib.logger import log_error
from lib import commands


def main() -> int:
    parser = argparse.ArgumentParser(description="NixOS Deployment CLI")
    parser.add_argument("host", help="Target network hostname or configuration name")
    
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Deploy
    deploy_p = subparsers.add_parser("deploy", help="Deploy system configuration")
    deploy_p.add_argument("action", nargs="?", default="switch", choices=["switch", "boot", "test"])
    deploy_p.add_argument("extra", nargs=argparse.REMAINDER)

    # Boot (Alias)
    boot_p = subparsers.add_parser("boot", help="Apply configuration on next boot")
    boot_p.add_argument("extra", nargs=argparse.REMAINDER)

    # Build
    build_sd_p = subparsers.add_parser("build-sd", help="Build SD image")
    build_sd_p.add_argument("extra", nargs=argparse.REMAINDER)
    
    build_iso_p = subparsers.add_parser("build-iso", help="Build ISO image")
    build_iso_p.add_argument("extra", nargs=argparse.REMAINDER)

    # SSH & Reboot
    ssh_p = subparsers.add_parser("ssh", help="Open SSH session to target host")
    ssh_p.add_argument("extra", nargs=argparse.REMAINDER)
    subparsers.add_parser("reboot", help="Reboot target host")

    args = parser.parse_args()
    ctx = NixContext.from_env()

    try:
        match args.command:
            case "deploy":
                return commands.deploy(args.host, args.action, args.extra, ctx)
            case "boot":
                return commands.deploy(args.host, "boot", args.extra, ctx)
            case "build-sd":
                return commands.build(args.host, "sd", args.extra, ctx)
            case "build-iso":
                return commands.build(args.host, "iso", args.extra, ctx)
            case "ssh":
                return commands.ssh(args.host, "ssh", args.extra, ctx)
            case "reboot":
                return commands.ssh(args.host, "reboot", [], ctx)
            case _:
                log_error("cli", f"Unknown command: {args.command}")
                return 1
    except KeyboardInterrupt:
        return 130
    except Exception as e:
        log_error("cli", f"Unhandled exception: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
