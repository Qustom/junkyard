# Worklog — DLV1 itch.io HTML5 delivery via butler

- **Date:** 2026-06-19
- **Subagent:** producer
- **Milestone:** M1.3 (Wave 1, infra)
- **Branch:** worktree-agent-ad2804e13b6c47744 (isolated worktree off main; equivalent to prod/DLV1)
- **Commit:** d1eba0613fe1729ad73dd126c350be60921ce997

## What changed
DLV1 stands up the itch.io HTML5 delivery pipeline (F5) alongside the existing Windows one.
Added a Godot `Web` export preset, a local `tools/push_itch.sh` (stamp → web export → resolve
itch key without printing it → `butler push build/web qusto/the-far-yard:html5`), wired the real
slug + a parallel web export/publish path into `nightly.yml` (ship BOTH Win64 + Web), and
documented the butler + web-template install + the human-only itch prerequisites in `SETUP.md`,
plus a web/Chromium playtest note in `tester_readme.md`. Per the Director disposition, web carries
data via DLV2's in-game export button (a sibling task) — DLV1 itself stays infra.

## Files touched
- `export_presets.cfg` — added `preset.1` "Web" (`platform="Web"`, `export_path="build/web/index.html"`, `variant/thread_support=true`, `progressive_web_app/ensure_cross_origin_isolation_headers=true`, reusing the Win64 `exclude_filter`); rewrote the header note for two presets.
- `tools/push_itch.sh` — new local push script; stamps via `tools/stamp_build.sh`, exports the Web preset headless, resolves `BUTLER_API_KEY` from env-or-`APIKEYS.md` `# Itch.io` section **without echoing it**, requires index.html+wasm+pck, then `butler push build/web qusto/the-far-yard:html5 --userversion m1-<date>-<sha>`.
- `.github/workflows/nightly.yml` — replaced the `studio/...` placeholder with real slugs `ITCH_TARGET_WIN`/`ITCH_TARGET_WEB` (`qusto/the-far-yard:{win-nightly,html5}`); added a Web export step + a Web push step + a Web artifact upload (both publishes share the existing `BUTLER_API_KEY` guard); refreshed the human-gated header to the qusto project + SAB/Chromium prerequisites.
- `SETUP.md` — new §1a: one-time export-templates (.tpz, carries both platforms) + butler install steps, the `tools/push_itch.sh` flow, and the human-only publish prerequisites (BUTLER_API_KEY secret, itch project Restricted/Draft+password+HTML, SAB toggle, Chromium-only, single-thread fallback, one manual confirming push).
- `tools/playtest/tester_readme.md` — web/Chromium run note: play in Chrome/Edge (Firefox lacks `credentialless` COEP), web `user://` = IndexedDB so use the in-game Export-telemetry button (DLV2), not the %APPDATA% zip flow.

## Checks run
- [x] `godot --headless --import` → clean (exit 0, no parse errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (exit 0).
- [x] **Web export builds:** `godot --headless --path . --export-release "Web" build/web/index.html` produced the full file-set — `index.html` (5.4 KB), `index.js` (358 KB), `index.wasm` (37 MB), `index.pck` (1.16 MB), audio worklets, icons. Threaded build confirmed (PThread/SharedArrayBuffer present in index.js); `index.html` references `ensureCrossOriginIsolationHeaders` (Godot 4.6.3 inlines the COI logic rather than emitting a standalone `coi-serviceworker.js`). Re-run on a clean `build/web` exited 0 and reproduced byte-set. (An earlier run exited 134 / SIGABRT at cleanup AFTER `savepack DONE` — a known non-deterministic Godot-headless-on-WSL2 teardown abort, not an export failure; the clean re-run exited 0.)
- [x] Export templates 4.6.3.stable installed to `~/.local/share/godot/export_templates/4.6.3.stable/` (35 templates incl. `web_release.zip` threaded + `web_nothreads_release.zip` single-threaded fallback).
- [x] `tools/push_itch.sh` `bash -n` syntax OK; the `# Itch.io` key parser extracts a non-empty token from `APIKEYS.md` (length 13) **without printing the value**.
- [x] `nightly.yml` is valid YAML (`yaml.safe_load`).
- [x] `build/web/` confirmed gitignored (`git check-ignore` hit); `APIKEYS.md` not tracked; the 5 owned files are the only changes.

## Definition of done — status
- butler installed + on PATH: **BLOCKED in this sandbox** — `broth.itch.ovh` (butler's only distribution host) does not resolve here (`itch.io` resolves but is IPv6-only; the butler broth host has no DNS). Install steps documented in SETUP.md §1a; a human runs them on a network that can reach broth.itch.ovh.
- 4.6.3 web templates installed + web export produces a non-empty file-set: **DONE**.
- `export_presets.cfg` carries a stable-named `Web` preset; `Win64` untouched: **DONE**.
- `tools/push_itch.sh` reads the key without printing it + would `butler push` build/web → qusto/the-far-yard:html5: **DONE (script)**; the real confirming push is **BLOCKED on butler install** (sandbox network) — a human runs one manual push.
- `nightly.yml` placeholder reconciled to the real target; `BUTLER_API_KEY` guard preserved: **DONE** (ships both Win64 + Web).
- Telemetry-retrieval decision reflected: Director ruled "web must carry data" → DLV2 owns the in-game export button; `tester_readme.md` documents the web/IndexedDB reality + points at the DLV2 button + Chromium-only: **DONE**.
- Worklog naming the commit SHA; no secret committed: **DONE**.

## Design deviations
None. On-spec with the LOCKED DLV1 design + Director disposition (ship both Win+Web; slug `:html5`;
threaded + COI + itch SAB toggle, Chromium-only; web telemetry via DLV2). The only gap is the
environment-blocked butler install + confirming push (network, not design) — flagged below.

## Handoffs / follow-ups (human steps remaining)
1. **Install butler** on a network that can reach `broth.itch.ovh` (SETUP.md §1a) — blocked in this sandbox (no DNS for the broth host).
2. **Provision the human-only itch prerequisites** (SETUP.md §1a): the `BUTLER_API_KEY` GitHub repo secret; the `qusto/the-far-yard` project set Restricted/Draft + password + Kind=HTML; the "SharedArrayBuffer support" toggle ON. The Director confirms these are already set up — so a human only needs butler installed + the local key to run the confirming push.
3. **Run the confirming push:** `export PATH="$HOME/.local/bin:$PATH"; bash tools/push_itch.sh` from a checkout with `APIKEYS.md` present (it is NOT in this worktree — it lives in the main checkout, gitignored). This pushes the current `main` greybox as a **pre-M1.3 pipeline-test build** (the real playtest push is RG1).
4. **DLV2 (sibling task)** owns the in-game JavaScriptBridge "Export telemetry" download button so a browser playtest returns its `run_log.jsonl`. A web-only re-gate `blockedBy` DLV2.
