# K0 — Foundation: knob + signal pre-declare (+ K1 retune) · Phase-2 Design

**Task:** K0 (M1.4 Wave 1, lands first). **Role:** general-purpose (programmer); K1 retune folds in `game-director-designer` content.
**Blocks:** K2, K3, K4, K5a, K5b, K5c, K5i, K7 (every behaviour task reads a K0-declared knob and/or emits a K0-declared signal).
**BlockedBy:** none.
**Authored:** 2026-06-21, Phase 2 of the four-phase process (`CLAUDE.md`), from `design/M1_4_Tasks/M1.4_Breakdown.md` §3/§6.

> **What this doc IS:** the **knob + signal contract** every other M1.4 build design keys off. K0 is the *single-writer pass*
> over the two shared files (`data/run_config/run_config.gd`, `systems/event_bus.gd`) so that no two Wave-2/3 tasks ever edit
> them in parallel (the M1.1 pre-declare rule, Breakdown §6). The knob/signal set below is a **provisional union** — assembled
> from the breakdown's task descriptions + open risks. It will be **refined once the K2/K3/K4/K5/K7 Phase-2 designs land**; the
> Open Questions section flags exactly which names/types are still soft. K0's job is to land *off/neutral* placeholders so the
> all-off control stays byte-identical and the build waves never touch these two files again.
>
> **What this doc is NOT:** any behaviour. K0 declares fields + signals + the K1 preset retune. It wires no quota logic, no
> camera, no hazard, no exit. Those are the consuming tasks. (Same contract R0 held for M1.1: "R0 owns only the container shape
> + the all-off default + the wiring," `run_config.gd:22-24`.)

---

## (a) Research — the as-built surface K0 extends

### A.1 `RunConfig` (`data/run_config/run_config.gd`) — the one run-scoped config object

- **Container shape + the hard contract.** `class_name RunConfig extends Resource` (`run_config.gd:1-2`). The class doc
  (`run_config.gd:3-24`) states the load-bearing invariant K0 must preserve: *"ALL-OFF DEFAULT = M1.0 BASELINE … every
  opposition disabled and every magnitude at zero/neutral, so an unconfigured run reproduces the M1.0 loop EXACTLY"*
  (`run_config.gd:17-20`). The run/meta boundary (`run_config.gd:12-15`): a `RunConfig` is **run-scoped configuration, NEVER
  persisted to SaveManager** — important for K2, whose *quota/run-number* is meta-state and so does **not** live here (only the
  *knobs that configure* the quota do).

- **The `@export_group` pattern + group prefix.** Each opposition is a group with a shared prefix the CFG menu keys off:
  `@export_group("R1 Pursuing Hazard", "r1_")` (`run_config.gd:57`), `"r2_"` (`:121`), `"r3_"` (`:140`), `"r4_"` (`:161`),
  `@export_group("Level Scale", "lvl_")` (`:192`), and `@export_group("Meta")` with no prefix (`:46`). **Every field in a group
  starts with the group's prefix** — this is the contract the ConfigMenu `SECTIONS`/`MANIFEST` rely on (see A.3). New M1.4
  groups must follow it: a new section ⇒ a new prefix ⇒ a new `@export_group(..., "<prefix>")` ⇒ a `SECTIONS`+`MANIFEST` entry.

- **Field kinds already in use** (K0's new knobs reuse exactly these widget-mapped kinds, no new kind):
  - `bool` master toggle, default `false` — `r1_enabled` (`:59`).
  - `int` — `r1_depth_threshold = 0` (`:61`), `r1_spawn_count = 0` (`:81`), `lvl_room_count = -1` (`:200`).
  - `float` — `r1_chase_speed = 0.0` (`:65`), `lvl_size_mult = 1.0` (`:207`).
  - `@export_enum("a","b","c") var x: int = 0` — `r1_spawn_distribution` (`:88`), `r1_density_metric` (`:105`),
    `r2_mechanism` (`:126`), `r3_penalty_kind` (`:150`). The CFG renders these as `OptionButton`s and the test reads the hint
    strings (A.3).
  - `PackedFloat32Array` — `r3_threshold_levels = PackedFloat32Array()` (`:148`); the ONE non-scalar (mini list-editor in CFG).
  - `String` — `build_tag = ""` (`:52`).

- **`to_flat_dict()` (`run_config.gd:281-339`)** — serializes **every** knob to a flat, JSON-safe `Dictionary` for the
  `run_started` telemetry row (additive `data`, *not* a schema bump). Keys are the field names; values are JSON primitives.
  The only special-case is `r3_threshold_levels`, routed through `_packed_to_float_array()` (`:316`, helper at `:345-349`) so
  the `PackedFloat32Array` becomes a plain `Array[float]`. **K0 must append every new knob here** in its group's comment block,
  preserving the grouped layout (`# R1` / `# R2` / … `# LVL`). New sections get their own comment block.

- **`all_oppositions_disabled()` (`:255-256`)** — `return not (r1_enabled or r2_enabled or r3_enabled or r4_enabled)`. The
  `lvl_*` axis is **deliberately excluded** (level scale is opposition-orthogonal, Resolved E, `:252-254`). **Decision for K0
  (see OQ-2):** the M1.4 hazards (K5) and quota/camera/timer/exit are *also* opposition-orthogonal-or-new-axis levers — do they
  join this predicate? Recommendation below: **the 3 new hazards (K5) are dangers like R1 and SHOULD count toward "not the
  baseline"**, but to keep the all-off-control test (`test_run_config.gd:32-34`, `:41`) and the M1.0-baseline meaning intact, the
  cleanest move is to **leave `all_oppositions_disabled()` untouched** and let the new-hazard `enabled` flags be checked by their
  own consumers — because that function literally means "reproduces the M1.0 *opposition* baseline," and all new knobs default
  off anyway, so a fresh `RunConfig.new()` is still all-off on every axis. (Folded into OQ-2.)

- **`inert_enabled_oppositions()` (`:370-397`)** — the BUG6 config-trap detector. **Not K0's to extend** (each consuming task
  may add its own trap line), but K0 should leave a comment seam so K2/K5 can append (e.g. "hazard enabled, spawn 0"). Noted in
  pseudocode as a *non-K0* TODO so a build agent doesn't wire it prematurely.

- **`make_default_play_preset()` (`:428-500`)** — the named preset the CFG rail + no-CFG fallback boot into. Built on a fresh
  `RunConfig.new()` (`:429`) so it NEVER mutates the all-off control. **This is where K1 retune lands** (A.4). The preset ends
  with an `assert(c.inert_enabled_oppositions().is_empty(), …)` (`:497-499`) — any new enabled-but-inert seam K0 adds to the
  preset must clear that assert.

### A.2 `EventBus` (`systems/event_bus.gd`) — the signal hub

- **Pure wiring, no state** (`event_bus.gd:1-6`). The pre-declare discipline is explicit and repeated: signals are *"declared
  centrally so wave-2 R1–R4 only EMIT — they never edit this file"* (`:83-85`), and the BUG2 `depth_changed` note codifies it:
  *"the declaration must exist before any emitter ships … TEL adds the opposition signals later and must NOT re-declare this"*
  (`:72-81`). **K0 is the M1.4 application of exactly this rule** (Breakdown §6: "K0 does this for the whole milestone up front").

- **Existing signal groups + the primitives-only telemetry rule.** Telemetry-row signals carry **primitives only** so
  `Telemetry` serializes straight to JSONL (`:86-88`, `:55-60`). Gameplay-event signals (not telemetry rows) may carry refs —
  e.g. `junk_dropped(item: JunkItem, …)` (`:67`). Relevant existing signals K0's new ones sit beside:
  - run lifecycle: `run_started(band_id, seed)` (`:9`), `run_ended(reason, duration_s, depth_reached)` (`:10`) — **arity LOCKED**
    (Breakdown §6): quota-fail reuses `run_ended` with a new `reason` (`&"quota_fail"`), it does **not** add a parameter.
  - economy: `currency_changed(kind, delta, source)` (`:14`), `haul_banked(total_value)` (`:15`) — K2 quota reads these.
  - dive clock: `dive_clock_changed(current, maximum)` (`:36`), `dive_clock_timeout()` (`:37`) — K4 timer extends this surface.
  - player: `player_died(cause)` (`:22`) — K5 hazards (lethal-on-contact) reuse this death path, like R1's `hazard_caught`.
  - R1 hazard telemetry: `hazard_awoke(depth, trigger)` (`:90`), `hazard_caught(depth, run_t_ms)` (`:91`) — K5's new hazards
    follow this exact telemetry-row shape.

### A.3 The two tests K0 must keep green (the knob-count contract)

- **`tests/test_run_config.gd`** — `expected_keys` (`:74-95`) is a hand-listed array of **every** `to_flat_dict()` key; Case 5
  (`:96-110`) asserts each is present, the dict is flat (no nested values), and JSON round-trips. **K0 must add every new knob
  to this array** in the matching comment block, or the test fails on a missing key. (It does NOT assert an exact count here —
  it asserts *presence* + flatness + round-trip — but the count is implied by the CFG test below.)

- **`tests/test_config_menu.gd`** — the **hard count** lives here: `if exported.size() != 46` (`:46-47`), with the breakdown in
  the comment (`:44-45`): *"R0: 32 + I2's 1 r1_ + I1's 3 lvl_ + J2's 2 r1_ + J3's 5 r1_density_* + J3's 1 lvl_loot_density_per_area
  + J4's 2 lvl_corridor_* = 46"*. `_exported_fields()` (`:103-111`) reflects RunConfig's stored+editor `@export` properties.
  **K0 must bump 46 → (46 + N_new_knobs)** and extend the comment's arithmetic. The CFG menu's own build-time coverage assertion
  (`config_menu.gd:205-232`, `has_full_coverage()`) cross-checks the bound-control set against the exported field set — so a knob
  with no MANIFEST entry crashes the menu at `_ready`.

- **The CFG menu is NOT reflection-driven for layout** (`config_menu.gd:61-64`: *"HAND-AUTHORED field manifest (§3.6 — NOT
  reflection)"*). It needs, per new knob: a `MANIFEST[prefix]` list entry (`:65-96`); per **new section** a `SECTIONS` entry
  (`:52-59`, `{prefix, title_key, gloss_key, master, collapsible}`) + CSV i18n keys; per numeric knob a `FIELD_RANGE` entry
  (`:100-136`) and optionally a `FIELD_STEP` (`:141-148`). **This wiring is the consuming UI task's job (K2/K3/K4 ui-ux,
  K5 if surfaced), NOT K0's** — but K0 *defines the knob names/types/groups they will wire*, and K0 *must bump the count tests*
  so the queue stays green between K0 landing and the UI tasks landing. (See OQ-5: do we bump the count to the full union in K0
  and accept a temporarily-red CFG coverage assert until the UI tasks wire the rows, or stage the count per-wave? Recommendation
  below.)

### A.4 K1 retune — the `make_default_play_preset()` per-depth values

The current preset's R1 per-depth block (`run_config.gd:441-443`):

```gdscript
c.r1_speed_per_depth = 18.9          # from the ba745e1 most-fun cell, verbatim
c.r1_catch_radius = 24.0             # floored to clear the 24px collision floor
c.r1_catch_radius_per_depth = 10.5
```

The K1 Director directive (Breakdown §3 K1 row): `r1_speed_per_depth → 3.0`, `r1_catch_radius_per_depth → 1.0`, **plus a third
per-depth value the Director phrased as "catch_speed_per_depth → 3.0"**. **There is no `r1_catch_speed_per_depth` knob today** —
the only per-depth knobs on R1 are `r1_speed_per_depth` (chase speed scaling, `:67`) and `r1_catch_radius_per_depth` (catch-radius
lunge, `:77`). So "catch_speed_per_depth" is a naming ambiguity K0 must resolve (OQ-1). The intent is clearly a *softening of the
per-depth ramps* — 18.9→3.0 on speed and 10.5→1.0 on catch-radius are both large reductions, consistent with "deeper got too
punishing too fast; flatten the depth curve." The third value is most likely a **restatement** of the speed ramp under a
loose name, not a request for a brand-new knob.

---

## (b) Pseudocode — the proposed K0 edits (illustrative, against the real APIs)

> All new knobs default **off/neutral** (bool→`false`, count/int→`0` or `-1`, float magnitude→`0.0`, mult→`1.0`, enum→`0`),
> exactly like every R0/I1/J2/J3/J4 knob, so a fresh `RunConfig.new()` reproduces M1.0 byte-for-byte and the all-off fingerprint
> stays `e943ac9c8bc1`. Names below are the **provisional union**; OQ flags the soft ones.

### B.1 New `@export` groups + knobs in `run_config.gd`

**K2 — Quota (configures the quota; the quota *value* that persists is meta-state in K2's save schema, NOT here):**

```gdscript
# =============================================================================
# K2 (M1.4) — Per-run quota / roguelite wipe (CONFIG knobs only; the live
# quota + run-number are META-STATE owned by K2's save schema, never here)
# =============================================================================
@export_group("K2 Quota", "quota_")
## Master toggle. OFF = no quota gate, no wipe (M1.3 behaviour).
@export var quota_enabled: bool = false
## Starting quota for run #1 (Director FINAL starting value $50 — preset, not default).
@export var quota_base_amount: int = 0
## How much the quota rises each time it is met (Director FINAL +$50/run — preset).
@export var quota_increment_per_run: int = 0
## WHEN the quota is checked (OQ-3): 0 = on_extract_only, 1 = on_any_run_end.
@export_enum("on_extract", "on_any_run_end") var quota_check_timing: int = 0
## WHAT counts toward it (OQ-3): 0 = this_run_banked, 1 = cumulative_money.
@export_enum("this_run_banked", "cumulative_money") var quota_basis: int = 0
```

**K3 — Resolution-independent camera (configures the visible world-units / zoom policy):**

```gdscript
# =============================================================================
# K3 (M1.4) — Resolution-independent camera (fixed visible world-units)
# =============================================================================
@export_group("K3 Camera", "cam_")
## Master toggle. OFF = today's camera (M1.3 behaviour — whatever the window shows).
@export var cam_enabled: bool = false
## Visible world width in px the viewport always shows, regardless of resolution.
## 0.0 = use today's behaviour (no fixed-units enforcement).
@export var cam_visible_world_width: float = 0.0
## Zoom policy when the window aspect != design aspect (OQ-4):
##   0 = fit_width (lock horizontal units), 1 = fit_height, 2 = contain (letterbox).
@export_enum("fit_width", "fit_height", "contain") var cam_zoom_policy: int = 0
```

**K4 — Configurable timer + near-end warning (surfaces the dive-clock length + a warning threshold):**

```gdscript
# =============================================================================
# K4 (M1.4) — Configurable dive timer + near-end warning
# =============================================================================
@export_group("K4 Timer", "timer_")
## Master toggle. OFF = today's DiveClockConfig length, no warning (M1.3 behaviour).
@export var timer_enabled: bool = false
## Dive length (s). 0.0 = use the existing DiveClockConfig default (OQ-6: knob vs config).
@export var timer_length_s: float = 0.0
## Seconds-remaining at which the near-end warning fires ONCE. 0.0 = no warning.
@export var timer_warning_threshold_s: float = 0.0
## Warning channel: 0 = visual_only, 1 = visual+audio.
@export_enum("visual_only", "visual_audio") var timer_warning_channel: int = 0
```

**K5a/b/c — the 3 new hazards. Provisional: one group per hazard, parallel to R1 (OQ-7):**

```gdscript
# =============================================================================
# K5a (M1.4) — Ping-pong hazard (bounces off room walls, lethal on contact)
# =============================================================================
@export_group("K5a Ping-Pong Hazard", "hpp_")
@export var hpp_enabled: bool = false
@export var hpp_base_count: int = 0              # spawns at depth 0 (per band/room — K5i decides)
@export var hpp_count_per_depth: float = 0.0     # additive count scaling per within-band depth
@export var hpp_speed: float = 0.0               # travel speed (px/s, greybox)
@export var hpp_per_room_cap: int = 0            # 0 = uncapped (preset MUST set > 0, perf guard)

# =============================================================================
# K5b (M1.4) — Bomb hazard (proximity pulse ~2s then explode; kills in radius)
# =============================================================================
@export_group("K5b Bomb Hazard", "hbomb_")
@export var hbomb_enabled: bool = false
@export var hbomb_base_count: int = 0
@export var hbomb_count_per_depth: float = 0.0
@export var hbomb_trigger_radius: float = 0.0    # proximity that starts the pulse
@export var hbomb_blast_radius: float = 0.0      # lethal radius at detonation
@export var hbomb_fuse_s: float = 0.0            # pulse duration before explode (Director ~2s preset)
@export var hbomb_per_room_cap: int = 0

# =============================================================================
# K5c (M1.4) — Rotating-spikes hazard (rotates in place, lethal on contact)
# =============================================================================
@export_group("K5c Rotating Spikes", "hspike_")
@export var hspike_enabled: bool = false
@export var hspike_base_count: int = 0
@export var hspike_count_per_depth: float = 0.0
@export var hspike_rotation_speed: float = 0.0   # deg/s (signed → direction)
@export var hspike_arm_length: float = 0.0       # reach of the lethal arm (px)
@export var hspike_per_room_cap: int = 0
```

**K7 — Exit placement rework (random/multiple exits, run-config-keyed for determinism):**

```gdscript
# =============================================================================
# K7 (M1.4) — Exit placement (random/multiple exits; all-off = today's single
# fixed gate at GATE_SPAWN_OFFSET, so the all-off fingerprint never moves)
# =============================================================================
@export_group("K7 Exits", "exit_")
## Master toggle. OFF = today's single fixed gate (M1.3 behaviour, fp unchanged).
@export var exit_enabled: bool = false
## Base exit count at depth 0. 0 = fall back to the single fixed gate (neutral).
@export var exit_base_count: int = 0
## Additive exit-count scaling per within-band depth.
@export var exit_count_per_depth: float = 0.0
## If true, ONE exit is always pinned at the spawn gate (the rest are placed randomly).
@export var exit_keep_one_at_spawn: bool = false
## Hard cap on total exits per band (perf/legibility guard). 0 = uncapped.
@export var exit_max_count: int = 0
```

### B.2 `to_flat_dict()` additions (append into the grouped return literal, `run_config.gd:281-339`)

```gdscript
        # ... existing LVL block ends ...
        "lvl_corridor_weight_mult": lvl_corridor_weight_mult,
        "lvl_short_corridors": lvl_short_corridors,
        # K2 (M1.4) — quota config knobs (additive payload; RG2 segments quota cohorts)
        "quota_enabled": quota_enabled,
        "quota_base_amount": quota_base_amount,
        "quota_increment_per_run": quota_increment_per_run,
        "quota_check_timing": quota_check_timing,
        "quota_basis": quota_basis,
        # K3 (M1.4) — camera config knobs
        "cam_enabled": cam_enabled,
        "cam_visible_world_width": cam_visible_world_width,
        "cam_zoom_policy": cam_zoom_policy,
        # K4 (M1.4) — timer + warning config knobs
        "timer_enabled": timer_enabled,
        "timer_length_s": timer_length_s,
        "timer_warning_threshold_s": timer_warning_threshold_s,
        "timer_warning_channel": timer_warning_channel,
        # K5a/b/c (M1.4) — new-hazard config knobs
        "hpp_enabled": hpp_enabled,
        "hpp_base_count": hpp_base_count,
        "hpp_count_per_depth": hpp_count_per_depth,
        "hpp_speed": hpp_speed,
        "hpp_per_room_cap": hpp_per_room_cap,
        "hbomb_enabled": hbomb_enabled,
        "hbomb_base_count": hbomb_base_count,
        "hbomb_count_per_depth": hbomb_count_per_depth,
        "hbomb_trigger_radius": hbomb_trigger_radius,
        "hbomb_blast_radius": hbomb_blast_radius,
        "hbomb_fuse_s": hbomb_fuse_s,
        "hbomb_per_room_cap": hbomb_per_room_cap,
        "hspike_enabled": hspike_enabled,
        "hspike_base_count": hspike_base_count,
        "hspike_count_per_depth": hspike_count_per_depth,
        "hspike_rotation_speed": hspike_rotation_speed,
        "hspike_arm_length": hspike_arm_length,
        "hspike_per_room_cap": hspike_per_room_cap,
        # K7 (M1.4) — exit-placement config knobs
        "exit_enabled": exit_enabled,
        "exit_base_count": exit_base_count,
        "exit_count_per_depth": exit_count_per_depth,
        "exit_keep_one_at_spawn": exit_keep_one_at_spawn,
        "exit_max_count": exit_max_count,
```

All values are JSON primitives (bool/int/float) — no new `_packed_to_float_array`-style helper needed (no new
`PackedFloat32Array` knob in the provisional set). The dict stays flat; the `test_run_config.gd` flatness + JSON round-trip
checks (`:99-110`) pass unchanged.

### B.3 New `EventBus` signals (append to `systems/event_bus.gd`; declared, never re-declared by emitters)

```gdscript
# === M1.4 signals (sole event_bus.gd edit this milestone, owner = K0) =========
# Pre-declared up front so K2/K3/K4/K5/K7 only EMIT — they never edit this file
# (the M1.1 pre-declare rule, M1.4 Breakdown §6). Telemetry-row payloads are
# PRIMITIVES ONLY (straight to JSONL). Signatures are PROVISIONAL — refined when
# the consuming Phase-2 designs land; Phase 3 locks them.

# --- K2 Quota (telemetry rows + HUD/Game-Over drive) -------------------------
## Live quota readout for the HUD (current banked-or-cumulative vs the run's target).
signal quota_changed(current: int, target: int, run_number: int)
## Quota resolved at run end: met == true → run-number++ + next quota; false → wipe pending.
signal quota_resolved(met: bool, run_number: int, target: int)
## The roguelite wipe ran (meta-state cleared to defaults). Emitted AFTER run_ended
## resolves (no run_ended arity change — the wipe is a separate meta op, Breakdown §6).
signal meta_wiped(reason: StringName)

# --- K3 Camera ---------------------------------------------------------------
## The fixed visible world-units actually applied this run (telemetry: "how far could I see").
signal camera_view_set(visible_world_width: float, zoom: float)

# --- K4 Timer warning --------------------------------------------------------
## Fires ONCE when remaining dive time crosses the near-end warning threshold.
## (dive_clock_changed/dive_clock_timeout already exist at event_bus.gd:36-37.)
signal dive_clock_warning(seconds_remaining: float)

# --- K5a/b/c new hazards (telemetry rows; reuse player_died for the kill) -----
## A new-hazard kill (kind = &"pingpong"/&"bomb"/&"spike"). Parallels hazard_caught
## (event_bus.gd:91). The actual death still flows through player_died(cause).
signal new_hazard_killed(kind: StringName, depth: int, run_t_ms: int)
## A bomb began its proximity pulse (telemetry: how often bombs are triggered).
signal bomb_pulse_started(depth: int, run_t_ms: int)

# --- K7 Exits ----------------------------------------------------------------
## Emitted once per band after exits are placed (telemetry: exit count + depth).
signal exits_placed(count: int, depth: int)
```

> **Signal-count note:** unlike knobs, **no test asserts a signal count** — `event_bus.gd` has no count test. So adding the full
> provisional signal set up front is safe (an unused declared signal is inert). This is *why* the pre-declare-everything rule is
> cheap on the EventBus side but needs the count-test bump on the RunConfig side.

### B.4 K1 retune in `make_default_play_preset()` (`run_config.gd:441-443`)

```gdscript
        c.r1_speed_per_depth = 3.0          # K1 (was 18.9): flatten the per-depth chase-speed ramp
        c.r1_catch_radius = 24.0            # unchanged — stays at the 24px physical floor
        c.r1_catch_radius_per_depth = 1.0   # K1 (was 10.5): flatten the per-depth catch-radius lunge
```

The "catch_speed_per_depth → 3.0" third value maps to **`r1_speed_per_depth → 3.0`** under the recommendation in OQ-1 — i.e.
the Director's "speed" and "catch_speed" both name the chase-speed ramp; there is one such knob and 3.0 is its new value. **No
new knob is added for it** (recommended), pending Director confirmation. The base `r1_catch_radius` (24.0) is left at the floor
so the catch test can still trip (`run_config.gd:395-396` BUG6 trap floor) and the preset's end-of-function
`assert(c.inert_enabled_oppositions().is_empty())` (`:497-499`) still passes.

### B.5 Test updates K0 must make in the same pass

- **`tests/test_run_config.gd`** — append every new key to `expected_keys` (`:74-95`) under M1.4 comment blocks (K2/K3/K4/K5/K7),
  mirroring the J2/J3/J4 comment style. (Add no new assertions — Case 5 is presence + flatness + JSON round-trip; that suffices.)
- **`tests/test_config_menu.gd`** — bump `46` → `46 + N` (`:46-47`) and extend the `:44-45` arithmetic comment with the M1.4
  additions (`+ K2's 5 + K3's 3 + K4's 4 + K5a's 5 + K5b's 7 + K5c's 6 + K7's 5`). **See OQ-5 for the count-vs-coverage timing
  question** — bumping the count here makes the CFG coverage assertion (`config_menu.gd:205-232`) red until the UI tasks add the
  `MANIFEST`/`SECTIONS` rows, so K0 and the UI wiring must be sequenced or the count staged per-wave.

---

## (c) Open Questions

**OQ-1 — K1 "catch_speed_per_depth" naming (load-bearing; recommend, then Director-confirm).**
There is no `r1_catch_speed_per_depth` knob. R1 has exactly two per-depth knobs: `r1_speed_per_depth` (chase speed,
`run_config.gd:67`) and `r1_catch_radius_per_depth` (catch-radius lunge, `:77`).
- **Option A (recommended):** "catch_speed_per_depth → 3.0" is a loose restatement of **`r1_speed_per_depth → 3.0`**; the
  Director gave two distinct numbers (3.0 and 1.0) that map cleanly to the two existing knobs (speed-ramp 3.0, radius-ramp 1.0).
  Both are *large reductions* from the current 18.9/10.5, consistent with "the depth ramp is too steep." No new knob.
- **Option B:** add a genuinely new `r1_catch_speed_per_depth` (a separate "speed *while catching/lunging*" ramp). Rejected unless
  the Director means a mechanic that doesn't exist yet — it would be a behaviour change (new R1 sub-mechanic), out of K0's
  declare-only scope, and would also bump the knob count + need a BUG6 trap.

  **Recommendation:** Option A — set `r1_speed_per_depth = 3.0`, `r1_catch_radius_per_depth = 1.0`, add no new knob. **Flag for
  Director confirmation** (this is a fun/tuning call): "Confirm 'catch_speed_per_depth' means the chase-speed-per-depth ramp
  (`r1_speed_per_depth`), not a new lunge-speed mechanic."

**OQ-2 — Does `all_oppositions_disabled()` learn about the new hazards (K5)?** The 3 new hazards are *dangers* like R1, so
arguably a run with only bombs on is "not the M1.0 baseline." But the function's documented meaning is "reproduces the M1.0
*opposition* (R1–R4) baseline" (`:250-256`), and the all-off-control test keys off it (`test_run_config.gd:32-34`). Every new
knob defaults off, so `RunConfig.new()` is still all-off on every axis regardless.
  **Recommendation:** **do not modify `all_oppositions_disabled()`** in K0 — leave it as the R1–R4 predicate. If the re-gate
  (RG2) needs a "is any new hazard on" segment, add a *separate* small predicate (`any_new_hazard_enabled()`) rather than
  overloading the M1.0-baseline meaning. Flag to Phase 3.

**OQ-3 — Quota knob shape vs K2's design (provisional until K2 lands).** K0 pre-declares `quota_enabled / quota_base_amount /
quota_increment_per_run / quota_check_timing / quota_basis`. But the Breakdown §7 lists the *quota timing/basis* as
load-bearing-and-unresolved (checked at extract-only vs every run-end; met by this-run-banked vs cumulative money). The two
enums above are my guess at the parameter surface. **If K2's Phase-2 design picks a fixed policy** (e.g. "always on-any-run-end,
always this-run-banked"), those two enums collapse to zero knobs and the count drops. **Recommendation:** declare the two enums
now (cheap, off-default, keeps K2 from re-editing `run_config.gd`); let K2's design confirm or delete them in its own
single-writer window *if* K2 is sequenced as a later wave — **but per the single-writer rule K2 must NOT re-edit run_config.gd**,
so the safer path is: K0 declares the *maximal* quota knob set and K2 simply reads whichever it needs. Mark these "K2-to-confirm."

**OQ-4 — Camera knob shape (K3) + the `project.godot` seam shared with K6.** `cam_visible_world_width` + `cam_zoom_policy` assume
a "fixed world-units" camera approach. But the Breakdown §7 says the camera approach itself (content-scale stretch via
`project.godot` `canvas_items` + fixed base resolution **vs** dynamic camera zoom-to-fit) is unresolved, and **K3 co-owns the
`project.godot` display+physics seam with K6 (jitter)**. If the chosen approach is *content-scale stretch* (a `project.godot`
setting), the "visible world-units" may be a **project setting, not a RunConfig knob** — in which case `cam_*` shrinks to maybe
just `cam_enabled` + telemetry. **Recommendation:** declare the provisional `cam_*` set off-default now; flag that K3's Phase-2
design may reduce it. The `camera_view_set` telemetry signal is approach-agnostic and stays regardless.

**OQ-5 — Knob-count bump timing (K0 vs the UI-wiring tasks): the CFG coverage-assertion crash window.** The CFG menu's
build-time `has_full_coverage()`/`_assert_full_coverage()` (`config_menu.gd:205-232`) **crashes `_ready` if any exported knob
lacks a `MANIFEST` row**, and `test_config_menu.gd:46` asserts an exact exported-field count. If K0 declares all ~35 new knobs
but does NOT wire the CFG `MANIFEST`/`SECTIONS`/`FIELD_RANGE` rows (those are the UI tasks' job), then **between K0 landing and
the UI tasks landing, `test_config_menu.gd` and the live CFG menu are RED**.
  Three options:
  - **(a) K0 also wires the CFG rows** (defeats the single-writer split a bit — K0 would touch `config_menu.gd` too — but it
    keeps the queue green at all times). The new sections need i18n title/gloss CSV keys, which K0 would have to stub.
  - **(b) K0 declares knobs + bumps the count test; the CFG menu is allowed to be red until the per-knob UI tasks wire their
    rows** (Wave 2/3). Simplest single-writer split but leaves a red window.
  - **(c) Stage the count per-wave:** K0 declares only the knobs whose consuming task is in the *next* wave, and each later wave's
    task adds its own knobs — **violates the "K0 does the whole milestone up front" Breakdown §6 rule** and re-introduces
    parallel edits to `run_config.gd`. Rejected.
  **Recommendation:** **(a)** — K0 owns `run_config.gd` + `event_bus.gd` **and** the CFG menu's structural rows
  (`SECTIONS`/`MANIFEST`/`FIELD_RANGE`/`FIELD_STEP` + stub CSV keys) for the new knobs, because those four tables are *mechanical
  derivations of the knob set* (one row per knob, same as J2/J3/J4 did in one pass) and keeping the coverage assertion green is
  the whole point of a single foundation pass. The UI tasks then style/range-tune their sections, not add coverage. **Flag to
  Phase 3 / Director:** confirm K0's scope includes the CFG structural rows (it expands K0 by one file but removes a red window).

**OQ-6 — Timer length: RunConfig knob, `DiveClockConfig` field, or both? (K4, Breakdown §7.)** I declared `timer_length_s` as a
RunConfig knob (0.0 = use the existing `DiveClockConfig` default). If K4's design instead exposes the existing
`DiveClockConfig` through the preset, `timer_length_s` is redundant. **Recommendation:** keep the RunConfig knob (it's the
config-marked-telemetry path RG2 needs — the length must land in `to_flat_dict()` either way); let K4 decide whether it *writes
through* to `DiveClockConfig` or replaces it. Mark "K4-to-confirm."

**OQ-7 — Three hazard groups vs one shared `haz_` group? (K5, Breakdown §7.)** I gave each hazard its own group/prefix
(`hpp_`/`hbomb_`/`hspike_`), parallel to R1 having its own `r1_` group — this is the cleanest CFG section split (one collapsible
section per hazard, one master toggle each) and matches how the Breakdown §7 *speculates* the shape (`h_pingpong_*`,
`h_bomb_*`, `h_spike_*`). The alternative — one `haz_` group with sub-knobs per type — is messier in the prefix-keyed CFG
(`@export_group` allows only one prefix). **Recommendation:** three groups, as drawn. **Flag to Phase 3 / the K5 designs:** the
*spawn count semantics* (per-band vs per-room; how `*_count_per_depth` composes with the existing per-room density seam in
K5i) is K5i's to define — K0 only declares `*_base_count` + `*_count_per_depth` + `*_per_room_cap`; if K5i needs a different
count model, it reads these and ignores what it doesn't use (no re-edit of `run_config.gd`).

**OQ-8 — Provisional vs final knob set (the meta-question).** This entire knob/signal union is assembled from the *breakdown's
task descriptions*, before the K2/K3/K4/K5/K7 Phase-2 designs exist. The single-writer rule means K0 must land the union **before**
those designs are necessarily final. Two strategies:
  - **Declare the maximal plausible set now** (this doc), accept that a few knobs may end up unused/renamed, and forbid the
    consuming tasks from re-editing `run_config.gd`/`event_bus.gd`. Unused off-default knobs are inert and harmless; an unused
    declared signal is inert. The cost is a slightly-too-large `to_flat_dict()` + count test.
  - **Sequence K0 *after* the Phase-2 designs of its dependents** — but that inverts the dependency (K0 unblocks them) and stalls
    the whole build.
  **Recommendation:** **declare the maximal set now** (strategy 1), and have **Phase 3 (fresh eyes) + the dependent Phase-2
  designs feed name/type corrections back into THIS doc before K0 is dispatched** — i.e. K0's *implementation* waits until the
  dependent designs land their knob lists, even though K0's *design* (this doc) is authored first. Concretely: this doc is the
  contract; each dependent Phase-2 design MUST cite the exact knob names it reads from here, and any divergence is reconciled
  into this doc (single source) before K0 the *code task* is dispatched. **Flag to Phase 3:** confirm this "design-first,
  implement-after-dependents-name-their-knobs" sequencing for K0.

---

## Determinism / all-off-fingerprint note (why off/neutral defaults are safe)

The fingerprint `e943ac9c8bc1` is computed over the *generated band* for the all-off config (the permanent control). It is moved
only by knobs that feed `fingerprint(seed+config)` — i.e. **cell-space / generation** knobs (R4 branching, J4 corridor weight —
see `run_config.gd:218-228`). Of K0's new knobs:
- **None of the K0 knobs feed generation when at their off/neutral default**, so a fresh `RunConfig.new()` produces the identical
  band → fingerprint unchanged. (Quota/camera/timer are post-generation; new-hazard placement is **pure run-state** like R1
  hazards, never fed to `fingerprint()` — Breakdown §6; exits at their `exit_enabled=false` default are *today's single fixed
  gate*, byte-identical.)
- **K7 exits are the one to watch:** when `exit_enabled=true` with random placement, exit placement must be **run-config-keyed
  and routed through a local sub-stream** (`run_seed ^ salt`, the B3/E3 pattern) or kept **pure post-generation run-state** so a
  non-neutral exit config moves fp *for that config only* — never the all-off control. K0 only *declares* `exit_*`; K7 enforces
  the determinism. The off-default (`exit_enabled=false`, all zeros/false) is exactly today's single gate → all-off fp
  unchanged.
- **K1 retune lives in `make_default_play_preset()`**, a *separate artifact* built on a fresh `RunConfig.new()` (`:429`); it never
  touches the code-level all-off default, so the control's fingerprint is untouched (the same contract J1 held, `:409-413`).

Therefore every K0 edit preserves the byte-identical all-off control and the `e943ac9c8bc1` fingerprint, satisfying the
load-bearing carried contract (Breakdown §2, §6).

---

## Resolved Decisions (Phase 3)

**Resolver:** fresh-eyes Phase-3 pass (NOT the K0 author), 2026-06-21. **Scope:** reconcile K0 — the shared-file
contract (`run_config.gd` + `event_bus.gd` + the CFG structural rows in `config_menu.gd`) — into the LOCKED knob + signal
set the build implements, cross-checked against every dependent Phase-2 design (K2/K3/K4/K5a/K5b/K5c/K5i/K7) and the
real as-built files (`run_config.gd`, `event_bus.gd`, `config_menu.gd`, `test_run_config.gd`, `test_config_menu.gd`,
`audio_director.gd`). This section is the **single source of truth** for K0's implementation; where a dependent doc's
pseudocode names a knob/signal differently from the table below, **the table below wins** and the dependent doc's build
agent reads these names.

### RD-0 — Method: how the conflicts were reconciled

The Phase-2 designs were authored in parallel and **diverged from K0's provisional union and from each other** on three
surfaces: (1) the hazard knob **prefix scheme** (K5a `hpp_`, K5b `h_bomb_`, K5c `hspike_` — and K5b's type-specific
field *names* differ from K0's draft), (2) the **quota signal names** (K0 `quota_changed`/`quota_resolved`, K2
`quota_evaluated`/`quota_advanced`) and **quota knob set** (K0's 5 incl. two enums vs K2's 3), and (3) the **K4 warning
signal signature** + the dead `light_low` request. K0 is the single writer on the two shared files, so K0 **must** ship
one reconciled set. The resolution rule applied throughout: **the consuming task's own design is authoritative for its
feature's internals** (K2 owns quota semantics, K5b owns the bomb's state machine, etc.), so where a consumer narrowed
or renamed K0's provisional draft, K0 adopts the consumer's names — *unless* a consumer's name breaks the cross-cutting
consistency a foundation pass exists to enforce (the hazard prefix scheme), in which case K0 imposes one consistent
scheme and the outlier consumer conforms.

### RD-1 — FINAL knob set (the authoritative `run_config.gd` table)

**Prefix scheme — RESOLVED.** Three hazard groups, one per hazard (confirms K0 OQ-7 / K5a OQ, K5c, K5i), with a
**single consistent prefix scheme: `hpp_` / `hbomb_` / `hspike_`** (no underscore after `h`). This is K0's, K5a's, K5c's
and K5i's scheme; **K5b's `h_bomb_` is the lone outlier and is OVERRULED** — K5i's descriptor table already reads
`rc.hbomb_enabled`/`rc.hbomb_base_count`/… (K5i §b), so adopting `h_bomb_` would silently break K5i's spawn loop. The
bomb's **type-specific field names are taken from K5b's design** (it owns the bomb mechanic) but **re-prefixed to
`hbomb_`**: K5b's `proximity_radius`/`pulse_seconds`/`blast_radius` are clearer than K0's draft `trigger_radius`/
`fuse_s`/`blast_radius`, so the final names are `hbomb_proximity_radius` / `hbomb_pulse_seconds` / `hbomb_blast_radius`.
(K5i's descriptor table only reads the four common spawn-seam knobs — `enabled`/`base_count`/`count_per_depth`/
`per_room_cap` — and passes `rc` whole to the entity, so the type-specific renames don't touch K5i.)

**The 35 new M1.4 knobs (every knob a dependent doc actually cites), grouped, all off/neutral by default:**

| Group / `@export_group` | Knob | Type | Default | Cited by |
|---|---|---|---|---|
| **K2 Quota** `"quota_"` | `quota_enabled` | `bool` | `false` | K2 §A.7/§B.10 |
| | `quota_base` | `int` | `0` | K2 (K0's `quota_base_amount` renamed → K2's `quota_base`) |
| | `quota_step` | `int` | `0` | K2 (K0's `quota_increment_per_run` renamed → K2's `quota_step`) |
| **K3 Camera** `"cam_"` | `cam_enabled` | `bool` | `false` | K3 §a |
| | `cam_visible_world_width` | `float` | `0.0` | K3 §b.4 |
| | `cam_zoom_policy` | `@export_enum("fit_width","fit_height","contain")` int | `0` | K3 §b.4 |
| **K4 Timer** `"timer_"` | `timer_enabled` | `bool` | `false` | K4 §A.4 |
| | `timer_length_s` | `float` | `0.0` | K4 §A.4/OQ-1 |
| | `timer_warning_threshold_s` | `float` | `0.0` | K4 §A.4/OQ-2 |
| | `timer_warning_channel` | `@export_enum("visual_only","visual_audio")` int | `0` | K4 §A.4/OQ-5 |
| **K5a Ping-Pong** `"hpp_"` | `hpp_enabled` | `bool` | `false` | K5a §2.1, K5i |
| | `hpp_base_count` | `int` | `0` | K5a, K5i |
| | `hpp_count_per_depth` | `float` | `0.0` | K5a, K5i |
| | `hpp_speed` | `float` | `0.0` | K5a §2.1 (entity-read) |
| | `hpp_per_room_cap` | `int` | `0` | K5a, K5i |
| **K5b Bomb** `"hbomb_"` | `hbomb_enabled` | `bool` | `false` | K5b, K5i |
| | `hbomb_base_count` | `int` | `0` | K5b, K5i |
| | `hbomb_count_per_depth` | `float` | `0.0` | K5b, K5i |
| | `hbomb_proximity_radius` | `float` | `0.0` | K5b §2.1 (entity-read) |
| | `hbomb_pulse_seconds` | `float` | `0.0` | K5b §2.1 (entity-read) |
| | `hbomb_blast_radius` | `float` | `0.0` | K5b §2.1 (entity-read) |
| | `hbomb_per_room_cap` | `int` | `0` | K5b, K5i |
| **K5c Rotating Spikes** `"hspike_"` | `hspike_enabled` | `bool` | `false` | K5c §A.3, K5i |
| | `hspike_base_count` | `int` | `0` | K5c, K5i |
| | `hspike_count_per_depth` | `float` | `0.0` | K5c, K5i |
| | `hspike_rotation_speed` | `float` | `0.0` | K5c §A.3 (entity-read; signed deg/s) |
| | `hspike_arm_length` | `float` | `0.0` | K5c §A.3 (entity-read) |
| | `hspike_per_room_cap` | `int` | `0` | K5c, K5i |
| **K7 Exits** `"exit_"` | `exit_enabled` | `bool` | `false` | K7 §C |
| | `exit_base_count` | `int` | `0` | K7 §C |
| | `exit_count_per_depth` | `float` | `0.0` | K7 §C |
| | `exit_keep_one_at_spawn` | `bool` | `false` | K7 §C |
| | `exit_max_count` | `int` | `0` | K7 §C |

**Count: 35 new knobs** = K2 3 + K3 3 + K4 4 + K5a 5 + K5b 7 + K5c 6 + K7 5. All append to `to_flat_dict()` in their
group block (RD-4), all scalar JSON primitives (bool/int/float) — **no new `PackedFloat32Array`**, so no new
`_packed_to_float_array`-style helper, and the `test_run_config.gd` flatness/round-trip checks pass unchanged.

**Quota knob set — RESOLVED to K2's 3 (K0's `quota_check_timing`/`quota_basis` enums are DROPPED).** K0's provisional
draft added two enums (`quota_check_timing`, `quota_basis`) to keep K2 from re-editing `run_config.gd`. **K2's own
Phase-2 design (K2 §A.7/§B.10) declares exactly three knobs (`quota_enabled`/`quota_base`/`quota_step`) and fixes the
timing/basis as Director-facing *behaviour* questions (K2 Q1/Q2), NOT as knobs** — the met-check seam (`sell_banked_junk`,
fires on all three run-ends) and the cumulative-vs-banked basis are resolved in code per the Director's verdict, not
surfaced as RunConfig enums. Adding the two K0 enums would be **two permanently-dead knobs** (nothing reads them — K2
hard-codes the policy) that nonetheless cost two CFG rows + two count-test slots + telemetry columns. **Resolution: drop
them. K0 declares K2's 3 knobs only.** If the Director later wants timing/basis swept per-run, that is a new knob in a
later iteration — not a speculative pre-declare now. (Net effect vs K0's draft: 5 → 3, so the milestone total is **35**,
not the 37 K0 §B.5's draft arithmetic implied.) **Naming:** K2's `quota_base`/`quota_step` win over K0's
`quota_base_amount`/`quota_increment_per_run` (K2 is the consumer and its pseudocode reads `qc.quota_base`/`qc.quota_step`).

**Contact/graze radii stay entity constants, not knobs (confirms K5a OQ-6, K5c OQ-2/OQ-3, K5b Q3 partial).** K5a's
`CONTACT_RADIUS`, K5c's `ARM_COUNT_DEFAULT`/`KILL_PAD`, etc. are **self-contained `const`s in the entity scripts** (the
`hazard_entity.gd:39-57` "feel knobs live in the file" precedent), NOT RunConfig knobs — this keeps the knob count
pinned at the 35 above. The two flagged-to-Director promotions (K5c `hspike_arm_count`, a possible `hpp`/`hbomb` graze
knob) are **NOT** in the M1.4 set; if the Director wants to sweep arm-count, it is a 36th knob added before K5c builds
(see RD-6 / **NEEDS DIRECTOR REVIEW**).

### RD-2 — FINAL signal set (the authoritative `event_bus.gd` table)

No test asserts an EventBus signal *count* (confirmed: `event_bus.gd` has no count test), so over-declaring is cheap and
an unused declared signal is inert — but the **names/signatures must be final** so consumers only emit. The reconciled
set (consumer names win; K0's provisional names that no consumer adopted are dropped):

| Signal (final) | Signature | Owner / emitter | Reconciliation |
|---|---|---|---|
| `quota_evaluated` | `(run_number: int, target: int, achieved: int, met: bool)` | K2 (`sell_banked_junk`) | **K2's name wins** over K0's `quota_changed(current,target,run_number)`. K2's pseudocode emits `quota_evaluated`; it is the single telemetry row RG2 reads (met-rate, achieved-vs-target). K0's `quota_changed` had no emitter. |
| `quota_advanced` | `(new_run_number: int, new_target: int)` | K2 (on a met quota) | **K2's name wins** over K0's `quota_resolved(met,run_number,target)`. Drives the HUD bump + SellScreen "next quota" line. |
| `meta_wiped` | `(prev_run_number: int)` | K2 (`wipe_meta`) | **Signature RESOLVED to K2's** `(prev_run_number: int)`. K0 drafted `meta_wiped(reason: StringName)`; K2's `wipe_meta()` emits `meta_wiped(prev_run_number)` and has no `reason` to pass (the only wipe cause in M1.4 is quota-fail). Adopt K2's int signature. |
| `camera_view_set` | `(visible_world_width: float, zoom: float)` | K3 (`CameraView._recompute`) | Unchanged from K0; K3 §a confirms it verbatim. Approach-agnostic telemetry ("how far could I see"). |
| `dive_clock_warning` | `(seconds_remaining: float, maximum: float)` | K4 (`DiveClock.modify_light`) | **K4 OQ-4 RESOLVED: ADD `maximum`.** K0 drafted single-arg `(seconds_remaining)`; K4's HUD cue + telemetry want the denominator for fraction symmetry with `dive_clock_changed(current, maximum)` (`event_bus.gd:36`). Free (primitives), matches the existing clock-signal shape. Final = 2-arg. |
| `new_hazard_killed` | `(kind: StringName, depth: int, run_t_ms: int)` | K5a/K5c (and K5b — see below) | Unchanged from K0; K5a §2.2 and K5c §A.4 emit `new_hazard_killed(&"pingpong"/&"spike", …)`. The shared kill-telemetry row for all new hazards. |
| `bomb_armed` | `(depth: int)` | K5b (`_arm`) | **K5b's name wins.** K0 drafted `bomb_pulse_started(depth, run_t_ms)`; K5b emits `bomb_armed(depth)` on the arm edge. Adopt K5b's name + signature. |
| `bomb_detonated` | `(depth: int, hit: bool)` | K5b (`_detonate`) | **NEW — K5b adds this** (K0 had no detonation signal). Telemetry: how many bombs detonate, how many were lethal. |
| `exits_placed` | `(count: int, depth: int)` | K7 (`_place_gate`) | Unchanged from K0; K7 §C/B.2 emits it once per band. |

**Bomb kill telemetry — RESOLVED:** K5b's kill flows through `GameState.fail_run(&"death")` and K5b emits
`bomb_detonated(depth, hit)` for the detonation row. For **consistency with K5a/K5c**, K5b SHOULD *also* emit
`new_hazard_killed(&"bomb", depth, run_t_ms)` on the lethal frame so RG2 has one uniform "a new hazard killed me" row
across all three types (RG2 segments deaths by `kind`). This is a **one-line add in K5b's `_detonate` on the `hit`
branch** — fold the note back to K5b. So K5b emits *both* `bomb_detonated` (every detonation, lethal or not) and
`new_hazard_killed(&"bomb", …)` (only when lethal). No K0 change (both signals are already declared).

**Dead `light_low()` — RESOLVED: REMOVE it from `event_bus.gd` in K0's pass (K4 OQ-3 Option A).** `light_low()` is
declared (`event_bus.gd:23`) and connected (`audio_director.gd:18`) but **never emitted anywhere** (verified: the only
two hits are the declaration + the AudioDirector connection; no `.emit(`). It is a dead, payload-free signal whose only
consumer (`_on_tension`, a stub) is better served by K4's live `dive_clock_warning`. **K0 removes the
`signal light_low()` line** (K0 is the single writer on `event_bus.gd`, so this removal must ride K0's pass — K4 cannot
edit the file). **Coupled edit (K4 owns, NOT K0):** `audio_director.gd:18` must drop `EventBus.light_low.connect(_on_tension)`
or it will error at load (connecting a removed signal). K4 re-points the audio hook to `dive_clock_warning` per K4 §B.4.
**Sequencing note for the build:** K0's `event_bus.gd` removal of `light_low` and K4's `audio_director.gd` disconnect
must land **together** (same wave or K4 immediately after K0) — if K0 removes the signal before K4 fixes the connect,
`audio_director.gd` fails to load. Since K4 is Wave-1 alongside K0-foundation, this is naturally co-sequenced; the build
orchestrator must verify the `audio_director.gd` line is updated in the same merge that removes `light_low`. *(If the
Director would rather keep `light_low` declared-but-dead to avoid the coupled edit, the fallback is: leave the signal,
and AudioDirector simply *also* connects `dive_clock_warning` — degrades cleanly, costs one dead signal. Recommend
removal; this is a trivial-cleanup call, not a vision call.)*

### RD-3 — K1 "catch_speed_per_depth" naming (K0 OQ-1)

**RESOLVED: Option A — no new knob.** Set in `make_default_play_preset()`: `c.r1_speed_per_depth = 3.0`,
`c.r1_catch_radius_per_depth = 1.0`, `c.r1_catch_radius = 24.0` (unchanged — stays at the 24px collision floor so the
catch test can trip and the BUG6 `r1_catch_radius_too_small` trap stays clear). The Director's "catch_speed_per_depth →
3.0" maps to the existing **`r1_speed_per_depth`** (the only chase-speed-per-depth ramp on R1; there is no
`r1_catch_speed_per_depth`). The two distinct numbers (3.0, 1.0) map cleanly onto the two existing per-depth ramps
(speed 18.9→3.0, catch-radius 10.5→1.0), both large reductions consistent with "flatten the too-steep depth curve."
Adding a genuinely-new lunge-speed knob would be a behaviour change outside K0's declare-only scope. **This is a
fun/tuning value, so the *numbers* are the Director's** — but the *interpretation* (which knob the directive names) is a
technical mapping, resolved here. **NEEDS DIRECTOR REVIEW (confirmation only, low-stakes):** "Confirm 'catch_speed_per_depth →
3.0' means the chase-speed-per-depth ramp `r1_speed_per_depth`, not a new lunge-speed mechanic." Recommendation: yes,
it's `r1_speed_per_depth`; proceed with Option A.

### RD-4 — `to_flat_dict()` additions

Append all 35 knobs from RD-1's table into the grouped return literal after the LVL block (`run_config.gd:338`), one
comment block per group (`# K2 (M1.4) …`, `# K3 …`, etc.), keys == field names, values the raw field. K0's §B.2
pseudocode is correct **except**: drop `quota_check_timing`/`quota_basis` (per RD-1), rename to `quota_base`/`quota_step`,
and rename the bomb keys to `hbomb_proximity_radius`/`hbomb_pulse_seconds`/`hbomb_blast_radius` (the §B.2 draft used
`hbomb_trigger_radius`/`hbomb_fuse_s`). Final additive key list = the 35 field names in RD-1.

### RD-5 — CFG-menu scope (K0 OQ-5): K0 OWNS the structural rows. **RESOLVED — Option (a).**

This is the load-bearing call for "the build never ships a red menu," and it is a **technical/scope call resolvable on
merit** (not a vision call), so it is resolved here, not deferred to the Director:

**K0 owns the `config_menu.gd` structural rows for all 35 new knobs** — the `SECTIONS` entries (7 new sections), the
`MANIFEST` lists, the `FIELD_RANGE` + `FIELD_STEP` entries — **and** the `_prefix_of` helper update + the new-section CSV
i18n keys, **in the same single-writer pass** as `run_config.gd` + `event_bus.gd`. Rationale (hard, not preference):

1. **`config_menu.gd:205-232` `has_full_coverage()`/`_assert_full_coverage()` crashes `_ready` if ANY exported knob
   lacks a bound control**, and `test_config_menu.gd:46` asserts an **exact** exported-field count (currently `46`). The
   moment K0's 35 knobs land in `run_config.gd`, the CFG menu's coverage assert goes red and `test_config_menu.gd` fails
   on the count — **for every other M1.4 task's test run** — until the rows exist. Staging the rows per-UI-task (Option
   b) leaves a multi-wave red window across the whole queue; staging the *knobs* per-wave (Option c) **violates the
   "K0 declares the whole milestone up front" rule** (Breakdown §6) and re-introduces parallel `run_config.gd` edits.
   Only Option (a) keeps the queue green at all times.
2. The four CFG tables are **mechanical derivations of the knob set** — one row per knob, exactly as J2/J3/J4 added their
   rows in one pass. They are not UI *design*; they are the coverage plumbing. The per-knob UI tasks (K2/K3/K4 ui-ux)
   then *style/range-tune* their sections (better labels, tuned slider spans), but they do **not** add coverage.

**Concrete `config_menu.gd` edits K0 makes (all derivable from RD-1):**

- **`SECTIONS`** — append 7 entries, each `{"prefix": <p>, "title_key": "CFG_SEC_<X>", "gloss_key": "CFG_GLOSS_<X>",
  "master": "<p>enabled", "collapsible": true}` for `quota_`/`cam_`/`timer_`/`hpp_`/`hbomb_`/`hspike_`/`exit_`. Every
  new group HAS a master `*_enabled` (unlike Meta), so all 7 are masters — good, the header CheckButton binds them and
  `has_full_coverage()` counts them via the `SECTIONS` master loop (`:210-212`).
- **`MANIFEST`** — append 7 ordered lists, the master first, mirroring RD-1's per-group rows (e.g.
  `"hbomb_": ["hbomb_enabled","hbomb_base_count","hbomb_count_per_depth","hbomb_proximity_radius","hbomb_pulse_seconds","hbomb_blast_radius","hbomb_per_room_cap"]`).
- **`FIELD_RANGE`** — every **numeric scalar** knob needs an entry or it falls back to `RANGE_MAGNITUDE` (harmless but
  imprecise). Enums (`cam_zoom_policy`, `timer_warning_channel`) and bools (`*_enabled`, `exit_keep_one_at_spawn`) need
  NONE (they render as OptionButton/CheckButton, no range). Suggested ranges (greybox scrub spans; SpinBox types past):
  counts → `RANGE_DEPTH (0,10)` or a new `RANGE_COUNT`; `*_per_depth` floats → `RANGE_MAGNITUDE`; `hpp_speed` →
  `RANGE_SPEED`; radii (`hbomb_proximity_radius`/`hbomb_blast_radius`/`hspike_arm_length`) → `RANGE_RADIUS`;
  `hbomb_pulse_seconds`/`timer_warning_threshold_s` → `RANGE_SECONDS`; `timer_length_s` → a new `RANGE_TIMER (0,120)`;
  `cam_visible_world_width` → a new `RANGE_VIEW (0,1920)`; `quota_base`/`quota_step` → `RANGE_MAGNITUDE` (or a new
  `RANGE_MONEY`); `*_per_room_cap`/`exit_max_count` → `RANGE_ROOM_CAP`; `hspike_rotation_speed` → a new
  `RANGE_ROTATION (-360,360)` (signed!). **The exact spans are scrub conveniences, not contracts** — a build agent may
  pick reasonable values; the only hard requirement is *an entry exists for each numeric knob it wants ranged* (absent =
  `RANGE_MAGNITUDE` fallback, still functional).
- **`FIELD_STEP`** — only where a non-default step matters (e.g. `quota_base`/`quota_step` step 10 or 50; the rest take
  the int=1.0/float=0.1 default). Optional.
- **`_prefix_of()` (`config_menu.gd:747-751`)** — **MUST** append the 7 new prefixes to the `["r1_","r2_","r3_","r4_","lvl_"]`
  list, or a new knob's live chip/summary refresh routes to the Meta section. This is a one-line edit K0 must not miss.
- **`_section_summary()` (`:664-692`)** — each new ON section currently returns `""` (no `match` case) → the chip shows
  just "ON" with no value summary. **Acceptable for greybox** (the per-row values are still visible); the UI tasks MAY
  add a `match` case per section later. NOT required for green.
- **CSV i18n** (`ui/config/config_strings.csv`) — K0 stubs `CFG_SEC_<X>` + `CFG_GLOSS_<X>` keys for the 7 sections, plus
  `CFG_FIELD_<KNOB>` keys are auto-derived via `"CFG_FIELD_%s" % field.to_upper()` (`:383`) so a missing key renders the
  raw key text (ugly but not a crash) — K0 SHOULD stub these too for legibility; the UI tasks polish the copy. **Stub,
  don't perfect.** Any enum knob's option labels come from the schema hint strings via `CFG_ENUM_PLACEHOLDER` (`:429`),
  already generic — no per-option CSV needed.

This expands K0 by **one file** (`config_menu.gd` + its CSV) but removes the red window entirely. **Confirmed scope
addition; resolved on technical merit — no Director call needed** (it's plumbing, not a vision/fun decision).

### RD-6 — Count-test bumps (the exact arithmetic)

- **`tests/test_config_menu.gd:46`** — bump `if exported.size() != 46` → **`!= 81`** (`46 + 35`). Extend the `:44-45`
  comment: `… = 46 + M1.4's (K2 3 quota_ + K3 3 cam_ + K4 4 timer_ + K5a 5 hpp_ + K5b 7 hbomb_ + K5c 6 hspike_ + K7 5 exit_) = 81`.
- **`tests/test_run_config.gd:74-95`** — append the 35 RD-1 keys to `expected_keys` under M1.4 comment blocks (no new
  assertion; Case 5 is presence + flatness + JSON round-trip, which the 35 scalar keys satisfy).
- **K0's own §B.5 arithmetic (`+ K2's 5 …`) is SUPERSEDED by this** — it predates dropping the two quota enums and is
  off by 2. The final new-knob count is **35**, the final total is **81**.

### RD-7 — `all_oppositions_disabled()` (K0 OQ-2)

**RESOLVED: do NOT modify it.** Leave it as the R1–R4 predicate (`run_config.gd:255-256`). Its documented meaning is
"reproduces the M1.0 *opposition* baseline," and the all-off-control test (`test_run_config.gd:32-34,83`) keys off it.
Every new M1.4 knob defaults off, so a fresh `RunConfig.new()` is all-off on every axis regardless — the test stays
green without touching this function. If RG2 wants an "is any new hazard on" cohort segment, that is a **separate**
predicate (`any_new_hazard_enabled()`) added by RG2/telemetry, NOT an overload of the M1.0-baseline meaning. (Confirms
K0's own recommendation; no consumer disputes it.)

### RD-8 — Off/neutral defaults keep the all-off fingerprint byte-identical (confirmed)

Re-verified against every dependent design: **none of the 35 knobs feeds `fingerprint(seed+config)` at its off/neutral
default.** Quota (K2 §B.10), camera (K3 §a — "post-generation, never hashed"), and timer (K4 §a.12 — "post-generation
run-state") are all post-generation. New-hazard placement (K5a/K5b/K5c/K5i) is **pure run-state on the already-graded
band, never feeds `fingerprint()`** (K5i §a.1; the J2/J3/R1 precedent) — and with every `*_enabled=false` the spawn
seam instantiates **no node** (K5i's gate), so the band is byte-identical. K7 exits at `exit_enabled=false`
short-circuit to today's single fixed gate at `GATE_SPAWN_OFFSET` (K7 §A.4/B.2) — *stronger* than R4/J4, K7 never moves
fp **even for non-neutral configs** (its random placement is run-state via a local `run_seed ^ EXITS_RNG_SALT`
sub-stream, never the global RNG). K1's retune lives only in `make_default_play_preset()` (a separate artifact on a
fresh `RunConfig.new()`), never the code-level default. **Therefore a fresh `RunConfig.new()` reproduces the M1.0 band →
fingerprint stays `e943ac9c8bc1`, byte-identical.** The carried baseline contract holds.

### Items flagged **NEEDS DIRECTOR REVIEW** (vision/fun/scope — NOT self-resolved)

These surfaced in K0's contract but are genuine Director calls; K0's *contract* is locked regardless of the verdict
(the knobs/signals exist either way), so they do **not** block K0's dispatch — they are tuning/feel decisions the
build-phase preset + RG1 sweep absorb:

1. **K1 retune interpretation (RD-3)** — confirm "catch_speed_per_depth → 3.0" = `r1_speed_per_depth` (recommend yes).
   *Low-stakes confirmation; the values themselves are a Director sweep.*
2. **K5c `hspike_arm_count` promotion (K5c OQ-2)** — keep arm-count an in-file `const 3` (recommended, keeps the knob
   count at 35), OR promote to a 36th RunConfig knob so RG1 can sweep "2 arms vs 6 arms." **If the Director wants it
   swept, K0 must add it before K5c builds** (it re-opens K0's pass by one knob + one CFG row + bumps the count 81→82).
   *Recommend: in-file const for M1.4; promote in a later iteration if playtest wants it.*
3. **The downstream feel calls each consumer already flagged** are NOT K0's contract and are listed here only so the
   Director sees them in one place when ratifying K0: K2 Q1 (quota checked every-run-end vs extract-only) + Q2
   (cumulative vs banked basis) + Q6/Q7 (wipe confirm / loss tally) — these are **behaviour resolved in K2's code per the
   Director's verdict, NOT K0 knobs** (which is why K0 drops K0's `quota_check_timing`/`quota_basis` enums, RD-1); K3
   OQ-3 (`aspect=expand` vs `keep` — feel); K5a OQ-7 / K5b / K5c OQ-5 hazard palette (legibility, character-animator +
   Director pick the trio as a set); K7 OQ-2/OQ-3 (preset `exit_keep_one_at_spawn` + whether the preset enables exits at
   all — re-gate methodology). **None of these change K0's knob/signal set** — they are preset-value + behaviour calls
   the build phase + RG1 absorb. K0 ships every knob off/neutral; the preset (a separate artifact) carries whatever the
   Director rules.
