# Omni Term AI — Multi-OS Packaging Plan (RDAP)

## 2. Scope of Work

**Primary Goal:** Make Omni Term AI installable on Ubuntu, Debian, Red Hat-family Linux, OpenBSD, and macOS using native packaging (`.deb`, `.rpm`, OpenBSD port, Homebrew) plus a POSIX `make install` / `install.sh` path.

**Non-Goals:**
- Official Debian NEW / Ubuntu PPA / Fedora COPR / Homebrew/core / OpenBSD CVS ports landing in this PR
- Windows, Snap, Flatpak, AppImage
- Bundling tmux, Neovim, grok, or agy
- Signed apt/yum repositories
- Committing untracked `nvim-config/lazy-lock.json` on the parent main tree

**Success Criteria / Definition of Done:**
- No hardcoded `/opt/repo/omni-term-ai` or `/home/chuck` in installed files
- `make DESTDIR=/tmp/omni-stage PREFIX=/usr install` produces a complete FHS-like tree
- `make deb` produces `dist/omni-term-ai_*_all.deb`; `dpkg-deb -I` and `-c` succeed
- RPM spec exists; `make rpm` builds when `rpmbuild` is available and fails clearly when not
- `Formula/omni-term-ai.rb` is a valid Homebrew formula (head + dependencies + test)
- OpenBSD port skeleton exists under `packaging/openbsd/`
- `install.sh` documents/detects all five OS families
- `omni-secret` selects secret-tool, macOS security, pass, or file backend
- README documents install commands per OS
- Feature branch pushed; PR opened against `main` (AGENTS.md)

**Constraints:** GPLv3; POSIX `/bin/sh` (OpenBSD has no bash in base); no GNU-only `install -D` / `readlink -f`; Neovim 0.9.5+; tmux 3.2+; do not clobber `~/.config/nvim`.

**Assumptions:** Users provide `tmux`, `nvim`, and optionally `agy`/`grok`. First tagged release may come after this PR; Homebrew formula is `head`-only until then.

**Required Environment:** git, make, `dpkg-deb` (this host), `gh` for PR. Optional: rpmbuild, brew, OpenBSD `portcheck`.

**Top Risks:** See RESEARCH.md §5.

---

## Phase 0 — Environment & Isolation Setup

### Milestone 0.1: Worktree
- **Task 1 of Milestone 0.1:** From clean main, `git worktree add -b gb/packaging-multi-os ../gb-packaging-multi-os-wt` and `cd` into it.
- **Verification:** `pwd` is `/opt/repo/gb-packaging-multi-os-wt`; branch `gb/packaging-multi-os`; status clean.
- **Status:** DONE (this worktree).

---

## Phase 1 — Research & Discovery

### Milestone 1.1: Domain research
- **Task 1 of Milestone 1.1:** Survey Debian Policy, nFPM, Homebrew Formula Cookbook + taps, OpenBSD ports (`NO_BUILD`, `PKG_ARCH=*`), Fedora package names, macOS `security` CLI, local toolchain (`dpkg-deb` present, no rpmbuild/brew).
- **Verification:** Findings captured for synthesis.
- **Status:** DONE.

### Milestone 1.2: Synthesize and freeze remaining plan
- **Task 1 of Milestone 1.2:** Write `RESEARCH.md` and this updated `PLAN.md`. Commit.
- **Verification:** Files exist; commit `Milestone 1.2: …`.

---

## Phase 2 — Define / Architecture

### Milestone 2.1: Layout and interfaces
- **Task 1 of Milestone 2.1:** Freeze install layout:

```
$(PREFIX)/bin/launch-ai-workspace
$(PREFIX)/bin/omni-exec
$(PREFIX)/bin/omni-secret
$(PREFIX)/bin/tmux-toggle-scratch
$(PREFIX)/share/omni-term-ai/lib/omni.sh
$(PREFIX)/share/omni-term-ai/tmux.conf
$(PREFIX)/share/omni-term-ai/nvim-config/
$(PREFIX)/share/applications/ai-workspace.desktop   # Linux
$(PREFIX)/share/icons/hicolor/scalable/apps/ai-workspace.svg
$(PREFIX)/share/man/man1/launch-ai-workspace.1
$(PREFIX)/share/doc/omni-term-ai/{README.md,LICENSE}
```

- Scripts resolve share dir from `$0` (follow symlinks) or `OMNI_TERM_AI_HOME`.
- Neovim: `NVIM_APPNAME=omni-term-ai`; first-run symlink if config missing.
- Tmux: `tmux -L omni-term-ai -f $OMNI_HOME/tmux.conf`.
- Secrets: `omni-secret get|store|backend` with secret-tool / security / pass / file.
- **Verification:** Layout written into Makefile comments and PACKAGING.md.

---

## Phase 3 — Implementation

### Milestone 3.1: Portable runtime (lib + scripts)
- **Task 1 of Milestone 3.1:** Add `lib/omni.sh` (path + nvim appname + secret backends).
- **Task 2 of Milestone 3.1:** Rewrite `launch-ai-workspace`, `omni-exec.sh`, `tmux-toggle-scratch` as POSIX `sh`; add `omni-secret`. Fix desktop Exec/Icon.
- **Verification:** `sh -n` on all scripts; `grep -R '/opt/repo\|/home/chuck' --exclude-dir=.git` empty in runtime files.

### Milestone 3.2: Makefile install
- **Task 1 of Milestone 3.2:** POSIX Makefile: `install`, `uninstall`, `deb`, `rpm`, `dist`.
- **Task 2 of Milestone 3.2:** `packaging/tests/verify-install.sh` against a DESTDIR.
- **Verification:** Test script exits 0.

### Milestone 3.3: Debian/Ubuntu .deb
- **Task 1 of Milestone 3.3:** `packaging/deb/control`, postinst; `make deb`.
- **Verification:** `dpkg-deb -I dist/*.deb` shows Depends including `tmux`, `neovim`, `libsecret-tools`; `Architecture: all`.

### Milestone 3.4: RPM spec
- **Task 1 of Milestone 3.4:** `packaging/rpm/omni-term-ai.spec` and `make rpm`.
- **Verification:** File exists; `make rpm` either builds or prints a skip/error without rpmbuild.

### Milestone 3.5: Homebrew formula
- **Task 1 of Milestone 3.5:** `Formula/omni-term-ai.rb` (head, depends_on, install, caveats, test).
- **Verification:** Ruby class `OmniTermAi`, `depends_on "neovim"`, `depends_on "tmux"`.

### Milestone 3.6: OpenBSD port skeleton
- **Task 1 of Milestone 3.6:** `packaging/openbsd/sysutils/omni-term-ai/{Makefile,pkg/DESCR,pkg/PLIST}`.
- **Verification:** `NO_BUILD=Yes` and `PKG_ARCH=*` present.

### Milestone 3.7: install.sh + CI
- **Task 1 of Milestone 3.7:** `install.sh` detects Debian/Ubuntu, RHEL/Fedora, OpenBSD, Darwin.
- **Task 2 of Milestone 3.7:** `.github/workflows/packages.yml` builds deb; rpm in Fedora container.
- **Verification:** `sh -n install.sh`; workflow YAML parses (`python3 -c 'import yaml'` or `grep jobs:`).

---

## Final Phase — Verification, Polish, Integration & Cleanup

### Milestone 4.1: Docs and full verify
- **Task 1 of Milestone 4.1:** README install sections for all five OS families; `packaging/PACKAGING.md`.
- **Task 2 of Milestone 4.1:** Re-run DESTDIR test, `make deb`, `sh -n`, grep for hardcoded paths.
- **Task 3 of Milestone 4.1:** Commit, push, `gh pr create`. Merge per AGENTS.md when allowed; remove worktree after merge.

**Commit after every Milestone:**
`git add . && git commit -m "Milestone X.Y: <what was achieved>"`
