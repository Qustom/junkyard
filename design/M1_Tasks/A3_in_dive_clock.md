# A3 — In-Dive Clock (Light / Stamina), Minimal

**Summary:** A single depleting in-dive resource (a "light" meter) that drains over the course of a dive to create push-your-luck time pressure; a visible meter shows its level, and on reaching zero it raises a `timeout` event on EventBus. Timeout *handling* is out of scope (lives in task E3) — this task only owns the resource, its UI, and the trigger.

- **Parent task:** A3 (M1 greybox prototype — time-pressure resource)
- **Dependencies:** EventBus autoload (for the `timeout` signal); GameState (run-state vs meta-state separation — the clock is strictly run-state and resets per dive). No hard dependency on A1/A2, but in practice the meter lives in the dive HUD alongside the player. Consumes E3 only as the eventual listener.
- **Acceptance criterion:** A visible meter depletes over the course of a run; reaching zero raises a `timeout` event on EventBus.

## Assets needed

System (`/systems/`):
- `systems/dive_clock.gd` (+ `dive_clock.tscn`, `class_name DiveClock extends Node`) — the resource logic. Lives in the **dive/run scene** (run-state), NOT as a global autoload, so it is created and destroyed per dive. It reads tuning from a Resource and emits via EventBus.

Data / Resource (`/data/dive/`):
- `data/dive/dive_clock_config.tres` (+ `dive_clock_config.gd`, `class_name DiveClockConfig extends Resource`) — tuning: `max_light: float`, `drain_per_second: float`, optional `start_light: float`. Data-driven per project convention; lets us tune the dive length without code changes.

UI (`/ui/`):
- `ui/dive_clock_meter.tscn` (+ `dive_clock_meter.gd`) — greybox meter. A `CanvasLayer` > `Control` containing a `ProgressBar` (or a `ColorRect` whose width/modulate is scaled by fraction). Anchored to a screen corner. Displays the current light fraction; turns a warning color (e.g. red) under a low threshold. Pure view — driven by an EventBus signal, holds no authoritative state.

GameState (`/systems/game_state.gd`):
- Run-state should hold the *config reference* or seed for the clock, and the clock writes nothing to meta-state. On dive start GameState (or the dive scene) constructs/resets `DiveClock`. Confirm whether GameState mirrors current light for save/telemetry, or whether the clock is purely transient (recommended transient for M1).

EventBus signals to add (`/systems/event_bus.gd`):
```gdscript
signal dive_clock_changed(current: float, maximum: float)  # for the meter UI
signal dive_clock_timeout()                                 # the required "timeout" event
signal dive_started()                                       # may already exist; resets clock
signal dive_ended()                                         # stop draining on extract/death
```

If a generic `timeout` name is preferred over `dive_clock_timeout`, lock it now since E3 listens for it. Telemetry (opt-in) can subscribe to `dive_clock_timeout` and `dive_clock_changed` via EventBus without the clock knowing.

## Code to generate

One core script plus a thin UI script. `DiveClock` holds `_current` light, decrements it by `drain_per_second * delta` each frame while active, emits `dive_clock_changed` (throttled or per-frame), and emits `dive_clock_timeout` exactly once when it crosses zero, then deactivates. It listens to `dive_started`/`dive_ended` on EventBus to reset/stop, keeping it decoupled from the dive flow. The clock is the single source of truth; the meter is a passive listener.

```gdscript
class_name DiveClock
extends Node

@export var config: DiveClockConfig

var _current: float = 0.0
var _active: bool = false
var _fired_timeout: bool = false

func _ready() -> void:
    EventBus.dive_started.connect(_on_dive_started)
    EventBus.dive_ended.connect(_on_dive_ended)
    # If the dive is already running when this node enters, caller can _on_dive_started().

func _on_dive_started() -> void:
    _current = config.start_light if config.start_light > 0.0 else config.max_light
    _active = true
    _fired_timeout = false
    EventBus.dive_clock_changed.emit(_current, config.max_light)

func _on_dive_ended() -> void:
    _active = false  # extract/death stops the drain; no timeout fired

func _process(delta: float) -> void:
    if not _active:
        return
    _current = max(0.0, _current - config.drain_per_second * delta)
    EventBus.dive_clock_changed.emit(_current, config.max_light)
    if _current <= 0.0 and not _fired_timeout:
        _fired_timeout = true
        _active = false
        EventBus.dive_clock_timeout.emit()   # E3 handles consequences
```

```gdscript
# data/dive/dive_clock_config.gd
class_name DiveClockConfig
extends Resource

@export var max_light: float = 90.0          # ~90s baseline dive budget
@export var start_light: float = 0.0         # 0 => use max_light
@export var drain_per_second: float = 1.0    # 1 unit/sec => max_light == seconds
```

```gdscript
# ui/dive_clock_meter.gd
extends Control

@onready var bar: ProgressBar = $ProgressBar
@export var warn_fraction: float = 0.25

func _ready() -> void:
    EventBus.dive_clock_changed.connect(_on_changed)

func _on_changed(current: float, maximum: float) -> void:
    bar.max_value = maximum
    bar.value = current
    var frac := current / maximum if maximum > 0.0 else 0.0
    bar.modulate = Color.RED if frac <= warn_fraction else Color.WHITE
```

Note: emitting `dive_clock_changed` every physics/idle frame is cheap for one bar; if Telemetry logs it, throttle to e.g. 4 Hz or log only on threshold crossings to avoid JSONL spam. Drives off `_process` (idle) so the meter is smooth; gameplay consequences are frame-rate independent enough at this scale, but `_physics_process` is an acceptable alternative if other timed systems align there.

## Open questions

- **Naming lock — `timeout` vs `dive_clock_timeout`:** E3 must listen to the exact signal name. Pick one now (the brief says "`timeout` event") and make EventBus match before E3 starts.
  - **Recommendation:** Lock `dive_clock_timeout()` as the canonical EventBus signal name. The bare `timeout` is too generic (collides conceptually with Godot's `Timer.timeout` and risks ambiguity as more systems are added), while `dive_clock_*` matches the namespaced sibling signals already proposed (`dive_clock_changed`). Document in EventBus that "the timeout event" === `dive_clock_timeout` so E3 binds the exact name.
- **Tuning — dive length & drain curve:** `max_light`/`drain_per_second` are placeholders (~90s). The whole M1 thesis is the dive-deeper-vs-extract tension, so this budget needs heavy playtesting. Also: linear drain vs. faster drain deeper / pickups that refill light? M1 likely linear, but confirm whether junk or descending modifies the clock.
  - **Recommendation:** Start with a SHORTER budget than 90s — set `max_light = 60`, `drain_per_second = 1.0` (60s/dive) so the ~30s decision window is reached quickly and playtest iterations are fast. Use pure linear drain for M1 and have junk pickup NOT modify the clock; make descending the only thing that costs light later (deeper = less budget remaining), which is the cleanest expression of the push-your-luck tension. This is the single most playtested number in M1 — treat 60 as a starting dial, not a commitment.
- **Light as fuel vs. pure timer:** Is "light" purely a countdown, or can the player spend/restore it (e.g. extraction refuels, descending costs)? Affects whether `DiveClock` exposes `add_light()`/`drain()` mutators now. Recommend adding a guarded `add_light(amount)` hook even if unused in M1.
  - **Recommendation:** Model light as fuel (spendable/restorable), not a pure timer — this is the design space the push-your-luck loop will eventually use. Add a single guarded `modify_light(amount: float)` method now (clamps to `[0, max_light]`, emits `dive_clock_changed`, and triggers the timeout path if it crosses zero) covering both `add` and `drain`. Leave it unused by M1 gameplay but wired, so descending-costs-light / extract-refuel can drop in later without touching the core loop.
- **Pause / menu behavior:** Should the clock keep draining during pause or inventory screens? Tie to `get_tree().paused` and the node's `process_mode`. Decide whether the clock is `PAUSABLE` (stops with the game) — almost certainly yes.
  - **Recommendation:** Yes — set `DiveClock.process_mode = PROCESS_MODE_PAUSABLE` (the default) so it stops draining whenever `get_tree().paused` is true. Pausing the tree freezes the drain automatically with no extra code. The pause menu / any future inventory screen should be the node that sets `get_tree().paused = true`, and that menu UI itself runs as `PROCESS_MODE_WHEN_PAUSED`. Draining through a pause would feel unfair and adds nothing to the M1 thesis.
- **Reset ownership:** Does GameState own dive start/reset and emit `dive_started`, or does the dive scene? Clock listens to EventBus either way, but the emitter must be unambiguous so the clock initializes exactly once per dive.
  - **Recommendation:** GameState owns the run lifecycle and is the SOLE emitter of `dive_started`/`dive_ended` — it resets run-state then emits, exactly once per dive. The dive scene is just where `DiveClock` lives; it never emits these itself, only listens. This single-owner rule prevents double-init (two emitters resetting the clock) and keeps the guard in the next question reliable. The dive scene may call a GameState method (`GameState.start_dive()`) that performs the reset-then-emit, but the emit stays in GameState.
- **Multiple zero-cross safety:** `_fired_timeout` guards against re-emitting; confirm there is no path where a dive restarts without `dive_started` re-firing (which resets the guard).
  - **Recommendation:** The guard is correct AS LONG AS the single-owner rule above holds — every dive (including restart-after-death) routes through `GameState.start_dive()` → `dive_started`, which sets `_fired_timeout = false`. To make this robust against a misfire, reset the guard in `_on_dive_started` (already done) AND defensively in any restart path; and since `DiveClock` is recommended to be created/destroyed per dive (not an autoload), a fresh node also starts with `_fired_timeout = false` by default. Both paths converge on "guard always reset before a new dive can deplete," so there is no double-emit path.
