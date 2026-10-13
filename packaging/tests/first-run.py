#!/usr/bin/env python3
"""BUG-06 regression: first run calls the sibling omni-config, not a PATH lookup.

The launcher is run by absolute path (the way the desktop entry runs it)
with no config file and a pty on stdin, so the first-run branch fires. The
sibling omni-config is a stub that records the call and exits 42, which
stops the launcher (set -e) before tmux. A decoy omni-config on PATH
records "decoy" and exits 43.

Both layouts are covered: the source tree, and `make install` into a
DESTDIR. Nothing touches the real config or tmux.

usage: first-run.py        Exit 0 = pass. Exit 77 = skipped (no pty).
"""
import os
import shutil
import subprocess
import sys
import tempfile
from typing import NoReturn

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SYSPATH = "/usr/bin:/bin"


def skip(why) -> NoReturn:
    print(f"first-run: SKIP ({why})")
    sys.exit(77)


def fail(why) -> NoReturn:
    print(f"FAIL: {why}", file=sys.stderr)
    sys.exit(1)


try:
    import pty
except ImportError:
    skip("no pty support")


def write_stub(path, tag, code, log):
    with open(path, "w") as f:
        f.write('#!/bin/sh\nprintf "%s %%s\\n" "$*" >> "%s"\nexit %d\n' % (tag, log, code))
    os.chmod(path, 0o755)


def run_in_pty(argv, env, stdin_text=b""):
    """Run argv with a pty as its controlling terminal. Return (code, output)."""
    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execve(argv[0], argv, env)
        finally:
            os._exit(127)
    if stdin_text:
        os.write(fd, stdin_text)
    out = b""
    while True:
        try:
            chunk = os.read(fd, 4096)
        except OSError:  # EIO once the child closes the pty
            break
        if not chunk:
            break
        out += chunk
    _, status = os.waitpid(pid, 0)
    os.close(fd)
    return os.waitstatus_to_exitcode(status), out.decode(errors="replace")


tmp = tempfile.mkdtemp(prefix="omni-first-run-")
try:
    log = os.path.join(tmp, "calls.log")
    decoy = os.path.join(tmp, "decoy-bin")
    os.makedirs(decoy)
    write_stub(os.path.join(decoy, "omni-config"), "decoy", 43, log)

    # Layout 1: source tree (launcher, lib/, sibling omni-config).
    src = os.path.join(tmp, "src")
    os.makedirs(src)
    shutil.copy2(os.path.join(ROOT, "launch-ai-workspace"), src)
    shutil.copytree(os.path.join(ROOT, "lib"), os.path.join(src, "lib"))
    write_stub(os.path.join(src, "omni-config"), "sibling", 42, log)

    # Layout 2: installed (bin/ next to share/omni-term-ai), via the Makefile.
    stage = os.path.join(tmp, "stage")
    r = subprocess.run(["make", "-s", "-C", ROOT, "DESTDIR=" + stage, "PREFIX=/usr", "install"],
                       capture_output=True, text=True)
    if r.returncode:
        fail(f"make install: {r.stderr.strip()}")
    write_stub(os.path.join(stage, "usr/bin/omni-config"), "sibling", 42, log)

    layouts = {
        "source": (os.path.join(src, "launch-ai-workspace"), {}),
        "installed": (os.path.join(stage, "usr/bin/launch-ai-workspace"),
                      {"OMNI_TERM_AI_HOME": os.path.join(stage, "usr/share/omni-term-ai")}),
    }
    paths = {"no omni-config on PATH": SYSPATH, "decoy first on PATH": decoy + ":" + SYSPATH}

    base = {
        "HOME": os.path.join(tmp, "home"),
        "XDG_CONFIG_HOME": os.path.join(tmp, "xdg"),  # no config file -> first run
        "TERM": "dumb",
        "LANG": "C",
    }
    os.makedirs(base["HOME"])

    def case(label, launcher, extra, path, want_tag, want_code, stdin_text=b""):
        if os.path.exists(log):
            os.unlink(log)
        env = dict(base, PATH=path, **extra)
        code, out = run_in_pty([launcher], env, stdin_text)
        calls = open(log).read().split() if os.path.exists(log) else []
        if "First time setup" not in out:
            fail(f"{label}: first-run branch did not fire\n{out}")
        if want_tag is None:
            if calls:
                fail(f"{label}: expected no omni-config call, got {calls}\n{out}")
        elif calls != [want_tag]:
            fail(f"{label}: expected [{want_tag}], got {calls} (exit {code})\n{out}")
        if code != want_code:
            fail(f"{label}: expected exit {want_code}, got {code}\n{out}")
        return out

    for lname, (launcher, extra) in layouts.items():
        for pname, path in paths.items():
            case(f"{lname}, {pname}", launcher, extra, path, "sibling", 42)

    # A launcher with no sibling (e.g. a symlink in another bin dir) still
    # finds omni-config on PATH, and says so clearly when it is nowhere.
    lonely = os.path.join(tmp, "lonely")
    os.makedirs(lonely)
    shutil.copy2(layouts["installed"][0], lonely)
    lonely_launcher = os.path.join(lonely, "launch-ai-workspace")
    extra = layouts["installed"][1]
    case("no sibling, decoy on PATH", lonely_launcher, extra, decoy + ":" + SYSPATH, "decoy", 43)
    if shutil.which("omni-config", path=SYSPATH) is None:
        out = case("no sibling, nothing on PATH", lonely_launcher, extra, SYSPATH, None, 1,
                   stdin_text=b"\n")
        if "cannot find omni-config" not in out:
            fail(f"missing omni-config should get a clear message\n{out}")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("first-run: OK (sibling omni-config wins over PATH, source and installed)")
