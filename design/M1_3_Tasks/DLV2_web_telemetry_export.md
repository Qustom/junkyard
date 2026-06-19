# DLV2 — In-game telemetry export for web builds (JavaScriptBridge)

**Milestone:** M1.3 · **Wave:** Infra (parallel) · **Origin:** Director disposition on DLV1/Q3 (2026-06-19): **"web must carry data."**
**Builder:** general-purpose + ui-ux-designer (the button/UX) · **dependsOn:** none (pairs with DLV1) · **Blocks:** any web-only re-gate.
**Touch:** a small in-game export control (HUD/pause/sell-screen) + a web-guarded export helper; NO telemetry schema/arity change.

> **Why this exists:** DLV1 ships the itch HTML5 build, but a web build's `user://telemetry/run_log.jsonl` lives in the
> browser's **IndexedDB**, not on disk — the proven desktop "zip `%APPDATA%` and send" retrieval flow (`tools/playtest/tester_readme.md`)
> does NOT work for web, and the re-gate (RG2) is 100% dependent on getting the `.jsonl` back. The Director ruled web must
> carry data, so DLV2 adds an **in-game way to export the telemetry log from a browser playtest**.

## 1. Goal & premise research (the implementing agent verifies against real source)

- `systems/telemetry/telemetry_schema.gd` `LOG_PATH` = `user://telemetry/run_log.jsonl`; the writer (`jsonl_writer.gd`) flushes per row. On web, `user://` maps to IndexedDB (OPFS/idbfs) — readable from GDScript via `FileAccess` (the file exists in the VFS), but NOT reachable by the desktop zip flow.
- **Mechanism:** `JavaScriptBridge` (Godot 4.x) can trigger a browser download. Read the JSONL via `FileAccess.get_file_as_bytes("user://telemetry/run_log.jsonl")`, then hand the bytes to a tiny JS shim (`JavaScriptBridge.eval` / `create_callback`) that builds a `Blob` + an `<a download>` click → the browser saves `run_log.jsonl` to the player's Downloads. (The agent confirms the current Godot 4.6 JavaScriptBridge download idiom.)
- **Platform guard:** `OS.has_feature("web")` — on desktop the control is hidden/no-op (desktop keeps the existing file-on-disk flow). So DLV2 is purely additive and inert off-web.

## 2. Design / approach

- A small **"Export telemetry" control** — recommended placement: the **sell/continue screen** (end-of-run, where the player pauses) and/or the pause menu, so the tester can export after a session. ui-ux-designer picks the seam consistent with E2 readability; general-purpose wires the export.
- On click (web only): read the JSONL bytes → JS `Blob` download named `run_log_<build-id>.jsonl` (use `BuildVersion.id()` so the file is self-labelling for RG2 cohorting).
- **No telemetry contract change:** DLV2 only READS the existing log and downloads it. No new EventBus signal, no schema bump, no `run_ended` change. Determinism untouched (fp `e943ac9c8bc1`).
- Desktop: control hidden (or shows "telemetry on disk" hint) — the desktop retrieval flow is unchanged.

## 3. Acceptance criteria

1. On a **web build**, after one or more runs, the player can click "Export telemetry" and the browser downloads a valid `run_log*.jsonl` whose contents match the in-VFS log (round-trip parseable, all envelope fields intact).
2. On **desktop**, the control is hidden/no-op; the existing on-disk flow is unaffected.
3. No telemetry schema/arity change; smoke + telemetry suites green; all-off baseline byte-identical.
4. `tools/playtest/tester_readme.md` documents the web export-and-send step (Chromium-only, per DLV1).

## 4. Open questions (resolve at build / brief time)
- Exact placement (sell screen vs pause vs both) — ui-ux call.
- Filename convention (`run_log_<id>.jsonl`) and whether to also offer "copy to clipboard" as a fallback.
- Whether to confirm the JavaScriptBridge download idiom works under itch's COI/SAB headers (test on the actual itch page, Chromium).

*Created at M1.3 Phase 4 from the Director's DLV1/Q3 disposition. Phase-2/3 depth was folded into DLV1's doc; DLV2 is the spun-off
implementation task. If it proves larger than a button (e.g. needs an OPFS read path), re-scope at the Wave brief.*
