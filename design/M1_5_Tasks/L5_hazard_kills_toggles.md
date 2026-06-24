# L5 — K5 per-hazard `*_kills` toggles · Per-task design (Phase 2)

**Milestone / version:** M1.5 (Agency & Legibility), Wave 2.
**Stable id:** L5. **Role(s):** general-purpose (entity guards + verify-driver retirement) + game-director-designer (the three knobs' design intent / preset stance).
**BlockedBy:** L0 (pre-declares `hpp_kills` / `hbomb_kills` / `hspike_kills`, extends `to_flat_dict()`, sets the knob-count). Entity files (`pingpong_hazard.gd` / `bomb_hazard.gd` / `spike_hazard.gd`) are **disjoint** from L1/L2/L3/L4 → parallel in Wave 2.
**Origin:** M1.4 Wave-5 deviation sweep — the Director dispositioned the verify driver's `_driven_default_preset()` as **Addressed** (`design/DESIGN_DEVIATIONS_HISTORY.md:334`).

---

## (a) Research on the premise

### Why a `*_kills` toggle per K5 hazard

The three M1.4 K5 hazards — ping-pong (K5a), bomb (K5b), rotating spikes (K5c) — are **unconditionally lethal**. Each, on a lethal contact, routes straight through the single run-end path `GameState.fail_run(&"death")` with **no per-hazard switch** to make that contact non-lethal. The exact guard points (the line each task must wrap in `if cfg.<prefix>_kills:`):

- **Ping-pong** — `scenes/hazards/pingpong_hazard.gd:138`, inside `_on_contact()`:
  ```gdscript
  EventBus.new_hazard_killed.emit(&"pingpong", depth, run_t_ms)   # :137
  GameState.fail_run(&"death")                                    # :138  ← guard point
  ```
  Called from `_physics_process` :125–127 on the rising edge of the `CONTACT_RADIUS` distance test (one-shot via `_killed_latched`).
- **Bomb** — `scenes/hazards/bomb_hazard.gd:118`, inside `_detonate()`:
  ```gdscript
  if hit:                                                          # :116  (player inside blast at detonation frame)
      EventBus.new_hazard_killed.emit(&"bomb", …)                  # :117
      GameState.fail_run(&"death")                                 # :118  ← guard point
  ```
  `hit` is the blast distance test (:114). A fizzle (player outside blast) already emits no kill row and does not fail the run.
- **Spike** — `scenes/hazards/spike_hazard.gd:96`, inside `_physics_process`:
  ```gdscript
  if not _killed_emitted:                                          # :91
      _killed_emitted = true                                       # :92
      …
      EventBus.new_hazard_killed.emit(&"spike", depth, run_t_ms)   # :95
      GameState.fail_run(&"death")                                 # :96  ← guard point
  ```
  Fired when `_is_player_on_any_arm()` (:88) is true (analytic distance-to-segment, one-shot via `_killed_emitted`).

Each hazard already **snapshots its `RunConfig` at `setup`** and reads typed `_cfg.<knob>` fields, so a new bool knob is a zero-friction read:
- ping-pong `setup(cfg, player, spawn_ctx)` — `pingpong_hazard.gd:63–74`, stores `_cfg = cfg` (:64).
- bomb `setup(cfg, player, _spawn_ctx)` — `bomb_hazard.gd:61–69`, stores `_cfg = cfg` (:62).
- spike `setup(cfg, player, spawn_ctx)` — `spike_hazard.gd:58–72`, stores `_cfg = cfg` (:59).

All three hold `_cfg` for the whole life of the entity (the R1 snapshot discipline, `hazard_entity.gd:83–91`), so the kills test is `if _cfg.<prefix>_kills:` at the guard point — no extra plumbing, no new `setup` argument, no `spawn_ctx` change. The `main_game.gd` spawn seam (`main_game.gd:457` for K5) is untouched.

### The pattern to mirror — R1's `r1_catch_kills`

R1 (the pursuer) already has exactly this knob, and the K5 family was explicitly modelled on R1 but **omitted the lethality toggle**:

- The knob: `data/run_config/run_config.gd:79` — `@export var r1_catch_kills: bool = false`. (R1's default is **false** because R1 ships a designed non-fatal cost path; the K5 toggles differ — see "Carried contracts" / OQ below — they default **`true`**.)
- It joins the flat snapshot: `run_config.gd:423` — `"r1_catch_kills": r1_catch_kills,`.
- The preset sets it on: `run_config.gd:633` — `c.r1_catch_kills = true` in `make_default_play_preset()`.
- The branch it gates — `hazard_entity.gd:189–193`:
  ```gdscript
  if _cfg.r1_catch_kills:
      GameState.fail_run(&"death")    # existing end path; _run_ended owns idempotency
  else:
      _apply_nonfatal_catch()         # R1's designed non-fatal cost
  ```

The K5 toggles mirror lines :79 / :423 / (preset) but their `false` branch is **not** R1's `_apply_nonfatal_catch()` cost (the K5 hazards have no designed non-fatal cost) — `false` simply **skips the kill** (the telemetry-emit / fizzle / juice behaviour on the `false` branch is OQ-1/OQ-2/OQ-3 below).

### The verify-harness driver problem (the thing this fixes)

The M1.4 verify driver (`tests/test_rg1_m14_verify.gd`) drives the **default play-preset** through a scripted end-cause matrix (`extract`, `timeout`, `death`) by stepping the run through depths 1→5 (`_drive_run` :476–478) and then forcing a chosen end-cause. But the preset ships a **shallow rotating spike** (`hspike_base_count=1`, `run_config.gd:760`) that appears from the first eligible room — so the unconditionally-lethal spike kills the driven player **before** the scripted `extract`/`timeout` end-cause can win. R1's lethality could be turned off (`r1_catch_kills=false`) to keep it from pre-empting the chosen end-cause; the **K5 hazards could not**.

The workaround was `_driven_default_preset()` (`tests/test_rg1_m14_verify.gd:457–462`), which clones `_default_preset()` and **disables the three K5 hazards entirely**:
```gdscript
func _driven_default_preset() -> RunConfig:
    var c := _default_preset()
    c.hpp_enabled = false        # :459
    c.hbomb_enabled = false      # :460
    c.hspike_enabled = false     # :461
    return c
```
Used at `:112` — `await _drive_run(_driven_default_preset(), &"extract", "M1-default-preset")`. Its own doc-comment (:446–456) flags the gap: *"unlike R1 (whose lethality is the `r1_catch_kills` knob), the new hazards have no per-hazard 'kills' toggle — a fatal contact always routes through `GameState.fail_run(&"death")`. … This mirrors the existing `r1_catch_kills=false` intent."* It also notes the cost of the workaround: the driven run no longer spawns the K5 entities at all, so the **driven** run does not exercise the real preset's spawn — it leans on the **separate** shape-check (`_verify_default_preset_shape`, :169+) and the assembled-spawn check (`_verify_new_hazards_spawn_assembled`, :102) to cover that the preset ships the hazards on.

**With the `*_kills` toggles existing**, the workaround is unnecessary and is **retired**: the driven matrix runs the **real** preset (all K5 hazards `_enabled = true`, spawning normally) with the three `*_kills` set `false`, so the entities spawn and behave but cannot pre-empt the scripted end-cause — exactly the `r1_catch_kills=false` shape, now uniform across the whole hazard family. The shape-checks (`_verify_default_preset_shape`) continue to assert the **real** preset has the K5 kills **on** (default), so we never lose the "preset ships lethal hazards" guarantee.

### Determinism / baseline safety

The three knobs are **run-state behaviour gates** — they affect what a live entity does on contact, not generation. K5 entities are pure run-state (placement never feeds `fingerprint()`; `pingpong_hazard.gd:16–19`, `bomb_hazard.gd:23–24`, `spike_hazard.gd:19–22`). Adding the knobs is **additive** and does not move the all-off fingerprint `e943ac9c8bc1`: with the K5 hazards' `_enabled = false` (the all-off default) the spawn seam never instantiates them, so the kills knob is never read. The kills knobs default **`true`** = today's lethal behaviour, so an unconfigured-but-K5-enabled run is byte-for-byte the M1.4 behaviour. A **kills-off run is a non-default configuration** (used by the verify driver and any future non-lethal sweep), exactly like the existing `r1_catch_kills=false` driven runs.

---

## (b) Pseudocode

### The three knobs (L0 declares these — listed here so L0 has the exact spec)

In `data/run_config/run_config.gd`, one bool per hazard, contiguous within each existing `@export_group` (the `hpp_` / `hbomb_` / `hspike_` prefix house style), default **`true`**:

```gdscript
# in @export_group "K5a Ping-Pong Hazard", "hpp_"   (near run_config.gd:296)
## Whether a lethal touch kills (death end-cause). Default true = M1.4 behaviour.
## false = the bouncer travels/bounces/tells but a contact does NOT end the run
## (the non-lethal preset the verify driver uses; mirrors r1_catch_kills).
@export var hpp_kills: bool = true

# in @export_group "K5b Bomb Hazard", "hbomb_"
@export var hbomb_kills: bool = true

# in @export_group "K5c Rotating Spikes", "hspike_"
@export var hspike_kills: bool = true
```

And each joins `to_flat_dict()` (L0), contiguous with its family block (after `hpp_per_room_cap` :488, after `hbomb_per_room_cap` :496, after `hspike_per_room_cap` :503):
```gdscript
"hpp_per_room_cap": hpp_per_room_cap,
"hpp_kills": hpp_kills,            # ← added
…
"hbomb_per_room_cap": hbomb_per_room_cap,
"hbomb_kills": hbomb_kills,        # ← added
…
"hspike_per_room_cap": hspike_per_room_cap,
"hspike_kills": hspike_kills,      # ← added
```

`make_default_play_preset()` does **not** need to set them (default `true` already = lethal preset). Setting them explicitly to `true` there is optional documentation; recommend **not** setting them (keep the preset diff minimal; the shape-check asserts the value, see below) — but this is a small game-director-designer call (see OQ-5).

**Knob count:** current 81 (Breakdown §6). L5 adds **+3** (→ 84 before L1/L2's knobs). **L0 owns the final count** across all M1.5 knobs and bumps `tests/test_run_config.gd` (the `expected_keys` list at :77+ and the count print :283) and `tests/test_config_menu.gd`. L5 does **not** touch the count tests — it only adds the entity guards + retires the driver (L0 having already declared the knobs is the `BlockedBy`).

### Entity guards (the L5 entity work — mirrors `hazard_entity.gd:189`)

**Ping-pong** — guard `_on_contact()` (`pingpong_hazard.gd:134–138`). The telemetry-emit stance is OQ-3:
```gdscript
func _on_contact() -> void:
    var run_t_ms: int = int(_spawn_time * 1000.0)
    var depth: int = GameState.current_depth_index
    EventBus.new_hazard_killed.emit(&"pingpong", depth, run_t_ms)   # see OQ-3 re: emit when non-lethal
    if _cfg.hpp_kills:
        GameState.fail_run(&"death")
    # else: non-lethal — the bouncer keeps travelling/bouncing; _killed_latched still
    # de-dupes (it re-arms on the falling edge per :128-129), so re-entry re-tests cleanly.
```

**Bomb** — guard the fatal block in `_detonate()` (`bomb_hazard.gd:116–118`):
```gdscript
if hit:
    EventBus.new_hazard_killed.emit(&"bomb", GameState.current_depth_index, _run_t_ms())  # OQ-3
    if _cfg.hbomb_kills:
        GameState.fail_run(&"death")
# the explode flash + queue_free (:115/:121) are unconditional juice/cleanup — unchanged.
# Whether a non-lethal bomb still pulses+detonates visually or stays inert is OQ-1.
```

**Spike** — guard the fatal call in `_physics_process` (`spike_hazard.gd:91–96`):
```gdscript
if not _killed_emitted:
    _killed_emitted = true
    var depth: int = GameState.current_depth_index
    var run_t_ms: int = int(_alive_time * 1000.0)
    EventBus.new_hazard_killed.emit(&"spike", depth, run_t_ms)      # OQ-3
    if _cfg.hspike_kills:
        GameState.fail_run(&"death")
    # else: non-lethal — keeps spinning; _killed_emitted latches so it fires once per
    # contact episode. (If non-lethal must re-fire on re-touch, see OQ-4.)
```

### Verify-driver change (`tests/test_rg1_m14_verify.gd` → the M1.5 verify; retire `_driven_default_preset()`)

**Note:** the M1.5 verify lives in a new `tests/test_rg1_m15_verify.gd` authored by RG1 from the M1.4 verify as template (per the milestone iteration loop). The change below is what RG1 carries forward; L5's deliverable is to **specify** it (and, if the M1.4 verify is retained as a regression, apply it there too — OQ-6).

1. **Delete `_driven_default_preset()`** (`:457–462`) and its doc-comment (`:446–456`).
2. At the driven-matrix call (`:112`), drive the **real** preset with the three K5 kills off — reuse the existing `_default_preset()` (which already sets `r1_catch_kills=false`, :442) and clear the K5 kills there or at the call site:
   ```gdscript
   # _default_preset() (around :437) — add the three K5 kills-off lines alongside r1_catch_kills:
   c.r1_catch_kills = false      # existing :442
   c.hpp_kills = false           # K5 non-lethal for the driven end-cause matrix (L5)
   c.hbomb_kills = false
   c.hspike_kills = false
   # NB: hpp_enabled / hbomb_enabled / hspike_enabled stay TRUE — the entities now SPAWN
   #     and behave; they just can't end the run, so the scripted end-cause wins.
   ```
   and the call becomes:
   ```gdscript
   await _drive_run(_default_preset(), &"extract", "M1-default-preset")   # was _driven_default_preset()
   ```
3. **Shape-checks unchanged** — `_verify_default_preset_shape()` (:169+) and the spawn-plan / assembled-spawn checks (:102, `_verify_new_hazard_spawn_plan`) keep calling the **real** `make_default_play_preset()` and continue to assert the K5 hazards ship **on** (`hpp_enabled` etc. true) — and SHOULD add an assertion that the preset's `hpp_kills`/`hbomb_kills`/`hspike_kills` are **`true`** (the lethal preset is the shipped product; only the driven copy turns them off). This is the new safety the toggle buys: the driven run exercises the real spawn, and the shape-check proves the real preset is lethal.

---

## (c) Open Questions

- **OQ-1 (bomb non-lethal semantics — pulse/detonate-but-survive vs fully inert).** With `hbomb_kills=false`, does the bomb still **arm → pulse → detonate visually** (just not kill), or stay inert in IDLE? **Recommendation:** keep the full state machine running (arm/pulse/flash) and only skip `fail_run` — the toggle is "does the blast kill," not "is the bomb present." This keeps the non-lethal run visually faithful to the lethal one (the driven verify then sees a real, behaving bomb) and matches R1's pattern (a non-lethal R1 still chases). The unconditional `_flash_blast()` + `queue_free` (`bomb_hazard.gd:115/:121`) already sit outside the `if hit` guard, so "detonate visually, don't kill" is the natural shape. *Low-risk; recommend resolve as "behaves fully, just doesn't kill."*

- **OQ-2 (ping-pong / spike tell + motion when non-lethal).** Same question for K5a/K5c: does the bouncer keep travelling/bouncing and the spike keep spinning (tells render) when `*_kills=false`? **Recommendation:** yes — identical to lethal except the `fail_run` is skipped (the motion/tell is independent of the kill). This is the minimal, R1-consistent change and is what makes the driven verify a faithful real-preset run. *Low-risk.*

- **OQ-3 (does a non-lethal hazard still emit `new_hazard_killed` / telemetry?).** The pseudocode above emits `new_hazard_killed` **before** the kills guard (so a non-lethal contact still logs a "would-have-killed" event), matching R1 which always emits `hazard_caught` regardless of `r1_catch_kills` (`hazard_entity.gd:188`). **Trade-off:** (a) emit-always keeps telemetry comparable (contact counts are independent of lethality, mirrors R1) but the row name `new_hazard_killed` is then a misnomer on a non-lethal contact; (b) emit-only-when-lethal makes the row name literal but loses the contact signal on non-lethal runs and **breaks** `tests/test_*_hazard.gd` which assert the emit fires (see OQ-6). **Recommendation:** **emit-always** (option a), mirroring R1 exactly — the row already means "lethal contact occurred," and the kills knob's whole point is "this contact would normally kill." Flag to Director only if the telemetry-name literalness matters for RG2 analysis. *Needs a quick game-director-designer/Director confirm — recommend emit-always.*

- **OQ-4 (non-lethal re-fire / latch behaviour).** The one-shot latches (`_killed_latched` ping-pong, `_killed_emitted` spike, EXPLODED-terminal bomb) currently assume the run ends on first contact, so re-fire never mattered. Non-lethal makes the entity outlive the contact. Ping-pong re-arms on the falling edge (`:128–129`) → it re-tests cleanly (fine). Spike's `_killed_emitted` **latches permanently** (`:43/:92`) → a non-lethal spike emits its telemetry **once ever** and then never again even on a second touch. Bomb is one-shot terminal (`queue_free`) regardless. **Question:** for a non-lethal spike, should `_killed_emitted` re-arm on the player leaving the arm (like ping-pong's falling-edge re-arm) so repeated contacts log repeatedly? **Recommendation:** for L5 scope (the toggle exists to make the verify driver work, not to ship a non-lethal preset), leave the latches as-is — the verify driver only needs the entity to *not* kill, not to log every re-touch. If a future sweep ships a non-lethal K5 preset for telemetry, re-arming is a follow-up. *Recommend defer; note in the worklog.*

- **OQ-5 (does `make_default_play_preset()` set the kills knobs explicitly?).** Default `true` already yields a lethal preset, so the preset need not set them. **Recommendation:** do **not** set them in the preset (minimal diff); instead add the `hpp_kills/hbomb_kills/hspike_kills == true` assertions to `_verify_default_preset_shape()` so the lethal-preset guarantee is test-enforced rather than restated in the preset body. Small game-director-designer call. *Low-risk.*

- **OQ-6 (do existing tests assert lethality? will they break?).** Audited: `tests/test_pingpong_hazard.gd`, `tests/test_bomb_hazard.gd`, `tests/test_spike_hazard.gd` all build their `RunConfig` via `RunConfig.new()` (the all-off default) and set only the magnitude knobs — so with the kills knobs defaulting **`true`**, every "kill ends the run / emits `new_hazard_killed`" assertion (ping-pong case (d) `test_pingpong_hazard.gd:109–114`; bomb case 1 `test_bomb_hazard.gd:143–146`; spike case (d) `test_spike_hazard.gd:149–155`) **still passes unchanged** — they get `*_kills=true` for free. **No existing test breaks.** Optional additive coverage (recommend, one per family): a case that sets `<prefix>_kills=false`, drives a contact, and asserts `GameState.run_active` stays true while `new_hazard_killed` still fires (OQ-3) — proving the toggle. This is the verifiable proof-of-done for L5 beyond the verify-driver retirement. **The verify driver itself** is the other place lethality is implicitly asserted (`_driven_default_preset` worked around it) — retiring it is the core deliverable.

- **OQ-7 (which verify file owns the retirement — `test_rg1_m14_verify.gd` regression vs new `test_rg1_m15_verify.gd`?).** Per the iteration loop, RG1 spins a new `tests/test_rg1_m15_verify.gd` from the M1.4 file. **Question:** does the M1.4 verify stay as a frozen regression (in which case `_driven_default_preset()` lives on there, harmlessly) or is it superseded? **Recommendation:** L5 specifies the change against the M1.5 verify (RG1 applies it); if the team keeps `test_rg1_m14_verify.gd` runnable as a regression, retire `_driven_default_preset()` there too (it is now dead weight and the toggle makes the cleaner form available everywhere). Confirm with RG1's owner during Wave 3. *Coordination note, not a design call.*

---

## Resolved Decisions (Phase 3)

_Fresh-eyes pass, 2026-06-24. Reviewer is NOT the L5 author. Resolved against the verified as-built code: the three K5
guard sites (`pingpong_hazard.gd` `_on_contact()`, `bomb_hazard.gd` `_detonate()` `if hit:` block, `spike_hazard.gd`
`_physics_process` `if not _killed_emitted:` block — all confirmed to emit `new_hazard_killed` then call
`GameState.fail_run(&"death")` **unconditionally**), the `r1_catch_kills` mirror (`run_config.gd:79`,
`hazard_entity.gd:189`), and the verify driver `_driven_default_preset()` / `_default_preset()`
(`tests/test_rg1_m14_verify.gd:431-462`, used at `:112`). All three K5 setups snapshot `_cfg` so a `_cfg.<prefix>_kills`
read is zero-friction. The knob declarations are owned by L0 (frozen in `L0` RD-1/RD-7: `hpp_kills`/`hbomb_kills`/
`hspike_kills`, `bool`, default `true`, +3 to the count)._

### RD-1 — OQ-3 (does a non-lethal hazard still emit `new_hazard_killed`?): YES, emit-always — RESOLVED on telemetry-cleanliness merit

**Locked: a non-lethal hazard STILL emits `new_hazard_killed` on contact; only `fail_run` is gated by `*_kills`.** The guard
wraps **only** the `fail_run` call, leaving the `new_hazard_killed.emit(...)` line above it untouched:

```gdscript
EventBus.new_hazard_killed.emit(&"<kind>", depth, run_t_ms)   # ALWAYS — contact occurred
if _cfg.<prefix>_kills:
    GameState.fail_run(&"death")                              # gated — only the kill is conditional
```

This is the **exact R1 mirror**: `hazard_entity.gd` always emits `hazard_caught` and only the `fail_run` is behind
`r1_catch_kills` (`:188-193`). Three reasons it is the clean resolution:

1. **Telemetry comparability.** `new_hazard_killed` already means "a lethal contact occurred." Contact counts stay
   independent of the lethality toggle, so RG2 can compare contact frequency across lethal and non-lethal cohorts on the
   same metric — the whole point of config-marked telemetry.
2. **It is what the verify driver needs.** The driver runs the real preset with `*_kills=false`; emit-always means the
   driven run still logs the contact rows (proving the entities spawn and behave), it just doesn't end the run.
3. **No existing test breaks.** Audited (matches L5 OQ-6): `test_pingpong_hazard.gd`, `test_bomb_hazard.gd`,
   `test_spike_hazard.gd` build `RunConfig` via `RunConfig.new()` and set only magnitude knobs → they inherit `*_kills=true`
   and every "kill ends the run / emits `new_hazard_killed`" assertion **passes unchanged** (the default `true` gives them
   today's lethal behaviour for free). Emit-*only-when-lethal* (the rejected option b) would instead **break** those
   `new_hazard_killed`-fired assertions on any future non-lethal test and lose the contact signal — so emit-always is also
   the lower-risk choice.

**The one cosmetic cost** (the row name `new_hazard_killed` is a slight misnomer on a non-lethal contact) is identical to
R1's pre-existing `hazard_caught`-on-non-fatal-catch and is **not** a Director call — it is a documented house convention.
*Flag to RG2 only* that on a `*_kills=false` cohort, a `new_hazard_killed` row means "would-have-killed contact," not a
death — RG2 segments deaths by the run-end cause, not by this row, so the death metric stays clean. **No Director review
needed.**

### RD-2 — OQ-1 / OQ-2 (non-lethal motion/tell): behaves fully, only `fail_run` skipped — RESOLVED (technical)

A `*_kills=false` hazard keeps its **full state machine and tell** — the bomb arms→pulses→flashes, the bouncer keeps
travelling/bouncing, the spike keeps spinning — it simply does not end the run. This is forced by the as-built structure and
is the minimal change:

- **Bomb:** `_flash_blast()` and the `queue_free` timer already sit OUTSIDE the `if hit:` guard (`bomb_hazard.gd`), so
  "detonate visually, don't kill" is the natural shape — only the two lines inside `if hit:` (`emit` stays, `fail_run`
  gated) change.
- **Ping-pong / spike:** motion/tell are independent of the contact branch; wrapping `fail_run` changes nothing about
  travel/rotation.

Mirrors R1 (a non-lethal R1 still chases). Makes the driven verify a faithful real-preset run. *No Director review needed.*

### RD-3 — OQ-4 (non-lethal re-fire / latch): leave latches AS-IS for L5 scope — RESOLVED (technical)

L5's purpose is to make the verify driver work (entities spawn + behave but cannot end the run), NOT to ship a non-lethal
preset for telemetry. So leave the one-shot latches unchanged: ping-pong re-arms on its falling edge (re-tests cleanly);
spike's `_killed_emitted` latches permanently (emits once ever per entity, then never again); bomb is one-shot terminal.
A non-lethal spike that should re-log every re-touch is a **follow-up** if a future sweep ships a non-lethal K5 preset —
note it in the worklog, do not build it now. *No Director review needed.*

### RD-4 — OQ-5 (does the preset set the kills knobs?): do NOT set them; assert in the shape-check — RESOLVED (minor design)

`make_default_play_preset()` does **not** set `hpp_kills`/`hbomb_kills`/`hspike_kills` (default `true` already yields the
lethal preset — minimal diff). Instead, the verify shape-check (`_verify_default_preset_shape`) **adds assertions that the
real preset's three `*_kills` are `true`**, so the lethal-preset guarantee is test-enforced rather than restated in the
preset body. *No Director review needed.*

### RD-5 — The `_driven_default_preset()` retirement (the core L5 deliverable), SPEC LOCKED against the verified driver

Verified the driver shape (`tests/test_rg1_m14_verify.gd`):
- `_default_preset()` (`:437-444`): builds the real `make_default_play_preset()`, sets `build_tag`, `seed_override=12345`,
  and `c.r1_catch_kills = false` (so R1 can't pre-empt the scripted end-cause).
- `_driven_default_preset()` (`:457-462`): clones `_default_preset()` and sets `hpp_enabled=false` / `hbomb_enabled=false` /
  `hspike_enabled=false` — **disabling the K5 entities entirely** so the unconditionally-lethal shallow spike
  (`hspike_base_count=1`) can't kill the driven player before the scripted `extract`/`timeout` cause wins.
- Used once, at `:112`: `await _drive_run(_driven_default_preset(), &"extract", "M1-default-preset")`.

**Locked retirement (RG1 carries this into `tests/test_rg1_m15_verify.gd`; L5 specifies it):**

1. **Delete `_driven_default_preset()` (`:457-462`) and its doc-comment (`:446-456`).**
2. In `_default_preset()` (`:437-444`), add the three K5 kills-off lines alongside the existing `r1_catch_kills = false`:
   ```gdscript
   c.r1_catch_kills = false      # existing
   c.hpp_kills = false           # L5: K5 non-lethal so the driven end-cause matrix wins
   c.hbomb_kills = false
   c.hspike_kills = false
   # hpp_enabled / hbomb_enabled / hspike_enabled stay TRUE — entities now SPAWN and behave;
   # they just cannot end the run, so the scripted end-cause is reached.
   ```
3. The call at `:112` becomes `await _drive_run(_default_preset(), &"extract", "M1-default-preset")`.
4. **Shape-checks unchanged + strengthened:** `_verify_default_preset_shape()` keeps calling the **real**
   `make_default_play_preset()` and continues to assert the K5 hazards ship `_enabled = true`, and **adds** the RD-4
   assertions that the real preset's `hpp_kills`/`hbomb_kills`/`hspike_kills` are `true`. This is the safety the toggle buys:
   the driven matrix now exercises the **real** K5 spawn (the entities instantiate + behave), and the shape-check proves the
   shipped preset is lethal — the `_driven_default_preset()` workaround that hid the K5 spawn from the driven run is gone.

> **OQ-7 (which file owns it):** L5 specifies the change against the M1.5 verify; if `test_rg1_m14_verify.gd` is kept runnable
> as a frozen regression, the same retirement should be applied there too (it is now dead weight). This is a Wave-3
> coordination note with RG1's owner, **not a design call** — no Director review needed.

### Needs Director review

**None.** Every L5 open question resolves on technical/design merit (emit-always mirrors R1; non-lethal-but-behaving is the
minimal structural change; latches stay as-is for L5 scope; the preset relies on the `true` default; the driver retirement is
mechanical). The one item that *touches* the Director — whether to ship a non-lethal K5 preset for telemetry — is explicitly
**out of L5 scope** (RD-3) and is a future-sweep follow-up, not an L5 decision. The `*_kills` default-`true` polarity is the
contract-preserving all-off-equivalent (L0 RD-1/OQ-8), not a fun call.
