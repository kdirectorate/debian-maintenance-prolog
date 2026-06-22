"""Remote executor entry point.

Dispatches an ``--action`` keyword to a corresponding ``do_<keyword>``
function. New actions are added simply by defining another ``do_<name>``
function in this module.
"""

from __future__ import annotations

import argparse
import inspect
import sys
import json
from pathlib import Path
from typing import Callable
from fabric import Connection

# ---------------------------------------------------------------------------
# Example JSON output for testing
# JSON = f"""
#     {{
#         "status": "{{status}}",
#         "action": "{action}",
#         "data": {{
#             "running_kernel": "6.1.0-18-amd64",
#             "installed_kernels": [
#             "6.1.0-18-amd64",
#             "5.10.0-8-amd64",
#             "6.1.0-17-amd64"
#             ]
#         }}
#     }}
# """


# ---------------------------------------------------------------------------
# Common utilities for action handlers
# ---------------------------------------------------------------------------
def _current_action() -> str:
    """Return the calling ``do_*`` function's name without the ``do_`` prefix."""
    caller_name = inspect.stack()[1].function
    return caller_name.removeprefix("do_")

def _package_results(status: str, message: str, action: str, data: dict) -> dict:
    return {
        "status": status,
        "message": message,
        "action": action,
        "data": data
    }

# ---------------------------------------------------------------------------
# Action handlers
#
# Every function whose name starts with ``do_`` is automatically exposed as a
# valid value for ``--action``. The suffix after ``do_`` is the keyword the
# user passes on the command line.
# ---------------------------------------------------------------------------

def do_collect_kernels(args: argparse.Namespace) -> int:
    """Get kernel information from the remote host."""
    
    try:
        CMD = "uname -r && echo '---KERNELS---' && dpkg-query -W -f='${Package}\n' 'linux-image-*'"
        action = _current_action()
        user = args.user or "root"
        connect_kwargs = {"allow_agent": True, "look_for_keys": True}
        if args.key is not None:
            connect_kwargs["key_filename"] = str(args.key)

        result = Connection(
            host=args.host,
            user=user,
            connect_kwargs=connect_kwargs,
        ).run(CMD, hide=True)

        # Parse the running kernel name and the list of installed kernels from the command output.
        data = {
            "running_kernel": result.stdout.splitlines()[0],
            "installed_kernels": [line for line in result.stdout.splitlines()[2:] if line.startswith("linux-image-")],
        }
        package = _package_results("success", "Kernels collected successfully", action, data)
    except Exception as e:
        package = _package_results("error", f"Failed to collect kernels: {e}", action, {})

    return package


# ---------------------------------------------------------------------------
# Dispatch helpers
# ---------------------------------------------------------------------------

ActionFn = Callable[[argparse.Namespace], int]


def _discover_actions() -> dict[str, ActionFn]:
    """Return a mapping of ``keyword -> function`` for every ``do_*`` callable."""
    actions: dict[str, ActionFn] = {}
    for name, obj in globals().items():
        if name.startswith("do_") and callable(obj):
            actions[name[len("do_") :]] = obj
    return actions


def _build_parser(action_names: list[str]) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="remote_executor",
        description="Run a maintenance action against a remote Debian host over SSH.",
    )
    parser.add_argument("--host", required=True, help="Hostname or IP of the target system.")
    parser.add_argument("--user", required=False, help="SSH username.")
    parser.add_argument(
        "--key",
        required=False,
        type=Path,
        help="Path to the SSH private key file.",
    )
    parser.add_argument(
        "--action",
        required=True,
        choices=sorted(action_names),
        help="Action keyword. Dispatches to the matching do_<keyword> function.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    actions = _discover_actions()
    if not actions:
        print("error: no do_* action handlers are defined", file=sys.stderr)
        return 2

    parser = _build_parser(list(actions))
    args = parser.parse_args(argv)

    handler = actions[args.action]
    package = handler(args)
    print(json.dumps(package, indent=2))

    return 0 if package["status"] == "success" else 1

if __name__ == "__main__":
    raise SystemExit(main())
