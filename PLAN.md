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

Empty. All P0 cards are done.

---

## In progress

Empty.

---

## Backlog — bugs

Empty. P1 bugs are done.

---

## Backlog — improvements

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

---

## Done

### IMP-03 — Package metadata matches runtime needs
- **Status:** done
- **Where:** `packaging/deb/control`, `packaging/rpm/omni-term-ai.spec`, `packaging/build-arch.sh`, `install.sh`, `omni-config home`, README bashrc snippet, Homebrew caveats
- **Fix:** curl is a hard dependency on deb, rpm, Arch, FreeBSD, and OpenBSD, and in `install.sh --deps`. python3 and sshfs stay optional (deb Suggests, Arch optdepends, README, caveats). The bashrc snippet is `. "$(omni-config home)/lib/omni-bash.sh"`. Homebrew caveats mention Azure FIM.
- **Verify:** `sh packaging/tests/package-deps.sh`. A `PREFIX=.../usr/local` install prints that share directory, and the README snippet sources the installed `omni-bash.sh`.

### IMP-01 — Tests fail if the bash libs are not installed
- **Status:** done
- **Where:** `packaging/tests/verify-install.sh`, `.github/workflows/packages.yml`
- **Finding:** Config round-trip, empty-secret export, jumpbox quoting, and the first-run sibling check were already in `make test` (BUG-01, BUG-03, BUG-02, BUG-06). The remaining hole was layout: the installed tree was not required to contain `omni-bash.sh`, `deepseek-completion.bash`, or `boot.sh`.
- **Fix:** Those three files must exist after `make install`. The two that are rewritten must not still contain `@OMNI_HOME@`. `sh -n` covers them. `luac -p` covers `omni_fim.lua` and `init.lua` when `luac` is present. CI installs shellcheck and the suite runs it at error severity when the binary is on `PATH`.
- **Verify:** Dropping the `omni-bash.sh` install lines from the Makefile made `verify-install.sh` exit 1 (`missing usr/share/omni-term-ai/lib/omni-bash.sh`). Restored, `make test` passes. shellcheck 0.10.0 `-S error` is clean.

### IMP-06 — Shell integration no longer retargets nvim
- **Status:** done. Two claims were already true and were not "fixed".
- **Where:** `lib/omni-bash.sh`; `nvim-config/init.lua`
- **Finding:** Sourcing `omni-bash.sh` exported `NVIM_APPNAME=omni-term-ai` and linked the packaged config. That is the change. `OMNI_FIM_ENGINE` and `OMNI_FIM_PROVIDER` already load through `omni_load_config` (BUG-01); a quoted `copilot; touch …` stayed data. Neovim 0.12.5 aliases `vim.loop` to `vim.uv` and does not print a deprecation (`runtime/lua/vim/_core/editor.lua`). The source still preferred `vim.uv`, with `vim.loop` kept for the 0.9.5 minimum. `-c "Neotree show"` was not a race: `-c` runs after init and before VimEnter, and lazy loads this start plugin during `setup()`. A private headless run opened the tree (`exists :Neotree` = 2, window count 2) with no `E492`. A command defined only on VimEnter does `E492` under `-c`, so the spec must stay eager. Treesitter tag `v0.9.3` was left alone.
- **Fix:** `OMNI_USE_NVIM_CONFIG=1` is the ask. Otherwise `NVIM_APPNAME` is unchanged and the config is not linked. An already-set `NVIM_APPNAME` is not overwritten.
- **Verify:** `sh packaging/tests/shell-integration.sh` and `sh packaging/tests/nvim-startup.sh`. The first failed on the pre-fix tree (`APPNAME=[omni-term-ai]`). Both pass after the fix, and `make test` runs them.

### IMP-02 — Apt and rpm repos are signed
- **Status:** done (#63; CI fix #64)
- **Where:** `packaging/build-repo.sh` (new), `packaging/repo-signing-key.asc` (new), `packages.yml` `repo-sign` / `pages-repo` / `verify-pages`, README install blocks
- **Fix:** Dedicated key `B395A97972B309A3E4CED62AB1C4CFC685A8F91B` (RSA 4096, sign-only, expires 2029-10-12). Private half is GitHub secret `REPO_SIGNING_KEY` and Vault `pass/ae/util/omni-term-ai-repo-signing`. `build-repo.sh` writes `InRelease`, `Release.gpg`, signed rpms, and `repomd.xml.asc`, and publishes the public key as `omni-term-ai.gpg` / `omni-term-ai.asc`. README uses `signed-by`, `gpgcheck=1`, `repo_gpgcheck=1`, and shows the fingerprint. `workflow_dispatch` with `republish` re-signs the current gh-pages without rebuilding it. The gh-pages guard now runs `ls-remote` inside a checkout and treats only exit 2 as a first publish.
- **Verify:** `packaging/tests/repo-signing.sh` (static, in `make test`). CI `repo-sign` builds and signs with a throwaway key, then `repo-client.sh` runs apt (`--error-on=any`, wrong key refused) and dnf (`gpgcheck`, `repo_gpgcheck`, `rpm -K`). Republish run 38393520651 signed gh-pages with `B395…F91B`; `verify-pages` passed against `https://coldcanuk.github.io/omni-term-ai`: apt `signed-by` update with `--error-on=any`, wrong key refused, dnf `repo_gpgcheck` + `gpgcheck`, `rpm -K` `signatures OK` for both rpms. `gpgv` on the live `InRelease` and `repomd.xml.asc` reports Good signature from this host.

### BUG-12 — Cleanup uses this clone
- **Status:** done
- **Where:** `AGENTS.md` rule 5
- **Fix:** Cleanup starts at the main worktree from `git worktree list`, not `/opt/repo`.
- **Verify:** `packaging/tests/agents-path.sh` and the documented `cd` lands in `/usr/local/src/omni-term-ai`.

### BUG-10 — Man pages match the CLI
- **Status:** done
- **Where:** `Makefile`, `man/*.1`
- **Fix:** Uninstall removes every shipped man page. Pages document jumpbox, fim, and Azure. `omni-secret.1` and `omni-exec.1` exist.
- **Verify:** `packaging/tests/man-pages.sh`

### BUG-11 — `--deps` covers Arch, Omarchy, and FreeBSD
- **Status:** done
- **Verify:** `packaging/tests/deps-arch.sh`

### BUG-13 — A failed gh-pages checkout does not publish
- **Status:** done
- **Verify:** `packaging/tests/gh-pages-guard.sh`

### BUG-09 — Stale FIM responses are ignored
- **Status:** done
- **Where:** `nvim-config/lua/omni_fim.lua`
- **Fix:** Each request has a stamp. Older callbacks do not paint. `on_exit` removes the payload. A multi-line accept parks the cursor at the end of the last inserted line.
- **Verify:** `packaging/tests/fim-stale.sh`

### BUG-08 — Bash FIM inserts the picked choice
- **Status:** done
- **Where:** `lib/omni-bash.sh`, `lib/deepseek-completion.bash`
- **Fix:** Bind when the configured provider has a key. Missing `python3` warns and returns. A numbered pick is written into `READLINE_LINE` without `eval`.
- **Verify:** `packaging/tests/bash-fim.sh`

### BUG-07 — FIM provider is explicit
- **Status:** done
- **Where:** `OMNI_FIM_PROVIDER` (`deepseek|openai|azure`, default `deepseek`); `nvim-config/lua/omni_fim.lua`; `lib/deepseek-completion.bash`
- **Verify:** `sh packaging/tests/fim-provider.sh` and `make test` passed. With both keys set, provider `deepseek` uses the DeepSeek beta URL and provider `openai` does not.

### BUG-06 — First run calls the sibling omni-config
- **Status:** done
- **Where:** `launch-ai-workspace` (`bindir` resolved before the first-run check)
- **Verify:** `python3 packaging/tests/first-run.py` and `make test` passed. With `PATH=/usr/bin:/bin` and no config, both the source tree and a `make install` DESTDIR launcher run the sibling `omni-config`, even when a decoy `omni-config` is first on PATH. A launcher with no sibling falls back to PATH; with none anywhere it says `cannot find omni-config` instead of `command not found`. The test fails on the pre-fix tree (exit 127). End-to-end: the real wizard ran from a staged install with `PATH=/usr/bin:/bin` and wrote the config.

### BUG-05 — Scratchpad and panic button: not a bug
- **Status:** closed, not reproduced. No code change.
- **Where:** `tmux.conf` `bind Space` / `bind E`; `tmux-toggle-scratch`
- **Finding:** The audit premise was wrong. `run-shell` jobs get `TMUX=<server socket>,<pid>,<session>` from tmux (`environ_for_session` in `job.c`, tmux 3.2+), so a bare `tmux` inside them talks to the `omni-term-ai` server. `display-popup -E` gets the same environment. `README.md` and `packaging/deb/control` already require tmux 3.2.
- **Verify:** `python3 packaging/tests/tmux-bindings.py` passed on tmux 3.7c. It attaches a real client to the omni socket, runs a decoy default server, and presses Prefix-E and Prefix-Space. Editor is recreated and the scratch popup opens and closes on the omni socket only. The decoy is untouched. With a `tmux` wrapper that drops `TMUX` (the audit's claim), the test fails and the decoy gains an Editor window, so the test detects the bug if it ever regresses. Wired into `make test`.

### BUG-04 — Azure FIM reaches the tmux session
- **Status:** done
- **Where:** `lib/omni.sh` `omni_publish_tmux_secrets`, `omni_apply_azure_config`; `omni-config` `azure-endpoint` / `azure-deployment`
- **Verify:** `sh packaging/tests/azure-env.sh` and `make test` passed. Config endpoint and deployment round-trip, including a `;` that does not run. Publish sets `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, and `AZURE_OPENAI_DEPLOYMENT`. A missing secret is `set-environment -g -u`, not an empty value. An empty config does not clobber an ambient endpoint.

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
- **Evidence:** Tree `/usr/local/src/omni-term-ai`, `main` == `origin/main` at `e5d2ea5`, VERSION `0.2.5`. Lua parses (`luac -p`). Reproduced config execution and sed `&` corruption. Confirmed Azure omission, PATH order, wrong tmux socket, and gh-pages `continue-on-error` by reading the files. The tmux socket finding was later disproved by test (BUG-05). The "bash file never loads `OMNI_FIM_ENGINE`" and "Neotree `-c` races" claims were later disproved (IMP-06). `vim.loop` is the old name, but 0.12.5 does not print a warning for it.
- **Not bugs:** `die()` waiting for Enter is intentional (`b02b79e`, desktop error visibility). Neovim 0.12.5 loaded `init.lua` headless; treesitter `v0.9.3` did not crash that load.

### PLAN-0.2.0 — Multi-harness, DeepSeek FIM, brew trust
- **Status:** done, shipped through 0.2.5. Do not re-implement. Corrections to what that plan became are the cards above.

---

## Pull order

1. BUG-01 done. BUG-03 done.
2. BUG-06 done.
3. BUG-04 done.
4. BUG-02 done. BUG-05 closed: not reproduced (regression test added)
5. BUG-07 and BUG-08 together (one provider model)
6. BUG-09, BUG-10, BUG-11, BUG-13
7. Improvements, IMP-01 first so later cards have a test to land in

## Definition of done for 0.3.0

- Every Ready card is in Done with its verify line observed, not assumed.
- `make test` passes, including the new behavior checks.
- CHANGELOG and VERSION say 0.3.0.
- PR against `main` per `AGENTS.md`. No direct commit to `main`.
