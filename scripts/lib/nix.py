import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class NixContext:
    flake_uri: str
    target_user: str
    sensible_override: Path | None

    @classmethod
    def from_env(cls) -> "NixContext":
        flake_uri = os.getenv("FLAKE_URI", ".")
        target_user = os.getenv("TARGET_USER", "root")

        home = Path(os.getenv("HOME", ""))
        override_path = Path(
            os.getenv("SENSIBLE_OVERRIDE", home / "code_home" / "sensible-nix")
        )

        has_override = (
            os.getenv("HAS_OVERRIDE", "false").lower() == "true"
            or override_path.exists()
        )

        return cls(
            flake_uri=flake_uri,
            target_user=target_user,
            sensible_override=override_path if has_override else None,
        )

    def get_override_args(self) -> list[str]:
        if self.sensible_override:
            return ["--override-input", "sensible", str(self.sensible_override)]
        return []

    def get_ci_args(self) -> list[str]:
        """Returns standard Nix arguments required for CI environments."""
        args = [
            "--extra-experimental-features",
            "nix-command flakes pipe-operators",
            "--no-warn-dirty",
        ]

        branch_file = Path("sensible-branch.txt")
        if branch_file.is_file():
            branch = branch_file.read_text(encoding="utf-8").strip()
            if branch:
                args.extend(
                    [
                        "--override-input",
                        "sensible",
                        f"git+ssh://git@git.urgobalt.dev/urgobalt/sensible-nix.git?ref={branch}",
                    ]
                )
        return args


def run_nix(args: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    cmd = ["nix"] + args
    kwargs.setdefault("text", True)
    return subprocess.run(cmd, **kwargs)


def eval_target_hosts(ctx: NixContext) -> list[str]:
    cmd = [
        "eval",
        f"{ctx.flake_uri}#nixosConfigurations",
        "--apply",
        "builtins.attrNames",
        "--json",
        "--extra-experimental-features",
        "nix-command flakes",
    ]
    res = run_nix(cmd, capture_output=True, check=True)
    return json.loads(res.stdout)


def resolve_wg_ip(host: str, ctx: NixContext) -> str | None:
    attr = f"{ctx.flake_uri}#nixosConfigurations.{host}.config.sensible.wireguard.wg0.topology.nodes.{host}.ip"
    cmd = [
        "eval",
        attr,
        "--extra-experimental-features",
        "nix-command flakes",
        "--raw",
    ] + ctx.get_override_args()

    res = run_nix(cmd, capture_output=True, check=False)
    if res.returncode == 0 and res.stdout.strip():
        return res.stdout.strip()
    return None
