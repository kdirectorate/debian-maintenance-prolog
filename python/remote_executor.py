"""Remote executor entry point.

Dispatches an ``--action`` keyword to a corresponding ``do_<keyword>``
function. New actions are added simply by defining another ``do_<name>``
function in this module.

Note: This module follows, sort of, Prolog's naming conventions since it
is mostly a Prolog helper. 
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

def connect_to_remote(args: argparse.Namespace) -> Connection:
    """Establish an SSH connection to the remote host."""
    user = args.user or "root"
    connect_kwargs = {"allow_agent": True, "look_for_keys": True}
    if args.key is not None:
        connect_kwargs["key_filename"] = str(args.key)

    return Connection(
        host=args.host,
        port=args.port,
        user=user,
        connect_kwargs=connect_kwargs,
    )

# Helper to run a command on the remote host
def run_command_on_remote(args: argparse.Namespace, cmd: str, conn: Connection = None) -> dict:
    """Run a command on the remote host and return the result as a package."""

    if conn is None:
        conn = connect_to_remote(args)
    with (conn if conn is not None else connect_to_remote(args)) as conn:
        user = args.user or "root"
        connect_kwargs = {"allow_agent": True, "look_for_keys": True}
        if args.key is not None:
            connect_kwargs["key_filename"] = str(args.key)

        result = conn.run(cmd, hide=True, warn=True)

        return result

def get_remote_time(args: argparse.Namespace) -> float:
    """Get the current time on the remote host in seconds since the epoch."""
    CMD = "date +%s"
    result = run_command_on_remote(args, CMD)
    return float(result.stdout.strip())

def get_remote_directory(args: argparse.Namespace, path: str, conn: Connection = None) -> dict:
    """Get file size and modification time files on the remote host."""

    current_remote_time = get_remote_time(args)

    CMD = f"sudo find {path} -type f -mtime -30 -printf '%p\t%s\t%T@\n'"
    result = run_command_on_remote(args, CMD, conn)
    files = []
    for line in result.stdout.splitlines():
        if line.startswith(path):
            file_path, sizebytes, age = line.split("\t")
            sizemb = round(int(sizebytes) / (1024*1024), 2)
            # Calculate the age in days by subtracting the file's modification time from 
            # the current remote time and converting seconds to days.
            age_days = round(float(current_remote_time - float(age)) / (60*60*24), 2)  # age in days
            files.append((file_path, sizemb, age_days))

    return files # list of tuples (path, size in MB, age in days)

# ---------------------------------------------------------------------------
# Action handlers
#
# Every function whose name starts with ``do_`` is automatically exposed as a
# valid value for ``--action``. The suffix after ``do_`` is the keyword the
# user passes on the command line.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# ACTION: purge unused kernels
# ---------------------------------------------------------------------------
def do_purge_kernels(args: argparse.Namespace) -> int:
    try:
        action = _current_action()
        json_parms = json.loads(args.parms)
        kernels = json_parms.get("kernels")
        if not kernels:
            raise ValueError("Missing 'kernels' parameter in JSON input.")
        
        with connect_to_remote(args) as conn:

            for kernel in kernels:
                CMD = f"sudo apt purge -y linux-image-{kernel}"
                sys.stderr.write(f"[DEBUG] Running command on remote {args.host}:{args.port}]: {CMD}\n")
                run_command_on_remote(args, CMD, conn)
            
            CMD = "sudo update-grub"
            run_command_on_remote(args, CMD, conn)

        package = _package_results("success", "Purged unused kernels.", 
                                   action, {"kernels": kernels})
    except Exception as e:
        package = _package_results("error", f"Failed to purge unused kernels: {e}", action, {})

    return package


# ----------------------------------------------------------------------------
# ACTION: Modify the remote host
# ----------------------------------------------------------------------------
def do_remove_packages(args: argparse.Namespace) -> int:
    """Attempt to remove a package."""
    try:
        action = _current_action()
        json_parms = json.loads(args.parms)
        packages = json_parms.get("packages")
        if not packages:
            raise ValueError("Missing 'packages' parameter in JSON input.")
        
        CMD = f"sudo apt-get remove -y {" ".join(packages)}"
        run_command_on_remote(args, CMD)
        package = _package_results("success", "Removed package.", 
                                   action, {"packages": packages})
    except Exception as e:
        package = _package_results("error", f"Failed to remove package: {e}", action, {})

    return package


def do_remove_file(args: argparse.Namespace) -> int:
    """Attempt to rm a file."""
    try:
        action = _current_action()
        json_parms = json.loads(args.parms)
        path = json_parms.get("path")
        if not path:
            raise ValueError("Missing 'path' parameter in JSON input.")
        
        CMD = f"sudo rm {path}"
        run_command_on_remote(args, CMD)
        package = _package_results("success", "Removed file.", 
                                   action, {"path": path})
    except Exception as e:
        package = _package_results("error", f"Failed to remove file: {e}", action, {})

    return package

# ---------------------------------------------------------------------------
# RECON: Get information from the remote host
# ---------------------------------------------------------------------------
def do_get_remote_sockets(args: argparse.Namespace) -> int:
    """Get a list of open sockets from the remote host."""
    try:
        CMD = "sudo ss -tulnpe"
        action = _current_action()
        result = run_command_on_remote(args, CMD)
        socks = []
        for i, line in enumerate(result.stdout.strip().splitlines()):
            line = line.strip()
            if not line: continue
            if i == 0 and line.startswith('Netid'): continue
            parts = line.split(maxsplit=6)
            if len(parts) < 6: continue
            local = parts[4]
            peer = parts[5]
            la, lp = local.rsplit(':', 1) if ':' in local else (local, '')
            pa, pp = peer.rsplit(':', 1) if ':' in peer else (peer, '')
            proc = parts[6] if len(parts) > 6 else ''
            pid = None
            name = None

            if 'pid=' in proc:
                s = proc.find('pid=') + 4
                e = proc.find(',', s)
                if e == -1: e = len(proc)
                try: pid = int(proc[s:e])
                except: pass
            if '(("' in proc:
                s = proc.find('("') + 2
                e = proc.find('"', s)
                if e > s: name = proc[s:e]
            socks.append({
                'netid': parts[0].lower(),
                'state': parts[1],
                'recv_q': int(parts[2]),
                'send_q': int(parts[3]),
                'local_address': la,
                'local_port': lp,
                'peer_address': pa,
                'peer_port': pp,
                'process': proc,
                'pid': pid,
                'name': name
            })

        package = _package_results("success", "Ports collected successfully", 
                                   action, {"sockets": socks})
    except Exception as e:
        package = _package_results("error", f"Failed to collect ports: {e}", action, {})

    return package

def do_get_remote_processes(args: argparse.Namespace) -> int:
    """Get a list of processes from the remote host."""
    try:
        CMD = "ps -eo pid,ppid,uid,user,pcpu,pmem,vsz,rss,tty,stat,start_time,time,cmd --no-headers"
        action = _current_action()
        result = run_command_on_remote(args, CMD)

        procs = []
        for line in result.stdout.strip().splitlines():
            line = line.strip()
            if not line: continue
            parts = line.split(None, 12)
            if len(parts) != 13: continue
            procs.append({
                'pid': int(parts[0]),
                'ppid': int(parts[1]),
                'uid': int(parts[2]),
                'user': parts[3],
                'pcpu': float(parts[4]),
                'pmem': float(parts[5]),
                'vsz': int(parts[6]),
                'rss': int(parts[7]),
                'tty': parts[8],
                'stat': parts[9],
                'start_time': parts[10],
                'time': parts[11],
                'cmd': parts[12]
            })

        package = _package_results("success", "Processes collected successfully", 
                                   action, {"processes": procs})
        
    except Exception as e:
        package = _package_results("error", f"Failed to collect processes: {e}", action, {})

    return package

def do_collect_modified_files(args: argparse.Namespace) -> int:
    """Get a list of modified files from the remote host."""

    with connect_to_remote(args) as conn:
        try:
            DIRS = [
                "/etc", "/bin", "/usr/bin", 
                "/usr/local/etc", "/usr/local/bin", "/usr/local/sbin"
            ]

            action = _current_action()
            modified_files = []
            for dir in DIRS:
                files = get_remote_directory(args, dir)
                modified_files.extend(files)

            package = _package_results("success", "Modified files collected successfully", 
                                    action, {"modified_files": modified_files})
        except Exception as e:
            package = _package_results("error", f"Failed to collect modified files: {e}", action, {})

        return package

def do_collect_temp_files(args: argparse.Namespace) -> int:
    """Get a list of temporary files from the remote host."""

    with connect_to_remote(args) as conn:
        try:
            action = _current_action()
            DIRS = [
                "/tmp", "/var/tmp"
            ]

            action = _current_action()
            temp_files = []
            for dir in DIRS:
                files = get_remote_directory(args, dir, conn)
                temp_files.extend(files)

            package = _package_results("success", "Temporary files collected successfully", 
                                    action, {"temp_files": temp_files})
        except Exception as e:
            package = _package_results("error", f"Failed to collect temporary files : {e}", action, {})

        return package
        
def do_collect_kernels(args: argparse.Namespace) -> int:
    """Get kernel information from the remote host."""
    
    try:
        CMD = "uname -r && echo '---KERNELS---' && dpkg-query -W -f='${Package}\n' 'linux-image-*'"
        action = _current_action()
        notes = f"[DEBUG] Running command on remote {args.host}:{args.port}]: {CMD}"
        result = run_command_on_remote(args, CMD)

        # Parse the running kernel name and the list of installed kernels from the command output.
        data = {
            "notes": notes,
            "running_kernel": result.stdout.splitlines()[0],
            "installed_kernels": [
                line.removeprefix("linux-image-")
                for line in result.stdout.splitlines()[2:]
                if line.startswith("linux-image-")
            ],
        }
        package = _package_results("success", "Kernels collected successfully", action, data)
    except Exception as e:
        package = _package_results("error", f"Failed to collect kernels: {e}", action, {})

    return package

def do_collect_apt_autoremove(args: argparse.Namespace) -> int:
    """Get autoremove information from the remote host."""
    
    try:
        CMD = "sudo apt autoremove --dry-run -q | grep 'The following packages will be REMOVED:' -A 1000 | tail -n +2"
        action = _current_action()

        notes = f"[DEBUG] Running command on remote {args.host}:{args.port}]: {CMD}"
        result = run_command_on_remote(args, CMD)

        # Parse the autoremove candidates from the command output.
        data = {
            "notes": notes,
            "autoremove_candidates": (result.stdout.splitlines() or [""])[0].strip().split()
        }
        package = _package_results("success", "Autoremove candidates collected successfully", action, data)
    except Exception as e:
        package = _package_results("error", f"Failed to collect autoremove candidates: {e}", action, {})

    return package
            

# ---------------------------------------------------------------------------
# Create Test Data
#
# Creates test files on the server that can later be acted upon by the app.
# ONLY USE IN TEST, not PROD.
# ---------------------------------------------------------------------------

def do_t_start_test_processes(args: argparse.Namespace) -> int:

    with connect_to_remote(args) as conn:
        try:
            CMDs = [
                "pkill sleep",
                # "bash -c 'exec -a /bin/bash -c \"while true; do sleep 1000; done\" &'",
                "nohup bash -c 'exec -a nc sleep infinity' >/dev/null 2>&1 < /dev/null &",
                "nohup bash -c 'exec -a pwncat sleep infinity' >/dev/null 2>&1 < /dev/null &",
                "nohup bash -c 'exec -a cobaltstrike sleep infinity' >/dev/null 2>&1 < /dev/null &"
            ]
            action = _current_action()

            for cmd in CMDs:
                run_command_on_remote(args, cmd, conn)

            package = _package_results("success", "Test processes created", action, {})
        except Exception as e:
            package = _package_results("error", f"Failed creating test processes: {e}", action, {})

        return package

def do_t_tamper_critical_files(args: argparse.Namespace) -> int:
    with connect_to_remote(args) as conn:
        try:
            CMDs = [
                """sudo touch -d "2 days ago" /etc/passwd""",
            ]
            action = _current_action()

            for cmd in CMDs:
                run_command_on_remote(args, cmd, conn)

            package = _package_results("success", "Tampered with critical files", action, {})
        except Exception as e:
            package = _package_results("error", f"Failed tampering with critical files: {e}", action, {})

        return package

def do_t_create_tmp_files(args: argparse.Namespace) -> int:
    with connect_to_remote(args) as conn:
        try:
            CMDs = [
                "fallocate -l 7M  /tmp/test_temp_7mb_expired",
                "fallocate -l 20M /tmp/test_temp_20mb_expired",
                "fallocate -l 20M /tmp/test_temp_20mb_current",
                "touch -d '7 days ago' /tmp/test_temp_7mb_expired /tmp/test_temp_20mb_expired",
                "touch -d '1 day ago' /tmp/test_temp_20mb_current",
            ]
                
            action = _current_action()

            for cmd in CMDs:
                run_command_on_remote(args, cmd, conn)
            package = _package_results("success", "Test /tmp files created", action, {})
        
        except Exception as e:
            package = _package_results("error", f"Failed creating /tmp files: {e}", action, {})

        return package

def do_t_create_apt_dependencies(args: argparse.Namespace) -> int:

    with connect_to_remote(args) as conn:
        try:
            CMDs = [
                "sudo apt-get update",
                "sudo apt-get install -y debtree",
                "sudo apt-get remove -y debtree"
            ]
            action = _current_action()

            for cmd in CMDs:
                run_command_on_remote(args, cmd, conn)

            package = _package_results("success", "Test apt dependencies created", action, {})
        except Exception as e:
            package = _package_results("error", f"Failed creating test apt dependencies: {e}", action, {})

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
    parser.add_argument("--port", required=False, type=int, 
                        help="SSH port of the target system.", default=22)
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
    parser.add_argument(
        "--parms",
        required=False,
        type=str,
        default="{}",
        help="JSON Action parameters.",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    actions = _discover_actions()
    if not actions:
        print("error: no do_* action handlers are defined", file=sys.stderr)
        return 2

    parser = _build_parser(list(actions))
    args = parser.parse_args(argv)

    #sys.stderr.write(f"[DEBUG] Parsed arguments: {args}\n")
    handler = actions[args.action]
    package = handler(args)
    print(json.dumps(package, indent=2))
    return 0 if package["status"] == "success" else 1

if __name__ == "__main__":
    raise SystemExit(main())
