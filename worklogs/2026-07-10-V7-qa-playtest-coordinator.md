# Worklog — V7 Telemetry log rotation + analysis-script argv

- **Date:** 2026-07-10
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.12
- **Branch:** feat/V7-telemetry-rotation
- **Commit:** 9ac91e5

## What changed

Implemented both fixes from `design/M1_12_Tasks/V7_telemetry_rotation.md` (Resolved
Decisions, Phase 3, binding), behavior-preserving on telemetry content/schema:

1. **Size-capped rotation in `JsonlWriter`.** Added an optional `max_bytes` constructor
   arg (default `DEFAULT_MAX_BYTES = 2 MB`), a `_size_bytes` tracker that is re-read from
   the true on-disk file length on every `_open()` (never assumed/cached across a
   toggle or relaunch), and a `_rotate()` method that rolls the current active file to
   `<path>.1` (replacing any older `.1` — ring depth 1) and reopens a fresh, empty file
   at the same well-known path. Guarded so the very first line into an empty file never
   triggers a rotation. Reuses the exact `DirAccess.rename_absolute` /
   `DirAccess.remove_absolute` / `FileAccess.file_exists` idiom `save_manager.gd:38-54`
   already established.
2. **`TelemetrySchema.MAX_LOG_BYTES`** (2 MB) added as the schema-owned constant (mirrors
   how `LOG_PATH` is already the schema's single source of truth). `SCHEMA_VERSION`
   stays `1` — this is a file-lifecycle change, not a row/envelope shape change.
3. **`telemetry.gd`'s one call site** (`_emit_row`) now passes
   `Schema.MAX_LOG_BYTES` to the `JsonlWriter` constructor. No other line in
   `telemetry.gd` changed.
4. **`telemetry_exporter.gd`**: added the documented code comment at the `LOG_PATH`
   constant noting the accepted double-rotation-in-one-web-session limitation (per
   Resolved Decision #3) — zero behavioral diff, comment only.
5. **`analyze_m1_2.py`**: added `sys.argv[1]` input with the frozen M1.2 log path
   preserved as the no-arg default (`DEFAULT_PATH`), per Resolved Decision #4.
6. **New test** `Game/tests/test_jsonl_writer_rotation.tscn` (+ `.gd`), scene-wrapped per
   Resolved Decision #7 (never `--script`), driving `JsonlWriter` directly at a tiny
   cap — no autoload/EventBus dependency. Covers: (a) a single overflow rotates to one
   `.1` generation with nothing lost, (b) sustained overflow across many appends keeps
   ring depth at exactly 1 (each new rotation replaces `.1`, never chains — the oldest
   content is correctly gone, not silently accumulated: a real, deliberately-verified
   consequence of the design's ring-depth-1 policy under sustained overflow, not a
   test bug), (c) reopening a `JsonlWriter` at the same path re-reads the TRUE on-disk
   length rather than assuming empty, so a cap set just above the pre-existing size
   still rotates promptly.

Note on test math: the design doc's own illustrative pseudocode assumed one rotation
across all 10 lines at cap=50, but at ~18 bytes/line that cap is crossed roughly every
2 lines, so 10 lines cause several cascading rotations, not one — each rotation
correctly replaces `.1` rather than accumulating (ring depth 1 is deliberately lossy for
generations older than the last two). I split the test into a small first batch (crosses
the cap exactly once, asserting nothing is lost) and a longer sustained-overflow batch
(asserting bounded, not-accumulating loss) so both properties are verified precisely
rather than asserting a byte count that the actual arithmetic can't satisfy.

## Files touched
- `Game/systems/telemetry/jsonl_writer.gd` — added size-cap rotation (`_rotate()`,
  `_size_bytes` tracking re-read on every `_open()`, optional `max_bytes` ctor arg).
- `Game/systems/telemetry/telemetry_schema.gd` — added `MAX_LOG_BYTES` const;
  `LOG_PATH` docstring updated to describe rotation (value unchanged).
- `Game/systems/telemetry/telemetry.gd` — one-line diff: `JsonlWriterScript.new(Schema.LOG_PATH, Schema.MAX_LOG_BYTES)`.
- `Game/ui/web_export/telemetry_exporter.gd` — added a doc comment on `LOG_PATH`
  documenting the accepted double-rotation gap; zero behavior change.
- `Game/tools/playtest/analyze_m1_2.py` — `sys.argv[1]`-aware `PATH`, default preserved.
- `Game/tests/test_jsonl_writer_rotation.gd` (new) — headless rotation unit test.
- `Game/tests/test_jsonl_writer_rotation.tscn` (new) — scene wrapper (+ `.uid` sidecar).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → `SMOKE OK — M0 architecture spike healthy`
- [x] `godot --headless --path Game res://tests/test_jsonl_writer_rotation.tscn` →
      `JSONL ROTATION OK` (new test, all 3 cases pass)
- [x] `godot --headless --path Game res://tests/test_telemetry_jsonl.tscn` → `TELEMETRY OK` (11 rows)
- [x] `godot --headless --path Game res://tests/test_telemetry_consent.tscn` → `CONSENT OK`
- [x] `godot --headless --path Game res://tests/test_telemetry_config_marking.tscn` → `TEL CONFIG MARKING OK`
- [x] `godot --headless --path Game --script res://tests/test_telemetry_exporter.gd` → `DLV2 EXPORTER OK`
      (this one is a `SceneTree`/`--script` test per its own docstring — no `.tscn` sibling exists;
      not one of the "never --script" scene tests, an existing documented exception)
- [x] `python3 Game/tools/playtest/analyze_m1_2.py` (no args) — reproduces the same
      M1.2 cohort output as before the change (default path unchanged)
- [x] `python3 Game/tools/playtest/analyze_m1_2.py playtest_data/M1.1/<file>.jsonl` —
      confirms an explicit path argument correctly re-targets the analysis with no source edit
- [x] Confirmed `TelemetrySchema.SCHEMA_VERSION` stays `1`, `LOG_PATH` value unchanged
      (`user://telemetry/run_log.jsonl`), `TelemetryExporter.has_log()`/`read_log_bytes()`
      still read only the active `LOG_PATH` (grep-verified, no enumeration added)
- [x] `Game/systems/save_manager.gd` untouched — no save-schema change
- [x] Definition of done met: "size-capped rotation... single `.1` roll... re-read true
      on-disk length on each `_open()`... `TelemetrySchema.LOG_PATH` +
      `telemetry_exporter.gd` stay byte-for-byte unchanged... NO rotation marker row...
      `analyze_m1_2.py` gets `sys.argv[1]` input, defaulting to the frozen M1.2 path...
      new scene-based rotation test drives rotation at a small cap headless" — all met.

## Debt ledger

- **Bounds a previously-unbounded resource.** Before V7, `jsonl_writer.gd`'s own
  docstring admitted the log is "never truncat[ed]" — every session ever run on a given
  machine appended into one eternal `user://telemetry/run_log.jsonl`. After V7: hard-
  bounded at ~`MAX_LOG_BYTES` (2 MB) active + one rolled `.1` generation (~4 MB worst
  case total), regardless of process-launch count or session length.
- **Removes a per-playtest-round manual script edit.** `analyze_m1_2.py`'s hardcoded
  `PATH` required copy-pasting/hand-editing the file for every new round (M1.9, M1.11,
  and this M1.12 round). Now any round's log runs via
  `python3 Game/tools/playtest/analyze_m1_2.py <path>` with zero source edits; the
  no-arg default still reproduces the exact original M1.2 output.
- **Net LOC is additive, not a deletion** (unlike most of Wave 1): roughly +55 lines in
  `jsonl_writer.gd` (rotation state + `_rotate()` + doc comments), +8 lines in
  `telemetry_schema.gd` (`MAX_LOG_BYTES` const + docs), a 1-line diff in `telemetry.gd`,
  an 8-line comment addition in `telemetry_exporter.gd`, a 6-line diff in
  `analyze_m1_2.py`, and a new ~150-line headless unit test (docstring-heavy, 3
  assertion cases). The debt paid down is qualitative: it closes two long-standing,
  explicitly-documented deferred-TODOs (`telemetry_schema.gd`'s old "rotation deferred
  to G4" comment, and `analyze_m1_2.py`'s hardcoded-path-per-round pattern) with zero
  behavior change to telemetry content/schema and zero change to any consumer
  (`TelemetryExporter`, the dozen hardcoded-`LOG_PATH` tests) that reads the active log
  by its well-known name.
- **Accepted, documented limitation carried forward (not new debt, but worth
  restating):** a single web session that itself crosses the 2 MB cap twice before the
  player clicks "Export telemetry" would silently lose the middle segment (rotated into
  `.1`, then overwritten by the next rotation before export). Per Resolved Decision #3
  this is accepted as practically unreachable (`jsonl_writer.gd`'s own "tens of lines
  per run" estimate implies hundreds of runs in one sitting to hit this) and is now
  documented in a code comment at `telemetry_exporter.gd`'s `LOG_PATH` constant.

## Design deviations

None. Every mechanism (size-cap, `.1` ring depth 1, unchanged exporter, unchanged
script default, 2 MB cap, no marker row, scene-wrapped test) was implemented exactly
per the V7 design doc's locked Phase-3 "Resolved Decisions." One minor arithmetic
correction was needed in the doc's own illustrative test pseudocode (see "Note on test
math" above under What changed) — the design's mechanism itself (§1's `_open`/
`append_line`/`_rotate`) was implemented verbatim with no changes; only the NEW test's
specific line counts/cap value were adjusted from the doc's illustrative sketch to
match the real arithmetic of ring-depth-1 rotation under sustained overflow. This is a
test-authoring correction, not a design deviation, and needs no Director sign-off — no
entry added to `design/DESIGN_DEVIATIONS.md`.

## Handoffs / follow-ups

None beyond what the V7 design doc already flagged as out-of-scope-by-design:
the dozen tests that hardcode the literal `user://telemetry/run_log.jsonl` path
instead of importing `TelemetrySchema.LOG_PATH` (minor pre-existing duplication,
explicitly called out in the design doc as out of V7's two-fix scope) remains
unaddressed here, matching the locked design's scope boundary.
