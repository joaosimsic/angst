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
base = tempfile.mkdtemp(prefix="zellij-bell-check-")
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
visual_bell true
pane_frames false
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
session = "bell-check"
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
    result = action("list-tabs", "--all", "--json")
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def panes():
    result = action("list-panes", "--all", "--json")
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def wait_for_tabs(count):
    deadline = time.time() + 15
    while time.time() < deadline:
        drain(0.2)
        current = tabs()
        if current and len(current) == count:
            return current
    return None


def terminal_pane(tab_position):
    current = panes()
    if not current:
        return None
    for pane in current:
        if not pane.get("is_plugin") and pane.get("tab_position") == tab_position:
            return pane
    return None


def run_bell(pane_id):
    result = action("write-chars", "-p", str(pane_id), "printf '\\a'")
    if result.returncode != 0:
        raise RuntimeError(f"write-chars failed: {result.stderr.strip()}")
    result = action("send-keys", "-p", str(pane_id), "Enter")
    if result.returncode != 0:
        raise RuntimeError(f"send-keys failed: {result.stderr.strip()}")


def tab_flag(tab_position, field):
    current = tabs()
    if not current:
        return None
    for tab in current:
        if tab.get("position") == tab_position:
            return bool(tab.get(field))
    return None


try:
    if wait_for_tabs(1) is None:
        raise RuntimeError("zellij session did not become ready")
    for _ in range(2):
        result = action("new-tab")
        if result.returncode != 0:
            raise RuntimeError(f"new-tab failed: {result.stderr.strip()}")
    if wait_for_tabs(3) is None:
        raise RuntimeError("three-tab layout was not created")
    drain(0.5)

    background_position = 1
    background_pane = terminal_pane(background_position)
    if background_pane is None:
        raise RuntimeError("background tab has no terminal pane")
    run_bell(background_pane["id"])

    deadline = time.time() + 5
    while time.time() < deadline:
        drain(0.2)
        if tab_flag(background_position, "has_bell_notification"):
            break
    else:
        raise RuntimeError("background tab did not receive a bell notification")
    print(f"background tab {background_position}: bell ok")

    current = tabs()
    if not current:
        raise RuntimeError("could not read tab state")
    active_position = next(tab["position"] for tab in current if tab["active"])
    active_pane = terminal_pane(active_position)
    if active_pane is None:
        raise RuntimeError("active tab has no terminal pane")
    run_bell(active_pane["id"])
    time.sleep(1)
    drain(0.2)
    if tab_flag(active_position, "has_bell_notification"):
        raise RuntimeError("active tab unexpectedly kept a bell notification")
    print(f"active tab {active_position}: bell stays suppressed")
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
