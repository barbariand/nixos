import sys

C_RESET = "\033[0m"
C_INFO = "\033[1;32m"
C_WARN = "\033[1;33m"
C_ERR = "\033[1;31m"
C_DEBUG = "\033[1;34m"
C_DIM = "\033[2m"

def log_info(ctx: str, msg: str) -> None:
    print(f"{C_INFO}INFO{C_RESET}  {C_DIM}{ctx}:{C_RESET} {msg}", file=sys.stderr)

def log_warn(ctx: str, msg: str) -> None:
    print(f"{C_WARN}WARN{C_RESET}  {C_DIM}{ctx}:{C_RESET} {msg}", file=sys.stderr)

def log_error(ctx: str, msg: str) -> None:
    print(f"{C_ERR}ERROR{C_RESET} {C_DIM}{ctx}:{C_RESET} {msg}", file=sys.stderr)

def log_debug(ctx: str, msg: str) -> None:
    print(f"{C_DEBUG}DEBUG{C_RESET} {C_DIM}{ctx}:{C_RESET} {msg}", file=sys.stderr)
