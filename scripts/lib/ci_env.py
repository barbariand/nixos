import os
import stat
import tempfile
from contextlib import contextmanager
from collections.abc import Generator
from .logger import log_info, log_warn


@contextmanager
def setup_ssh_context() -> Generator[None, None, None]:
    """
    Context manager to temporarily configure SSH for private flake inputs during CI runs.
    Ensures secure handling and cleanup of the deployment key.
    """
    deploy_key = os.getenv("RUNNER_DEPLOY_KEY")
    os.environ["GIT_TERMINAL_PROMPT"] = "0"

    if not deploy_key:
        log_warn(
            "ci_env", "RUNNER_DEPLOY_KEY is not set. Fetching private inputs may fail."
        )
        yield
        return

    log_info("ci_env", "Configuring SSH context for private flake inputs")
    with tempfile.NamedTemporaryFile(mode="w", delete=False) as key_file:
        key_file.write(deploy_key)
        key_path = key_file.name

    os.chmod(key_path, stat.S_IRUSR | stat.S_IWUSR)
    original_ssh_cmd = os.environ.get("GIT_SSH_COMMAND")
    os.environ["GIT_SSH_COMMAND"] = (
        f"ssh -i {key_path} -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
    )

    try:
        yield
    finally:
        if os.path.exists(key_path):
            os.remove(key_path)

        if original_ssh_cmd is not None:
            os.environ["GIT_SSH_COMMAND"] = original_ssh_cmd
        else:
            os.environ.pop("GIT_SSH_COMMAND", None)
