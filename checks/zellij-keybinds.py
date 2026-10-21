import json
import os
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time

zellij = sys.argv[1]
base = tempfile.mkdtemp(prefix="zellij-keybind-check-")
home = os.path.join(base, "home")
socket_dir = os.path.join(base, "sockets")
runtime_dir = os.path.join(base, "runtime")
config = os.path.join(base, "config.kdl")
for directory in (home, socket_dir, runtime_dir):
    os.makedirs(directory)
os.chmod(runtime_dir, 0o700)
with open(config, "w") as f:
    f.write(
        """
keybinds clear-defaults=true {
    shared_except "locked" {
        bind "Ctrl j" { GoToTab 1; }
        bind "Ctrl k" { GoToTab 1; GoToPreviousTab; }
    }
}
"""
    )
env = os.environ.copy()
for key in ("ZELLIJ", "ZELLIJ_SESSION_NAME", "ZELLIJ_PANE_ID", "ZELLIJ_CONFIG_FILE"):
    env.pop(key, None)
env.update(
    {
        "HOME": home,
        "XDG_CACHE_HOME": os.path.join(home, ".cache"),
        "XDG_DATA_HOME": os.path.join(home, ".local", "share"),
        "XDG_CONFIG_HOME": os.path.join(home, ".config"),
        "XDG_RUNTIME_DIR": runtime_dir,
        "ZELLIJ_SOCKET_DIR": socket_dir,
        "SHELL": shutil.which("bash") or "/bin/bash",
        "TERM": "xterm-256color",
        "LANG": "C.UTF-8",
    }
)
session = "keybind-check"
master, slave = pty.openpty()
proc = subprocess.Popen(
    [zellij, "-s", session, "-c", config],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    env=env,
    preexec_fn=os.setsid,
    close_fds=True,
)
os.close(slave)
output = bytearray()


def drain(seconds=0.2):
    deadline = time.time() + seconds
    while time.time() < deadline:
        ready, _, _ = select.select([master], [], [], 0.05)
        if ready:
            try:
                chunk = os.read(master, 65536)
            except OSError:
                return
            if not chunk:
                return
            output.extend(chunk)


def action(*args):
    return subprocess.run(
        [zellij, "--session", session, "action", *args],
        env=env,
        capture_output=True,
        text=True,
        timeout=10,
    )


def tabs():
    result = action("list-tabs", "--state", "--json")
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def active_position():
    current = tabs()
    if not current:
        return None
    for tab in current:
        if tab.get("active"):
            return tab.get("position")
    return None


def wait_for_tabs(count):
    deadline = time.time() + 15
    while time.time() < deadline:
        drain(0.2)
        current = tabs()
        if current and len(current) == count:
            return current
    return None


def wait_for_active(position):
    deadline = time.time() + 5
    while time.time() < deadline:
        drain(0.2)
        if active_position() == position:
            return True
    return False


try:
    if wait_for_tabs(1) is None:
        raise RuntimeError("zellij session did not become ready")
    for _ in range(2):
        result = action("new-tab")
        if result.returncode != 0:
            raise RuntimeError(f"new-tab failed: {result.stderr.strip()}")
    if wait_for_tabs(3) is None:
        raise RuntimeError("three-tab layout was not created")
    if not wait_for_active(2):
        raise RuntimeError("third tab was not focused")

    cases = [
        ("Ctrl+j", b"\x0a", 0),
        ("Ctrl+k", b"\x0b", 2),
    ]
    for label, sequence, expected in cases:
        os.write(master, sequence)
        if not wait_for_active(expected):
            raise RuntimeError(
                f"{label} did not focus tab position {expected}; "
                f"current position is {active_position()}"
            )
        print(f"{label}: ok")
finally:
    action("quit")
    time.sleep(0.3)
    try:
        proc.terminate()
        proc.wait(timeout=3)
    except Exception:
        proc.kill()
    try:
        os.close(master)
    except OSError:
        pass
    if sys.exc_info()[0] is not None:
        tail = bytes(output[-4000:]).decode("utf-8", "replace")
        print(f"pty output tail:\n{tail}", file=sys.stderr)
    shutil.rmtree(base, ignore_errors=True)
