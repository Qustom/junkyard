# G1 — Wire M1 Telemetry Events

**Summary:** Hook the `Telemetry` autoload to listen on `EventBus` and write M1-relevant gameplay events to a local JSONL log so run-length and economy validation can be computed offline.

- **Parent task:** G1 (M1 breakdown)
- **Dependencies:** E1 (run lifecycle / GameState run state), E3 (banking + currency flow), C2 (band/depth progression)
- **Acceptance criterion:** A completed run produces structured JSONL containing run duration, end cause, band depth reached, and haul banked/lost; the opt-in telemetry toggle is respected (no file writes when off).

---

## Assets needed

Feature-first layout. New and touched files:

- `/systems/telemetry/telemetry.gd` — the `Telemetry` autoload (already registered as an autoload per project architecture); this task implements its M1 listener + writer behavior.
- `/systems/telemetry/telemetry_schema.gd` — small const/enum module defining event type names and the JSONL schema version, imported by `telemetry.gd` and reused by G2 tests and G4 analysis.
- `/systems/telemetry/jsonl_writer.gd` — thin append-only file writer (open on first event, buffered, flushed on `run_ended` and on `tree_exiting`). Kept separate so it can be unit-tested without the full autoload.
- `/systems/core/event_bus.gd` — confirm/extend the M1 signal surface (see signals below). No new architecture, just ensure the signals exist and are emitted by E1/E3/C2 owners.
- `/systems/settings/settings.gd` + settings UI — the opt-in `telemetry_enabled` toggle (default **off**) persisted via `SaveManager`. The settings screen needs a clearly labeled checkbox plus one line of copy explaining what is logged and that no PII is collected.
- Log output path: `user://telemetry/run_log.jsonl` (Godot `user://` resolves to the per-OS app-data dir). One rolling file for M1; rotation deferred.
- No CI workflow file is required for G1 itself, but the JSONL schema doc here is the contract that G2 (`/tests`) and G4 (analysis) build against.

---

## Code to generate

**Classes / signals / configs to produce:**

- `EventBus` signals consumed by Telemetry (typed):
  - `run_started(run_id: String, seed: int, tier_label: String)`
  - `run_ended(run_id: String, cause: String, duration_s: float, banked_total: int, lost_total: int, max_depth: int)`
  - `junk_picked_up(run_id: String, item_id: String, value: int, depth: int)`
  - `junk_banked(run_id: String, value: int, depth: int)` — emitted on successful extract
  - `junk_lost(run_id: String, value: int, depth: int, cause: String)` — emitted on death/forfeit
  - `band_depth_reached(run_id: String, depth: int)` — fired once per new max depth
- `Telemetry` autoload responsibilities: read the opt-in flag, connect the above signals, normalize each into a schema row, append via `JsonlWriter`. It must **derive nothing it can get from the event** and only stamp wall-clock time + monotonic time + schema version.
- `telemetry_schema.gd` exposes `SCHEMA_VERSION := 1` and an `EventType` enum/string set so producers and tests share constants.

**JSONL event schema (one JSON object per line):**

Common envelope on every row:

```
{
  "v": 1,                       // schema version
  "ts": "2026-06-15T14:02:31Z", // wall clock, UTC ISO-8601
  "t_ms": 18342,                // monotonic ms since run_started (0 for run_started)
  "run_id": "r_a1b2c3",         // stable per-run id (GameState)
  "session_id": "s_88f0",       // stable per-process id
  "type": "junk_picked_up",     // EventType
  "data": { ... }               // type-specific payload
}
```

Sample lines for one short run:

```
{"v":1,"ts":"2026-06-15T14:02:13Z","t_ms":0,"run_id":"r_a1b2c3","session_id":"s_88f0","type":"run_started","data":{"seed":774411,"tier_label":"15min"}}
{"v":1,"ts":"2026-06-15T14:02:20Z","t_ms":7100,"run_id":"r_a1b2c3","session_id":"s_88f0","type":"band_depth_reached","data":{"depth":1}}
{"v":1,"ts":"2026-06-15T14:02:24Z","t_ms":11020,"run_id":"r_a1b2c3","session_id":"s_88f0","type":"junk_picked_up","data":{"item_id":"scrap_coil","value":12,"depth":1}}
{"v":1,"ts":"2026-06-15T14:02:31Z","t_ms":18342,"run_id":"r_a1b2c3","session_id":"s_88f0","type":"band_depth_reached","data":{"depth":2}}
{"v":1,"ts":"2026-06-15T14:02:45Z","t_ms":32500,"run_id":"r_a1b2c3","session_id":"s_88f0","type":"junk_lost","data":{"value":12,"depth":2,"cause":"death"}}
{"v":1,"ts":"2026-06-15T14:02:45Z","t_ms":32510,"run_id":"r_a1b2c3","session_id":"s_88f0","type":"run_ended","data":{"cause":"death","duration_s":32.5,"banked_total":0,"lost_total":12,"max_depth":2}}
```

`run_ended.cause` enum for M1: `"extract"`, `"death"`, `"quit"`, `"timeout"`.

**Telemetry listener pseudocode (GDScript-flavored):**

```gdscript
extends Node
# Autoload: Telemetry

const Schema = preload("res://systems/telemetry/telemetry_schema.gd")
const JsonlWriter = preload("res://systems/telemetry/jsonl_writer.gd")

var _enabled: bool = false
var _writer: JsonlWriter = null
var _session_id: String = ""
var _run_t0_ms: int = 0

func _ready() -> void:
    _session_id = "s_" + _short_id()
    _enabled = Settings.telemetry_enabled            # opt-in, default false
    Settings.telemetry_toggled.connect(_on_toggle)
    EventBus.run_started.connect(_on_run_started)
    EventBus.run_ended.connect(_on_run_ended)
    EventBus.junk_picked_up.connect(_on_pickup)
    EventBus.junk_banked.connect(_on_banked)
    EventBus.junk_lost.connect(_on_lost)
    EventBus.band_depth_reached.connect(_on_depth)

func _on_toggle(value: bool) -> void:
    _enabled = value
    if not _enabled and _writer != null:
        _writer.close()          # stop writing immediately; keep existing file

func _emit(type: String, run_id: String, data: Dictionary) -> void:
    if not _enabled:
        return
    if _writer == null:
        _writer = JsonlWriter.new("user://telemetry/run_log.jsonl")
    var row := {
        "v": Schema.SCHEMA_VERSION,
        "ts": Time.get_datetime_string_from_system(true) + "Z",  # UTC
        "t_ms": Time.get_ticks_msec() - _run_t0_ms,
        "run_id": run_id,
        "session_id": _session_id,
        "type": type,
        "data": data,
    }
    _writer.append_line(JSON.stringify(row))

func _on_run_started(run_id: String, seed: int, tier_label: String) -> void:
    _run_t0_ms = Time.get_ticks_msec()
    _emit(Schema.RUN_STARTED, run_id, {"seed": seed, "tier_label": tier_label})

func _on_run_ended(run_id, cause, duration_s, banked_total, lost_total, max_depth) -> void:
    _emit(Schema.RUN_ENDED, run_id, {
        "cause": cause, "duration_s": duration_s,
        "banked_total": banked_total, "lost_total": lost_total,
        "max_depth": max_depth,
    })
    if _writer != null:
        _writer.flush()

func _on_pickup(run_id, item_id, value, depth) -> void:
    _emit(Schema.JUNK_PICKED_UP, run_id, {"item_id": item_id, "value": value, "depth": depth})

func _on_banked(run_id, value, depth) -> void:
    _emit(Schema.JUNK_BANKED, run_id, {"value": value, "depth": depth})

func _on_lost(run_id, value, depth, cause) -> void:
    _emit(Schema.JUNK_LOST, run_id, {"value": value, "depth": depth, "cause": cause})

func _on_depth(run_id, depth) -> void:
    _emit(Schema.BAND_DEPTH_REACHED, run_id, {"depth": depth})

func _exit_tree() -> void:
    if _writer != null:
        _writer.flush()
        _writer.close()
```

`JsonlWriter` is intentionally dumb: `new(path)` ensures the dir exists and opens in append mode; `append_line(s)` writes `s + "\n"`; `flush()`/`close()` for durability. This is the seam G2 tests exercise directly (write rows, read back, assert parseable JSON + field presence).

---

## Open questions

- **Schema fields:** Do we need per-pickup `item_id` granularity in M1, or is aggregate value enough? Including it costs nothing now and helps later balance, but it is the only field bordering on "content data."
  - **Recommendation:** Keep `item_id` in the per-pickup event. It is a low-cardinality categorical (a handful of greybox junk types, not a UGC/per-instance ID), which is exactly the kind of field analytics guidance says is safe and useful to retain — you can always aggregate by type later, but you cannot recover detail you never logged. It is not PII and adds negligible cost. ([source](https://www.gameanalytics.com/reports/event-design-tracking-guide-for-gameanalytics))
- **`junk_banked` shape:** Emit one event per banked item, or a single roll-up at extract time? The sample above logs the roll-up in `run_ended`; decide whether the per-item `junk_banked` signal is wired in M1 or deferred.
  - **Recommendation:** Wire `junk_banked` as one event per banked item in M1, and keep the `banked_total` roll-up in `run_ended` as a cross-check. The per-item events are what feed the drop-off funnel and "banked anything vs. died with a haul" metric in G4; the roll-up alone cannot reconstruct depth-of-bank distribution. Volume is trivial for greybox runs, so there is no reason to defer.
- **Run id / session id source:** Confirm `GameState` owns `run_id` generation and that it is stable across the whole run (not regenerated on scene reload). Where does `session_id` live — `GameState` or `Telemetry`?
  - **Recommendation:** `GameState` owns `run_id`: generate it once when the run begins (alongside the seed) and store it as run state so it survives scene reloads — never mint it in a scene `_ready()`. `session_id` lives in `Telemetry` (set once in its `_ready()` for the process lifetime), since it is a logging-infrastructure concern, not gameplay state, and `Telemetry` already outlives individual runs as an autoload.
- **Flush cadence vs. crash safety:** Flush only on `run_ended` (cheap, but a crash mid-run loses the run) vs. flush every N events. For greybox M1, run-end flush is probably fine — confirm.
  - **Recommendation:** Flush on `run_ended` and on `tree_exiting` for M1, but also flush opportunistically on the rare high-value events (`band_depth_reached`, `junk_banked`) so a mid-run crash still preserves the funnel-defining moments. Event volume per run is tiny (tens of lines), so the cost of these extra flushes is negligible and it buys real crash safety — a crash is exactly when you most want the data. Proper flush-before-exit lifecycle handling is the single most common cause of dropped logs. ([source](https://opentelemetry.io/docs/languages/dotnet/logs/best-practices/))
- **Toggle semantics on mid-run disable:** If a tester disables telemetry mid-run, do we keep the partial run already written, or is partial data acceptable? Current pseudocode keeps it.
  - **Recommendation:** Keep the partial data already on disk (current pseudocode behavior) and stop writing immediately. Disabling means "stop collecting from now on," not "retroactively erase"; the rows already written were captured under consent in effect at the time, contain no PII, and the G4 analysis already keys on complete `run_started..run_ended` pairs so an incomplete run is simply skipped as noise. Surface this clearly in the toggle copy ("stops future logging; does not delete past logs").
- **`user://` discoverability:** Testers will need the log path to send results back. Should the settings screen show/copy the resolved `OS.get_user_data_dir()` path, or do we add an "export telemetry" button? (Touches G4 collection.)
  - **Recommendation:** Do both, cheaply: show the resolved `user://telemetry/` path next to the toggle with a "Copy path" button and an "Open log folder" button (`OS.shell_open(ProjectSettings.globalize_path("user://telemetry/"))`). This is a few lines and removes the single biggest friction point in manual JSONL return for non-technical testers; a dedicated "export/zip" button is overkill for one rolling file in M1 and can be deferred to G4 if collection proves painful.
