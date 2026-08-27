# Omni Term AI — Multi-Harness Shell Assistants + DeepSeek FIM + Brew Trust (RDAP)

## 2. Scope of Work

**Primary Goal:** Make the Command Center's two AI panes (top-left / top-right) configurable by the end user across a registry of shell AI assistants ("harnesses") — `grok`, `agy`, `copilot`, `claude code`, `codex`, and the DeepSeek harness (`dsh`) — with the DeepSeek API key powering Fill-In-The-Middle (FIM) code completion in the Neovim Editor, and with macOS Homebrew install instructions updated for the mandatory `brew trust` step.

**Non-Goals:**
- Bundling or installing the harness binaries themselves (users install their chosen assistants; we detect and guide)
- Chat/agent features inside Neovim beyond FIM completion (no nvim-copilot, no avante)
- FIM providers other than DeepSeek (architecture leaves room, but only DeepSeek ships in this milestone)
- Windows support
- Changing the tmux/Neovim defaults already shipped in v0.1.0 other than pane titles and the config-driven harness panes

**Success Criteria / Definition of Done:**
- `omni-config` CLI exists: `list` (supported + installed harnesses with install hints), `get`, `set left|right <harness>`, and an interactive wizard when run bare
- Config file `~/.config/omni-term-ai/config` (`OMNI_LEFT_HARNESS` / `OMNI_RIGHT_HARNESS`) defaults to `agy` / `grok` (today's hardcoded behavior) and is honored by `launch-ai-workspace`
- `launch-ai-workspace` validates both harnesses, prints a clear per-harness install hint when a binary is missing, and exits non-zero; pane borders show the harness names (tmux ≥ 3.2 `select-pane -T`)
- Harness auth env vars are injected into the tmux session and by `omni-exec` (grok→`XAI_API_KEY`, agy→`GEMINI_API_KEY`, copilot→`GH_TOKEN`/`GITHUB_TOKEN`, claude→`ANTHROPIC_API_KEY`, codex→`OPENAI_API_KEY`, deepseek→`DEEPSEEK_API_KEY`)
- `omni-secret` accepts `xai deepseek anthropic openai github gemini`
- Neovim shows DeepSeek FIM ghost-text completions (`https://api.deepseek.com/beta/completions`, model `deepseek-v4-pro`, `prompt` + `suffix`) when `DEEPSEEK_API_KEY` is present, with `<Tab>` accept and `<C-e>` dismiss
- README documents: harness table (install + auth + launch), `omni-config` usage, DeepSeek FIM, and the macOS `brew trust coldcanuk/omni-term-ai` step (Homebrew ≥ 6.0.0 requirement)
- `man/launch-ai-workspace.1` updated; new `man/omni-config.1`
- `make test` (verify-install.sh) passes with `omni-config` in the staged tree; `sh -n` clean on all scripts; VERSION bumped to 0.2.0; CHANGELOG updated
- Feature branch pushed, PR opened and merged per AGENTS.md, worktree removed, `main` clean

**Constraints:** GPLv3; POSIX `/bin/sh` (OpenBSD base has no bash); tmux ≥ 3.2 (repo minimum; `select-pane -T` needs 3.2+); Neovim ≥ 0.9.5 with lazy.nvim; no new required system packages (FIM uses `curl`, already a runtime peer for lazy.nvim/telescope); do not clobber `~/.config/nvim`; no hardcoded `/opt/repo` paths in installed files.

**Assumptions:** Users install their chosen harnesses themselves; DeepSeek FIM endpoint `https://api.deepseek.com/beta/completions` stays OpenAI-compatible with `prompt`/`suffix` (verified 2026-08-27); `dsh` (DeepSeek Harness) runs as `dsh web --no-open` in a pane; Homebrew ≥ 6.0.0 requires explicit tap trust (verified 2026-08-27, Homebrew 6.0.20 current).

**Required Environment:** git, make, `sh`, `curl` (verification), `tmux` ≥ 3.2 for local run test (this host has 3.4), `gh` for the PR. No API keys needed for build/test (FIM gracefully no-ops without `DEEPSEEK_API_KEY`).

**Top Risks:**
| Risk | Mitigation |
| --- | --- |
| DeepSeek FIM model/endpoint drift | Model + endpoint are config (`omni_fim` setup opts); RESEARCH.md pins the 2026-08-27 verified shape |
| Homebrew trust wording wrong for older Homebrew | Document Homebrew ≥ 6.0.0 trust step plus pre-6.0 fallback (`brew install --HEAD --formula ./Formula/omni-term-ai.rb`) |
| Harness binary names collide (e.g. `codex` also ships with OpenAI SDK) | `omni_harness_installed` uses `command -v`; install hints show canonical sources |
| `agy` auth is Google-only (no API key in pane) | `agy` env var optional (`GEMINI_API_KEY`); docs state browser sign-in is primary |
| Config file syntax errors break launch | Sourcing guarded; fall back to defaults with a warning |

---

## Phase 0 — Environment & Isolation Setup

### Milestone 0.1: Worktree
- **Task 1 of Milestone 0.1:** Worktree exists: `/opt/repo/gb-multi-harness-ai-wt` on branch `gb/multi-harness-ai` (created earlier, at `main`).
- **Verification:** `cd /opt/repo/gb-multi-harness-ai-wt && git status` clean; branch name matches.
- **Status:** DONE.

---

## Phase 1 — Research & Discovery

### Milestone 1.1: Domain research
- **Task 1 of Milestone 1.1:** Verify each harness CLI (install, launch, auth env): grok (xAI Grok Build), agy (Google Antigravity), copilot (github/copilot-cli), claude code (`@anthropic-ai/claude-code`), codex (`@openai/codex`), deepseek (`dsh`, DeepSeek Harness). Verify DeepSeek FIM endpoint shape. Verify Homebrew `brew trust` (Tap-Trust, Homebrew 6.0.0+). Verify tmux `select-pane -T` (3.2+).
- **Verification:** All claims cross-checked against official docs / npm registry / GitHub (2026-08-27). See RESEARCH.md §7.
- **Status:** DONE.

### Milestone 1.2: Synthesize and freeze remaining plan
- **Task 1 of Milestone 1.2:** Write RESEARCH.md §7 and this updated PLAN.md. Commit.
- **Verification:** Files exist; commit `Milestone 1.2: ...`.

---

## Phase 2 — Define / Architecture

### Milestone 2.1: Interfaces and data model
- **Task 1 of Milestone 2.1:** Freeze harness registry in `lib/omni.sh`: names `grok agy copilot claude codex deepseek`; per-harness binary, launch command, auth env var(s), install hint.
- **Task 2 of Milestone 2.1:** Freeze config format: `$XDG_CONFIG_HOME/omni-term-ai/config` (POSIX sh, sourced) with `OMNI_LEFT_HARNESS` / `OMNI_RIGHT_HARNESS`; defaults `agy`/`grok`.
- **Task 3 of Milestone 2.1:** Freeze secret names: `xai deepseek anthropic openai github gemini` mapped to `XAI_API_KEY DEEPSEEK_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY GH_TOKEN/GITHUB_TOKEN GEMINI_API_KEY`.
- **Task 4 of Milestone 2.1:** Freeze FIM design: `nvim-config/lua/omni_fim.lua` — debounced ghost-text completion via `curl` → `https://api.deepseek.com/beta/completions` (`model=deepseek-v4-pro`, `prompt`=text before cursor, `suffix`=text after cursor, `max_tokens=128`, `temperature=0`), no-op without `DEEPSEEK_API_KEY`.
- **Verification:** Decisions recorded here; no code yet.

---

## Phase 3 — Implementation

### Milestone 3.1: lib/omni.sh harness registry + config
- **Task 1 of Milestone 3.1:** Add `omni_config_path`, `omni_load_config` (defaults + guarded source), `omni_config_get`, `omni_validate_harness`.
- **Task 2 of Milestone 3.1:** Add `omni_harness_list`, `omni_harness_bin`, `omni_harness_cmd`, `omni_harness_env`, `omni_harness_install_hint`, `omni_harness_installed`, `omni_harness_name` (claude→"claude code" display).
- **Verification:** `sh -n lib/omni.sh`; `omni_harness_list` prints 6 names.

### Milestone 3.2: omni-config CLI
- **Task 1 of Milestone 3.2:** New `omni-config` script: `list`, `get [left|right]`, `set <left|right> <harness>` (validates), `path`, bare = interactive wizard (numbered menu, POSIX `read`).
- **Verification:** `omni-config list` shows installed status + hints; `set left codex` writes config; `set left bogus` errors.

### Milestone 3.3: omni-secret + omni-exec multi-key
- **Task 1 of Milestone 3.3:** Extend `omni-secret` `valid_name` to `xai deepseek anthropic openai github gemini`.
- **Task 2 of Milestone 3.3:** `omni-exec` exports all six harness env vars (from secrets; empty when unset).
- **Verification:** `omni-exec env | grep -E 'XAI_API_KEY|DEEPSEEK_API_KEY|ANTHROPIC|OPENAI|GH_TOKEN|GEMINI'` shows keys set from keychain.

### Milestone 3.4: launch-ai-workspace config-driven panes
- **Task 1 of Milestone 3.4:** Load config; validate left/right harnesses; error+install hint and exit 1 if a binary is missing.
- **Task 2 of Milestone 3.4:** Send harness launch commands to panes `.0`/`.1`; set pane titles (`select-pane -T`); enable `pane-border-status top` in tmux.conf.
- **Task 3 of Milestone 3.4:** `omni_apply_tmux_env` also sets harness env vars in tmux global env (from secrets).
- **Verification:** With config `left=codex right=claude`, session panes run `codex` / `claude`; pane titles visible; missing-binary case prints hint and exits 1.

### Milestone 3.5: DeepSeek FIM in Neovim
- **Task 1 of Milestone 3.5:** `nvim-config/lua/omni_fim.lua`: debounced insert-mode ghost text via extmark; `curl` to DeepSeek beta completions; `<Tab>` accept, `<C-e>` dismiss; no-op without key; highlight group.
- **Task 2 of Milestone 3.5:** Wire `require('omni_fim').setup({})` into `nvim-config/init.lua`.
- **Verification:** `nvim --headless -u NVIM_APPNAME...` loads without error; with `DEEPSEEK_API_KEY` set and network, ghost text appears (manual; CI only checks load).

### Milestone 3.6: Packaging + tests
- **Task 1 of Milestone 3.6:** Makefile installs `omni-config` + `man/omni-config.1`; `verify-install.sh` checks both; `sh -n` list includes `omni-config`.
- **Task 2 of Milestone 3.6:** Formula caveats: `brew trust` + key stores; deb/rpm descriptions mention configurable harnesses.
- **Verification:** `make test` passes; `make DESTDIR=/tmp/... PREFIX=/usr install` includes `bin/omni-config`.

---

## Phase 4 — Documentation

### Milestone 4.1: README
- **Task 1 of Milestone 4.1:** README: harness table (install, auth, launch), `omni-config` usage, DeepSeek FIM section, macOS `brew trust` section (Homebrew ≥ 6.0.0) with the exact command sequence and pre-6.0 fallback, requirements spelled out.
- **Verification:** All 6 harnesses + trust + FIM documented; commands copy-pasteable.

### Milestone 4.2: Man pages + desktop + version
- **Task 1 of Milestone 4.2:** Update `man/launch-ai-workspace.1` (config file, harness panes); add `man/omni-config.1`.
- **Task 2 of Milestone 4.2:** Update `ai-workspace.desktop` comment/keywords; CHANGELOG 0.2.0; VERSION 0.2.0.
- **Verification:** `man` renders; grep finds no stale "Launch Grok and Agy" text.

---

## Final Phase — Verification, Polish, Integration & Cleanup

### Milestone 5.1: Full verify + merge
- **Task 1 of Milestone 5.1:** `sh -n` all scripts; `make test`; DESTDIR install test; grep staged tree for `/opt/repo` / `/home/chuck`; `omni-config` smoke tests; FIM module loads headless.
- **Task 2 of Milestone 5.1:** `git add . && git commit -m "Complete: multi-harness, DeepSeek FIM, brew trust docs – ready for merge"`; `git push -u origin gb/multi-harness-ai`.
- **Task 3 of Milestone 5.1:** `gh pr create` against `main`; `gh pr merge --merge --delete-branch` per AGENTS.md.
- **Task 4 of Milestone 5.1:** `cd /opt/repo/omni-term-ai && git checkout main && git pull origin main && git worktree remove ../gb-multi-harness-ai-wt`.
- **Verification:** main clean, worktree gone, PR merged.

---

**Commit after every Milestone:**
`git add . && git commit -m "Milestone X.Y: <what was achieved>"`
