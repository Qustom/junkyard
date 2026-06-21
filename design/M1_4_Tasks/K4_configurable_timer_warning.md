# K4 — Configurable timer + near-end warning · Phase-2 Design

**Task:** K4 (M1.4, Wave 2). **Role:** `general-purpose` (programmer — DiveClock + run-start wiring) **+ `ui-ux-designer`** (the HUD warning cue). One shared worklog.
**BlockedBy:** K0 (reads K0-declared `timer_*` knobs + emits the K0-declared `dive_clock_warning` signal).
**Blocks:** RG1 (the re-gate build reads the warning cue + the config-marked telemetry).
**Authored:** 2026-06-21, Phase 2 of the four-phase process (`CLAUDE.md`), from `design/M1_4_Tasks/M1.4_Breakdown.md` §3/§7 and `design/M1_4_Tasks/K0_foundation_knobs_signals.md` (the locked knob/signal contract).

> **Director work-order (verbatim):** *"Make the timer configurable. Also add a threshold near the end of the timer which makes it put out a warning that time is almost up."*
>
> **What this doc delivers:** (1) the dive-clock **length** surfaced as a run-scoped, config-marked, telemetry-visible knob (`timer_length_s`) read at run start; (2) a **near-end warning** that fires **exactly once** as remaining light crosses a threshold (`timer_warning_threshold_s`), debounced with a `_fired_warning` latch mirroring the existing `_fired_timeout` latch; (3) the new `EventBus.dive_clock_warning(...)` signal (K0 pre-declared) and a **HUD warning cue** (visual flash/colour, optional audio).
>
> **The load-bearing invariant:** **all-off behaviour is byte-identical.** `timer_enabled=false` (default) ⇒ the DiveClock uses today's `DiveClockConfig` length and emits **no** warning ⇒ the M1.0/M1.3 clock is unchanged, the all-off fingerprint `e943ac9c8bc1` is untouched (the clock is post-generation run-state and never feeds `fingerprint()`).

---

## (a) Research — the as-built surface K4 extends

### A.1 `DiveClock` (`systems/dive_clock.gd`) — the run-state clock K4 modifies

- **Lifecycle + run-state contract** (`dive_clock.gd:1-24`). The clock is a **per-dive run-state Node, NOT an autoload** — created/destroyed each dive, so *"a fresh node always starts with its guards reset"* (`:6-8`). It connects three EventBus signals in `_ready()` (`:35-41`): `run_started` → reset+start, `run_ended` → stop, `exposure_clock_tax` → R3 tax consumer. **K4 adds no new `_ready` connection** — it reads its length from the run config at the existing `_on_run_started` edge and emits the warning from inside the existing `modify_light()` mutator.

- **The drain loop** (`:63-66`): `_process(delta)` early-returns when `not _active`, else calls `modify_light(-config.drain_per_second * delta)`. **Per-frame drain is the key constraint for the warning latch** — at `drain_per_second=1.0` and 60 fps the clock crosses any threshold inside a single 1/60 s step, so the warning MUST be edge-debounced exactly like the timeout, or it would re-fire every frame below the threshold.

- **The single guarded mutator** (`modify_light`, `:84-92`) — the canonical pattern K4 copies:
  ```gdscript
  func modify_light(amount: float) -> void:
      if config == null:
          return
      _current = clampf(_current + amount, 0.0, config.max_light)
      EventBus.dive_clock_changed.emit(_current, config.max_light)
      if _current <= 0.0 and not _fired_timeout:   # ← the EXACT pattern K4 mirrors for the warning
          _fired_timeout = true
          _active = false
          EventBus.dive_clock_timeout.emit()
  ```
  The timeout uses a **one-shot latch** `_fired_timeout` (`:30`, set true at `:90`) so `dive_clock_timeout` fires **exactly once** even though the clock keeps being mutated/clamped at 0. **K4 adds a parallel `_fired_warning` latch** with the identical discipline. Note: `modify_light` is the **single** mutator — both the `_process` drain AND the R3 `exposure_clock_tax` (`:73-76`) flow through it, so putting the warning check here automatically covers a tax-driven crossing too (a tax that drops the clock past the threshold also warns — correct).

- **Reset edge** (`_on_run_started`, `:46-53`): sets `_current` from config, `_active=true`, `_fired_timeout=false`, then emits the initial `dive_clock_changed`. **K4 extends this**: (i) reset `_fired_warning=false`; (ii) apply the `timer_length_s` override to the effective length (A.4 below); (iii) handle the "started already below threshold" edge (OQ-2).

- **Read-only accessors** (`:96-105`): `get_light()`, `get_max_light()`, `is_active()` — K4 needs no new accessor (the warning carries its payload in the signal).

### A.2 `DiveClockConfig` (`data/dive/dive_clock_config.gd`) — the authored length

- `class_name DiveClockConfig extends Resource` with three `@export`s: `max_light = 60.0` (*"1 unit/sec ⇒ max_light == seconds"*, `:12-13`), `start_light = 0.0` (`0 ⇒ start full`, `:15-17`), `drain_per_second = 1.0` (`:19-20`). The doc names 60 *"the single most-playtested number in M1 — treat 60 as a dial"* (`:9-10`). This is **already data-authored** — the length is editable in the `.tres` today. K4's job is **not** to make it editable (it is); it is to surface it **on the run-scoped, config-marked, per-run-telemetry axis** RG2 segments on (see OQ-1 / the recommendation).

- Because `drain_per_second` defaults to `1.0`, **`max_light` reads as seconds** and a "seconds-remaining" warning threshold is directly comparable to `_current`. If `drain_per_second != 1.0` the warning threshold is still in **light-units**, not wall-clock seconds (OQ-3 covers the naming/semantics).

### A.3 `EventBus` clock signals + the K0 pre-declared warning signal

- Existing: `dive_clock_changed(current: float, maximum: float)` (`event_bus.gd:36`), `dive_clock_timeout()` (`:37`). Primitives-only (telemetry-safe).
- **K0 pre-declares** (locked in `K0_foundation_knobs_signals.md` §B.3):
  ```gdscript
  # --- K4 Timer warning --------------------------------------------------------
  ## Fires ONCE when remaining dive time crosses the near-end warning threshold.
  signal dive_clock_warning(seconds_remaining: float)
  ```
  **K4 only EMITS this — it never edits `event_bus.gd`** (the M1.1 pre-declare rule, Breakdown §6). **One refinement request to fold back into K0 (OQ-4):** I recommend the signal also carry `maximum` for HUD-fraction symmetry with `dive_clock_changed` — i.e. `dive_clock_warning(seconds_remaining: float, maximum: float)`. Per the K0 doc's own OQ-8 ("dependent designs feed name/type corrections back into K0 before it is dispatched"), this is exactly the kind of correction K0 expects; see OQ-4 for the trade-off and my recommendation.

### A.4 The K0 `timer_*` knobs K4 reads (locked contract)

From `K0_foundation_knobs_signals.md` §B.1 (`@export_group("K4 Timer", "timer_")`):
```gdscript
@export var timer_enabled: bool = false                 # OFF = today's DiveClockConfig length, no warning
@export var timer_length_s: float = 0.0                 # 0.0 = use the existing DiveClockConfig default
@export var timer_warning_threshold_s: float = 0.0      # seconds-remaining the warning fires at; 0.0 = no warning
@export_enum("visual_only", "visual_audio") var timer_warning_channel: int = 0
```
All default **off/neutral** → a fresh `RunConfig.new()` reproduces M1.0. These land in `to_flat_dict()` (K0 §B.2) so RG2 sees the per-run length + threshold + channel on the `run_started` telemetry row.

**How K4 reaches the run config from DiveClock.** The clock is a run-state node; the run config lives on `GameState.active_run_config` (the read-only accessor the HUD already uses, `decision_hud.gd:283-284`: `var cfg: RunConfig = GameState.active_run_config`). K4 reads it the same way at the `_on_run_started` edge. **It does NOT take the config via the `run_started` signal args** (those are `band_id, seed` only, `event_bus.gd:9`) — it reads `GameState.active_run_config` directly, exactly as `decision_hud._r2_enabled()` does.

### A.5 The two HUD surfaces a warning cue can live in

- **`ui/hud/decision_hud.gd` (`DecisionHUD`, E2)** — the in-dive decision surface, *"the centrepiece of the M1 'is it fun?' gate"* (`:3-7`). **PURE PROJECTION** — owns no source of truth. It already subscribes to `dive_clock_changed` (`:93`, handler `:142-148`), already owns the clock bar (`_clock_bar`, `:77`), the urgency colour ramp (`_urgency_color`, `:183-187`), the green→amber→red constants (`:54-56`), an off-ladder **toll-pulse** colour + a re-triggering pulse Tween for the R2 toll (`CLOCK_TOLL_PULSE` `:61`, `_pulse_clock_bar()` `:206-212`), and a HUD-space shake (`_shake_root()` `:263-277`). **This is the natural home for the K4 warning cue** — the warning is a one-shot, more emphatic sibling of the existing R2 clock-toll pulse on the bar the player already watches, and it can be gated on `timer_enabled` exactly like the I3 cues are gated on `_r2_enabled()`/`_r3_enabled()`. All strings go through `tr()` against `ui/hud/hud_strings.csv` (`:23`).

- **`ui/dive_clock_meter.gd` (`DiveClockMeter`, A3)** — a *second, simpler* greybox view of the same clock. It also subscribes to `dive_clock_changed` (`:17`) and already has a `warn_fraction` (`@export var warn_fraction: float = 0.25`, `:13`) that turns its bar **red** under 25% (`:24`). **This is a pre-existing, FRACTION-based, CONTINUOUS, passive low-light tint — NOT a one-shot event.** It is *related to but distinct from* K4's warning: K4 is a **discrete, debounced, signal-driven "time's almost up" punch**, not a steady colour state. K4 should **not** be confused with or fold into `warn_fraction` (it is a different channel; see OQ-2 on fraction-vs-seconds and the relationship). K4 *may* optionally also react in this meter, but the primary cue lives in `DecisionHUD` (the surface the gate watches).

### A.6 `light_low()` — the dead pre-existing signal (reuse or supersede?)

- `EventBus.light_low()` is **declared** (`event_bus.gd:23`, an A3-era "in-dive clock" signal alongside `stamina_low`) and is **connected** in `AudioDirector._ready()` → `_on_tension()` (`audio_director.gd:18`, `:24-25`), **but it is NEVER EMITTED anywhere in the codebase** (verified: the only two hits for `light_low` are the declaration and the AudioDirector connection — no `.emit(`). So `light_low()` is a **dead, never-fired signal with an existing audio consumer wired to it**: `_on_tension()` is a stub (`# TODO(M2): nudge interactive transition / stinger`).
- This is directly relevant to the work-order's audio half: there is an **already-wired (stubbed) audio hook** waiting for a "light is low" event. K4's warning is precisely that event. **OQ-3 resolves whether K4 emits `light_low()` (reusing the dead signal + its AudioDirector hook) or emits only the new typed `dive_clock_warning(...)` and supersedes `light_low()`.** Recommendation in (c): **emit the new typed `dive_clock_warning` as the source of truth, AND have AudioDirector subscribe to it** (moving the existing `_on_tension` connection from the dead `light_low` to the live `dive_clock_warning`), retiring `light_low` — one signal, carrying a payload, with the audio hook re-pointed.

---

## (b) Pseudocode — illustrative, against the real as-built APIs

> Two edit sites: **`systems/dive_clock.gd`** (programmer — the latch + length override + emit) and **`ui/hud/decision_hud.gd`** (ui-ux — the cue). Plus optional one-liners in `systems/audio_director.gd` (re-point the audio hook) and `ui/hud/hud_strings.csv` (the warning string).

### B.1 `DiveClock` — length override + the warning latch

```gdscript
# systems/dive_clock.gd — additions (all gated so timer_enabled=false ⇒ M1.0 behaviour)

var _current: float = 0.0
var _active: bool = false
var _fired_timeout: bool = false
var _fired_warning: bool = false          # NEW — one-shot warning latch, mirrors _fired_timeout
var _warning_threshold: float = 0.0        # NEW — resolved seconds-remaining; 0.0 ⇒ no warning this run
var _effective_max: float = 0.0            # NEW — config.max_light OR the timer_length_s override


func _on_run_started(_band_id: StringName = &"", _seed: int = 0) -> void:
    if config == null:
        push_error("DiveClock: no config assigned; cannot start.")
        return

    # --- K4: resolve the effective length + warning threshold from the run config ---
    _effective_max = config.max_light                 # default = today's authored length
    _warning_threshold = 0.0                          # default = no warning (all-off control)
    var cfg: RunConfig = GameState.active_run_config  # same accessor decision_hud uses (:283)
    if cfg != null and cfg.timer_enabled:
        if cfg.timer_length_s > 0.0:
            _effective_max = cfg.timer_length_s       # 0.0 ⇒ keep DiveClockConfig.max_light (OQ-1)
        _warning_threshold = cfg.timer_warning_threshold_s   # 0.0 ⇒ still no warning

    # start_light semantics unchanged, but "full" now means the EFFECTIVE max:
    _current = config.start_light if config.start_light > 0.0 else _effective_max
    _active = true
    _fired_timeout = false
    _fired_warning = false
    # K4 edge case (OQ-2): if the dive somehow STARTS at/below the threshold (e.g. a tiny
    # timer_length_s, or start_light already low), arm the latch as already-fired so we never
    # warn on the very first frame — the warning is a "running low" cue, not a "you start low" cue.
    if _warning_threshold > 0.0 and _current <= _warning_threshold:
        _fired_warning = true

    EventBus.dive_clock_changed.emit(_current, _effective_max)   # max is now the effective max


func _process(delta: float) -> void:
    if not _active:
        return
    modify_light(-config.drain_per_second * delta)   # unchanged — drain still flows through the mutator


func modify_light(amount: float) -> void:
    if config == null:
        return
    _current = clampf(_current + amount, 0.0, _effective_max)     # clamp to the EFFECTIVE max
    EventBus.dive_clock_changed.emit(_current, _effective_max)

    # --- K4: near-end warning — fire EXACTLY ONCE as we cross the threshold (debounced) ---
    # Ordered BEFORE the timeout block so a single mutation that blows past the threshold
    # straight to zero still emits the warning before the timeout (legible "almost → gone").
    if _warning_threshold > 0.0 and not _fired_warning and _current <= _warning_threshold:
        _fired_warning = true
        EventBus.dive_clock_warning.emit(_current, _effective_max)   # OQ-4: payload incl. max

    if _current <= 0.0 and not _fired_timeout:
        _fired_timeout = true
        _active = false
        EventBus.dive_clock_timeout.emit()


func get_max_light() -> float:
    # K4: report the EFFECTIVE max (used by HUD/tests) — falls back to config when no override.
    return _effective_max if _effective_max > 0.0 else (config.max_light if config != null else 0.0)
```

**Why the latch is correct under per-frame drain.** `_fired_warning` flips true on the first frame `_current <= _warning_threshold` and never resets until the next `_on_run_started`. Subsequent sub-threshold frames skip the emit (`not _fired_warning` is false) — identical discipline to `_fired_timeout`. A refuel back above the threshold (R3 over-tax + extract-refuel are future seams) does **not** re-arm it within a dive — that matches the timeout's once-per-dive semantics; re-arming on refuel is explicitly out of scope (note it in the worklog).

### B.2 `DecisionHUD` — the one-shot warning cue (visual flash, optional audio gate handled in AudioDirector)

```gdscript
# ui/hud/decision_hud.gd — additions

## K4: off-ladder one-shot "time almost up" punch colour (hotter/longer than the R2 toll pulse).
const CLOCK_WARNING_PULSE := Color(1.0, 0.35, 0.30)   # alarm red-white; distinct from CLOCK_TOLL_PULSE
@export var warning_pulse_seconds: float = 0.8        # longer than clock_pulse_seconds (0.35) — it's an alarm
@export var warning_flash_count: int = 3              # blink N times so it reads as a discrete alert
var _warning_tween: Tween

func _ready() -> void:
    ...
    EventBus.dive_clock_warning.connect(_on_dive_clock_warning)   # K4 — the one-shot near-end warning
    ...

## K4: project the already-emitted dive_clock_warning. Gated on timer_enabled so an all-off run
## never shows it (= M1.0 HUD). VISUAL is always on when enabled; AUDIO is AudioDirector's job,
## gated separately on timer_warning_channel (B.4) — keeps the HUD a pure-visual surface.
func _on_dive_clock_warning(_seconds_remaining: float, _maximum: float) -> void:
    if not _timer_enabled():
        return
    _flash_warning()
    # Optional: a transient tr("HUD_TIME_LOW") banner near the clock, reusing the
    # _spawn_cost_indicator(...) float-and-fade pattern (decision_hud.gd:217-244) for a
    # "TIME LOW" label — text channel alongside the colour channel (readability rule).

func _flash_warning() -> void:
    if _warning_tween != null and _warning_tween.is_valid():
        _warning_tween.kill()
    _warning_tween = create_tween()
    for i in range(warning_flash_count):
        _warning_tween.tween_property(_clock_bar, "modulate", CLOCK_WARNING_PULSE,
            warning_pulse_seconds / float(warning_flash_count) * 0.5)
        _warning_tween.tween_property(_clock_bar, "modulate",
            _urgency_color(_clock_fraction), warning_pulse_seconds / float(warning_flash_count) * 0.5)
    # settle back onto the live drain colour (the steady amber/red ramp continues afterward).

func _timer_enabled() -> bool:
    var cfg: RunConfig = GameState.active_run_config   # mirrors _r2_enabled()/_r3_enabled() (:282-289)
    return cfg != null and cfg.timer_enabled
```

Notes:
- The cue reuses **exactly** the established I3 idiom: an off-ladder pulse colour, a re-triggering `Tween` on `_clock_bar.modulate`, and an opposition-style `_timer_enabled()` gate parallel to `_r2_enabled()`/`_r3_enabled()` (`:282-289`). It settles back onto `_urgency_color(_clock_fraction)` — the same lerp the R2 toll pulse settles onto (`:212`) — so it composes cleanly with the steady drain ramp.
- The warning colour is **distinct** from `CLOCK_TOLL_PULSE` (the R2 amber-white, `:61`) so a player can tell "near-end warning" (alarm red) from "egress toll bit me" (amber). Colour is **never the only channel**: the bar fill, the numeric `HUD_CLOCK_TIME` readout (already updating, `:147`), and the optional "TIME LOW" banner are the redundant channels (the readability rule the file already follows, `:53-64`).

### B.3 `hud_strings.csv` — the optional warning banner string

```csv
HUD_TIME_LOW,Time almost up!
```
(Appended to `ui/hud/hud_strings.csv` — same `tr()` discipline as the existing `HUD_*` keys; the `.en.translation` re-imports.)

### B.4 `audio_director.gd` — re-point the audio hook (supersede the dead `light_low`)

```gdscript
# systems/audio_director.gd — _ready()
func _ready() -> void:
    EventBus.band_entered.connect(_on_band_entered)
    EventBus.player_died.connect(_on_player_died)
    EventBus.stamina_low.connect(_on_tension)
    EventBus.dive_clock_warning.connect(_on_clock_warning)   # K4: the live near-end warning
    # (light_low removed — it was never emitted; dive_clock_warning supersedes it. See OQ-3.)

## K4: audio half of the warning. GATED on timer_warning_channel == visual_audio so the
## audio only plays when the run config asks for it; visual-only configs stay silent here.
func _on_clock_warning(_seconds_remaining: float, _maximum: float) -> void:
    var cfg: RunConfig = GameState.active_run_config
    if cfg == null or not cfg.timer_enabled or cfg.timer_warning_channel != 1:  # 1 = visual_audio
        return
    pass  # TODO(M2 / audio-designer): play the placeholder "time low" stinger via the audio bus.
```
This retires `light_low()` cleanly: its only consumer (`_on_tension`) is re-pointed at the live, payload-carrying `dive_clock_warning`. **If the Director prefers to keep `light_low()` as the audio-only channel** (OQ-3 Option B), instead emit BOTH from `DiveClock` — but that is two signals for one event and I recommend against it.

---

## (c) Open Questions

**OQ-1 — Where does the timer length live: a `RunConfig` knob, the existing `DiveClockConfig.tres` exposed through the preset, or both? (Director Breakdown §7; mirrors K0 OQ-6.)**
- **Option A (recommended): `RunConfig.timer_length_s` is the surfaced knob; it OVERRIDES the effective length at run start; `0.0` ⇒ fall back to `DiveClockConfig.max_light`.** Rationale: the milestone's whole comparison machinery is *config-marked telemetry* (`to_flat_dict()` → the `run_started` row, RG2 segments on it). The length MUST land on that axis to be sweepable + comparable per-run, and only a `RunConfig` knob does that — a `.tres` edit is a global build change, invisible per-run in telemetry and not Reset-able to the all-off control. The `DiveClockConfig.tres` stays the **authored default** (the "60 is a dial" base, `dive_clock_config.gd:9`); the knob is the per-run override layered on top. This is exactly the `lvl_room_count = -1 ⇒ use BandGenConfig baseline` pattern (`run_config.gd:200`, `effective_room_count()` `:271-274`).
- **Option B:** expose `DiveClockConfig` through the preset only (no RunConfig knob). Rejected: no per-run telemetry mark, not Reset-able, not sweepable in CFG.
- **Option C:** both — knob writes THROUGH to a per-run-cloned `DiveClockConfig`. Over-engineered for M1.4; the override-at-`_on_run_started` path (Option A) is simpler and the config Resource is read-only shared today.
- **Recommendation:** **Option A.** Keep `timer_length_s` (K0 already declared it); `DiveClock` reads `_effective_max = timer_length_s if > 0 else config.max_light` at the run-start edge. The `make_default_play_preset()` may set a non-zero `timer_length_s` if the Director wants the played length to differ from 60 — **flag as a tuning call**: *"What dive length should the default play-preset ship? Keep 60 (leave `timer_length_s=0` ⇒ use DiveClockConfig) or set an explicit value?"*

**OQ-2 — Warning threshold: a FRACTION of max (e.g. 0.25), or ABSOLUTE seconds-remaining? (Director Breakdown §7.)**
- K0 declared it as **absolute seconds** (`timer_warning_threshold_s`). Trade-offs:
  - **Absolute seconds (recommended):** "warn at 10 s left" is a fixed, intuitive reaction-budget — the player always gets the same wall-clock heads-up regardless of dive length. Simplest to compare against `_current` (when `drain_per_second=1.0`, `_current` *is* seconds). Risk: if `timer_length_s` is set *below* the threshold the warning never fires usefully (handled by the OQ-clamp / the start-already-below latch in B.1).
  - **Fraction of max:** scales automatically with `timer_length_s` (always "warn at the last 25%"), and matches the EXISTING `DiveClockMeter.warn_fraction` (`dive_clock_meter.gd:13`) + `DecisionHUD.urgency_fraction` (`decision_hud.gd:36`, default 0.25) idiom — there's prior art for a *fraction* on this clock. Risk: the heads-up shrinks on short dives (25% of a 20 s dive = 5 s, maybe too little to react).
  - The two existing fraction-based cues (`warn_fraction`, `urgency_fraction`) are **continuous tints**, not one-shot events — they're a different channel, so reusing a *fraction* for the one-shot warning would be a third fraction knob doing a fourth thing.
- **Recommendation:** **absolute seconds (`timer_warning_threshold_s`), as K0 declared** — a fixed reaction budget is the clearest "time is almost up" semantics for the work-order, and it's independent of length so a sweep of `timer_length_s` doesn't silently rescale the warning. Add the start-already-below latch (B.1) so a pathological short timer never spam-warns or warns-on-frame-0. **Needs Director nod** (fun/feel call) — recommend absolute, with the preset starting threshold ~10 s of a 60 s dive.

**OQ-3 — Reuse the dead `light_low()` signal, or supersede it with the new typed `dive_clock_warning(...)`?**
- `light_low()` is **declared (`event_bus.gd:23`) + connected in AudioDirector (`audio_director.gd:18`) but NEVER emitted** — a dead signal with a stubbed audio consumer (`_on_tension`, `:24-25`).
- **Option A (recommended): emit the new typed `dive_clock_warning(seconds_remaining[, maximum])` as the single source of truth, and RE-POINT AudioDirector's existing hook from `light_low` → `dive_clock_warning`, retiring `light_low`.** One event, one signal, a useful payload (the HUD and audio both read the same thing), and the already-wired audio stub gets re-used rather than left dangling. `light_low()` carries no payload and is mis-scoped (it predates the per-frame clock); keeping it would mean two signals for one event.
- **Option B:** keep `light_low()` as the *audio-only* channel and emit BOTH `light_low()` (for AudioDirector) and `dive_clock_warning()` (for the HUD/telemetry) from `DiveClock`. Rejected: two signals for one event, with `light_low` carrying no payload and no debounce contract.
- **Option C:** emit only `light_low()`, drop the new signal. Rejected: K0 already pre-declared `dive_clock_warning` as the milestone contract; `light_low` is payload-free and can't feed telemetry/HUD-fraction.
- **Recommendation:** **Option A** — supersede `light_low()`. Concretely: K4 emits `dive_clock_warning`; AudioDirector moves its `light_low.connect(_on_tension)` to `dive_clock_warning.connect(_on_clock_warning)`; `light_low` is removed from `event_bus.gd` **by K0** (the single-writer on that file) — i.e. **fold "remove the dead `light_low` signal" into K0's pass**, since K4 must not edit `event_bus.gd`. *(Flag to Phase 3: this is a one-line removal request back to K0; if the Director would rather leave `light_low` declared-but-dead, K4 simply ignores it and the recommendation degrades to "AudioDirector subscribes to `dive_clock_warning` instead.")*

**OQ-4 — Should `dive_clock_warning` carry `maximum` as well as `seconds_remaining`? (Refinement back to K0.)**
- K0 declared `dive_clock_warning(seconds_remaining: float)`. The HUD cue (B.2) and any "remaining / max" telemetry want the denominator for symmetry with `dive_clock_changed(current, maximum)` (`event_bus.gd:36`).
- **Recommendation:** **add `maximum: float`** → `dive_clock_warning(seconds_remaining: float, maximum: float)`. It's free (primitives-only, telemetry-safe), matches the existing clock-signal shape, and lets a consumer compute the fraction without re-reading `DiveClock`. Per K0's own OQ-8 ("dependent designs feed name/type corrections back into K0 before dispatch"), **fold this signature change into K0**. Low-stakes; recommend adopting. *(If left as-is, the HUD reads `_clock_fraction` it already tracks (`decision_hud.gd:82`, `:143`) and the single-arg signal still works — so this is a nicety, not a blocker.)*

**OQ-5 — Visual-only, or visual + audio? (Director Breakdown §7 / work-order's "put out a warning".)**
- K0 declared `timer_warning_channel` (`visual_only` / `visual_audio`). The visual cue is **always** built (it's the legible primary channel and the gate watches `DecisionHUD`); audio is **optional, config-gated**, and lands in AudioDirector against the existing stubbed hook (B.4) — M2 supplies the actual stinger, so M1.4 ships a **placeholder/no-op audio path** behind the gate.
- Trade-offs: audio is a strong "look up NOW" channel but (a) M1.4 has no music/SFX yet (AudioDirector is an M0 stub, `audio_director.gd:11`), (b) web-export audio + the playtest build add risk, (c) accessibility — audio must never be the *only* channel (it isn't; visual is primary).
- **Recommendation:** **ship the visual cue unconditionally (gated only on `timer_enabled`); wire the audio path behind `timer_warning_channel == visual_audio` but as a no-op/placeholder TODO for M2** (don't block K4/RG1 on real audio). Default `timer_warning_channel = 0` (visual_only) so the all-off + first sweeps are visual. **Flag to Director:** *"For the RG1 playtest build, visual-only is recommended (audio is an M2 stub); confirm we don't need a placeholder beep for this playtest."* — a small scope/fun call.

**OQ-6 — Should the warning re-arm on a refuel back above the threshold within one dive?**
- Today nothing refuels the clock except a *future* extract-refuel / R3 over-correction seam (`modify_light` is positive-capable, `:84`). The timeout latch never re-arms within a dive; I mirror that for the warning (B.1).
- **Recommendation:** **do not re-arm within a dive** (match `_fired_timeout`). One warning per dive is the simplest, least-noisy contract and matches the work-order ("a warning that time is almost up", singular). If a later milestone adds meaningful mid-dive refuels, re-arming becomes a deliberate follow-up. *(Low-stakes; resolvable on technical merit, noting it for completeness.)*

---

## Resolved Decisions (Phase 3)

**Fresh-eyes resolver, 2026-06-21.** I did not author this design. I verified every cited API against the live source before resolving: `systems/dive_clock.gd` (the `_fired_timeout` latch at `:30`/`:89-92`, the single `modify_light` mutator, `_on_run_started` at `:46-53`, `config.start_light` semantics at `:50`), `data/dive/dive_clock_config.gd` (`max_light=60`, `drain_per_second=1.0`), `systems/event_bus.gd` (the dead `light_low()` declared at `:23`, the live `dive_clock_changed/timeout` at `:36-37`), `systems/audio_director.gd` (`light_low.connect(_on_tension)` at `:18`, `stamina_low.connect(_on_tension)` at `:19`, the stub `_on_tension` at `:24`), `ui/hud/decision_hud.gd` (`GameState.active_run_config` at `:283`, the `_r2_enabled()/_r3_enabled()` gate idiom at `:282-289`, `_clock_fraction` tracked at `:82`/`:143`, `urgency_fraction` at `:36`), and `ui/dive_clock_meter.gd` (`warn_fraction` continuous tint at `:13`/`:24`). All citations in (a)/(b) check out. The design's instinct — mirror `_fired_timeout` exactly, gate on `timer_enabled` like the R2/R3 cues, keep the HUD a pure-visual projection — is sound. Resolutions below; one threshold-feel value and one RG1 audio-scope call are flagged for the Director.

**RD-1 — Timer-length knob location: `RunConfig.timer_length_s` override; `DiveClockConfig.tres` stays the authored default (OQ-1, Option A). RESOLVED.**
The `RunConfig` knob is the *only* path that lands the length on the config-marked telemetry axis (`to_flat_dict()` → the `run_started` row, which RG2 segments on) and the *only* path that is Reset-able to the all-off control. A bare `.tres` edit is a global build change — invisible per-run in telemetry, not sweepable in CFG, not the all-off baseline. So `timer_length_s` is the surfaced/swept knob; `DiveClockConfig.max_light` (60) remains the authored default the override layers on top. The resolution mechanism is exactly as B.1 draws it and exactly the established `effective_room_count()` precedent (`run_config.gd:271-274`, `lvl_room_count = -1 ⇒ use baseline`):
```gdscript
_effective_max = config.max_light                       # authored default (60)
if cfg != null and cfg.timer_enabled and cfg.timer_length_s > 0.0:
    _effective_max = cfg.timer_length_s                 # per-run override; 0.0 ⇒ keep authored default
```
**Reject Option C (write-through to a per-run-cloned `DiveClockConfig`)** — `DiveClockConfig` is a read-only shared Resource today; cloning it per run to carry one float is over-engineering for M1.4. The override-at-`_on_run_started` path is simpler, telemetry-correct, and touches no shared Resource. **Not "both."** The single source of the *effective* length at runtime is `_effective_max`, resolved once at the run-start edge; the `.tres` and the knob are two inputs to that one resolution, not two live length sources.

**RD-2 — Threshold semantics: ABSOLUTE seconds-remaining (`timer_warning_threshold_s`), as K0 declared (OQ-2). RESOLVED on technical merit; the exact value is a Director feel-call.**
Absolute seconds is the correct *type* for three independent reasons: (1) a fixed reaction budget ("you always get 10 s of warning") is the clearest reading of the work-order's "time is almost up"; (2) it is directly comparable to `_current` at the default `drain_per_second=1.0` (where `_current` *is* seconds remaining), needing no fraction arithmetic in the hot mutator; (3) it does **not** silently rescale when `timer_length_s` is swept — a fraction would couple the two knobs and make a length sweep also a warning sweep, contaminating RG2's per-knob comparison. The two existing *fraction* cues (`urgency_fraction` at `decision_hud.gd:36`, `warn_fraction` at `dive_clock_meter.gd:13`) are **continuous passive tints on a different channel** — reusing a fraction here would be a third fraction-knob doing a fourth, discrete-event thing. Keep them distinct (see RD-7).
- **Semantics caveat (state it in the worklog):** the threshold is in **light-units**, which equal **wall-clock seconds only while `drain_per_second == 1.0`** (the authored default). If a future run sets `drain_per_second != 1.0`, the "seconds" naming is approximate. This is acceptable for M1.4 (no knob sweeps `drain_per_second`; it is not even a `RunConfig` field) — but the comparison `_current <= _warning_threshold` is in light-units and is correct regardless of drain rate; only the *name* "seconds" drifts. Do not rename the knob (K0 already locked `timer_warning_threshold_s`); just document the light-unit identity.
- **NEEDS DIRECTOR REVIEW** *(fun/feel — the value, not the type)*: the **preset threshold value and feel**. Recommendation: `timer_warning_threshold_s ≈ 10.0` against the 60 s authored dive (the last ~17% of the dive) — long enough to react (turn for an exit), short enough that it reads as "almost up," not a mid-dive nag. Director confirms 10 s, or sweeps {8, 10, 12} in RG2.

**RD-3 — Signal: emit the new typed `dive_clock_warning`; retire the dead `light_low()`; AudioDirector re-points to the live signal (OQ-3, Option A). RESOLVED. K4 NEEDS one removal from K0.**
`light_low()` is verified dead: declared at `event_bus.gd:23`, connected at `audio_director.gd:18`, **never `.emit()`-ed** anywhere. It is payload-free and predates the per-frame clock, so it cannot feed the HUD fraction or telemetry. `dive_clock_warning` (K0-pre-declared) is the milestone-contract signal with a payload. So: **K4 emits only `dive_clock_warning`**; AudioDirector moves its hook from `light_low.connect(_on_tension)` to `dive_clock_warning.connect(_on_clock_warning)`; `light_low()` is **deleted from `event_bus.gd`**.
- **Ownership boundary (the coordination this RD locks):** `event_bus.gd` is **K0's single-writer file** this milestone. K4 must NOT edit it. Therefore the `light_low()` *deletion* is a **request folded into K0's pass**, alongside the `dive_clock_warning` declaration K0 already owns. K4's NEEDS-FROM-K0 list is exactly two lines: **(i)** declare `dive_clock_warning` with the RD-4 signature (K0 already has it, modulo the arg add); **(ii)** remove the dead `signal light_low()` line (`event_bus.gd:23`). Both are one-line edits inside K0's existing window — fold them into K0 before K0 is dispatched (this is precisely the "dependents feed corrections back into K0" path K0's own OQ-8 anticipates).
- **K4 owns** the AudioDirector re-point (`systems/audio_director.gd` is not K0's file): swap line 18's connect target and add `_on_clock_warning`. **Note the `stamina_low` co-connection:** `_on_tension` is *also* wired to `stamina_low` (`audio_director.gd:19`). When K4 re-points the `light_low` connection to a *new* `_on_clock_warning` handler (rather than reusing `_on_tension`), leave the `stamina_low → _on_tension` line untouched — `stamina_low` is a separate, still-valid (also-dead-but-not-ours-to-touch) signal. Do not collapse the two handlers; the warning handler needs the `timer_warning_channel` gate (RD-6) that `_on_tension` does not have.
- **Degradation path:** if the Director declines to delete `light_low()` (wants it kept declared-but-dead), the resolution degrades cleanly to: K4 still emits `dive_clock_warning`, AudioDirector still subscribes to `dive_clock_warning`, and `light_low` is simply left inert and unsubscribed. No K4 behaviour changes. (Recommend the deletion — a dead, payload-free signal is debt.)

**RD-4 — `dive_clock_warning` payload/signature: `dive_clock_warning(seconds_remaining: float, maximum: float)` (OQ-4). RESOLVED. K4 NEEDS the arg-add from K0.**
Add `maximum: float` to K0's declared single-arg signature. Rationale: (1) **symmetry** with the existing `dive_clock_changed(current, maximum)` (`event_bus.gd:36`) — every clock signal then carries the same `(value, max)` shape; (2) it lets any consumer (HUD, future telemetry) compute the fraction `seconds_remaining / maximum` without re-reading `DiveClock`; (3) it is **free** — both args are primitives, so the telemetry-safe/JSONL rule (`event_bus.gd:86-88`) is preserved. The emit carries the **effective** values: `EventBus.dive_clock_warning.emit(_current, _effective_max)` (B.1) — so a length-overridden run reports its real denominator, not the authored 60.
- **NEEDS FROM K0:** change the K0 declaration from `signal dive_clock_warning(seconds_remaining: float)` to `signal dive_clock_warning(seconds_remaining: float, maximum: float)`. One-line edit in K0's window. **Telemetry note:** K0's `dive_clock_warning` is a HUD/audio drive signal, *not* a `to_flat_dict()` row — so no `expected_keys`/count-test impact; the arg add is purely a connect-arity change for the two consumers (DecisionHUD `_on_dive_clock_warning`, AudioDirector `_on_clock_warning`), both of which K4 writes to match.
- Low-stakes; adopt. (If the Director insists on the single-arg form, the HUD already tracks `_clock_fraction` at `decision_hud.gd:82`/`:143` and works without the `maximum` arg — but adopt the two-arg form; it costs nothing and ends the asymmetry.)

**RD-5 — Visual cue lives in `DecisionHUD`, mirroring the R2/R3 idiom. RESOLVED.**
The primary cue is the one-shot `_flash_warning()` on `_clock_bar.modulate` in `DecisionHUD` — the surface the "is it fun?" gate watches, the bar the player already reads. It composes correctly because it settles back onto `_urgency_color(_clock_fraction)` (the same lerp the R2 toll pulse settles onto, `decision_hud.gd:212`), so the steady drain ramp resumes cleanly after the blink. The cue is gated by `_timer_enabled()` — a new helper parallel to the verified `_r2_enabled()/_r3_enabled()` pattern (`decision_hud.gd:282-289`), reading `GameState.active_run_config`. **Distinct colour** (`CLOCK_WARNING_PULSE`, alarm-red) from `CLOCK_TOLL_PULSE` (R2 amber-white) so the two events are not confused. Colour is never the only channel — the numeric `HUD_CLOCK_TIME` readout (already live, `:147`) and the optional `tr("HUD_TIME_LOW")` banner (B.3, via the existing `_spawn_cost_indicator` float-and-fade idiom) are the redundant channels, satisfying the readability rule the file already follows. The `DiveClockMeter.warn_fraction` tint (RD-7) is **not** touched.

**RD-6 — Visual always on (when enabled); audio config-gated behind `timer_warning_channel`, no-op placeholder for M1.4 (OQ-5). RESOLVED on scope; the RG1 audio question is the Director's.**
Visual ships unconditionally whenever `timer_enabled` is true (it is the legible primary channel). Audio is **optional and config-gated**: `timer_warning_channel == 1` (`visual_audio`) routes into AudioDirector's `_on_clock_warning`, which for M1.4 is a **no-op placeholder TODO(M2)** — `AudioDirector` is still an M0 stub (`audio_director.gd` has no real bus/SFX), and M2 owns the actual stinger. This keeps the HUD a pure-visual surface (the audio gate lives in AudioDirector, not the HUD — correct separation per B.2/B.4) and does not block K4/RG1 on real audio. The default `timer_warning_channel = 0` (`visual_only`) means the all-off control and the first sweeps are visual.
- **NEEDS DIRECTOR REVIEW** *(scope/fun — does RG1 ship audio?)*: M1.4 has **no audio assets** (AudioDirector is a stub). Recommendation: **RG1 ships visual-only** — wire the audio path behind the gate as a no-op TODO(M2), and have `make_default_play_preset()` set `timer_warning_channel = 0`. If the Director wants an audible "look up NOW" for the playtest, that is a *small* additional ask: a placeholder beep via `audio-designer-composer` against the stubbed bus, web-export-tested. Default recommendation: skip the beep, ship visual-only, revisit audio in M2 with the real soundscape. Director confirms.

**RD-7 — Warning does NOT re-arm on a refuel within a dive; latches once like `_fired_timeout` (OQ-6). RESOLVED on technical merit.**
The `_fired_warning` latch flips true on the first sub-threshold frame and resets **only** at the next `_on_run_started` — byte-identical discipline to `_fired_timeout` (`dive_clock.gd:30`/`:89-92`). A positive `modify_light` (the future extract-refuel / R3 over-tax seam) that lifts `_current` back above the threshold does **not** re-arm the warning within the dive. This matches the timeout's once-per-dive contract and the work-order's singular phrasing ("a warning that time is almost up"). It is also the **anti-storm guarantee**: under per-frame drain (`drain_per_second=1.0` @ 60 fps crosses the threshold inside one 1/60 s step), the latch is the only thing preventing a per-frame emit storm below the threshold — exactly why the timeout uses the same latch. Two latch-correctness details, both already in B.1 and both **confirmed correct**:
  - **Order matters:** the warning check must run **before** the timeout check in `modify_light`, so a single large mutation that blows straight past the threshold to zero still emits `dive_clock_warning` *before* `dive_clock_timeout` (legible "almost → gone"). Keep the B.1 ordering.
  - **Start-already-below edge:** if a dive *starts* at/below the threshold (a pathologically small `timer_length_s`, or a low `start_light`), pre-arm `_fired_warning = true` in `_on_run_started` so the warning never fires on frame 0 — it is a "running low" cue, not a "you start low" cue. Keep the B.1 guard `if _warning_threshold > 0.0 and _current <= _warning_threshold: _fired_warning = true`.
  - If a later milestone adds *meaningful* mid-dive refuels and wants re-arming, that is a deliberate future follow-up with hysteresis (re-arm only after rising a margin above the threshold, to avoid a flicker storm at the boundary) — explicitly out of M1.4 scope. Note it in the worklog.

**RD-8 — All-off invariant holds; the clock never feeds `fingerprint()`. CONFIRMED.**
`timer_enabled = false` (the code-level default) ⇒ `_effective_max = config.max_light` (today's 60), `_warning_threshold = 0.0` ⇒ the threshold guard `if _warning_threshold > 0.0 …` is false on every frame ⇒ **no** `dive_clock_warning` ever emits, and the clock behaves byte-for-byte as M1.0/M1.3. The DiveClock is **post-generation run-state** (`dive_clock.gd:3-8`) — it is created/destroyed per dive and writes nothing to meta-state — so it is **never an input to `fingerprint(seed+config)`**; the all-off fingerprint `e943ac9c8bc1` is untouched by anything K4 does, at any config value (length, threshold, channel all only affect post-generation run-state). The fun values (`timer_enabled=true`, a non-zero `timer_length_s`/threshold) ship in `make_default_play_preset()`, never in the code-level all-off default — the carried contract (Breakdown §2/§6). **One coordination note for K0:** `timer_length_s`, `timer_warning_threshold_s`, `timer_enabled`, `timer_warning_channel` all join `to_flat_dict()` (K0 §B.2 already lists them) and the `test_run_config.gd` `expected_keys` + the `test_config_menu.gd` count bump — those are K0's edits, not K4's; K4 only *reads* the knobs via `GameState.active_run_config`.

### K4's NEEDS-FROM-K0 (the coordination contract, consolidated)
K4 must not edit `event_bus.gd` (K0's single-writer file). K4 needs exactly these from K0's pass, all one-line edits inside K0's existing window:
1. **Signature:** declare `signal dive_clock_warning(seconds_remaining: float, maximum: float)` (add the `maximum` arg — RD-4).
2. **Removal:** delete the dead `signal light_low()` (`event_bus.gd:23` — RD-3). *(Degrades gracefully if the Director declines: K4 leaves it inert.)*
3. (Already in K0 §B.1/§B.2 — no new ask:) the four `timer_*` knobs at off/neutral defaults + their `to_flat_dict()` rows + the count-test bump.

K4 owns and edits: `systems/dive_clock.gd` (length override + `_fired_warning` latch + emit), `ui/hud/decision_hud.gd` (the visual cue), `systems/audio_director.gd` (re-point + gated no-op audio), `ui/hud/hud_strings.csv` (the `HUD_TIME_LOW` banner string).

### Items needing Director review (surfaced per orchestrator-loop step 7)
- **RD-2:** the preset warning-threshold **value/feel** — recommend `timer_warning_threshold_s ≈ 10.0` against a 60 s dive (the *type*, absolute seconds, is resolved; only the number is a feel-call). *(fun/feel)*
- **RD-6:** whether **RG1 ships audio** — recommend **visual-only** for the playtest (audio is an M2 stub; wire the gated path as a no-op TODO). A placeholder beep is a small optional add if the Director wants it. *(scope/fun)*

All other open questions (OQ-1 length location, OQ-3 signal supersede, OQ-4 payload, OQ-6 re-arm) are **resolved on technical merit** above and need no Director call.
