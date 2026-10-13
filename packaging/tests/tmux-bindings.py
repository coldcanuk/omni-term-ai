#!/usr/bin/env python3
"""BUG-05 regression: Prefix-E and Prefix-Space act on the omni-term-ai server.

A real client is attached to the workspace socket through a pty, with a
decoy server on the default socket. The keys are pressed and both servers
are inspected. Everything runs under a private TMUX_TMPDIR and a fake nvim,
so no real tmux server is touched.

usage: tmux-bindings.py [tmux.conf]   (default: tmux.conf in the source tree)
Exit 0 = pass. Exit 77 = skipped (no tmux or no pty).
"""
import os
import select
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from typing import NoReturn

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONF = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "tmux.conf")
OMNI = "omni-term-ai"
PREFIX = b"\x02"  # C-b; tmux.conf does not change the prefix


def skip(why) -> NoReturn:
    print(f"tmux-bindings: SKIP ({why})")
    sys.exit(77)


def fail(why) -> NoReturn:
    print(f"FAIL: {why}", file=sys.stderr)
    sys.exit(1)


if shutil.which("tmux") is None:
    skip("tmux not installed")
try:
    import fcntl
    import pty
    import struct
    import termios
except ImportError:
    skip("no pty support")

tmp = tempfile.mkdtemp(prefix="omni-tmux-")
fakebin = os.path.join(tmp, "bin")
os.makedirs(fakebin)
nvim_log = os.path.join(tmp, "nvim.log")
with open(os.path.join(fakebin, "nvim"), "w") as f:
    f.write('#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexec sleep 600\n' % nvim_log)
os.chmod(os.path.join(fakebin, "nvim"), 0o755)

env = {k: v for k, v in os.environ.items() if not k.startswith("TMUX")}
env.update(
    TMUX_TMPDIR=tmp,
    TERM="xterm-256color",
    SHELL="/bin/sh",
    # Source tree first so run-shell finds this tree's tmux-toggle-scratch.
    PATH=os.pathsep.join([ROOT, fakebin, os.environ.get("PATH", "/usr/bin:/bin")]),
)
# -L, like the launcher. "default" is the server a bare `tmux` reaches.
SOCK = {"omni": OMNI, "decoy": "default"}


def t(server, *args, check=False):
    r = subprocess.run(["tmux", "-L", SOCK[server], *args], env=env,
                       capture_output=True, text=True, timeout=10)
    # tmux can exit 0 after a socket error, so stderr counts too.
    if check and (r.returncode or r.stderr.strip()):
        fail(f"tmux {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip()


def lines(server, *args):
    out = t(server, *args)
    return sorted(out.splitlines()) if out else []


def snapshot(server):
    return {
        "sessions": lines(server, "list-sessions", "-F", "#{session_name}"),
        "windows": lines(server, "list-windows", "-a", "-F", "#{session_name}:#{window_name}#{window_id}"),
        "clients": lines(server, "list-clients", "-F", "#{client_session}"),
    }


def wait_for(what, cond, timeout=8.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if cond():
            return
        time.sleep(0.1)
    fail(f"timed out waiting for {what}\n  omni={snapshot('omni')}\n  decoy={snapshot('decoy')}")


def editor_id():
    return t("omni", "display-message", "-p", "-t", "ws:=Editor", "#{window_id}")


def nvim_calls():
    if not os.path.exists(nvim_log):
        return []
    with open(nvim_log) as f:
        return [ln for ln in f.read().splitlines() if ln]


pid = None
stop = threading.Event()
try:
    # Decoy first: an unqualified `tmux` that lost the workspace socket lands here.
    t("decoy", "-f", "/dev/null", "new-session", "-d", "-s", "decoy", check=True)
    t("omni", "-f", CONF, "new-session", "-d", "-s", "ws", "-n", "Command Center",
      "-x", "120", "-y", "40", check=True)
    t("omni", "new-window", "-t", "ws", "-n", "Editor", check=True)
    t("omni", "select-window", "-t", "ws:=Command Center", check=True)
    decoy0 = snapshot("decoy")

    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe("tmux", ["tmux", "-L", SOCK["omni"], "attach-session", "-t", "ws"], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

    def drain():
        while not stop.is_set():
            r, _, _ = select.select([fd], [], [], 0.1)
            if r:
                try:
                    os.read(fd, 65536)
                except OSError:
                    return

    threading.Thread(target=drain, daemon=True).start()
    wait_for("client to attach", lambda: snapshot("omni")["clients"] == ["ws"])

    # Prefix-E: the Editor window on the workspace server is replaced.
    before = editor_id()
    os.write(fd, PREFIX + b"E")
    wait_for("Prefix-E to recreate Editor", lambda: editor_id() not in ("", before)
             and nvim_calls() == ["-c Neotree show"])
    editors = [w for w in snapshot("omni")["windows"] if w.startswith("ws:Editor")]
    if len(editors) != 1:
        fail(f"expected one Editor window: {snapshot('omni')['windows']}")

    # Prefix-Space: a scratch popup attaches to the workspace server.
    os.write(fd, PREFIX + b" ")
    wait_for("Prefix-Space to open scratch", lambda: "scratch" in snapshot("omni")["clients"])

    # Prefix-Space again: the popup closes; the scratch session survives.
    os.write(fd, PREFIX + b" ")
    wait_for("Prefix-Space to close scratch", lambda: snapshot("omni")["clients"] == ["ws"])
    if "scratch" not in snapshot("omni")["sessions"]:
        fail("scratch session should persist after closing the popup")

    if snapshot("decoy") != decoy0:
        fail(f"default tmux server was modified: {decoy0} -> {snapshot('decoy')}")
finally:
    stop.set()
    if pid:
        try:
            os.kill(pid, 9)
            os.waitpid(pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
    for s in SOCK:
        subprocess.run(["tmux", "-L", SOCK[s], "kill-server"], env=env, capture_output=True)
    shutil.rmtree(tmp, ignore_errors=True)

print("tmux-bindings: OK (Prefix-E and Prefix-Space stay on the omni-term-ai socket)")
