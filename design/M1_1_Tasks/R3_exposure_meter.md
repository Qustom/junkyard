# R3 — Rising Instability / Exposure Meter (expanded design spec)

**Milestone:** M1.1 — Greybox Cost Axis · **Workstream:** (b) the four oppositions · **Wave:** 2 (parallel worktrees)
**Task id:** R3 · **Author:** game-director-designer · **Status:** spec (pre-implementation)
**Assignees (per breakdown §4 R3):** general-purpose (meter + penalty) · game-director-designer (this spec + defaults) · ui-ux-designer (greybox HUD readout)
**dependsOn:** R0 (`RunConfig` on `main`), BUG2 (live within-band depth), TEL (wave-1 pre-declaration of all six R3 signals — `exposure_meter_changed`, `exposure_crossed`, `exposure_penalty`, `exposure_speed_mult_changed`, `exposure_vision_mult_changed`, `exposure_clock_tax`; §0/§9 D1)
**Companions:** `M1.1_Breakdown.md` (§2 guardrails, §4 R3, §6 wave-2), `M1_As_Built.md` (canonical APIs), `data/run_config/run_config.gd` (the R3 knobs)

---

## 0. Guardrail header — READ FIRST (this is a throwaway, not M3)

This meter is a **throwaway, baby-grade prototype** of the eventual M3 exposure system. It exists only to test whether a **lingering cost** makes "push deeper vs. extract now" a felt gamble. It is **explicitly NOT**:

- **Not the M3 exposure model.** The real M3 system is the Blades-in-the-Dark "Heat" design from the GDD: 0–100 with a large inert buffer, 3–4 telegraphed crisis thresholds with randomized flavor, slow passive decay plus costly mitigation sinks, and a partly-permanent top-band escalation that is **meta-state**. R3 has **none** of that depth and **none** of its persistence. If the re-gate says "fun," M3 builds the real thing from scratch; R3 is discarded.
- **Not meta-state.** `GameState.exposure` (an `int`) and `GameState.add_exposure(delta)` already exist as **persistent meta-state** (`M1_As_Built.md` §GameState; `EventBus.exposure_changed` / `exposure_threshold_crossed`). **R3 does NOT touch them.** R3's meter is a **separate run-state scalar that resets to 0 at the start of every dive and is discarded at run end** — never banked, never saved, never read by SaveManager. The naming collision is unfortunate but the boundary is hard: meta `exposure` = persistent; R3 meter = disposable per-dive.
- **Not balanced.** Every number ships **configurable-not-balanced** (breakdown §2). Acceptance is "the knob exists and takes effect," not "the value is right." The Director sweeps values across playtest runs via the CFG menu.

If you (the programmer) find you *must* edit `event_bus.gd` or `game_state.gd` to build this, **stop and flag it** — per wave-2 rules (§6) R3 must touch neither. See §8 (files) and §9 (Director-ratified decisions) for the seams that keep it out of both.

> **Ratified cross-cutting decision (Director 2026-06-19).** R3 applies all of its mechanical penalties by **emitting penalty-multiplier / tax signals that TEL pre-declares on `event_bus.gd` in wave 1**. R3 never edits `event_bus.gd` or `game_state.gd` — it only *emits* the pre-declared signals; the **Player** consumes the speed mult, the **R4 fog** consumes the vision mult, and the **A3 dive clock** consumes the clock tax. The three signals TEL must pre-declare in wave 1 (exact signatures, pinned):
>
> ```gdscript
> # systems/event_bus.gd — declared by TEL in wave 1 (R3 emits only)
> signal exposure_speed_mult_changed(mult: float)   # Player multiplies stats.max_speed by mult
> signal exposure_vision_mult_changed(mult: float)  # R4 fog multiplies its vision radius by mult
> signal exposure_clock_tax(seconds: float)         # A3 dive clock subtracts `seconds` from remaining light
> ```
>
> These are in addition to the three projection/telemetry signals TEL also pre-declares for R3: `exposure_meter_changed(value: float, maximum: float)`, `exposure_crossed(level: int, depth: int, run_t_ms: int)`, `exposure_penalty(level: int, penalty_kind: int)`. **TEL owns the declaration of all six; R3 owns only the emit.**

---

## 1. Goal & design intent

> **One sentence:** A meter that climbs while you're deep and punishes lingering — the most direct counter to "linger deep and loot freely."

M1.0 proved the loop is engaging but degenerate: with a reward axis (deeper = better junk) and **no cost axis**, the dominant strategy is "push to the end, then walk back and extract." R3 attacks that strategy at its root: it puts a **clock-like pressure on depth itself**. The deeper you are and the longer you stay, the faster a meter fills; crossing its thresholds inflicts escalating, *felt* penalties; filling it can end the run as a forced loss. Where the A3 dive clock is a **flat** time budget (drains the same everywhere), R3 is a **depth-weighted** time budget — it makes the *last room specifically* expensive to occupy, which is exactly the decision M1.1 needs to make tense.

R3 is one of four parallel oppositions. It is independently on/off, independently telemetried, and stackable with R1/R2/R4 so the Director can isolate or combine cost axes (§6).

---

## 2. Meter design (the climb model)

### 2.1 State (run-state, disposable)

A single run-state float `meter` in range `[0, METER_MAX]`. **`METER_MAX = 100.0`** is a fixed internal constant (not a knob) — it gives thresholds and penalties a stable 0–100 frame so the Director tunes `r3_threshold_levels` against a known ceiling. The meter:

- **Resets to `0.0`** at dive start (on `EventBus.run_started`).
- **Is discarded** at run end (on `EventBus.run_ended`) — never persisted, never read into meta.
- **Lives only while `run_active`** and only when `r3_enabled`.

### 2.2 Climb rate as a function of depth + time-in-band

Per frame, when in-band and not retreating, the meter climbs at:

```
climb_per_second = r3_base_climb_rate + (r3_rate_per_depth * live_depth)
```

- `r3_base_climb_rate` — the flat climb that accrues anywhere in the band (the "time-in-band" term; even at depth 0 the meter creeps). This is what makes *lingering at any depth* cost something.
- `r3_rate_per_depth * live_depth` — the **depth-weighted** term. `live_depth` is the player's current within-band depth index (BUG2's live depth, see §2.4). Deeper → faster fill. This is the term that makes the *deep* rooms the expensive ones.

The two terms combine additively so the Director can dial "is lingering anywhere costly, or only lingering *deep*?" by trading `r3_base_climb_rate` against `r3_rate_per_depth`.

> **Design note — why additive, not multiplicative.** A multiplicative `base * (1 + per_depth*d)` couples the two knobs (changing base rescales the depth weighting), which is harder to sweep cleanly. Additive keeps each knob's effect independent, which is what a configurable-not-balanced sweep wants. **Linear-in-depth is the committed prototype model** (Director-ratified, §9 D5) — no `Curve` knob is added for the gate.

### 2.3 Decay on retreat (shallowing)

When the player moves to a **shallower** depth than their running max — i.e. they are retreating toward the gate — the meter **decays** instead of climbing:

```
if retreating:   meter -= r3_decay_on_retreat * delta   (clamped at 0)
else:            meter += climb_per_second * delta       (clamped at METER_MAX)
```

`r3_decay_on_retreat = 0.0` (the default) means the meter is a **ratchet** — once it climbs it never falls, so the only escape is to extract. A positive decay makes retreat a **relief valve**: backing off shallow buys the meter down, rewarding the player who reads the threat and pulls out. This is a key push/pull knob for the gamble — the Director sweeps it (§7).

**"Retreating" defined (greybox-simple, ratified):** the player is retreating this frame iff `live_depth < max_depth_reached_this_dive`. This stateless `< max` test is the committed design (Director-ratified, §9 D2) — it reads the BUG2 surface directly and needs no per-sample delta tracking. Standing still at max depth = climbing (not retreating). Standing still while already shallow (below max) = decaying, which is the intended "I pulled back and I'm catching my breath" behavior.

### 2.4 Reading live depth (BUG2 seam — no game_state edit)

R3 needs the **live within-band depth** every frame. BUG2 (wave 1, lands before R3) makes this real: it tracks the player's live `depth_index` and `max_depth` in run-state and emits `depth_changed(depth_index, max_depth)` on change. R3 reads this **passively**:

- Subscribe to `EventBus.depth_changed(depth_index, max_depth)` and cache `live_depth` + `max_depth_reached`. **No polling, no game_state edit** — R3 only listens.
- Cross-check against `M1_As_Built.md` once BUG2 lands: if BUG2 exposes the live depth as a `GameState` read-only member (e.g. `GameState.current_depth` becomes the live within-band index) **R3 may read that member directly** as a fallback for the value between signal emissions, but must still treat it as **read-only** (never assign). The signal is the source of change; the member (if present) is a convenience snapshot. **Confirm the exact BUG2 surface name at brief time** — do not assume; this spec was authored before BUG2 merged.

---

## 3. Threshold & penalty design

### 3.1 Threshold crossings

`r3_threshold_levels: PackedFloat32Array` is an **ascending** list of meter values (against the 0–100 frame). Each time the meter **rises across** a level it hasn't crossed yet this dive, R3:

1. emits `EventBus.exposure_crossed(level_index, live_depth, run_t_ms)` (TEL row),
2. applies the penalty of kind `r3_penalty_kind` at magnitude `r3_penalty_magnitude` (§3.3),
3. emits `EventBus.exposure_penalty(level_index, r3_penalty_kind)` (TEL row).

Crossing detection is **edge-triggered and one-shot per level per dive**: track the index of the highest level crossed so far (`_levels_crossed: int`). A level only fires on the rising edge. If `r3_decay_on_retreat > 0` and the meter falls back below a crossed level, the prototype **does NOT un-fire** the penalty and does **NOT** re-arm the level. **One-shot-per-dive, no re-arm, is the committed design** (Director-ratified, §9 D3); re-arming is a balance feature deferred to M3. The meter can fall, but a crossed threshold stays crossed for the dive. This keeps the prototype's penalty bookkeeping trivial and avoids penalty-flicker.

### 3.2 Max-meter forced loss

If `r3_max_forces_loss` and `meter >= METER_MAX`, R3 ends the run as a **forced timeout**:

- route through the existing `GameState.fail_run(&"timeout")` (`M1_As_Built.md` §GameState / §E3) — the same path the A3 dive-clock timeout already uses. This re-uses the locked end-cause `timeout`, applies the pockets fraction, banks the kept subset, and emits the locked `run_ended(&"timeout", duration_s, depth_reached)`. **No new end-cause, no `run_ended` arity change** (breakdown §2).
- R3 does **not** emit `run_ended` itself and does **not** edit `game_state.gd`. It **calls** the existing public `fail_run` method. This is the one cross-system call R3 makes; it is a method call on an autoload, not a file edit — permitted under §6, which forbids *editing* `game_state.gd`, not *calling* it. **Director-ratified (§9 D1):** calling `fail_run` is the committed mechanism (it is already the public run-end API every M1 system uses, consistent with E3); the request-signal fallback is not used.
- The `_run_ended` idempotency guard in `GameState` (E3) makes a same-frame tie safe (e.g. extract vs. max-meter on the same frame → extract wins).

`r3_max_forces_loss = false` (default) means the meter is **penalty-only**: it can stack speed/vision/clock penalties to make deep lingering miserable, but never directly kills. The Director chooses whether R3 is a soft-pressure system or a hard-cap system.

### 3.3 What each penalty kind does concretely (and its seam)

`r3_penalty_kind` ∈ `{0 none, 1 speed, 2 vision, 3 clock}` (the enum in `run_config.gd`). The penalty is applied **at magnitude `r3_penalty_magnitude`** on each crossing. Because crossings are additive in effect, N crossings of a `speed` penalty stack to N× the per-crossing reduction (capped — see each kind). **All three penalty seams must avoid editing `game_state.gd`.**

**`0 none`** — no effect; the meter and its crossings are telemetry-only. Useful as a control: "does the *meter visible on the HUD* change behavior even with no mechanical bite?" (a real playtest question).

**`1 speed`** — slow the player. The player reads `stats.max_speed` off a `PlayerMovementStats` resource each `_physics_process` (`entities/player/player.gd` → `step_velocity` uses `stats.max_speed`). **Ratified seam (no game_state edit):** R3 emits the **TEL-pre-declared `exposure_speed_mult_changed(mult: float)`** signal; the player subscribes and multiplies `stats.max_speed * _exposure_speed_mult` in `step_velocity`. This keeps R3 out of both `game_state.gd` and `event_bus.gd` (TEL declares the signal, not R3) and keeps the player out of R3's internals. The rejected alternative — a `GameState.run_speed_mult` member — is a `game_state.gd` edit and is **not** used (Director-ratified, §9 D1). **Concrete effect:** `speed_mult = max(SPEED_FLOOR, 1.0 - r3_penalty_magnitude * _levels_crossed)`, with `SPEED_FLOOR = 0.35` so stacked penalties never freeze the player.

**`2 vision`** — shrink the player's sightline. M1.0 has full vision; R4 introduces a vision/fog node. **Ratified seam:** R3 does **not** build its own fog. It emits the **TEL-pre-declared `exposure_vision_mult_changed(mult: float)`** signal that the R4 fog node multiplies into its radius — i.e. R3 *tightens* R4's vision. R3 and R4 are wave-2 parallel, so the two agree this read contract at wave-2 brief time. **When R4 is off (R3 isolated) the `vision` penalty is a deliberate no-op** — it still logs the crossing + penalty telemetry, but there is no fog system to tighten, so nothing changes on-screen. This is intended and documented (Director-ratified, §9 D4): `r3_penalty_kind = vision` **requires R4 enabled to be felt**, and the CFG menu surfaces that note so a `vision`-with-R4-off sweep isn't misread as "vision does nothing."

**`3 clock`** — tax the A3 dive clock. The dive clock drains via `EventBus.dive_clock_changed(current, maximum)` and times out via `dive_clock_timeout` (`M1_As_Built.md` §HUD/A3). **Ratified seam (no game_state edit):** R3 emits the **TEL-pre-declared `exposure_clock_tax(seconds: float)`** signal that the A3 clock system subtracts from its remaining light — one-shot per crossing. R3 does **not** reach into A3's clock system directly; the coupling is the signal contract only (Director-ratified, §9 D7). The previously-listed "self-accelerate the meter instead" fallback is **dropped** — the clock-tax signal is the committed mechanism.

**Stacking across kinds (ratified):** the enum selects **one** kind per run, and that is the committed prototype design (Director-ratified, §9 D6). Multi-kind stacking (e.g. speed AND clock) is **not** built for the gate; it would be a `RunConfig` schema change (a `PackedInt32Array` of kinds or per-kind flags) rippling into CFG and TEL's snapshot, and is deferred as an explicit follow-up rather than a wave-2 surprise.

---

## 4. HUD readout (greybox, pure projection)

A **greybox exposure bar** in the HUD, authored by **ui-ux-designer**, following the E2 `decision_hud.gd` pattern exactly: **pure projection, owns no source of truth, signal-driven, no polling** (`M1_As_Built.md` §HUD).

- **What it reads:** R3 emits a new pre-declared signal `EventBus.exposure_meter_changed(value: float, maximum: float)` every time the meter changes (or once per frame while climbing — see §6 pseudocode for the emit cadence). The HUD subscribes and sets a `ProgressBar` fill = `value / maximum`. This mirrors how E2's clock bar reads `dive_clock_changed(current, maximum)`.
- **Greybox styling:** a plain default-theme `ProgressBar` + a numeric `Label` (e.g. "Exposure: 42 / 100"), so color is never the only channel (E2 readability rule). A green→amber→red tint as it fills is welcome (mirrors E2's clock ramp) but optional for greybox; the numeric readout is the load-bearing channel.
- **Threshold ticks (nice-to-have):** marking the `r3_threshold_levels` on the bar (small ticks) telegraphs the next penalty, which sharpens the gamble. Optional for greybox; recommended if cheap.
- **Visibility:** the bar shows only when `r3_enabled` (hidden entirely with R3 off, so an all-off run's HUD equals M1.0). The HUD reads `GameState.active_run_config.r3_enabled` at run start to decide visibility (read-only).
- **Signal ownership (ratified):** `exposure_meter_changed(value: float, maximum: float)` is **pre-declared by TEL on `main` in wave 1** (with the other five R3 signals, §0) so neither R3 nor the HUD edits `event_bus.gd`. The name is committed (Director-ratified, §9 D1) — no generic reuse.

> The HUD (ui-ux) and the meter (general-purpose) share one worklog under R3.

---

## 5. Telemetry

R3 emits the two TEL-pre-declared opposition signals (breakdown §4 R3, §6); payloads coordinated with TEL:

| Event (EventBus signal → TEL row) | Payload | Fires when |
|---|---|---|
| `exposure_crossed(level, depth, run_t_ms)` | `level` = threshold index crossed (int, 0-based into `r3_threshold_levels`); `depth` = live within-band depth at crossing; `run_t_ms` = run elapsed ms | each rising-edge threshold crossing (§3.1) |
| `exposure_penalty(level, penalty_kind)` | `level` = same threshold index; `penalty_kind` = the applied `r3_penalty_kind` enum int | each time a crossing's penalty is applied (§3.3) |
| *(max → existing)* `run_ended(reason=&"timeout", …)` | locked arity, unchanged | when `r3_max_forces_loss` and meter hits `METER_MAX` → `fail_run(&"timeout")` (§3.2) |

- **No `run_ended` widening.** The forced loss rides the existing locked `run_ended(reason, duration_s, depth_reached)` with `reason = &"timeout"`, exactly as the A3 clock timeout does (breakdown §2; `M1_As_Built.md` §Telemetry). The analysis distinguishes an R3-forced timeout from an A3-clock timeout via the **config snapshot** on `run_started` (`r3_max_forces_loss = true` + presence of `exposure_crossed` rows) — no new end-cause string is introduced.
- **Config snapshot.** TEL already snapshots `RunConfig.to_flat_dict()` onto `run_started.data.run_config` (R0/TEL), so every run records its R3 knobs. RG2's analysis correlates `exposure_crossed`/`exposure_penalty` frequency, crossing-depth, and timeout-rate against the swept R3 config.
- **With R3 off:** no `exposure_*` rows appear (the meter system is inert / not instantiated). TEL acceptance (§4 TEL) covers "with it disabled, they don't."
- The signals are **pre-declared by TEL in wave 1**; R3 only **emits** them in wave 2 — R3 never edits `event_bus.gd`.

---

## 6. Pseudocode

> Illustrative GDScript-shaped pseudocode for the meter system's `_process` (climb/decay, edge-triggered crossing, penalty application, max→timeout) and the HUD emit. **Not** final code — the programmer writes typed GDScript against the as-built APIs confirmed at brief time. Autoload references resolve per `M1_As_Built.md` §Testing constraints.

```gdscript
# systems/oppositions/exposure_meter.gd  (run-state system node, NOT an autoload)
class_name ExposureMeter
extends Node

const METER_MAX: float = 100.0
const SPEED_FLOOR: float = 0.35   # stacked speed penalties never freeze the player

var _cfg: RunConfig            # cached from GameState.active_run_config at run start
var _active: bool = false      # r3_enabled AND run_active
var _meter: float = 0.0        # run-state, disposable
var _live_depth: int = 0       # from EventBus.depth_changed (BUG2)
var _max_depth: int = 0        # running max this dive (from BUG2)
var _levels_crossed: int = 0   # highest threshold index fired this dive (one-shot)

func _ready() -> void:
    EventBus.run_started.connect(_on_run_started)
    EventBus.run_ended.connect(_on_run_ended)
    EventBus.depth_changed.connect(_on_depth_changed)   # BUG2 surface (confirm name)
    set_process(false)

func _on_run_started(_band_id, _seed) -> void:
    _cfg = GameState.active_run_config
    _active = _cfg != null and _cfg.r3_enabled
    _meter = 0.0
    _live_depth = 0
    _max_depth = 0
    _levels_crossed = 0
    set_process(_active)
    if _active:
        _emit_meter_changed()        # HUD shows 0/100 at dive start
        _emit_speed_mult()           # reset modifiers to neutral (mult 1.0)

func _on_run_ended(_reason, _dur, _depth) -> void:
    _active = false
    set_process(false)
    _emit_speed_mult_neutral()       # never leak a speed penalty across runs

func _on_depth_changed(depth_index: int, max_depth: int) -> void:
    _live_depth = depth_index
    _max_depth = max_depth

func _process(delta: float) -> void:
    if not _active or not GameState.run_active:
        return

    # --- climb vs. decay (retreating = shallower than this dive's max) ---
    var retreating: bool = _live_depth < _max_depth
    if retreating and _cfg.r3_decay_on_retreat > 0.0:
        _meter = maxf(0.0, _meter - _cfg.r3_decay_on_retreat * delta)
    else:
        var climb := _cfg.r3_base_climb_rate + _cfg.r3_rate_per_depth * float(_live_depth)
        _meter = minf(METER_MAX, _meter + climb * delta)

    # --- edge-triggered, one-shot threshold crossings ---
    var levels := _cfg.r3_threshold_levels
    while _levels_crossed < levels.size() and _meter >= levels[_levels_crossed]:
        var idx := _levels_crossed
        _levels_crossed += 1
        EventBus.exposure_crossed.emit(idx, _live_depth, _run_t_ms())
        _apply_penalty(idx)
        EventBus.exposure_penalty.emit(idx, _cfg.r3_penalty_kind)

    # --- max-meter forced loss ---
    if _cfg.r3_max_forces_loss and _meter >= METER_MAX:
        _active = false
        set_process(false)
        GameState.fail_run(&"timeout")     # existing public API; idempotency guard handles ties
        return

    _emit_meter_changed()   # HUD projection (every frame while climbing)

func _apply_penalty(_level_idx: int) -> void:
    match _cfg.r3_penalty_kind:
        0:  # none — telemetry only
            pass
        1:  # speed — recompute & broadcast a multiplicative speed modifier
            _emit_speed_mult()
        2:  # vision — tighten R4's vision if present, else no-op (see §3.3)
            _emit_vision_mult()
        3:  # clock — tax the A3 dive clock (or self-accelerate fallback, §3.3)
            EventBus.exposure_clock_tax.emit(_cfg.r3_penalty_magnitude)

func _emit_speed_mult() -> void:
    var mult := maxf(SPEED_FLOOR, 1.0 - _cfg.r3_penalty_magnitude * float(_levels_crossed))
    EventBus.exposure_speed_mult_changed.emit(mult)   # player multiplies into max_speed

func _emit_speed_mult_neutral() -> void:
    EventBus.exposure_speed_mult_changed.emit(1.0)

func _emit_vision_mult() -> void:
    var mult := maxf(0.2, 1.0 - _cfg.r3_penalty_magnitude * float(_levels_crossed))
    EventBus.exposure_vision_mult_changed.emit(mult)  # R4 fog reads (no-op if R4 off)

func _emit_meter_changed() -> void:
    EventBus.exposure_meter_changed.emit(_meter, METER_MAX)   # HUD bar reads this

func _run_t_ms() -> int:
    return Time.get_ticks_msec()   # or the run-start-relative ms BUG1 captures (confirm)
```

```gdscript
# ui/hud/exposure_readout.gd  (ui-ux-designer; pure projection, mirrors decision_hud.gd)
extends Control
@onready var _bar: ProgressBar = %ExposureBar
@onready var _label: Label = %ExposureLabel

func _ready() -> void:
    var cfg = GameState.active_run_config
    visible = cfg != null and cfg.r3_enabled        # hidden with R3 off → HUD == M1.0
    EventBus.exposure_meter_changed.connect(_on_meter_changed)

func _on_meter_changed(value: float, maximum: float) -> void:
    _bar.max_value = maximum
    _bar.value = value
    _label.text = tr("HUD_EXPOSURE_FMT") % [int(value), int(maximum)]   # "Exposure: 42 / 100"
```

**Emit-cadence note:** `_emit_meter_changed()` every frame while climbing is fine for a greybox HUD (one signal/frame), matching how A3's clock emits `dive_clock_changed` continuously. If the Director wants to throttle, emit only on integer-value change — a trivial later optimization, not a correctness issue.

---

## 7. Config defaults recommendation

### 7.1 All-off default (the permanent control — ships in the default `.tres`)

Per R0, the default `RunConfig` reproduces M1.0 exactly. R3's contribution to that default is **already correct** in `run_config.gd`:

```
r3_enabled            = false
r3_base_climb_rate    = 0.0
r3_rate_per_depth     = 0.0
r3_threshold_levels   = []          (empty)
r3_penalty_kind       = 0  (none)
r3_penalty_magnitude  = 0.0
r3_max_forces_loss    = false
r3_decay_on_retreat   = 0.0
```

No change to the default `.tres` is needed for R3. With these, R3 is inert and the HUD bar is hidden → the run equals the M1.0 baseline. **Do not author non-zero defaults.**

### 7.2 First sweep set (Director starts here in the CFG menu — NOT baked into data)

These are **menu-entered starting points** for the playtest sweep, sized against `METER_MAX = 100` and the M1 dials (60s dive clock, ~18s median run, depth typically a handful of indices on the linear spine). They are **recommendations to enter live**, not values to commit to the default `.tres`.

| Knob | Sweep A — "soft pressure, retreat relieves" | Sweep B — "hard ratchet, deep = lethal" | Rationale |
|---|---|---|---|
| `r3_enabled` | true | true | turn it on |
| `r3_base_climb_rate` | 1.0 /s | 0.5 /s | A: meter fills in ~100s even at depth 0 (slower than the 60s clock — lingering anywhere creeps); B: depth dominates |
| `r3_rate_per_depth` | 1.5 /s per depth | 4.0 /s per depth | B at depth 4 ≈ 16/s → fills in ~6s of deep lingering (sharp deep-room tax) |
| `r3_threshold_levels` | `[40, 70, 90]` | `[50, 85]` | A: three escalating warnings; B: one mid warning then near-cap |
| `r3_penalty_kind` | 1 (speed) | 3 (clock) | A: getting slower deep is felt but survivable; B: eats the dive clock, compounding |
| `r3_penalty_magnitude` | 0.20 | 6.0 (seconds) | A: each crossing −20% speed (3 crossings → floor at 0.40, near SPEED_FLOOR); B: each crossing −6s clock |
| `r3_max_forces_loss` | false | true | A: penalty-only pressure; B: max meter = forced `timeout` |
| `r3_decay_on_retreat` | 3.0 /s | 0.0 (ratchet) | A: retreating shallow buys the meter down (relief valve, rewards reading the threat); B: no escape but extraction |

**Sweep intent:** A tests whether *soft, recoverable* depth pressure shifts behavior (does anyone now extract early to dodge the slowdown?). B tests whether a *hard, depth-lethal* meter produces the missing `timeout` outcomes M1.0 lacked (30 extract / 0 timeout). The Director sweeps between and around these to find where the gamble lives. Record each run's config via the TEL snapshot so RG2 can compare.

---

## 8. Files to create / touch

**Create (R3, wave-2 worktree):**
- `systems/oppositions/exposure_meter.gd` — the `ExposureMeter` run-state system node (§6). A `Node` placed in the dive scene (RG1/G3 assembly wires it in, like other run-systems), not an autoload. Owns the meter, climb/decay, crossings, penalties, max→timeout call, and the HUD emit.
- `ui/hud/exposure_readout.gd` + its scene fragment (e.g. a `Control` added under the E2 `DecisionHUD`) — the greybox bar/label (ui-ux-designer, §4).
- (optional) a localization key `HUD_EXPOSURE_FMT` in the HUD strings CSV (`ui/hud/hud_strings.csv`, per E2's `tr()` rule).

**Read (no edits):**
- `data/run_config/run_config.gd` / the active `RunConfig` (R0) — read R3 knobs via `GameState.active_run_config` (read-only).
- `EventBus` signals (R3 **emits** all six: `exposure_meter_changed`, `exposure_crossed`, `exposure_penalty`, `exposure_speed_mult_changed`, `exposure_vision_mult_changed`, `exposure_clock_tax`). **All six pre-declared by TEL in wave 1** (Director-ratified, §0 + §9 D1) — R3 never edits `event_bus.gd`.
- `depth_changed(depth_index, max_depth)` (BUG2) — subscribe for live depth.
- `GameState.fail_run(&"timeout")` (E3) — **call** (not edit) for the forced loss.
- `entities/player/player.gd` — the **player** (not R3) subscribes to `exposure_speed_mult_changed(mult)` and multiplies `stats.max_speed` by the cached mult in `step_velocity`. That player edit belongs to whoever owns the speed-penalty seam (coordinate at brief time; it is a player-script edit, not a `game_state.gd`/`event_bus.gd` edit).

**Confirmed NOT touched (wave-2 hard rule §6):**
- **`systems/event_bus.gd`** — NOT edited by R3. TEL pre-declares every signal R3 emits in wave 1. ✅
- **`systems/game_state.gd`** — NOT edited by R3. R3 reads `active_run_config` (R0) + live depth (BUG2), and **calls** the existing public `fail_run` — it adds no member and changes no method. ✅ (Calling `fail_run` is the Director-ratified mechanism, §9 D1; the request-signal alternative is not used.)

---

## 9. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ratified **every recommendation** below as a committed decision. The spec body now commits to one design; these entries are the canonical record. References elsewhere in this doc point here as `§9 D<n>`.

**D1 — Penalty seam: emit TEL-pre-declared signals; never edit `event_bus.gd`/`game_state.gd`.**
**Decision:** R3 reaches the player / R4-fog / A3-clock **only** by emitting multiplier/tax signals that **TEL pre-declares on `event_bus.gd` in wave 1**: `exposure_speed_mult_changed(mult: float)`, `exposure_vision_mult_changed(mult: float)`, `exposure_clock_tax(seconds: float)` (plus the three projection/telemetry signals `exposure_meter_changed(value: float, maximum: float)`, `exposure_crossed(level: int, depth: int, run_t_ms: int)`, `exposure_penalty(level: int, penalty_kind: int)`). R3 **only emits**; the consumers (Player, R4 fog, A3 clock, HUD) subscribe. The `GameState.run_speed_mult` member alternative is rejected. The max-meter loss **calls** the existing public `GameState.fail_run(&"timeout")` (a method call, not a file edit); the request-signal fallback is rejected.
*Rationale:* keeps wave-2 R3 out of both shared files (TEL is the sole `event_bus.gd` editor) while reusing the locked run-end API — the decoupling the wave-2 rules require.

**D2 — "Retreating" detection: stateless `live_depth < max_depth_reached`.**
**Decision:** retreat is detected by the stateless `< max` test against the BUG2 surface; no per-sample delta tracking.
*Rationale:* simplest correct rule for a throwaway, reads BUG2 directly, no extra state to manage.

**D3 — Threshold re-arm: one-shot per dive, no re-arm.**
**Decision:** a crossed threshold stays crossed for the dive; decay below it does not un-fire or re-arm the penalty.
*Rationale:* trivial bookkeeping and no penalty-flicker; re-arming is an M3 balance feature, out of the throwaway's scope.

**D4 — Vision penalty: emit `exposure_vision_mult_changed`; no-op when R4 off; "requires R4."**
**Decision:** R3's `vision` kind tightens R4's fog radius via `exposure_vision_mult_changed(mult)` (contract agreed with R4 at wave-2 brief); with R4 off it is a deliberate telemetry-only no-op. The CFG menu and spec mark `r3_penalty_kind = vision` as "requires R4 enabled to be felt." R3 builds no fog of its own.
*Rationale:* one fog system (R4's), no duplication; honest documentation prevents misreading a `vision`-with-R4-off sweep.

**D5 — Climb model: linear-in-depth (`base + per_depth * depth`), no `Curve` knob.**
**Decision:** the prototype ships the linear additive climb; no `Curve`/threshold-curve knob is added.
*Rationale:* linear answers "does depth-pressure shift behavior at all" and keeps the `RunConfig` schema (and CFG surface) small; a curve is added only if the sweep proves linear can't find the tension.

**D6 — Penalty-kind stacking: one kind per run.**
**Decision:** `r3_penalty_kind` selects exactly one kind per run; multi-kind stacking is not built for the gate.
*Rationale:* matches the enum, keeps the sweep attributable (one penalty per behavior change); multi-kind is a deferred `RunConfig` schema follow-up, not a wave-2 surprise.

**D7 — Meter vs. A3 dive clock: independent by default, coupled only via the `clock` kind.**
**Decision:** R3's meter is an **independent** depth-weighted pressure; it touches the A3 flat clock **only** when `r3_penalty_kind = clock` (which emits `exposure_clock_tax` for A3 to subtract). Any other kind leaves the two pressures fully independent. The Director accepts two clock-like pressures on screen when `clock` is selected; ui-ux owns the HUD legibility of "two bars" in that config (the R3 bar is hidden entirely with R3 off, §4).
*Rationale:* the knobs let the sweep decide whether coupling or independence reads better, with no schema cost; flagging the two-bar load to ui-ux protects readability.

---

*Living spec. The §9 decisions are Director-ratified (2026-06-19) and the body commits to them. Authored pre-BUG2/pre-TEL-merge — the six R3 signal names + signatures are now pinned (TEL pre-declares them in wave 1, §0/§9 D1); still confirm the BUG2 live-depth surface name at wave-2 brief time and update `M1_As_Built.md` if it differs. One R3 worklog covers the general-purpose meter + ui-ux HUD readout.*
