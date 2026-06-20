# Worklog — DLV2 In-game telemetry export for web (JavaScriptBridge)

- **Date:** 2026-06-19
- **Subagent:** general-purpose
- **Milestone:** M1.3 (Wave 1 — infra)
- **Branch:** worktree-agent-ada839477ba43a3d8 (isolated worktree off `main`)
- **Commit:** c2c743f32e54bb838362c681b62de4972caa31a6

## What changed
Added a web-only "Export telemetry" control to the sell/continue screen so a browser
playtester can pull `user://telemetry/run_log.jsonl` (which lives in the browser's
IndexedDB VFS, unreachable by the desktop "zip %APPDATA%" flow) down to their browser
Downloads — RG2's web re-gate depends on getting the `.jsonl` back (Director: "web must
carry data"). New `TelemetryExporter` helper does the read + download; the SellScreen
wires the button. Pure READER: no telemetry schema/arity change, no new EventBus signal,
determinism untouched.

## Download idiom (confirmed for Godot 4.6)
Used the engine built-in **`JavaScriptBridge.download_buffer(buffer, name, mime)`**
rather than a hand-rolled `JavaScriptBridge.eval` shim. `download_buffer` IS the current
4.6 idiom — the engine internally builds the `Blob` and clicks a transient `<a download>`,
which is exactly the mechanism the spec described, but it manages the JS object lifetime
and Blob URL for us (more robust than a manual shim). Per the Godot docs it must be called
from a user gesture (a button press) or the browser blocks the download — satisfied here
because it fires from the button's `pressed` handler. MIME `application/x-ndjson` (browser
may override from the `.jsonl` extension; harmless).

## Behaviour
- **Web build:** button visible on the sell screen. On click → reads the existing log
  bytes via `FileAccess.get_file_as_bytes` → `download_buffer` → browser saves
  `run_log_<BuildVersion.id()>.jsonl` (e.g. `run_log_m1-20260619-691d9da.jsonl`,
  self-labelling for RG2 cohorting). A small status label confirms "Downloaded <name>"
  or "No telemetry to export yet" if no run has been logged.
- **Desktop:** the button + status label are `hide()`-den and the signal is never
  connected; `TelemetryExporter.is_supported()` / `trigger_download()` / `export()` are
  inert no-ops. DLV2 is fully additive and inert off-web; the desktop on-disk retrieval
  flow is unchanged.

## Files touched
- `ui/web_export/telemetry_exporter.gd` (NEW) — `TelemetryExporter` RefCounted helper.
  Pure testable halves (`read_log_bytes`, `download_filename`, `has_log`, `is_supported`)
  + the web-only side-effect (`trigger_download`, `export`). `LOG_PATH` sources from
  `TelemetrySchema.LOG_PATH` (single source of truth); filename from `BuildVersion.id()`.
- `ui/sell/sell_screen.gd` — added `%ExportTelemetryButton`/`%ExportStatusLabel` refs,
  `_setup_export_control()` (web guard: hide + skip wiring on desktop), and
  `_on_export_telemetry_pressed()`. No change to the existing sell/tally/continue logic.
- `ui/sell/sell_screen.tscn` — added `ExportTelemetryButton` (Button) + `ExportStatusLabel`
  (Label) under the existing VBox, after BackToConfigButton.
- `ui/sell/sell_strings.csv` — added `SELL_EXPORT_TELEMETRY`, `SELL_EXPORT_DONE`,
  `SELL_EXPORT_EMPTY`.
- `tests/test_telemetry_exporter.gd` (NEW) — headless test of the pure half.

## Ownership compliance
Did NOT touch (as instructed, avoiding the J5/DLV1 collisions): `ui/hud/decision_hud.gd`,
`ui/hud/hud_strings.csv`, `tools/playtest/tester_readme.md`, `run_config.gd`,
`main_game.gd`, `hazard_entity.gd`, `telemetry.gd`. DLV2 lives entirely on the
sell-screen + new `ui/web_export/` seam, disjoint from J5's in-dive HUD.

## Checks run
- [x] `godot --headless --import` clean (no script/parse errors; only the expected
  first-pass `.translation` regen notices, gone on the 2nd import).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK** (exit 0).
- [x] `godot --headless --script res://tests/test_telemetry_exporter.gd` → **DLV2 EXPORTER OK**
  (exit 0) — asserts: no-log → empty bytes (no error); written JSONL → byte-identical
  read-back; `download_filename()` == `run_log_<BuildVersion.id()>.jsonl`; `is_supported()`
  == `OS.has_feature("web")`; `trigger_download`/`export` are no-ops off-web.
- [x] `godot --headless --script res://tests/test_sell_screen.gd` → **SELL SCREEN OK**
  (exit 0) — no regression on the existing reward beat.
- Headless cannot exercise the actual browser download (`download_buffer` needs a real web
  runtime + user gesture). **Human verification needed on the itch build (Chromium):**
  run a dive, hit the sell screen, click "Export telemetry", confirm a
  `run_log_*.jsonl` lands in Downloads and round-trip parses (also confirm it works under
  itch's COOP/COEP/SAB headers — see DLV2 spec Open Q3).

## Design deviations
**One, minor (recommend "Reviewed"):** the spec §1 described handing bytes to "a tiny JS
shim (`JavaScriptBridge.eval` / `create_callback`) that builds a `Blob` + an `<a download>`
click." I instead used the engine built-in `JavaScriptBridge.download_buffer(buffer, name,
mime)`, which performs that exact Blob+anchor mechanism internally and is the blessed 4.6
idiom — fewer moving parts, no manual JS object lifetime to manage. Same observable
behaviour (named file → browser Downloads), no contract impact. Surfacing for the Director
to confirm the built-in is preferred over a hand-rolled shim.

## Handoffs / follow-ups
- **tester_readme export-step text (for DLV1 / orchestrator to fold into
  `tools/playtest/tester_readme.md`):**
  > **Web build (itch, Chromium only):** the telemetry log lives inside the browser, not on
  > disk, so there is no folder to zip. After you finish a run and reach the sell screen,
  > click **"Export telemetry"**. Your browser downloads a file named
  > `run_log_<build-id>.jsonl` (e.g. `run_log_m1-20260619-691d9da.jsonl`) to your Downloads
  > folder — the build id in the filename lets us match it to your build. Send us that
  > `.jsonl` file. You can export again any time you reach the sell screen; the file is
  > cumulative for the session, so the last export of a session is the one to send. (Use
  > Chrome/Chromium — the itch web build requires the COOP/COEP headers other browsers may
  > not honour.)
- Human must confirm the download works on the live itch page under COI/SAB headers (spec
  Open Q3). If `download_buffer` is ever blocked there, fall back to a `JavaScriptBridge.eval`
  Blob shim or a "copy to clipboard" path (spec Open Q2) — the `TelemetryExporter` seam
  isolates that change to one file.
