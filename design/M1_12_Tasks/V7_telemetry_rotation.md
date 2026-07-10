# V7 / R8 — Telemetry log rotation + analysis-script argv

> Phase 2 per-task design doc for M1.12 (`design/M1_12_Tasks/M1.12_Breakdown.md`, Wave 1,
> file-disjoint alongside V1/V5/V8/V9). Assignee: `qa-playtest-coordinator` (owns
> telemetry + analysis, per the roster in `CLAUDE.md`). **This is a design doc — no code
> is touched here.**
>
> Scope (two small, independent fixes, both behavior-preserving on content/schema):
> (a) bound `user://telemetry/run_log.jsonl`, currently a single unbounded roller, with a
> size-capped rotation to one rolled `.1` generation; (b) give `Game/tools/playtest/analyze_m1_2.py`
> an `argv[1]` input path (default preserved) so a new playtest round needs no source edit.

---

## (a) Research on the premise — the telemetry write path

### The write path today

- **`Game/systems/telemetry/telemetry_schema.gd:19-21`** declares the single on-disk path as
  a class constant, the schema module's own docstring already flagging the deferral:
  ```
  ## On-disk log path. One rolling JSONL file for M1 (rotation deferred to G4 if the
  ## file grows painful). `user://` resolves to the per-OS app-data dir.
  const LOG_PATH: String = "user://telemetry/run_log.jsonl"
  ```
  `SCHEMA_VERSION` (`telemetry_schema.gd:17`) is `1` and stays `1` — V7 touches file
  *lifecycle*, never the row envelope or any payload shape.

- **`Game/systems/telemetry/jsonl_writer.gd`** is the "dumb appender" (`class_name
  JsonlWriter extends RefCounted`, line 21) — no EventBus/autoload knowledge, by design,
  so it's the seam G2 could unit-test headless without booting the Telemetry autoload
  (docstring, lines 6-9). Its own docstring is explicit about the bug this task fixes
  (lines 11-12):
  ```
  ## Lifecycle: `new(path)` ensures the parent dir exists and opens the file in
  ## append mode (creating it if absent, never truncating an existing log).
  ```
  Concretely, `_open()` (lines 37-54) does:
  ```gdscript
  func _open(path: String) -> void:
      if _file != null:
          return
      var dir := path.get_base_dir()
      if dir != "":
          DirAccess.make_dir_recursive_absolute(dir)
      if FileAccess.file_exists(path):
          _file = FileAccess.open(path, FileAccess.READ_WRITE)
      else:
          _file = FileAccess.open(path, FileAccess.WRITE_READ)
      ...
      _file.seek_end()
  ```
  Every time a `JsonlWriter` opens `LOG_PATH` and the file already exists (i.e. **every
  session that was ever run on that machine, forever** — this is not a single-session
  concern), it seeks to the end and keeps appending. There is no size check, no
  generation, no truncation, anywhere in this file. `append_line()` (lines 59-63) is
  equally dumb — one `store_line` per call, no bound.

- **`Game/systems/telemetry/telemetry.gd`** is the only production caller of
  `JsonlWriter`. `_emit_row()` (lines 118-138) lazily constructs the writer on first use:
  ```gdscript
  func _emit_row(type: String, data: Dictionary) -> void:
      if not _enabled:
          return
      if _writer == null:
          _writer = JsonlWriterScript.new(Schema.LOG_PATH)     # line 122 — the one call site
          if not _writer.is_open():
              _writer = null
              return
      ...
      _writer.append_line(JSON.stringify(row))
  ```
  `_writer` is closed (and nulled) in exactly two places: `set_enabled(false)`
  (lines 105-110, when the player toggles the Settings flag off) and `_exit_tree()`
  (lines 383-387, on autoload teardown at process exit). Both close cleanly (`flush()`
  then `close()`) — reopening later (`_emit_row` sees `_writer == null` again) resumes
  **appending to the same file**, per `_open()`'s "never truncating" contract above. This
  matters for the rotation design below: `_writer` can legitimately open/close/reopen
  **multiple times within one real player session** (toggle telemetry off then back on
  in Settings) without that being a new "session" in the rotation sense — see Pseudocode
  §1's placement rationale.

- Every row still carries the full schema envelope (`_emit_row` lines 128-137: `v`, `ts`,
  `t_ms`, `run_id`, `session_id`, `type`, `data`) — **completely untouched by this task**.
  `_session_id` (`telemetry.gd:42`, stamped once in `_ready()` line 60 as `"s_" +
  _short_id(...)`) is already a *process-lifetime* id available for any "which session
  wrote this row" grouping an analyst wants — it needs no new plumbing, it already rides
  every row.

### The exporter's active-log lookup (must keep working)

- **`Game/ui/web_export/telemetry_exporter.gd:30-31`** re-derives its own path from the
  *same* schema constant, documented as the single source of truth:
  ```gdscript
  ## The log we export. Single source of truth: the schema module's LOG_PATH.
  const LOG_PATH: String = TelemetrySchema.LOG_PATH
  ```
  `has_log()` (lines 46-47) and `read_log_bytes()` (lines 52-55) both check/read exactly
  `LOG_PATH` — nothing else. **As long as `TelemetrySchema.LOG_PATH` keeps naming the same
  file and that file is the one actively being appended to for the CURRENT session,**
  the exporter needs zero changes. This is the hard constraint the rotation design must
  respect: whatever rotation scheme V7 picks, **the well-known active path must always be
  the freshest, currently-writable log** — never a rotated-away backup.

- A dozen existing headless tests hardcode the exact same literal string as their own
  `LOG_PATH` (NOT via `TelemetrySchema` — this duplication is itself minor debt, but is
  explicitly out of V7's two-fix scope): `Game/tests/test_telemetry_jsonl.gd:22`,
  `test_telemetry_consent.gd:22`, `test_telemetry_config_marking.gd:25`,
  `test_corridor_summary_row.gd:10`, `test_def_menu_coverage.gd:37`,
  `test_rg1_loop_verify.gd:29`, `test_rg1_m12_verify.gd:38`, `test_rg1_m13_verify.gd:47`,
  `test_rg1_m14_verify.gd:37`, `test_rg1_m15_verify.gd:43`, plus
  `test_telemetry_exporter.gd:24` (reads `TelemetryExporter.LOG_PATH` directly). Every one
  of these opens/deletes/asserts on the literal `user://telemetry/run_log.jsonl` path — a
  second hard constraint: **the active file's name must not change.** I surveyed each of
  these for a rotation hazard: every one calls its own `_remove_log()` helper (e.g.
  `test_telemetry_jsonl.gd:193-196`, `test_telemetry_consent.gd:120-122`) **immediately
  before** each `set_enabled(true)`/drive-a-run cycle, so none of them depends on
  accumulation across multiple writer opens within one test process — a size-cap
  rotation (§ below) will never fire during normal test data volumes (see Pseudocode
  §1's cap-size rationale), and even if it somehow did, no test asserts an exact row
  *count* that a rotation would violate (they check "at least one row of type X exists,"
  e.g. `test_telemetry_jsonl.gd:80-82`).

### The precedent already in-repo for exactly this kind of file-lifecycle op

- `Game/systems/save_manager.gd:38-54` (`_atomic_store`) already does an atomic
  tmp-then-rename write with a rolled `.bak` generation — the established idiom for
  "roll the previous file aside, keep exactly one generation, using the real Godot
  `DirAccess` static file ops":
  ```gdscript
  # Back up the previous good file before swapping in the new one.
  if FileAccess.file_exists(path):
      DirAccess.copy_absolute(path, path + ".bak")
  return DirAccess.rename_absolute(tmp, path)  # atomic on same filesystem
  ```
  V7's rotation reuses this exact vocabulary (`DirAccess.rename_absolute`,
  `DirAccess.remove_absolute`, `FileAccess.file_exists`) — no new file-op idiom enters
  the codebase, it's the same pattern SaveManager already proved out, applied to
  `jsonl_writer.gd` instead of `save_manager.gd`.

### The analysis script's hardcoded path

- **`Game/tools/playtest/analyze_m1_2.py`** (156 lines) is the only round-analysis script
  in the repo — I grepped both `tools/` (repo root; does not exist) and `Game/tools/`
  (only `analyze_m1_2.py`, `loop_smoke_checklist.md`, `tester_readme.md` live in
  `Game/tools/playtest/`) and found **no sibling round-analysis scripts** to parameterize
  alongside it. Its header (lines 1-4) already documents the intended invocation:
  ```python
  # RG2 — M1.2 telemetry analysis helper (feeds design/M1_2_Tasks/G4_findings_M1.2.md).
  # Reads the cumulative JSONL playtest log, partitions runs by build SHA + run_config,
  # and prints cohort counts, per-config distributions, and per-fix event evidence.
  # Run from repo root:  python3 tools/playtest/analyze_m1_2.py
  ```
  and the hardcoded input is line 8:
  ```python
  PATH='playtest_data/M1.2/run_log_2026-06-19.jsonl'
  ```
  a path relative to the **repo root** (confirmed: `playtest_data/M1.1/` and
  `playtest_data/M1.2/` both live at `/mnt/c/source/junkyard/playtest_data/`, not under
  `Game/`) — every subsequent playtest round (M1.9's, M1.11's, and this M1.12 regression
  round if one is ever run) required copy-pasting this whole file and hand-editing line 8
  (and the cohort-detection `if b==...` build-SHA literals at lines 39-40, which are a
  separate, larger, out-of-scope concern — see Open Questions). `PATH` is read exactly
  once, at module scope (line 12: `for line in open(PATH):`), so parameterizing it is a
  two-line change (import `sys`, replace the literal with an `argv`-aware default).

---

## (b) Pseudocode

### §1 — Rotation policy: **size-capped, one rolled `.1` generation** (recommended)

**Why size-cap over per-session:** the breakdown's own DoD phrasing — *"the log rotates
deterministically (unit-testable via `jsonl_writer` at a small cap — headless)"* — points
at a size threshold, not a session boundary, and for good reason: a "session" is a
`Telemetry`-level concept (tied to autoload `_ready()`/process lifetime), but as the
research above shows, `_writer` can legitimately close and reopen **within one real
session** (a Settings toggle) without that being a rotation event. Rooting rotation in
`JsonlWriter` itself — the file's own accumulated byte size — needs **no session concept
at all**, is entirely self-contained in the one file already documented as the seam for
headless unit tests, and directly targets the actual bug: *`_open()` never truncates,
regardless of how many process launches or toggle-cycles contributed to the pre-existing
size*. A size cap bounds the file no matter which axis (long session vs. many short
sessions vs. months of dev-machine accumulation) produced the growth.

```gdscript
# jsonl_writer.gd — additive change, same class, same public surface plus one new
# optional constructor arg (default-valued, so the one production call site can
# either pass nothing — same as today — or pass the schema's named cap).

const DEFAULT_MAX_BYTES: int = 2 * 1024 * 1024   # 2 MB soft cap (see Open Q: is this the right number)

var _max_bytes: int = DEFAULT_MAX_BYTES
var _size_bytes: int = 0                          # tracked, not re-queried, after the first open

func _init(path: String, max_bytes: int = DEFAULT_MAX_BYTES) -> void:
    _path = path
    _max_bytes = max_bytes
    _open(path)

func _open(path: String) -> void:
    if _file != null:
        return
    ... # UNCHANGED: make_dir_recursive_absolute, open READ_WRITE-or-WRITE_READ, error handling
    _file.seek_end()
    _size_bytes = _file.get_length()               # NEW: know what's already on disk

func append_line(line: String) -> void:
    if _file == null:
        return
    var added := line.to_utf8_buffer().size() + 1   # +1 for store_line's trailing "\n"
    # Only rotate EXISTING content out of the way — never rotate on the very first
    # line into an empty file (guards against one oversized line looping forever).
    if _size_bytes > 0 and _size_bytes + added > _max_bytes:
        _rotate()
    _file.seek_end()
    _file.store_line(line)
    _size_bytes += added

func _rotate() -> void:
    # Mirrors save_manager.gd:39-54's atomic tmp->path rename idiom, reversed: the
    # OLD active file becomes the single ".1" generation, freeing the well-known
    # active name for a brand-new empty file — so every reader that looks up
    # LOG_PATH (TelemetryExporter, the dozen hardcoded-path tests) keeps finding
    # "the log" at the exact same name, whether it was just rotated or not.
    _file.flush()
    _file.close()
    _file = null
    var bak_path := _path + ".1"
    if FileAccess.file_exists(bak_path):
        DirAccess.remove_absolute(bak_path)          # ring depth 1 — drop the OLDER .1
    DirAccess.rename_absolute(_path, bak_path)        # this session's overflow -> .1
    _file = FileAccess.open(_path, FileAccess.WRITE_READ)  # fresh, empty, at the SAME name
    if _file == null:
        _open_error = FileAccess.get_open_error()
        push_warning("JsonlWriter: rotation could not reopen %s (err %d)" % [_path, _open_error])
        return
    _size_bytes = 0
```

`flush()`, `close()`, `is_open()`, `get_open_error()`, `get_path()` are unchanged.

**How the active log stays discoverable:** `TelemetrySchema.LOG_PATH` and
`TelemetryExporter.LOG_PATH` are **not touched at all** — both still name
`user://telemetry/run_log.jsonl`, and after any rotation that exact path is (by
construction of `_rotate()`) always the fresh, currently-open file. A rotation that
happens *while the web exporter's target session is still running* only affects rows
written before the rotation instant — see Open Questions §3 for the one edge case this
doesn't cover (a single web session that itself crosses the cap twice).

**Schema-owned constant** (mirrors how `LOG_PATH` is already the schema's single source
of truth for the exporter):

```gdscript
# telemetry_schema.gd — additive const, no SCHEMA_VERSION bump (file lifecycle, not row shape)
const MAX_LOG_BYTES: int = 2 * 1024 * 1024
```

**Telemetry's one call-site diff** (`telemetry.gd:122`):

```gdscript
# before:
_writer = JsonlWriterScript.new(Schema.LOG_PATH)
# after:
_writer = JsonlWriterScript.new(Schema.LOG_PATH, Schema.MAX_LOG_BYTES)
```

Everything else in `telemetry.gd` — every `_emit_row` call, every row's `data` payload,
`_exit_tree`, `set_enabled` — is untouched.

**New headless unit test** (the DoD's "unit-testable via `jsonl_writer` at a small cap"),
a bare-`RefCounted` test in the same style the docstring already promised
(`jsonl_writer.gd:6-9`), no autoload needed:

```gdscript
# tests/test_jsonl_writer_rotation.gd (new file) — run as a --script test (RefCounted
# only, no EventBus/Telemetry/scene needed) OR wrapped in the existing scene-test
# convention if the suite's harness expects .tscn; either is fine, JsonlWriter needs no
# scene tree.
var path := "user://telemetry/_test_rotation.jsonl"
_cleanup(path)
var w := JsonlWriter.new(path, 50)          # tiny cap: a handful of short lines crosses it
for i in range(10):
    w.append_line("line %d 0123456789" % i)  # ~20 bytes/line -> crosses 50B by line ~3
w.close()
assert FileAccess.file_exists(path)                    # active file present, small
assert FileAccess.file_exists(path + ".1")              # exactly one rolled generation
assert _line_count(path) < 10                           # active holds only the newest tail
assert _line_count(path) + _line_count(path + ".1") == 10  # nothing silently dropped, just moved
_cleanup(path)  # + path + ".1"
```

### §2 — `analyze_m1_2.py` argv change

```python
# before (lines 1-8):
# ... Run from repo root:  python3 tools/playtest/analyze_m1_2.py
import json, statistics
from collections import Counter, defaultdict

PATH='playtest_data/M1.2/run_log_2026-06-19.jsonl'

# after:
# ... Run from repo root:  python3 Game/tools/playtest/analyze_m1_2.py [path-to-jsonl]
#     Defaults to the frozen M1.2 round's log when no path is given (unchanged
#     behavior for the existing no-arg invocation); pass an explicit path for any
#     later round, e.g.:
#       python3 Game/tools/playtest/analyze_m1_2.py playtest_data/M1.12/run_log_YYYY-MM-DD.jsonl
import sys, json, statistics
from collections import Counter, defaultdict

DEFAULT_PATH = 'playtest_data/M1.2/run_log_2026-06-19.jsonl'
PATH = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH
```

Nothing below line 8 changes — `PATH` is read exactly once (`for line in open(PATH):`,
line 12) so the rest of the 156-line script is untouched. Running with **no** args
reproduces today's exact M1.2 output byte-for-byte (behavior-preserving default);
running with an explicit path lets any future round (M1.9/M1.11/M1.12 data, all already
sitting in `playtest_data/`) analyze without a source edit.

---

## Open Questions

1. **Per-session vs. size-cap (the version's headline call for this task).** I recommend
   **size-cap** (§1 above) — it directly targets the documented bug ("never truncating,"
   `jsonl_writer.gd:12`), needs no `Telemetry`-level "session boundary" concept, stays
   entirely inside the one file already earmarked as the headless-testable seam, and
   matches the DoD's "at a small cap" phrasing. The rejected alternative (rotate once per
   `Telemetry._ready()`, i.e. once per real process launch) is *simpler to reason about
   in player terms* but harder to unit-test deterministically without simulating multiple
   process launches, and doesn't bound a single pathologically long session. Does the
   Director/QA want size-cap alone, or size-cap **plus** a session-boundary marker (a
   cheap additive row stamping `_session_id` at the top of every rotation, so an analyst
   can still reconstruct "which rows came from which real play session" even after a
   mid-session rotation)? I lean toward "size-cap alone is enough for M1.12's scope" since
   `_session_id` already rides every row unconditionally (`telemetry.gd:42,60`) — no new
   plumbing needed even without a marker row.
2. **Ring depth — one `.1` generation only, or deeper (`.1`, `.2`, …)?** I recommend
   **depth 1**, matching the breakdown's explicit wording ("a rolled-over `.1` file") and
   `SaveManager`'s own precedent (a single `.bak`, not a chain). Anyone who wants deeper
   history for a specific playtest round already has the real archival mechanism in use
   today — copying the log into `playtest_data/M1.<k>/` by hand at round end (as M1.1 and
   M1.2's existing fixtures show) — so a deep in-place ring would be redundant machinery.
3. **Does the exporter enumerate rolled files, or only the active one?** Recommend
   **only the active one, unchanged, for M1.12** (`TelemetryExporter` stays untouched —
   zero-diff). The one edge case this misses: a single **web** session so long it
   crosses the 2 MB cap **twice** in one sitting would silently lose the middle segment
   (rotated into `.1`, then overwritten by the next rotation before the player ever
   clicks "export"). Given the writer's own estimate of "tens of lines per run"
   (`jsonl_writer.gd:17-19`), reaching 2 MB needs on the order of hundreds of runs in one
   sitting — implausible for a play session, plausible only for an unattended long-haul
   soak test. I'd flag this as an accepted, documented limitation rather than a reason to
   extend the exporter now; revisit only if a real playtest round shows truncated web
   exports.
4. **Default path for the analysis script.** Recommend keeping the frozen
   `playtest_data/M1.2/run_log_2026-06-19.jsonl` as `DEFAULT_PATH` (exact
   behavior-preservation for the existing no-arg command everyone already knows), with
   every later round passed explicitly via `argv[1]`. The alternative (default to
   "whatever's newest in `playtest_data/`") is over-engineering for a script whose whole
   fix is "stop hardcoding" — an explicit argument is simpler and unambiguous per
   invocation.
5. **The 2 MB cap value itself is an arbitrary engineering constant**, not derived from a
   stated budget (no documented disk-quota or IndexedDB-size target exists for telemetry
   today). I'd flag this to the Director/QA as a "does this number matter" check —
   my recommendation is to leave it generous (bounds worst-case accumulation without ever
   being reachable in normal play) and revisit only if a real device shows storage
   pressure.
6. **Should `_rotate()` write a self-describing marker row into the fresh file** (e.g. an
   additive `type: "log_rotated"` row noting the previous generation's size/session,
   mirroring the additive-row convention already used throughout `telemetry.gd` for
   `CORRIDOR_SUMMARY`/`NEW_HAZARD_KILLED`/etc.) so a reader of a rotated log knows history
   continues in `.1`? This lives in `jsonl_writer.gd`, which today has **zero** schema
   awareness (it takes a pre-serialized string) — adding a marker row would either break
   that separation (writer would need to know JSON shape) or require `Telemetry` itself
   to detect "did my last append trigger a rotation" and emit the marker, which is a
   bigger seam change than this task's two-fix scope implies. I lean **no** for M1.12
   (keep `JsonlWriter` schema-blind, as designed) but flag it as a nice-to-have for
   Phase 3 to weigh.

---

## Expected debt ledger

- **Bounds an unbounded resource.** Today `jsonl_writer.gd`'s own docstring admits the
  file is "never truncat[ed]" (`jsonl_writer.gd:12`) — literally every session ever run
  on a given machine (dev box or tester box) appends into one eternal
  `user://telemetry/run_log.jsonl`. After V7: hard-bounded at ~`MAX_LOG_BYTES` active +
  one rolled `.1` generation (~2×`MAX_LOG_BYTES` worst case, default ~4 MB total),
  regardless of how many process launches or how long any one session ran.
- **Removes a per-round manual script edit.** `analyze_m1_2.py`'s hardcoded `PATH`
  (`analyze_m1_2.py:8`) required copy-pasting/hand-editing the file for every new
  playtest round (M1.9, M1.11, and any future M1.12 round). After V7, any round's log —
  including the M1.1/M1.2 data already sitting in `playtest_data/` — runs via
  `python3 Game/tools/playtest/analyze_m1_2.py <path>` with **zero source edits**; the
  no-arg default reproduces today's exact M1.2 output unchanged.
- **Honest net-LOC framing (this task is additive, not a deletion):** unlike most of
  Wave 1 (V1/V5/V9, which delete duplicated/dead surface), V7's fix is a small, well-tested
  *addition* — roughly +25-35 lines in `jsonl_writer.gd` (rotation state + `_rotate()`),
  +2 lines in `telemetry_schema.gd` (`MAX_LOG_BYTES`), a 1-line diff in `telemetry.gd`, a
  3-line diff in `analyze_m1_2.py`, and a new ~40-60 line headless unit test
  (`test_jsonl_writer_rotation.gd` or equivalent). The debt paid down is **qualitative,
  not line-count**: it closes two long-standing, explicitly-documented deferred-TODOs
  (`telemetry_schema.gd:20`'s "rotation deferred to G4 if the file grows painful," and
  `analyze_m1_2.py`'s hardcoded-path-per-round pattern) with zero behavior change to the
  telemetry content/schema and zero change to any consumer (`TelemetryExporter`, the
  dozen hardcoded-`LOG_PATH` tests) that reads the active log by its well-known name.

---

## Resolved Decisions (Phase 3)

*Fresh-eyes pass. I re-verified every factual claim in this doc directly against the
as-built code (`jsonl_writer.gd`, `telemetry_schema.gd`, `telemetry.gd:122`,
`telemetry_exporter.gd:30-31`, `save_manager.gd:38-54`, and the 11 test files that
hardcode `LOG_PATH`) before ratifying. All check out as stated. Every OQ below resolves
on merit — none of this is a vision/fun/tone/scope/date call, so nothing is kicked to the
Director; the two candidates the brief flagged as possible product calls (cap value,
exporter enumeration) are resolved here with reasoning, not deferred.**

1. **Size-cap vs. per-session rotation → size-cap, ratified.** I traced the mid-session
   toggle concern by hand: `_open()` (jsonl_writer.gd:37-54, unchanged by this design)
   calls `_file.seek_end()` then the design's new `_size_bytes := _file.get_length()`.
   `get_length()` re-reads the *actual on-disk length* every time a `JsonlWriter` is
   constructed — including the reopen after `set_enabled(false)` → `set_enabled(true)`
   (`telemetry.gd:105-110`) or after `_exit_tree` on a later process launch. So
   `_size_bytes` is never reset to 0 by a toggle or relaunch; it always reflects the true
   accumulated size before the next `append_line` decides whether to rotate. This is
   exactly the property the design claims and it is NOT fooled by the toggle scenario.
   Size-cap is confirmed as the correct policy: it is self-contained in `jsonl_writer.gd`
   (no `Telemetry`-level "session" concept needed), directly targets the documented bug
   (`jsonl_writer.gd:12`'s "never truncating"), and is deterministically unit-testable at
   a small cap exactly as the breakdown's DoD asks. **Decision: implement size-cap inside
   `jsonl_writer.gd` per §1's pseudocode, unchanged.**

2. **Ring depth → one `.1` generation, ratified.** Matches the breakdown's own wording
   ("a rolled-over `.1` file," `M1.12_Breakdown.md` R8/V7 goal) and mirrors
   `save_manager.gd:38-54`'s single `.bak` precedent exactly — verified: `_atomic_store`
   keeps exactly one backup generation via `DirAccess.copy_absolute` before the rename,
   no chain. A deeper ring is unjustified machinery for a resource whose real long-term
   archival already happens by hand (`playtest_data/M1.<k>/`, confirmed present for M1.1
   and M1.2 at `/mnt/c/source/junkyard/playtest_data/`). **Decision: depth 1, as designed.**

3. **Exporter enumeration → active log only, unchanged, ratified.** Confirmed
   `telemetry_exporter.gd:30-31,46-47,52-55` reads exactly `LOG_PATH` and nothing else —
   `has_log()` and `read_log_bytes()` have no directory-listing or glob logic to add a
   second file to. This is not a genuine product call: the exporter is triggered by a
   human clicking a browser download button mid- or end-of-session
   (`telemetry_exporter.gd:11` "must run inside a user gesture"), and `jsonl_writer.gd`'s
   own docstring estimate ("tens of lines per run," lines 17-19) means reaching the 2 MB
   cap *twice* in one sitting needs hundreds of runs without a single export click — an
   unattended soak-test pattern, not a tester workflow. Extending the exporter to zip/
   concatenate `.1` + active would touch a file whose docstring explicitly commits to
   "pure reader, zero-diff" scope creep for a practically unreachable case.
   **Decision: `TelemetryExporter` stays untouched (zero-diff). The double-rotation-in-
   one-web-session gap is an accepted, documented limitation** — add one code comment at
   `telemetry_exporter.gd`'s `LOG_PATH` constant noting the accepted gap and pointing at
   this doc, so a future reader who hits it isn't surprised. No Director flag needed.

4. **Analysis-script default path → keep the frozen M1.2 literal, ratified.** Verified
   `analyze_m1_2.py:8` and its module-scope single read (`for line in open(PATH)`, line
   12) — the two-line `sys.argv`-aware change in §2 is exactly right and
   behavior-preserving for the existing no-arg invocation everyone already runs.
   Defaulting to "newest file in `playtest_data/`" would add directory-scanning logic to
   a script whose entire fix is "stop hardcoding" — unjustified scope growth.
   **Decision: `DEFAULT_PATH = 'playtest_data/M1.2/run_log_2026-06-19.jsonl'`, `PATH =
   sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH`, exactly as designed.**

5. **The 2 MB cap value → keep 2 MB, resolved on merit (not a Director item).** No
   documented disk/IndexedDB budget exists to derive a "correct" number from, so this is
   an engineering constant, not a product decision — there is no competing constraint
   (player expectation, storage quota, support policy) for a Director to weigh against
   it. 2 MB is generous relative to the writer's own "tens of lines per run" estimate
   (thousands of runs before the cap engages) and small relative to any modern device's
   free space or browser IndexedDB quota. **Decision: `DEFAULT_MAX_BYTES = 2 * 1024 *
   1024`, mirrored as `TelemetrySchema.MAX_LOG_BYTES`, exactly as designed** — revisit
   only if a real device/browser shows storage pressure (no evidence of that today).

6. **Self-describing rotation marker row → no, ratified.** Confirmed
   `jsonl_writer.gd` has zero schema/JSON awareness today (it takes a pre-serialized
   `String` and never parses one) — the class's whole reason to exist (docstring lines
   6-9) is to be the schema-blind seam G2 unit-tests without booting `Telemetry`. Adding
   a marker row would force a choice between breaking that boundary (writer learns JSON
   shape) or growing `Telemetry` a new "did my last emit trigger a rotation" detection
   path — real surface for a case that `_session_id` (already riding every row
   unconditionally, `telemetry.gd:42,60`) already lets an analyst reconstruct
   session-vs-row grouping without any rotation-awareness at all. **Decision: no marker
   row.** `_rotate()` stays purely a file-lifecycle op with no payload opinion.

7. **New rotation test — scene-wrapped, not bare `--script` (resolving the design's
   "either is fine" ambiguity).** The design's pseudocode (§1) offers `--script` or the
   scene convention as equally acceptable. They are not: every existing test in
   `Game/tests/` — including `test_telemetry_jsonl.gd`, which also only needs
   `FileAccess`/`JSON`, no autoload — ships as a `.tscn` (`test_telemetry_jsonl.tscn` runs
   its `Node`-extending script as a scene), and the repo's standing constraint is that
   verify/knob tests run as **scenes** (`godot --headless <tscn>`), never `--script`, to
   avoid a second, inconsistent suite-invocation convention and the documented
   no-concurrent-headless-instances import-lock hazard that a stray bare-script runner
   could trip over in CI. `JsonlWriter` needing no scene tree is not a reason to break
   from the suite's uniform invocation. **Decision: `test_jsonl_writer_rotation.gd`
   extends `Node` and ships with a matching `.tscn`, run via `godot --headless
   res://tests/test_jsonl_writer_rotation.tscn`, identical in shape to
   `test_telemetry_jsonl.tscn` — never `--script`.**

**Net effect on the design:** zero changes to the pseudocode in §1/§2 — every mechanism
(size-cap, `.1` ring depth 1, unchanged exporter, unchanged script default, 2 MB cap, no
marker row) is confirmed correct on merit and ready to build as written. The only added
concreteness is (a) one explanatory code comment to add at
`telemetry_exporter.gd`'s `LOG_PATH` constant documenting the accepted double-rotation
gap, and (b) the new test must be `.tscn`-wrapped like its siblings, not a bare
`--script` test. No item needs Director review — this design is locked as of Phase 3.
