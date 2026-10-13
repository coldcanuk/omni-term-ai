# Omni Term AI — Audit remediation (0.3.0)

Supersedes the 0.2.0 multi-harness plan. That work shipped (VERSION `0.2.5`, `main` at `e5d2ea5`). This plan is the correction list from an audit of `/usr/local/src/omni-term-ai` on 2026-10-13. Visual board: `kanban.html`.

**Target:** 0.3.0. Do not bump VERSION until the Ready column is done and `make test` passes.

**Method:** one card at a time, on this branch (`gb/audit-kanban`), worktree `.worktrees/gb-audit-kanban-wt`. No commits to `main`. WIP limit: 1.

**Non-goals:** new harnesses, new FIM vendors beyond the three already claimed, rewriting the tmux layout.

## How to read the board

| Column | Meaning |
| --- | --- |
| Ready | Pull next. Ordered. These are broken or unsafe on the current tree. |
| In progress | The one card being fixed. Empty until pulled. |
| Backlog | Confirmed bugs and improvements not yet pulled. |
| Done | Audit recorded. 0.2.0 plan closed. Cards move here only after the verification line passes. |

---

## Ready

### BUG-04 — Azure FIM key never reaches the tmux session
- **Kind:** bug, P0
- **Where:** `launch-ai-workspace` `omni_apply_tmux_env` (stops at `GEMINI_API_KEY`); README claims `AZURE_OPENAI_API_KEY`
- **Evidence:** `omni_export_harness_keys` exports `AZURE_OPENAI_API_KEY`, but the launcher never `set-environment`s it. Endpoint and deployment are documented as bashrc exports, which a desktop `Terminal=true` launch often does not source. Neovim inside the session therefore cannot do Azure FIM.
- **Fix:** Inject `AZURE_OPENAI_API_KEY` with the other keys (non-empty only, per BUG-03). Store endpoint and deployment in the config file (they are not secrets) and inject those too, so desktop launch does not depend on bashrc.
- **Verify:** After `omni-secret store azure` plus config endpoint/deployment, `tmux show-environment -g` inside the session lists all three. Unset secret does not plant an empty key.

### BUG-05 — Scratchpad and panic button talk to the wrong tmux server
- **Kind:** bug, P0
- **Where:** `tmux.conf` `bind Space` / `bind E`; `tmux-toggle-scratch`
- **Evidence:** Both invoke the `tmux` binary. `run-shell` does not set `TMUX`, and neither command passes `-L omni-term-ai`. The workspace server is socket `omni-term-ai`. Prefix-Space and Prefix-E hit the default server or fail.
- **Fix:** Use tmux command lists on the current server (`bind E kill-window ... \; new-window ... \; send-keys ...`). Implement the scratchpad with `display-popup` / `if-shell` in `tmux.conf`, or pass `-L omni-term-ai` explicitly. Do not shell out to an unqualified `tmux`.
- **Verify:** With a default tmux server also running, Prefix-Space toggles a popup on the omni socket only, and Prefix-E recreates the Editor window on that socket only.

### BUG-06 — First-run wizard is not on PATH
- **Kind:** bug, P0
- **Where:** `launch-ai-workspace` lines 16–18 call `omni-config`; `PATH` is prepended with the script directory only at lines 64–66
- **Evidence:** Desktop `Exec` is the absolute launcher path. A user-prefix install (`~/.local/bin` not on the desktop PATH) cannot find `omni-config`. Same for `./launch-ai-workspace` from a source tree.
- **Fix:** Resolve `bindir` first. Invoke `"$bindir/omni-config"`.
- **Verify:** `PATH=/usr/bin:/bin ./launch-ai-workspace` with no config file runs the sibling `omni-config`, not a PATH lookup.

---

## In progress

Empty. Pull BUG-06 next.

---

## Backlog — bugs

### BUG-07 — Stored OpenAI key silently replaces DeepSeek FIM
- **Kind:** bug, P1
- **Where:** `nvim-config/lua/omni_fim.lua` (Azure, then OpenAI, then DeepSeek); `lib/deepseek-completion.bash` (same order)
- **Evidence:** `omni_export_harness_keys` always exports every stored key. Codex users who also stored `openai` never hit DeepSeek, and `OMNI_FIM_ENGINE` has no provider field (`native|copilot|none` only).
- **Fix:** Add `OMNI_FIM_PROVIDER=deepseek|openai|azure` (default `deepseek`). Native FIM calls only that provider. Do not infer the vendor from which keys happen to be set.
- **Verify:** Both OpenAI and DeepSeek keys set, provider `deepseek`: request URL is the DeepSeek beta completions endpoint. Provider `openai` does not call DeepSeek.

### BUG-08 — Bash FIM completion does not complete
- **Kind:** bug, P1
- **Where:** `lib/omni-bash.sh`, `lib/deepseek-completion.bash`, README "FIM Bash Completion"
- **Evidence:** The snippet is sourced only when `DEEPSEEK_API_KEY` is non-empty, so OpenAI-only and Azure-only users get no binding. The Python asks for `n=3` and, when more than one choice comes back, only `echo`s them; nothing is inserted and there is no picker. `python3` is an undeclared dependency. Model text is `eval`'d.
- **Fix:** Bind when any configured provider key is present. Check `python3` and no-op with a one-line warning if missing. Either request `n=1` or present a numbered pick and insert that choice. Assign `READLINE_LINE` / `READLINE_POINT` without `eval` of model text.
- **Verify:** OpenAI-only key still binds Ctrl-F. Two choices can be selected and land in the line. Missing `python3` does not abort the shell.

### BUG-09 — FIM can show a stale completion and leak the payload
- **Kind:** bug, P1
- **Where:** `nvim-config/lua/omni_fim.lua`
- **Evidence:** `on_stdout` applies whatever curl returns; there is no generation counter, so a slow response for an old prefix can paint ghost text after the user has typed more. `vim.fn.tempname()` is never deleted. Multiline accept sets the cursor to `col + #last` on the last line; after `nvim_buf_set_text`, later lines start at column 0.
- **Fix:** Stamp each request. Ignore callbacks whose stamp is not current. `os.remove` the payload in `on_exit`. For a multi-line insert, park the cursor at `#last` on the last inserted line (0-based).
- **Verify:** Overlapping mocked responses: only the latest prefix is shown. No payload file left in temp. A two-line accept leaves the cursor at the end of line 2, not `col` bytes past it.

### BUG-10 — Uninstall and man pages drift from the CLI
- **Kind:** bug, P1
- **Where:** `Makefile` `uninstall` (removes `launch-ai-workspace.1`, not `omni-config.1`); `man/omni-config.1`; `man/launch-ai-workspace.1`
- **Evidence:** `omni-config` supports `jumpbox` and `fim`. Neither man page says so. Both SEE ALSO `omni-secret(1)` and `omni-exec(1)`, which do not exist. `make uninstall` leaves `omni-config.1` installed.
- **Fix:** Remove `omni-config.1` on uninstall. Document jumpbox, fim, and azure in the existing pages. Add `omni-secret.1` and `omni-exec.1`, or drop the dangling SEE ALSO.
- **Verify:** `DESTDIR` install then uninstall leaves no `man1/omni-*` or `man1/launch-ai-workspace.1`. `man -l` text mentions jumpbox and fim.

### BUG-11 — `install.sh --deps` ignores Arch, Omarchy, and FreeBSD
- **Kind:** bug, P1
- **Where:** `install.sh` `install_deps` (Debian, Fedora, OpenBSD, Darwin only)
- **Evidence:** Arch's `ID=arch` with empty `ID_LIKE` falls through to "Unknown Linux" and exits 1. README tells Omarchy users this project is a supported install path. This host is Omarchy.
- **Fix:** `pacman -S --needed` for arch/omarchy/manjaro. `pkg install` for FreeBSD. Keep the unknown-distro error for everything else.
- **Verify:** A dry-run or `ID=arch` case selects pacman and does not exit 1 before the package command.

### BUG-12 — Agent cleanup path does not exist
- **Kind:** bug, P1
- **Where:** `AGENTS.md` rule 5 (`cd /opt/repo/omni-term-ai`); rule 2 uses `.worktrees/`
- **Evidence:** This tree is `/usr/local/src/omni-term-ai`. Rule 5 and rule 2 disagree. An agent that follows rule 5 cannot clean up.
- **Fix:** Cleanup from `git rev-parse --show-toplevel`, then `git worktree remove .worktrees/gb-<feature>-wt`. Delete the `/opt/repo` line.
- **Verify:** The documented commands succeed in this clone.

### BUG-13 — A failed gh-pages checkout can wipe the package repo
- **Kind:** bug, P1
- **Where:** `.github/workflows/packages.yml` `pages-repo`
- **Evidence:** Checkout of `gh-pages` is `continue-on-error: true`. Deploy uses `peaceiris/actions-gh-pages` with `keep_files: false` and `publish_dir: ./repo`. If checkout fails, the job still publishes a directory that contains only the newly downloaded deb/rpm.
- **Fix:** Fail the job if the checkout fails, unless the branch truly does not exist yet (first publish). Never publish an empty tree over an existing repo. `keep_files: false` is fine only after a successful checkout of the current site.
- **Verify:** Workflow YAML no longer continues past a failed checkout. A review of the job shows the publish step is skipped or failed when `repo/` is not a real gh-pages tree.

---

## Backlog — improvements

### IMP-01 — Tests check layout, not behavior
- **Kind:** improvement, P1
- **Where:** `packaging/tests/verify-install.sh`, `.github/workflows/packages.yml`
- **Evidence:** `make test` checks that files exist and `sh -n`s a subset of scripts. It does not mention `lib/omni-bash.sh`, `lib/deepseek-completion.bash`, or `lib/boot.sh`. No shellcheck on this host. No test covers config round-trip, empty-secret export, or the jumpbox argument quoting.
- **Fix:** Extend the smoke test to assert those three libs are installed. Add a POSIX test script for BUG-01, BUG-03, and BUG-06 that does not need a live tmux server. Run `shellcheck -s sh` in CI when the runner has it. `nvim --headless` load of `omni_fim` stays a non-network check (`luac -p` already passes).
- **Verify:** `make test` fails if `omni-bash.sh` is dropped from the Makefile. The new script fails on the pre-fix tree and passes after BUG-01 and BUG-03.

### IMP-02 — Apt and rpm repos are unsigned
- **Kind:** improvement, P2
- **Where:** README install blocks (`trusted=yes`, `gpgcheck=0`); `packages.yml` Release generation
- **Fix:** Sign the Release file and the rpm repo. Document the key fingerprint. Remove `trusted=yes` and `gpgcheck=0` once a key is published. Until then, label the current instructions as unverified.
- **Verify:** A clean apt source entry without `trusted=yes` updates against the published repo.

### IMP-03 — Package metadata does not match runtime needs
- **Kind:** improvement, P2
- **Where:** `packaging/deb/control` (no `curl`), `packaging/build-arch.sh` PKGBUILD (`depends` is only neovim, tmux, git, ripgrep), `Formula/omni-term-ai.rb` caveats (no azure), README bashrc path
- **Evidence:** FIM needs `curl`. Bash completion needs `python3`. Jumpbox needs `sshfs` and a remote `launch-ai-workspace`. README tells users to source `$HOME/.local/share/omni-term-ai/lib/omni-bash.sh`; `make install` defaults to `PREFIX=/usr/local`.
- **Fix:** Align Depends/depends with curl at minimum. Document python3 and sshfs as optional features, not silent requirements. Point the bashrc snippet at the installed datadir (`omni-config` can print it) instead of a hard-coded `~/.local` path. Mention azure in the Homebrew caveats.
- **Verify:** deb control and PKGBUILD both list curl. README snippet works for a `/usr/local` install.

### IMP-04 — Secrets are visible to `ps` and easy to collide
- **Kind:** improvement, P2
- **Where:** `lib/omni.sh` `security add-generic-password -w`; `omni_fim.lua` curl `-H` with the key; `secret-tool store/lookup api <name>`
- **Fix:** Pass the macOS password and the curl auth header via a 0600 file or curl config, not argv. Namespace secret-tool attributes (`service omni-term-ai`) and migrate old items on read so existing keys still resolve.
- **Verify:** `ps` during an FIM request and during `omni-secret store` does not show the key. A lookup still finds a key stored before the attribute change.

### IMP-05 — Docs and changelog lag the tree
- **Kind:** improvement, P2
- **Where:** `CHANGELOG.md`, `README.md`, `Formula/omni-term-ai.rb`
- **Evidence:** 0.2.5 notes the symlink crash only. Jumpbox, Azure/OpenAI FIM, bash completion, and the desktop jumpbox default are in the tree and not in the changelog. This plan replaces the stale 0.2.0 `PLAN.md`.
- **Fix:** When 0.3.0 ships, changelog the fixes above. Do not rewrite history of 0.2.x beyond a one-line "undocumented features now covered by 0.3.0".
- **Verify:** CHANGELOG 0.3.0 lists every Ready card that merged.

### IMP-06 — Editor startup and shell integration are broader than they look
- **Kind:** improvement, P2
- **Where:** `nvim-config/init.lua` (`vim.loop`, treesitter tag `v0.9.3`, `nvim -c "Neotree show"`); `lib/omni-bash.sh`
- **Evidence:** This host runs Neovim 0.12.5. Headless load of `init.lua` succeeded (plugins cloned, `fim_engine=unset` printed) so the pin is not a crash today. `vim.loop` is the old name. `omni-bash.sh` sets `NVIM_APPNAME` for every nvim in the shell and does not load `OMNI_FIM_ENGINE` from the config file. `-c Neotree` was not proven; it can run before the command exists.
- **Fix:** Prefer `vim.uv` with a `vim.loop` fallback. Load `OMNI_FIM_ENGINE` (and provider, once BUG-07 exists) in `omni-bash.sh` via the same parser as BUG-01. Make `NVIM_APPNAME` opt-in. Open Neotree from a `VimEnter` autocmd after lazy has defined the command, and drop the racing `-c`.
- **Verify:** `nvim --headless` on 0.12 prints no `vim.loop` deprecation. A shell that sourced `omni-bash.sh` does not change `NVIM_APPNAME` unless asked. Editor window shows the tree without `E492`.

---

## Done

### BUG-03 — Empty secrets no longer clobber tokens
- **Status:** done
- **Where:** `lib/omni.sh` `omni_assign_secret`, `omni_publish_tmux_secrets`; `launch-ai-workspace` `omni_apply_tmux_env`
- **Verify:** `sh packaging/tests/empty-secrets.sh` and `make test` passed. Missing github secret leaves `GH_TOKEN=from-keyring` through `omni-exec`. A stored secret still replaces it. An already-empty variable is unset. tmux gets `set-environment -g GH_TOKEN from-keyring`, never an empty value.

### BUG-02 — Jumpbox no longer mounts itself
- **Status:** done
- **Where:** `launch-ai-workspace`, `lib/omni.sh` `omni_jumpbox_target_script`
- **Verify:** `sh packaging/tests/jumpbox-args.sh` and `make test` passed. No-arg launch with a jumpbox set SSHes `OMNI_SKIP_JUMPBOX=1 exec launch-ai-workspace` and does not sshfs the jumpbox hostname. `@prod` sshfses only the quoted target. A target containing `; touch` is one quoted assignment and does not run. A failing `sshfs` exits non-zero.

### BUG-01 — Config is parsed, not sourced
- **Status:** done
- **Where:** `lib/omni.sh` (`omni_load_config`, `omni_config_quote`, `omni_config_parse_value`, `omni_config_update`); `omni-config` writer; `man/omni-config.1` no longer says the file is sourced
- **Verify:** `sh packaging/tests/config-roundtrip.sh` and `make test` passed. Values with `;`, backticks, `$()`, `&`, `|`, quotes, spaces, and `\` round-trip. A hand-written `OMNI_JUMPBOX=...; touch` and `$(touch)` do not create the sentinel. Newlines are rejected. Legacy unquoted files still load.

### AUDIT-00 — Audit of 0.2.5
- **Status:** done
- **Evidence:** Tree `/usr/local/src/omni-term-ai`, `main` == `origin/main` at `e5d2ea5`, VERSION `0.2.5`. Lua parses (`luac -p`). Reproduced config execution and sed `&` corruption. Confirmed Azure omission, PATH order, wrong tmux socket, and gh-pages `continue-on-error` by reading the files.
- **Not bugs:** `die()` waiting for Enter is intentional (`b02b79e`, desktop error visibility). Neovim 0.12.5 loaded `init.lua` headless; treesitter `v0.9.3` did not crash that load.

### PLAN-0.2.0 — Multi-harness, DeepSeek FIM, brew trust
- **Status:** done, shipped through 0.2.5. Do not re-implement. Corrections to what that plan became are the cards above.

---

## Pull order

1. BUG-01 done. BUG-03 done. Next: BUG-06
2. BUG-06 (tiny, unblocks first-run testing)
3. BUG-04 (depends on the non-empty export rule)
4. BUG-02 done. Then BUG-05
5. BUG-07 and BUG-08 together (one provider model)
6. BUG-09, BUG-10, BUG-11, BUG-13
7. Improvements, IMP-01 first so later cards have a test to land in

## Definition of done for 0.3.0

- Every Ready card is in Done with its verify line observed, not assumed.
- `make test` passes, including the new behavior checks.
- CHANGELOG and VERSION say 0.3.0.
- PR against `main` per `AGENTS.md`. No direct commit to `main`.
