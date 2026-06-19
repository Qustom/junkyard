# BUG6 — `hazard_caught` debounce + config-trap guards

**Milestone:** M1.3 — Legibility & Density · **Workstream:** Wave 1 (Foundation & correctness) · **Wave:** 1
**Task id:** BUG6 · **Design author:** `qa-playtest-coordinator` · **Builder (build phase):** `general-purpose`
**dependsOn:** none (correctness; runs parallel in Wave 1) · **soft-overlaps:** J1 (the play-preset is one of the
config-trap remedies — see §4.2 / §5 Q2)
**Touch-map (proposed, single-writer):** `scenes/hazards/hazard_entity.gd` (debounce latch);
config-trap guard lands in **`ui/config/config_menu.gd`** (recommended primary) and/or as a flag inside
`RunConfig` (`data/run_config/run_config.gd`) read by Telemetry's `run_started` snapshot.
**Does NOT touch:** the `run_ended` arity, the telemetry schema version (additive `data` only), `event_bus.gd`
signatures (a new warning signal, *if* chosen, is pre-declared the M1.1 way — see §4.2c). `J1` owns
`run_config.gd`/`config_menu.gd` this wave — **if BUG6's guard lands in CFG, BUG6 and J1 co-own those files and must
be sequenced or merged carefully** (see §6 ownership note).

> This is a **design / approach** doc (Phase 2). It specifies the two fixes + their checks and recommends a mechanism
> for each; it does **not** modify game code. Phase 3 resolves the Open Questions (§5) before a builder is dispatched.

---

## 1. Goal & premise

Two distinct telemetry-trustworthiness defects surfaced in the M1.2 re-gate (`design/M1_2_Tasks/G4_findings_M1.2.md`
§3-I2, §3-R3, §3-R4, §5). Both corrupt the *very data the re-gate reads* rather than the gameplay, so both are
QA-owned correctness work, not tuning:

1. **`hazard_caught` per-frame storm** (§3-I2, §5 "BUG6"). The catch emits **every physics frame** the player is
   inside catch radius — per-run counts ran 85 → 2,199 events, **9,503 total** across the M1.2 cohort. A "catches per
   run" metric is meaningless and the log bloats ~300× on the one event the cost-axis read depends on. The fix:
   **emit `hazard_caught` exactly once per catch episode** (edge-trigger / one-shot).

2. **Config traps** (§3-R3, §3-R4, §5 "Config-trap guards"). R3 was *enabled* on 7 runs but ran **dead** because
   every R3-on run carried `r3_threshold_levels = []` (0 `exposure_crossed`, 0 `exposure_penalty` — BUG5/R3 went
   untested). R4 was *enabled* on 30 runs but the lost-proxy ran dead on all of them because
   `r4_lost_proxy_threshold = 0.0` (0 `nav_lost_proxy` — I4's lost cue went untested). An *enabled* opposition that is
   silently inert means a whole experiment cell is wasted and the gate is invalid for that opposition. The fix:
   **surface the trap before the run commits** so a playtest can't run an opposition dead without anyone noticing.

Neither is a gameplay bug; both are telemetry hygiene, mirroring M1.2's I5 (`design/M1_2_Tasks/I5_telemetry_hygiene.md`)
and BUG4 (`design/M1_2_Tasks/BUG4_robust_seal.md`) correctness shape.

---

## 2. Research — the confirmed defects (cite the real code)

### 2.1 The per-frame emit (BUG6 root cause)

`scenes/hazards/hazard_entity.gd` `_physics_process()` → the AWAKE block's catch test (lines 135–141):

```gdscript
# Catch test: distance-based, deterministic, no physics overlap needed (§2.4).
var catch_r: float = _cfg.r1_catch_radius + _cfg.r1_catch_radius_per_depth * float(depth)
if _catch_cooldown <= 0.0 \
        and global_position.distance_to(_player.global_position) <= catch_r:
    _on_catch(depth)
```

`_on_catch()` (lines 167–177) **always** emits, then branches on lethality:

```gdscript
func _on_catch(depth: int) -> void:
    var run_t_ms: int = int(_time_in_band * 1000.0)
    EventBus.hazard_caught.emit(depth, run_t_ms)        # <-- fires EVERY frame within radius
    if _cfg.r1_catch_kills:
        GameState.fail_run(&"death")                    # idempotent at the GameState level
    else:
        _apply_nonfatal_catch()                          # sets _catch_cooldown = 1.0s
```

Two emit paths, two different per-frame behaviours — and the per-frame storm is **emit-side, not logger-side**:

- **Non-fatal path** (`r1_catch_kills = false`): `_apply_nonfatal_catch()` sets `_catch_cooldown =
  NONFATAL_COOLDOWN_SECONDS` (1.0 s) and the catch test is gated by `_catch_cooldown <= 0.0`. So the non-fatal path is
  *already* throttled to ~1 emit/sec — at 60 Hz that's still ~60 emits over a 1 s overlap, not one per catch, but it is
  not the worst offender. **This is the path that produced `r_f936dc`'s 2,122 catches → extract** (§3-I2): a long
  overlap re-firing once per cooldown window while the player was eventually able to leave.

- **Fatal path** (`r1_catch_kills = true`, the default for every M1.2 R1 run): `_catch_cooldown` is **never set**, so the
  catch test re-passes every single physics frame for as long as the bodies overlap. `GameState.fail_run(&"death")` is
  idempotent — its `_run_ended` guard absorbs the duplicate run-end calls (so there is *one* `run_ended` row, which is
  why durations/causes are clean) — **but `EventBus.hazard_caught.emit()` runs BEFORE the `fail_run` call and is NOT
  guarded by `_run_ended`.** So the run ends correctly while `hazard_caught` keeps firing every frame until the node /
  player is torn down. *This is the dominant source of the 2,199-event runs.*

The header comment (lines 16–18, 164–166) is explicit that GameState's `_run_ended` guard is "the single source of
truth for run-end idempotency" and that R1 has "no local 'already ended' bool". That is correct for the *run-end* path,
but it leaves the **telemetry emit unguarded** — the emit happens unconditionally one line above the `fail_run` call.
So `fail_run`'s idempotency does NOT cover the telemetry storm; it only de-dupes the run-end. BUG6 must add a
hazard-local one-shot latch around the *emit* (and/or the catch test) — the run-end guard does not and cannot reach it.

Telemetry confirms the storm is purely emit-side: `systems/telemetry/telemetry.gd` `_on_hazard_caught()` (lines
191–196) just writes one row per signal — no de-dup, by design (it trusts the emitter):

```gdscript
func _on_hazard_caught(depth: int, _run_t_ms: int) -> void:
    _emit_row(Schema.HAZARD_CAUGHT, {"depth": depth, "run_t_ms": _elapsed_ms()})
    if _writer != null:
        _writer.flush()  # high-value: precedes a death run_ended
```

Note the per-event `_writer.flush()`: every storm frame forces a disk flush, so 2,199 events is also 2,199 fsync-class
writes per run — a real I/O cost, not just log volume. One more reason to fix at the emit.

### 2.2 The config traps (R3, R4-lost, and a third: R4-fog)

Each opposition system *self-gates to inert* when its driving knob is at its all-off default, **even when the master
`enabled` toggle is ON**. That is correct all-off behaviour (the master toggle alone must not change the baseline), but
it creates a silent trap: the Director flips the master ON, the CFG summary shows the section "ON", yet the mechanism
never fires.

| Trap | Knob @ default | Gating code | Symptom in M1.2 data |
|---|---|---|---|
| **R3 crossings** | `r3_threshold_levels = []` | `exposure_meter.gd:131-136` — the `while _levels_crossed < levels.size()` loop has **0 iterations** when `levels` is empty, so the meter climbs but nothing is ever crossed | 0 `exposure_crossed`, 0 `exposure_penalty` across 7 R3-on runs |
| **R4 lost-proxy** | `r4_lost_proxy_threshold = 0.0` | `lost_proxy.gd:40` — `_active = ... and _rc.r4_lost_proxy_threshold > 0.0` → `set_process(false)`, the node never accumulates | 0 `nav_lost_proxy` across 30 R4-on runs |
| **R4 fog** (same family, not yet flagged) | `r4_vision_radius = 0.0` | `vision_fog.gd:138` — `_active = ... and _rc.r4_vision_radius > 0.0` → invisible, no occlusion | fog on only 3/30 R4-on runs; the rest had `r4_vision_radius = 0.0` and the fog was inert |

The pattern is identical in all three: **`master_enabled == true` AND the load-bearing magnitude knob == its all-off
zero/empty default → the mechanism is a no-op.** A config-trap guard should detect exactly this conjunction. (R3 also
has a softer trap — non-empty thresholds but `r3_penalty_kind = none` is telemetry-only-by-design, so that one is NOT a
trap; only the *crossing* must fire for the gate, and `none` still emits `exposure_crossed`. The guard should key off
the crossing-enabling knob, not the penalty kind.)

### 2.3 Why this is QA/correctness, not tuning

The M1.3 re-gate (RG2) must re-test R3/BUG5 and R4-lost with the knobs *populated* (`G4_findings_M1.2.md` §4: "two
fixes couldn't be evaluated because the swept config disabled them, not because the code failed"). If the M1.3
playtest repeats the M1.2 trap, the re-gate is invalid again. The guard is the structural fix that makes the re-test
*reliable* rather than dependent on the Director remembering to populate two specific knobs. The debounce makes the
hazard-catch metric *measurable* at all.

---

## 3. Recommended fix (a) — `hazard_caught` one-shot latch

### 3.1 Mechanism: a hazard-local edge-trigger latch (recommended)

Add a `_caught_latched: bool` to `HazardEntity` that gates the **emit** so it fires exactly once on the *transition*
into catch range, and re-arms when the player leaves catch range (so a second, genuine catch after an escape still
logs). This is the minimal edge-trigger, it lives entirely in the hazard (no new contract, no schema change, no
EventBus edit), and it composes cleanly with both lethality paths:

```gdscript
var _caught_latched: bool = false   # true while the player is continuously inside catch radius

# in _physics_process AWAKE block, replacing the catch test:
var in_range: bool = global_position.distance_to(_player.global_position) <= catch_r
if in_range and not _caught_latched and _catch_cooldown <= 0.0:
    _caught_latched = true           # latch on the rising edge -> at most one emit per episode
    _on_catch(depth)
elif not in_range:
    _caught_latched = false          # re-arm only after the player has left the radius (falling edge)
```

`_on_catch()` then emits **once** per latched episode. Notes:

- **Fatal path:** the single emit precedes `fail_run(&"death")` exactly as today, but now there is exactly **one**
  `hazard_caught` row per fatal catch — pairing the (already-correct) `_run_ended` run-end idempotency with a matching
  emit idempotency. The two guards are complementary: `_run_ended` de-dupes the run-end; `_caught_latched` de-dupes the
  telemetry. After the fatal catch the run is over, so re-arming never happens in practice — but the latch makes the
  *first and only* frame emit, killing the per-frame storm regardless of how long the bodies remain overlapping during
  teardown.
- **Non-fatal path:** the existing `_catch_cooldown` (1.0 s) already throttles re-catches; the latch is stricter and
  better — instead of "re-fire every cooldown window while still overlapping", it is "fire once, then stay silent until
  the player actually leaves radius, then (after cooldown) may catch again". This turns the `r_f936dc`-style
  2,122-catch overlap into the intended **one event per distinct catch**. Keep `_catch_cooldown` for the
  knockback/stun gameplay timing; the latch governs the *emit*. Order: require BOTH `not _caught_latched` AND
  `_catch_cooldown <= 0.0` on the rising edge (a catch right after the cooldown window, while the player never left
  radius, should NOT silently re-emit — leaving radius is the canonical re-arm).
- **Setup reset:** clear `_caught_latched = false` in `setup()` (alongside `_state`, `_time_in_band`, `_depin_dir`) so
  a pooled/respawned hazard starts un-latched.

### 3.2 Alternative considered — rely on the existing run-end guard (rejected)

One might argue "the `fail_run` `_run_ended` guard already makes the run end once, so just move the emit after the
guard." **Rejected:** (1) the run-end guard is inside `GameState`, not visible to `HazardEntity`, and the spec
explicitly forbids R1 adding a local "already ended" bool that *prevents* the `fail_run` call (line 166); (2) it only
covers the **fatal** path — the **non-fatal** path never ends the run, so the storm there would survive entirely; (3)
even on the fatal path, the emit-before-`fail_run` ordering is deliberate (a `hazard_caught` should precede its
`run_ended.death` in the log). The latch is the right scope: it fixes both paths, changes no contract, and keeps the
emit-then-end ordering.

### 3.3 Verification (objective)

- **GdUnit4 unit** (extend `tests/test_pursuing_hazard.gd`, which already counts `hazard_caught` via `_caught`): drive
  a hazard to overlap the player for **N physics frames** with `r1_catch_kills = true`; assert `_caught.size() == 1`
  (not N). Add a non-fatal case: overlap for N frames, assert `== 1`; then move the player out of radius and back in
  (after cooldown), assert `== 2`. This is the regression-lock — it would have caught the storm.
- **Re-test of the analysis metric:** after the build wave, RG2's helper should show `hazard_caught` per-run counts in
  the **single digits** (≈ deaths + non-fatal bumps), not hundreds/thousands. A coarse CI/log assertion ("no run emits
  > K `hazard_caught`", K small, e.g. 20) can lock it in `test_rg1_*` style verifies.

---

## 4. Recommended fix (b) — config-trap guard

### 4.1 What "trap" means precisely

A config trap = **`<opp>_enabled == true` AND the opposition's load-bearing driver knob is at its all-off default**, so
the mechanism is inert. The three known traps (§2.2):

| id | condition | meaning |
|---|---|---|
| `r3_no_thresholds` | `r3_enabled and r3_threshold_levels.is_empty()` | meter climbs, nothing ever crosses (no crossing/penalty events) |
| `r4_no_lost_proxy` | `r4_enabled and r4_lost_proxy_threshold <= 0.0` | lost-proxy never accumulates (no `nav_lost_proxy`) |
| `r4_no_vision` | `r4_enabled and r4_fog_enabled and r4_vision_radius <= 0.0` | fog enabled but radius 0 → no occlusion |

This is small, stable, and centralisable. **Recommendation: a single `RunConfig.inert_enabled_oppositions() ->
PackedStringArray` method** (in `data/run_config/run_config.gd`) that returns the ids of every enabled-but-inert
opposition for a config. One source of truth, consumed by both the CFG warning (§4.2a) and the telemetry flag (§4.2b),
and trivially unit-testable. A future R-task adding a trap adds one line here.

### 4.2 Where the guard surfaces — recommendation: CFG warning + telemetry flag (both), preset is J1's job

Three candidate placements; recommend **(a) + (b)** (warn-and-mark), with **(c)/preset deferred to J1**:

**(a) CFG pre-run warning — RECOMMENDED PRIMARY.** `config_menu.gd` is where the Director commits a config and already
owns redundant readouts (the summary bar, per-section chips). It is the natural place to warn *before* a dead run is
launched. Concretely: in `_refresh_summary()` / per-section chip refresh, when `inert_enabled_oppositions()` is
non-empty, render a **high-contrast warning line** (text + a non-colour cue per the UI readability rules — e.g. a
"INERT" tag chip on the offending section, mirroring the existing ON/OFF chip channel) naming each trap, e.g.
*"R3 ENABLED BUT INERT — no threshold levels (no crossings will fire)."* This is warn-and-continue: it does **not**
block Start (the Director may *want* a climb-only R3 cell), it makes the trap impossible to miss. Strings go through
`tr()` against `config_strings.csv` (add `CFG_TRAP_*` keys), consistent with the existing CFG i18n rule. This reuses
the existing chip/summary refresh path the Director already reads, so it costs almost nothing to add and is seen at the
exact decision moment.

**(b) `run_started` telemetry flag — RECOMMENDED COMPANION.** Add an **additive `data` field** to the `run_started` row
(NOT a schema bump — same pattern as the existing `run_config` snapshot, `telemetry.gd:130-135`):
`"inert_enabled_oppositions": ["r3_no_thresholds", ...]` (empty array when clean). This makes a dead-config run
**self-identifying in the log**, so RG2 can automatically exclude/flag trap runs *after the fact* even if the live
warning was missed. It rides the same `_active_run_config_dict()` call site — Telemetry calls
`RunConfig.inert_enabled_oppositions()` on the active config when stamping `run_started`. No new event, no schema
version change, no `run_ended` arity change (per the M1.3 contract). This is cheap insurance the analyst gets for free.

**(c) Sane defaults via the J1 play-preset — DEFERRED to J1, note the dependency.** The cleanest *prevention* is that
the default play-preset the game boots into (J1) ships R3/R4 with populated thresholds when their masters are on — so
the common case is never a trap. **But the M1.3 ratified preset has R3 OFF and R4 ON** (`G4_findings_M1.2.md` §5-F1),
so the J1 preset must at least ship `r4_lost_proxy_threshold > 0.0` and `r4_vision_radius > 0.0` if it has R4 fog on,
or the *default boot* is itself a trap. **BUG6 does not own the preset values — that is J1.** BUG6's contribution here
is to *flag* the dependency: J1's design must consult §4.1's trap list so the shipped preset is trap-free, and BUG6's
guard (a)+(b) is the safety net for any non-default config the Director sweeps. Recommend the guard ships regardless of
J1 (warn-only is harmless and catches manual sweeps); the preset fix is J1's, the warning is BUG6's.

**Recommendation summary:** ship **(a) CFG warn-line + (b) `run_started` flag**, both driven by one
`RunConfig.inert_enabled_oppositions()` method; **defer (c)** to J1 with an explicit cross-task note. Warn-only (not
block) — the Director keeps the freedom to run a climb-only cell deliberately, but can never do it *unknowingly*.

### 4.2c If a new EventBus signal is wanted (it isn't, for the recommended path)

The recommended placement (CFG label + `run_started` data field) needs **no new EventBus signal** — CFG reads the
config directly and Telemetry already stamps `run_started`. If Phase 3 instead chooses a *runtime* warning (e.g.
`main_game.start_new_run` emits a warning when it stages a trap config), that would need a pre-declared signal
(e.g. `config_trap_detected(ids: PackedStringArray)`) added to `event_bus.gd` **on `main` before the parallel wave**,
the M1.1 way (owner declares, others subscribe). Flag for Phase 3; the recommended path avoids it.

### 4.3 Verification (objective)

- **GdUnit4 unit** (`tests/test_run_config.gd` or a new `test_config_traps.gd`):
  `RunConfig.inert_enabled_oppositions()` returns `[]` for the all-off control and for any fully-populated config;
  returns exactly `["r3_no_thresholds"]` for `r3_enabled=true, r3_threshold_levels=[]`; `["r4_no_lost_proxy"]` for
  `r4_enabled=true, r4_lost_proxy_threshold=0.0`; the union when multiple traps coexist. **The all-off control must
  return `[]`** (it must not warn on the baseline — no master is enabled).
- **CFG coverage:** extend `tests/test_config_menu.gd` — assert the warning line appears when a trap config is loaded
  and is absent for the all-off default. (The existing `has_full_coverage()` knob-count assertion is untouched — BUG6
  adds no new `@export` knob, so the CFG coverage count does not change.)
- **Telemetry:** extend `tests/test_telemetry_config_marking.gd` — assert `run_started.data.inert_enabled_oppositions`
  is present, is an array, and is `[]` for the all-off control.
- **Determinism unaffected:** BUG6 adds no spatial knob and no behaviour change to the generator, so the all-off
  fingerprint stays `e943ac9c8bc1` (the guard only *reads* config; the latch only changes emit cardinality, not
  movement/catch *gameplay* — the player still dies on the same frame). Note for the builder: confirm the latch does
  not change *when* `fail_run` is called (it must still fire on the same rising-edge frame the old code did) so death
  timing — and thus `duration_s` — is byte-identical for a given seed.

---

## 5. Open Questions (for Phase 3 — fresh eyes)

1. **Debounce mechanism — latch vs. cooldown-unification vs. lean on run-end guard.** Recommended: the
   `_caught_latched` rising/falling-edge latch (§3.1), because it fixes BOTH lethality paths and changes no contract.
   *Open:* should the non-fatal path's re-arm be **"player left radius"** (recommended — cleanest semantic "distinct
   catch") or **"cooldown expired"** (re-fire each cooldown window even while still overlapping, closer to today's
   throttled behaviour)? The two differ for a player pinned against a wall in radius: "left radius" emits 1, "cooldown"
   emits 1/sec. Recommend "left radius" for telemetry cleanliness; flag if the gameplay reading of "the hazard caught
   me again" should log repeated bumps during a sustained pin. *Mostly a technical call (resolvable by fresh eyes); the
   only soft judgment is whether a sustained pin is "one catch" or "many" for the analyst — recommend one.*

2. **Config-trap policy — warn-only vs. block vs. auto-fix-via-preset vs. all three.** Recommended: **warn-only (a) +
   telemetry flag (b)**, with auto-fix deferred to J1's preset (c). *Open / partly a Director call:* should the guard
   ever **block** Start on a trap (forcing the Director to either populate the knob or turn the master off)? Block is
   safer for the gate (no dead run is possible) but removes the legitimate "climb-only R3 cell" and "branching-only R4
   cell" experiments the Director may want. **This is a UX/scope call — flag "needs Director review" with the
   recommendation: warn-only, do not block** (preserve sweep freedom; the telemetry flag + RG2 filter is the backstop).

3. **Where the warning lives — CFG vs. runtime vs. telemetry-only.** Recommended: **CFG (a) + telemetry (b)**, not
   runtime. *Open:* is the CFG label sufficient, or does the Director also want a runtime/HUD nudge (e.g. a one-line
   on-dive notice) in case they launch from a non-CFG path? Recommend CFG+telemetry only for M1.3 (runtime needs a
   pre-declared signal, §4.2c, and the playtest always launches via CFG). Fresh eyes confirm the launch path is always
   CFG-mediated (`config_menu.apply_and_get_config()` → `main_game.start_new_run`, per `config_menu.gd` header) — if a
   non-CFG launch path exists, re-weigh.

4. **Trap scope — three known traps, or generalise.** Recommended: enumerate the three known driver-knob traps in
   `inert_enabled_oppositions()` (§4.1). *Open:* should R1 also be trap-checked (e.g. `r1_enabled` with
   `r1_spawn_count = 0`, or `r1_catch_radius < player_r + hazard_r` which re-creates the M1.1 caught=0 bug noted in
   `run_config.gd:52-54`)? R1's `r1_catch_radius` floor is arguably the *most* dangerous trap (it silently re-creates
   the original "never catches" defect). **Recommend adding `r1_no_spawn` (`r1_enabled and r1_spawn_count <= 0`) and
   `r1_catch_radius_too_small` to the trap set** — the analysis cost is one more line and it closes the exact defect
   class. Fresh eyes confirm the radius floor value (player_r 14 + hazard_r 10 = 24 px per the I2 bodies).

5. **J1 preset dependency (cross-task).** §4.2c notes the J1 default preset must be trap-free given the ratified
   "R3 OFF, R4 ON" stack. *Open / coordination:* J1 owns the preset values and the `run_config.gd`/`config_menu.gd`
   files this wave (M1.3 breakdown §5 single-writer note). **If BUG6's guard lands in `config_menu.gd` and the
   `inert_enabled_oppositions()` method in `run_config.gd`, BUG6 and J1 are co-writing both files in Wave 1.** Resolve
   in Phase 3 / at brief time: either (i) sequence BUG6 after J1 in Wave 1, (ii) co-own the two files under one
   branch/brief, or (iii) land the `inert_enabled_oppositions()` method + the telemetry flag (file-disjoint from J1 via
   `run_config.gd` additive method + `telemetry.gd`) in BUG6 and let J1 add the CFG warning label as part of its CFG
   work. *Recommend (iii): the method + telemetry flag are BUG6's (small, testable, the gate-critical part); the CFG
   label is folded into J1's CFG edit to avoid a two-writer collision on `config_menu.gd`.* This is the cleanest
   ownership split and the orchestrator should set it at brief time.

---

## 6. Definition of done

- `hazard_caught` emits **at most once per catch episode** (one-shot latch, re-armed on leaving radius); a GdUnit4
  test drives an N-frame overlap and asserts exactly 1 emit (fatal) / correct count across escape-and-re-catch
  (non-fatal). The fatal-path death frame (and thus `duration_s`) is unchanged for a given seed.
- A `RunConfig.inert_enabled_oppositions()` method returns the enabled-but-inert opposition ids (`[]` for the all-off
  control), unit-tested for each known trap.
- The trap is surfaced **before commit** via a CFG warning line (folded into J1's CFG edit per §5 Q5) **and** an
  additive `run_started.data.inert_enabled_oppositions` telemetry field — warn-only, Start is not blocked.
- No `run_ended` arity change, no telemetry schema bump, no new EventBus signal (unless Phase 3 chooses the runtime
  path, then pre-declared on `main` first). All-off determinism fingerprint `e943ac9c8bc1` unchanged.
- Single worklog at `worklogs/<date>-BUG6-*.md` naming the commit(s), tests run, and any deviation.
```
