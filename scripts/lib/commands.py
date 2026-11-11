import subprocess
from .nix import NixContext, resolve_wg_ip
from .logger import log_info


def get_target(host: str, ctx: NixContext) -> str:
    ip = resolve_wg_ip(host, ctx) or host
    return f"{ctx.target_user}@{ip}"


def deploy(host: str, action: str, extra_args: list[str], ctx: NixContext) -> int:
    target = get_target(host, ctx)
    log_info("deploy", f"Running nh os {action} on '{host}' ({target})")

    cmd = [
        "nh", "os", action, ctx.flake_uri,
        "--hostname", host,
        "--target-host", target
    ] + ctx.get_override_args() + extra_args

    return subprocess.run(cmd).returncode


def build(host: str, build_type: str, extra_args: list[str], ctx: NixContext) -> int:
    targets = {
        "sd": "system.build.sdImage",
        "iso": "system.build.isoImage",
        "netboot": "system.build.netboot-prebuilt",
        "toplevel": "system.build.toplevel",
    }
    
    attr = f"{ctx.flake_uri}#nixosConfigurations.{host}.config.{targets.get(build_type, 'system.build.toplevel')}"
    
    log_info("build", f"Building {build_type.upper()} image for '{host}'...")
    cmd = ["nix", "build", attr, "--show-trace"] + ctx.get_override_args() + extra_args
    return subprocess.run(cmd).returncode


def ssh(host: str, action: str, extra_args: list[str], ctx: NixContext) -> int:
    target = get_target(host, ctx)
    
    if action == "reboot":
        log_info("ssh", f"Rebooting '{host}' ({target})...")
        return subprocess.run(["ssh", "-t", target, "sudo reboot"]).returncode

    log_info("ssh", f"Connecting to '{host}' ({target})")
    return subprocess.run(["ssh", target] + extra_args).returncode
