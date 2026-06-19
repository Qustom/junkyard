# I3 — R2/R3 Visual Cues (expanded design spec)

**Milestone:** M1.2 — Greybox: Legibility & Level Scale · **Workstream:** (b) Wave 2 — oppositions retuned to the new canvas
**Task id:** I3 · **Design author:** ui-ux-designer · **Fresh-eyes resolver (Phase 3):** game-director-designer (independent design lens) · **Builder:** ui-ux-designer · **Status:** READY (Phase 3 complete 2026-06-19 — §3 resolved in "Resolved Decisions"; 5 CLOSED, 2 flagged for Director: Q3 salience, Q5 shake)
**dependsOn:** none — R2/R3 already emit every signal this task projects (`M1.2_Breakdown.md` §I3). Builds on the M1.1 HUD on `main`.
**Companions:** `M1.2_Breakdown.md` (§I3, §3 Wave 2, §6 wave order) · `design/M1_1_Tasks/G4_findings_M1.1.md` (§2 I3 triage — the premise) · `design/M1_1_Tasks/R3_exposure_meter.md` §4 (the R3 HUD pattern) · `design/M1_1_Tasks/R2_costlier_return.md` §4 (the R2 signal) · `M1_As_Built.md` (canonical APIs — wins on any conflict) · `ui/hud/decision_hud.gd`/`.tscn`, `ui/hud/exposure_readout.gd`, `ui/hud/hud_strings.csv` (the surfaces this task edits)

---

## 0. Guardrail header — READ FIRST

This task is **pure HUD projection of signals that already exist.** It is **DESIGN ONLY** at Phase 2; the build wave wires the cues. The hard rules:

- **No new game state, no new game logic.** Every cue is a projection of an *already-emitted* EventBus signal. R2/R3 already fire; I3 only *renders* what they fire. The HUD owns **no source of truth** (the E2 `decision_hud.gd` contract).
- **No new EventBus signal needed.** Every cue maps to a signal **already pre-declared on `event_bus.gd` and already emitted** by R2/R3 (confirmed against `systems/event_bus.gd`, see §1). If the build wave discovers a cue truly *needs* a new signal, it must be **pre-declared the M1.1 way** (TEL/owner declares it on `main` before the parallel wave; the HUD only subscribes) — but this spec is authored so that **none is required**.
- **Off = M1.0 HUD.** Every cue is visible **only when its opposition is enabled** (`r2_enabled` / `r3_enabled` read from `GameState.active_run_config`, read-only). An all-off run's HUD is **byte-for-byte the M1.1/M1.0 baseline** — no extra bar, no flash, no indicator. This preserves the permanent control.
- **Greybox.** Plain default-theme `ProgressBar`/`Label`/`ColorRect`, `Tween`-driven flashes, no art. A human owns the visual polish pass; I3 hands off placeholder styling only.
- **Honor the E2 readability rules** (`decision_hud.gd` header): every colour cue is backed by a **redundant non-colour channel** (a numeric readout, a tick mark, a shape/position change, or motion), strings go through `tr()` against `ui/hud/hud_strings.csv`, and the **at-risk numbers stay highest-contrast** regardless of band styling.

---

## 1. Goal & premise research

> **One sentence:** R2 (egress toll) and R3 (exposure) **bite mechanically but fire invisibly** — make the player *see* the exposure climb, *see/feel* each threshold penalty, and *see/feel* each retreat toll, using only the signals R2/R3 already emit.

### 1.1 Why (the premise)

`G4_findings_M1.1.md` §2 (the M1.2-triggering triage) records I3 at priority **M**:

> **I3 — Exposure (R3) + walkback (R2) have no visual cues.** Mechanically firing (5 timeouts) but invisible: R3's HUD bar isn't legible/telegraphed; R2's clock-toll has no dedicated cue (clock just drops). Fix: R3 — prominent exposure bar + threshold ticks + penalty flash. R2 — a "toll" pulse on the clock + a retreat-cost indicator. UI work.

The headline data (`G4_findings_M1.1.md` §1): R2-only and R3-only runs produced **5 `timeout` losses** (2 from R2, 3 from R3) that M1.0 never had, and R3 shortened the median run from 16.9 s to 5.2 s. **So the cost mechanics work** — they *can* change the outcome. But the Director **can't see what's happening on screen** while it happens: the exposure bar exists (M1.1 R3) but isn't legible/telegraphed enough to read mid-dive, and the egress toll has *no* dedicated cue at all — the dive clock just drops a little faster with no signal that *the toll* caused it. M1.2's whole thesis (`M1.2_Breakdown.md` §1) is that the cost axis must become **legible** before the "is the gamble fun" verdict is fair. I3 is the legibility half for the two attritional oppositions.

### 1.2 The real signals (confirmed against `systems/event_bus.gd` on `main`)

All six are **already declared and already emitted** — I3 subscribes only:

| Signal (exact signature on `event_bus.gd`) | Emitted by | What I3 renders |
|---|---|---|
| `exposure_meter_changed(value: float, maximum: float)` | R3 each frame while climbing | the exposure **bar fill + numeric readout** (R3's existing `exposure_readout.gd` already does this) |
| `exposure_crossed(level: int, depth: int, run_t_ms: int)` | R3 on each rising-edge threshold crossing | a **threshold-cross flash** + tick highlight |
| `exposure_penalty(level: int, penalty_kind: StringName)` | R3 each time a crossing's penalty applies | the **penalty flash** + a `tr()`'d penalty banner ("Slowed" / "Sight narrows" / "Light drains") |
| `return_cost_incurred(depth: int, cost_kind: StringName, magnitude: float)` | R2 on each retreat-cost event | the **clock-toll pulse** + a floating **"-N retreat cost"** indicator |

> **Note on `exposure_penalty` arity.** `R3_exposure_meter.md` §3.1 narrated `penalty_kind` as an `int` enum, but the **as-built signal on `event_bus.gd` is `exposure_penalty(level: int, penalty_kind: StringName)`** — `penalty_kind` is a `StringName` (`&"speed"` / `&"vision"` / `&"clock"` / `&"none"`). `M1_As_Built.md` / the live signature wins; I3 keys the penalty banner off the **`StringName`** kind. Confirm the exact kind strings R3 emits at brief time (likely the `@export_enum("none","speed","vision","clock")` labels in `run_config.gd`).
>
> `r3_threshold_levels` is `PackedFloat32Array` on `run_config.gd` (the ascending meter values, against the fixed `METER_MAX = 100.0` frame). I3 reads it **read-only** from `GameState.active_run_config.r3_threshold_levels` to draw the tick marks — no new state.

### 1.3 The existing HUD (what's there, and why R3's bar isn't legible enough)

- **`ui/hud/decision_hud.gd` + `.tscn` (E2)** is the model for a *good* readout. The **dive-clock bar** (`ClockBar`, top-right `VBoxContainer`) is the gold standard: a `ProgressBar` whose fill *and* an off-ladder green→amber→red `modulate` ramp *and* a numeric "`Ns`" `Label` all encode the same quantity — three redundant channels — plus a Holding-label **pulse** under `urgency_fraction`. It is pure projection (`dive_clock_changed`, `run_inventory_changed`, `band_entered`), signal-driven, no polling, all strings via `tr()`. **The clock bar is the template for both I3 cues.**
- **`ui/hud/exposure_readout.gd` (R3's current bar)** is a child `Control` of the DecisionHUD root. It projects `exposure_meter_changed` to a `ProgressBar` (`%ExposureBar`) + a numeric `Label` (`%ExposureLabel`, "Exposure: 42 / 100"), and shows only when `r3_enabled`. **Why it isn't legible enough (the G4 gap):** it is *correct but inert* —
  1. **No colour ramp** — unlike the clock bar it never tints, so the player can't read "danger now" at a glance (the numeric label is the only severity cue, and it's small at `font_size 16` low-left).
  2. **No threshold telegraph** — `r3_threshold_levels` are invisible, so the next penalty is a surprise; the player can't see "two ticks away from a slowdown."
  3. **No penalty feedback** — `exposure_crossed`/`exposure_penalty` fire into the void; nothing on screen marks the *moment* a penalty lands, so a sudden slowdown reads as a bug, not a consequence.
  4. **Low salience/position** — tucked under the Holding label at low-left (`offset_top = 50`), small, static; it doesn't draw the eye the way the climbing pressure deserves.

I3 closes all four gaps for R3 and adds R2's missing cues, reusing the clock-bar pattern.

---

## 2. Design / approach + pseudocode

### 2.1 Where the cues live (the seam)

**Recommendation:** **extend the existing HUD surfaces in place**, do not build a separate overlay scene:
- **R3 cues** extend `ui/hud/exposure_readout.gd` + its `ExposureReadout` sub-tree in `decision_hud.tscn` (the bar already lives there; add the ramp, the ticks, and a flash overlay to the same node).
- **R2 cues** extend `ui/hud/decision_hud.gd` (it already owns the clock bar — the toll pulse is a flash *on that bar*) plus a small floating-indicator node added under the DecisionHUD `Root`.

Rationale: both cues are *projections of the same decision surface* the DecisionHUD already owns; a separate overlay would duplicate the run-boundary visibility bookkeeping and the `tr()` plumbing for no benefit, and would risk a second source of "what's the clock doing." Keeping R2's toll pulse *on the existing clock bar* is also the most honest cue — the toll **is** a clock drain, so flashing the clock is causally truthful. (See Open Question Q1 — flagged for the Director; the floating-indicator-vs-log-line choice is Q2.)

**Single-writer note (per `M1.2_Breakdown.md` §6):** I3 is HUD-disjoint from the other Wave-2 tasks (I2 hazard, I4 vision touch `hazard_entity`/`vision_fog`/`main_game.gd`, not the HUD). I3 owns `decision_hud.gd/.tscn`, `exposure_readout.gd`, and `hud_strings.csv` for the wave — no cross-file collision expected.

### 2.2 R3 — prominent exposure bar + threshold ticks + penalty flash/shake

Three additions to `ExposureReadout`, all driven by signals it already (or newly) subscribes to:

**(a) Colour ramp + bigger bar (legibility gap #1, #4).** Tint `%ExposureBar` green→amber→red as a function of `value/maximum`, reusing the DecisionHUD's off-ladder ramp constants so R2/R3/clock share **one** ramp source (the readability "one source of truth shared with art" rule). The numeric label and the bar fill remain the redundant non-colour channels. Raise the bar's prominence in the `.tscn` (taller `custom_minimum_size`, higher position, larger label font) — a greybox styling change, not new logic.

**(b) Threshold ticks (gap #2).** Draw a small tick on the bar at each `r3_threshold_levels[i] / maximum` fraction, read **read-only** from `active_run_config` at run start. Greybox: thin `ColorRect` children positioned by fraction, or a `_draw()` overlay. A **crossed** tick switches to a "spent" style (filled/checked) on `exposure_crossed` so the player sees *how many penalties remain* — a non-colour (shape/state) channel telegraphing the next bite. Ticks are the **redundant non-colour telegraph** behind the colour ramp.

**(c) Penalty flash + optional shake (gap #3).** On `exposure_crossed`, flash the bar (a `Tween` punching `modulate`/a brief white overlay back to rest) and highlight the just-crossed tick. On `exposure_penalty`, show a short `tr()`'d **penalty banner** naming the kind (`&"speed"` → "Slowed", `&"vision"` → "Sight narrows", `&"clock"` → "Light drains", `&"none"` → no banner) that fades out. The flash is the redundant **motion** channel; the banner is the redundant **text** channel; neither relies on colour alone. An optional **screen-shake** on penalty is **out of scope by default** and gated behind an accessibility toggle if added at all (Open Question Q5 — Director feel call; M5 owns the global shake toggle).

```gdscript
# ui/hud/exposure_readout.gd  (EXTENDS the existing R3 bar — projection only, no new state)
class_name ExposureReadout
extends Control

@onready var _bar: ProgressBar = %ExposureBar
@onready var _label: Label = %ExposureLabel
@onready var _flash: ColorRect = %ExposureFlash      # NEW greybox node: white overlay, alpha 0 at rest
@onready var _banner: Label = %ExposurePenaltyBanner # NEW greybox node: fades a penalty name
@onready var _ticks: Control = %ExposureTicks        # NEW greybox node: hosts threshold tick rects

# Shared ramp — same constants as decision_hud.gd (one source of truth for art; §3 readability).
const RAMP_GREEN := Color(0.30, 0.85, 0.35)
const RAMP_AMBER := Color(0.95, 0.80, 0.20)
const RAMP_RED   := Color(0.92, 0.26, 0.24)

func _ready() -> void:
    EventBus.exposure_meter_changed.connect(_on_meter_changed)
    EventBus.exposure_crossed.connect(_on_crossed)      # NEW: threshold telegraph + flash
    EventBus.exposure_penalty.connect(_on_penalty)      # NEW: penalty banner
    EventBus.run_started.connect(_on_run_boundary)
    EventBus.run_ended.connect(_on_run_boundary)
    _refresh_visibility()

func _on_meter_changed(value: float, maximum: float) -> void:
    _bar.max_value = maximum
    _bar.value = value
    var frac: float = (value / maximum) if maximum > 0.0 else 0.0
    _bar.modulate = _ramp(frac)                          # colour channel
    _label.text = tr("HUD_EXPOSURE_FMT").format({"value": int(value), "max": int(maximum)})  # numeric channel

func _on_crossed(level: int, _depth: int, _run_t_ms: int) -> void:
    _mark_tick_spent(level)                              # shape/state channel: this penalty is now spent
    _punch_flash()                                       # motion channel: a moment happened

func _on_penalty(_level: int, penalty_kind: StringName) -> void:
    var key := _penalty_banner_key(penalty_kind)         # &"speed"→"HUD_PENALTY_SPEED", etc.
    if key == &"":
        return                                           # &"none" → telemetry-only, no banner
    _banner.text = tr(key)                               # text channel
    _fade_banner()

func _on_run_boundary(_a = null, _b = null, _c = null) -> void:
    _refresh_visibility()
    _rebuild_ticks()                                     # read r3_threshold_levels (read-only) per run

func _refresh_visibility() -> void:
    var cfg: RunConfig = GameState.active_run_config
    visible = cfg != null and cfg.r3_enabled             # off = M1.0 HUD

func _rebuild_ticks() -> void:
    # Read-only projection of r3_threshold_levels → tick rects at level/100 fractions.
    var cfg: RunConfig = GameState.active_run_config
    # ... position one greybox ColorRect per threshold; reset all to "unspent" style ...

# _ramp / _punch_flash / _fade_banner / _mark_tick_spent / _penalty_banner_key: greybox Tween + lookup helpers.
```

### 2.3 R2 — clock-toll pulse + floating "-N retreat cost" indicator

Two cues, both projecting `return_cost_incurred(depth, cost_kind, magnitude)`:

**(a) Clock-toll pulse.** When `cost_kind == &"clock"`, the toll *is* a dive-clock drain (R2 routes through `DiveClock.modify_light(-cost)`), so the most truthful cue is to **flash the existing clock bar** the player already watches — a brief `Tween` punch on `%ClockBar` (a white/amber pulse settling back to its ramp colour) so the drop reads as *the toll biting*, not background drain. For non-clock kinds (`&"exposure"` → R3's shared meter, `&"meter"` → R2's own debt) the clock didn't move, so the pulse instead lands on the relevant readout (the exposure bar for `&"exposure"`; the floating indicator alone for `&"meter"`). The pulse is the **motion** channel.

**(b) Floating "-N retreat cost" indicator.** On every `return_cost_incurred`, show a short-lived `tr()`'d indicator (e.g. "-12 light" / "-8 exposure" / "-N retreat cost") that rises and fades — the **text + magnitude** channel, so the player reads *how much* the toll cost and *which* resource, not just that something flashed. `cost_kind` selects the unit string; `magnitude` fills the number. (`&"decay"` from `decay_behind` link-collapse → a "route collapsed" indicator with no number, since its magnitude is a link count.)

```gdscript
# ui/hud/decision_hud.gd  (EXTENDS E2 — projection only; the toll pulse rides the clock bar it already owns)
func _ready() -> void:
    # ... existing E2 connections (dive_clock_changed, run_inventory_changed, band_entered, boundaries) ...
    EventBus.return_cost_incurred.connect(_on_return_cost)   # NEW: R2 toll cues
    _refresh_r2_visibility()

func _on_return_cost(depth: int, cost_kind: StringName, magnitude: float) -> void:
    if not _r2_enabled():                                 # off = M1.0 HUD; never fires when R2 disabled
        return
    if cost_kind == &"clock":
        _pulse_clock_bar()                                # motion channel on the bar the toll actually drained
    _spawn_cost_indicator(cost_kind, magnitude)           # text+magnitude channel: "-12 light"

func _spawn_cost_indicator(cost_kind: StringName, magnitude: float) -> void:
    var unit := _cost_unit_key(cost_kind)                 # &"clock"→"HUD_COST_LIGHT", &"exposure"→..., &"decay"→...
    var label := tr("HUD_RETREAT_COST").format({"amount": int(magnitude), "unit": tr(unit)})
    # ... spawn a transient Label under Root, Tween rise+fade, free on finish ...

func _refresh_r2_visibility() -> void:
    var cfg: RunConfig = GameState.active_run_config
    _r2_cues_active = cfg != null and cfg.r2_enabled      # gate all R2 cues; off → no extra HUD

# _pulse_clock_bar: Tween punch on %ClockBar's modulate back to _urgency_color(_clock_fraction).
```

### 2.4 New `tr()` strings (added to `ui/hud/hud_strings.csv`)

Externalized per the readability rule (no inline player-facing text):

| key | en (greybox placeholder) | used by |
|---|---|---|
| `HUD_PENALTY_SPEED` | `Slowed` | R3 penalty banner (`&"speed"`) |
| `HUD_PENALTY_VISION` | `Sight narrows` | R3 penalty banner (`&"vision"`) |
| `HUD_PENALTY_CLOCK` | `Light drains` | R3 penalty banner (`&"clock"`) |
| `HUD_RETREAT_COST` | `-{amount} {unit}` | R2 floating cost indicator |
| `HUD_COST_LIGHT` | `light` | R2 indicator unit (`cost_kind == &"clock"`) |
| `HUD_COST_EXPOSURE` | `exposure` | R2 indicator unit (`cost_kind == &"exposure"`) |
| `HUD_COST_METER` | `egress debt` | R2 indicator unit (`cost_kind == &"meter"`) |
| `HUD_COST_DECAY` | `route collapsed` | R2 indicator (`cost_kind == &"decay"`, no number) |

(`HUD_EXPOSURE_FMT`, `HUD_CLOCK_TIME` etc. already exist — reused as-is.)

### 2.5 Does any cue need a NEW EventBus signal?

**No.** Every cue maps to one of the four signals already declared **and** already emitted (§1.2). The R3 bar already subscribes to `exposure_meter_changed`; this task adds subscriptions to `exposure_crossed`, `exposure_penalty` (both already emitted by R3), and `return_cost_incurred` (already emitted by R2). **Zero new signals, zero new game state, zero `event_bus.gd` edit.** If the build wave finds a genuine gap (e.g. it wants an explicit "toll bit the clock" event distinct from a background drain — but `return_cost_incurred` with `cost_kind == &"clock"` already conveys this), it must be **pre-declared the M1.1 way** (owner declares on `main` before the parallel wave; HUD subscribes only) — flagged here, but the design needs none.

### 2.6 Readability-rule checklist (every cue passes)

| Cue | Colour channel | Redundant non-colour channel(s) |
|---|---|---|
| Exposure bar | green→amber→red ramp | numeric "N / 100" label + bar fill length |
| Threshold ticks | (none — neutral) | tick **position** (telegraph) + spent/unspent **shape state** |
| Threshold cross | flash colour | **motion** (punch) + tick state change |
| Penalty | flash colour | **text** banner (`tr()`) + **motion** |
| R2 clock-toll | clock-bar pulse colour | **motion** (pulse) on the already-numeric clock bar |
| R2 cost indicator | (neutral text) | **number** (magnitude) + **unit text** + **motion** (rise/fade) |

The **legibility layer holds in every band**: these cues are HUD-space (CanvasLayer), unaffected by band lighting/palette, and the at-risk numbers (clock seconds, exposure value, cost magnitude) stay highest-contrast (white + outline, per the existing `.tscn` theme overrides).

---

## 3. Open Questions (Phase-3 fresh-eyes pass resolves; Director feel/legibility calls flagged)

**Q1 — Where do the cues live: extend `decision_hud`/`exposure_readout` in place, or a new dedicated overlay scene?** *Recommendation:* extend in place (§2.1) — the cues are projections of the decision surface the DecisionHUD already owns, and the R2 toll pulse is causally the clock bar. **Director/legibility call:** is one combined surface clearer, or does a dedicated "pressure overlay" read better when several oppositions stack? *(Leans: extend in place.)*

**Q2 — Floating world-space cost text vs. a HUD-anchored indicator vs. a log line?** *Recommendation:* a HUD-anchored floating indicator near the clock bar (§2.3b), not world-space (world-space pixel-art floating combat text is a later art concern and fights the greybox norm), and not a scrolling log (a log buries the *moment*). **Director feel call:** does a transient near-clock "-N light" read as *the toll*, or does it need to originate at the player to feel diegetic? *(Leans: HUD-anchored transient.)*

**Q3 — How prominent is too prominent (greybox legibility vs. cluttering the screen)?** The exposure bar must get *more* salient (the G4 gap), but stacking R3 ramp + ticks + flash + banner + R2 pulse + cost indicator + the E2 clock + Holding + Depth risks a busy HUD in an all-on config. **Director legibility call:** what's the salience budget — e.g. cap simultaneous flashes, debounce the penalty banner, or share one "pressure region" of the screen? *(Leans: debounce/queue flashes; keep one left-column pressure stack.)*

**Q4 — Do R2 and R3 share one unified "pressure" readout, or stay two separate cues?** R2 (toll) and R3 (exposure) are *different* pressures (a discrete retreat charge vs. a continuous climbing meter), and `R3 §9 D7` already flagged the "two clock-like bars" readability load when R2's `exposure` toll feeds R3's meter. *Recommendation:* keep them **separate** (different mental models; the toll is event-y, the meter is continuous), but co-locate them in one screen region for a coherent "pressure" read. **Director legibility call.** *(Leans: separate cues, co-located.)*

**Q5 — Is a screen-shake on penalty in scope?** A short shake on `exposure_penalty` would make the bite visceral, but shake is an accessibility concern (M5 owns the global screen-shake toggle + telemetry per the playbook) and can read as jank in greybox. *Recommendation:* **out of scope by default**; if added, gate behind the (future) accessibility toggle, default off, and never make it the *only* channel. **Director feel call.** *(Leans: defer; flash + banner suffice for the gate.)*

**Q6 — Threshold ticks: live `_draw()` overlay vs. pre-placed `ColorRect` children?** A greybox-implementation choice (both are signal-free read-only projections of `r3_threshold_levels`). *Recommendation:* whichever the builder finds cheaper; `_draw()` scales cleaner if the bar resizes, `ColorRect` children are simpler to style later. **Builder's call, not the Director's** — noted for completeness.

**Q7 — Penalty banner persistence when penalties stack fast (B-sweep "hard ratchet").** In R3's `r3_threshold_levels = [50, 85]` biting sweep, two crossings can land seconds apart; a banner per crossing could thrash. *Recommendation:* fade-and-replace (latest wins) with a minimum on-screen time, or a tiny stack count. **Director/legibility call**, tied to Q3's salience budget. *(Leans: latest-wins with a floor duration.)*

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

**Reviewer:** game-director-designer (independent design/feel lens; did NOT author §0–§3). **Method:** read the doc, `M1.2_Breakdown.md` §I3, `G4_findings_M1.1.md` §2, and the *as-built source* — `event_bus.gd` (signal signatures), `exposure_meter.gd` + `return_cost.gd` (what's actually emitted), and the three HUD surfaces (`decision_hud.gd`, `exposure_readout.gd`, `hud_strings.csv`). The author's APIs are correct; the resolutions below close every question against the as-built reality, with three genuine feel/legibility calls escalated.

### Confirmed against source (the builder must key off these exact values)

**The author's `exposure_penalty` arity note is CORRECT and verified.** `event_bus.gd:98` declares `signal exposure_penalty(level: int, penalty_kind: StringName)` — 2nd arg is `StringName`, not `int`. `exposure_meter.gd:112` emits `EventBus.exposure_penalty.emit(idx, _penalty_kind_name())`.

**`penalty_kind` StringName values actually emitted** (`exposure_meter.gd` `_penalty_kind_name()`, lines 142–151): **`&"speed"`, `&"vision"`, `&"clock"`, `&"none"`** — exactly the four in the doc. Banner key map: `&"speed"`→`HUD_PENALTY_SPEED`, `&"vision"`→`HUD_PENALTY_VISION`, `&"clock"`→`HUD_PENALTY_CLOCK`, `&"none"`→no banner (`tr()` key resolves to `&""` → early-return).

**`cost_kind` StringName values actually emitted by R2** (`return_cost.gd` `_charge()` + `_maybe_decay_links_behind()`, lines 144/154/157/190): **`&"clock"`, `&"exposure"`, `&"meter"`, `&"decay"`** — exactly the four in the doc. The doc's unit-key map is correct.

**TWO load-bearing facts the source revealed that reshape the open questions** (the builder must honor these; they are not optional):

- **F1 — `penalty_kind` is run-CONSTANT, not per-crossing.** `_apply_penalty()`/`_penalty_kind_name()` both read the single `_cfg.r3_penalty_kind` enum, so *every* `exposure_penalty` in a given run carries the **same** kind string. The banner text never *changes* within a run — only the *number* of crossings does. This collapses Q7: there is no "different message thrash," only "the same penalty bit again, harder." (Drives Q7's resolution.)
- **F2 — `exposure_crossed` and `exposure_penalty` fire same-frame, paired, in lockstep** (`exposure_meter.gd:108` then `:112`), once per threshold, never re-armed (`_levels_crossed` one-shot). On `&"none"`, `exposure_crossed` *still* fires (so tick-spend + flash play) while `exposure_penalty` carries `&"none"` (no banner). The telegraph survives the telemetry-only control. **Builder rule: drive flash + tick-spend off `exposure_crossed`; drive the banner off `exposure_penalty`** — do not double-flash by reacting to both.

---

### Q1 — Where do the cues live? → **RESOLVED: extend in place. CLOSED.**
**Decision:** Extend `exposure_readout.gd`/`ExposureReadout` (R3) and `decision_hud.gd` + its `Root` (R2). No new overlay scene. The author's lean is right and I'm closing it, not escalating — this is a design-merit call, not a taste call. The R2 toll *is* a `DiveClock.modify_light(-cost)` drain (`return_cost.gd:143`), so flashing the clock bar the player already watches is the **causally truthful** cue; a separate overlay would invent a second "what is the clock doing" surface and duplicate the run-boundary visibility bookkeeping both HUDs already do correctly. **Rationale:** legibility of a gamble comes from *fewer, co-located* surfaces, not more; the "pressure overlay when oppositions stack" worry is really a salience-budget question, which is Q3's job, not a reason to split scenes.

### Q2 — Floating cost text: world-space vs HUD-anchored vs log? → **RESOLVED: HUD-anchored transient. CLOSED.**
**Decision:** A short-lived HUD-anchored indicator that rises+fades, spawned under `Root` near the clock bar (the surface the toll actually drained). Not world-space, not a log. **Rationale:** (1) world-space pixel-art floating text is a later art concern and fights the greybox norm; (2) a scrolling log buries *the moment* — the whole G4 complaint is that the toll is invisible *as it bites*, which is a moment-cue need, not a history need; (3) anchoring it next to the clock bar makes the cause ("the clock just dropped because of *this*") spatially legible. I'm closing this on design merit — "diegetic origin at the player" is an art-polish nicety the greybox gate does not need, and the human owns the later polish pass anyway. The transient near-clock "-N light" reads as the toll precisely *because* it's adjacent to the drain.

### Q3 — Salience budget (how prominent is too prominent)? → **⚠ NEEDS DIRECTOR REVIEW** (with a concrete recommendation to build against now).
**Recommendation to build against (so the wave is not blocked):**
- **One left-column "pressure stack."** Co-locate the exposure bar (made taller/higher per the G4 gap), its ticks, its flash, and its penalty banner in one vertical region; keep the E2 clock/Holding/Depth in their existing top-right cluster. The R2 cost indicator spawns near the clock (its causal home). This gives the eye **two** pressure zones (continuous = left, event = top-right), not seven scattered flashes.
- **One flash at a time.** A single shared "flash budget": when a new crossing/toll flash starts, it *replaces* (re-triggers) rather than stacks — `Tween.kill()` the prior then re-punch. No additive alpha pile-up.
- **Banner: latest-wins, single instance,** with a floor on-screen time (see Q7).
**Why this is the Director's call, not mine:** "how busy is too busy" with all oppositions on is exactly a *felt-legibility* judgment that only reads true in a live playtest on the new I1 level scale — the same class of call as the M1 "is it fun?" gate. I can make it *not-cluttered-by-construction*; whether it's *legible enough* is the gate's verdict. **Recommendation: ship the two-zone + single-flash-budget layout above; let RG1/the playtest confirm or dial it.** *(Leans: two-zone, single flash budget.)*

### Q4 — Shared vs separate R2/R3 readout? → **RESOLVED: separate cues, co-located. CLOSED.**
**Decision:** Keep them separate — they are different mental models (R3 = a continuous climbing meter you watch; R2 = a discrete event charge that *happens* to you) — but co-locate within the pressure-zone scheme of Q3. **Rationale, sharpened by source:** the `exposure` toll path (`return_cost.gd:145–154`) routes R2's charge *into R3's meter*, so when `cost_kind == &"exposure"` the **exposure bar will already move** (via `exposure_meter_changed`) *and* the cost indicator fires. Two cues for one event is fine and correct here — the bar shows the *new steady-state*, the indicator shows the *discrete bite that caused it* — but the builder must NOT additionally pulse the exposure bar for `&"exposure"` tolls (the bar's own `_on_meter_changed` ramp already reflects it; adding a pulse would double-cue). This is a design-merit close, not a Director call: the two pressures genuinely are different objects and forcing them into one unified readout would muddy the gamble.

### Q5 — Screen-shake on penalty in scope? → **⚠ NEEDS DIRECTOR REVIEW** (recommend: defer).
**Recommendation: out of scope by default for the M1.2 gate.** Flash + tick-spend + banner already give the penalty three redundant channels (motion + shape-state + text); shake adds *visceral feel* but (a) M5 owns the global screen-shake toggle + accessibility telemetry per the playbook, so shipping it here means shipping it *without* its accessibility control, and (b) un-tuned greybox shake reads as jank and can contaminate the "is the bite legible" read with "is the HUD broken." **Why the Director and not me:** whether the bite needs to be *visceral* (not just legible) to make the gamble *fun* is a feel call the playtest answers — and it's cheap to add post-gate if RG3 says "the penalties don't *land* emotionally." **Recommendation: defer; build the flash+banner; revisit only if the gate reports the penalty feels weightless.** Never make shake the *only* channel if it is ever added. *(Leans: defer.)*

### Q6 — Tick rendering: `_draw()` vs `ColorRect` children? → **RESOLVED: builder's call. CLOSED (not a design question).**
**Decision:** Builder chooses; both are signal-free read-only projections of `r3_threshold_levels`. Note for the builder: `r3_threshold_levels` is read once per run on the `run_started` boundary (rebuild ticks then), positioned at `level / METER_MAX` (METER_MAX = 100.0, a fixed const in `exposure_meter.gd:25`, NOT a config field — hardcode 100.0 or read the bar's `max_value`). No Director input needed.

### Q7 — Banner persistence when penalties stack fast? → **RESOLVED: latest-wins, single instance, floor duration. CLOSED** (collapsed by F1).
**Decision:** One banner instance, **latest-wins with a minimum on-screen time** (~0.8–1.0 s floor; builder tunes). **Rationale — F1 makes this trivial:** because `penalty_kind` is run-constant, "latest-wins" never swaps to a *different* message — it always re-asserts the *same* string ("Slowed" / "Sight narrows" / "Light drains"). So a fast `[50, 85]` double-crossing should NOT thrash text; it should **re-pulse the one banner** (re-trigger its fade with a fresh floor duration) so the player reads "it bit again." Optionally append a stack count ("Slowed ×2") to convey the *escalation* (each crossing stacks the speed mult per `exposure_meter.gd:157`), but a count is a nice-to-have, not required for the gate. The flash + the spent-tick advancing already carry "another one landed," so even a static banner is acceptable. This is design-merit closed (tied to Q3's single-flash-budget rule); no Director input needed beyond Q3's overall salience verdict.

---

### Out-of-scope note for the builder (NOT an I3 concern, do not fix here)
`return_cost.gd:152` calls `meter.call(&"add", cost)` for the `exposure` toll, but `exposure_meter.gd` exposes **no `add()` method** — the `has_method(&"add")` guard means the exposure toll currently charges *nothing* into R3's meter. That is an R2/R3 *integration* gap (owned by those systems, surfaces only when a run enables R2 with `toll_resource = exposure` AND R3), **not** an I3 cue concern: I3 only renders the `return_cost_incurred(&"exposure")` *indicator* and whatever the exposure bar shows. Flagging it so the builder does not mistake "the exposure bar didn't move on an `exposure` toll" for an I3 bug — and so RG1/QA can route it to the right owner.

---

## 4. Files to create / touch (build wave — not this Phase-2 doc)

**Edit (greybox, projection only):**
- `ui/hud/exposure_readout.gd` — add `exposure_crossed` / `exposure_penalty` subscriptions, the ramp, ticks, flash, penalty banner (§2.2).
- `ui/hud/decision_hud.gd` — add the `return_cost_incurred` subscription, the clock-toll pulse, and the floating cost indicator (§2.3).
- `ui/hud/decision_hud.tscn` — add greybox child nodes (`ExposureFlash`, `ExposurePenaltyBanner`, `ExposureTicks` under `ExposureReadout`; a cost-indicator spawn anchor under `Root`); bump the exposure bar's prominence (size/position/font).
- `ui/hud/hud_strings.csv` — add the eight new keys (§2.4).

**Read (no edits):**
- `GameState.active_run_config` (`r3_enabled`, `r2_enabled`, `r3_threshold_levels`) — read-only.
- `systems/event_bus.gd` signals — **subscribe only**, no edit (all four already declared + emitted).

**Confirmed NOT touched:** `systems/event_bus.gd`, `systems/game_state.gd`, any R2/R3 system node, any generator/`main_game.gd` file. I3 is HUD-only and adds no new signal or state.

---

*Living spec. Phase-3 fresh-eyes pass resolves §3 (Director-review items flagged); confirm at brief time the exact `penalty_kind` / `cost_kind` `StringName` values R3/R2 emit and any `M1_As_Built.md` HUD-API corrections (as-built wins). One I3 worklog covers the build wave.*

---

## Director Disposition (2026-06-19, FINAL — design locked)

Director **accepted all Phase-3 defaults**: extend the existing HUD surfaces in place; R3 = colour-ramped exposure bar +
read-only threshold ticks + penalty banner on `exposure_crossed`/`exposure_penalty` (keyed on the confirmed
`penalty_kind` StringNames **`speed`/`vision`/`clock`/`none`**); R2 = clock-bar pulse + floating "−N {unit}" on
`return_cost_incurred`; every cue backed by a non-colour channel, invisible when its opposition is off (= M1.0 HUD).
A small/optional **screen-shake on penalty is in scope** (Q5 accepted). No new EventBus signal.

**Design LOCKED.**
