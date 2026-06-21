# K2 — Quota system + roguelite wipe (Phase-2 design)

**Milestone:** M1.4 — Stakes, Variety & Legibility
**Task:** K2 (Quota system + roguelite wipe) — the headline stakes feature.
**Roles:** general-purpose (GameState/SaveManager/main_game) + game-director-designer (economy/this doc)
+ ui-ux-designer (HUD readout + Game-Over screen) + qa-playtest-coordinator (save fixture).
**Blocked by:** K0 (knob + signal pre-declare). **Wave:** 2 (sequenced K2 → K7; both touch `main_game.gd`/`game_state.gd`).
**Status:** Phase 2 (design). Open Questions await Phase 3 fresh-eyes + Director ratification.

**Director work-order (verbatim):** "Add a quota to give a reason why we keep getting money. Every run
there must be some amount met or it's a game over. Every time it's met, the run number should increase.
Every new run, increase the quota. Make these values configurable. Have it start at $50 and increase it by
$50 every run."

**Director FINAL disposition (locked, not re-litigated here):** a quota **MISS = FULL roguelite wipe**
— reset meta-state to zero/defaults. This doc designs *how*, not *whether*.

---

## (a) Research

### A.1 Why this task — the design hole M1.3 exposed

The M1.3 re-gate verdict was **ITERATE** because the loop reads as **low-stakes**: Money accumulates but
nothing is ever *at risk* if you under-perform (`M1.4_Breakdown.md` §1). Today the only failure is
death/timeout, which costs you the *unbanked* haul minus pockets (`game_state.gd:323 fail_run`) — a soft,
within-run loss. There is no reason to *keep* getting money beyond "the number goes up." K2 supplies the
missing *why*: each run owes a quota; miss it and you lose everything you've built (the roguelite wipe);
meet it and the bar rises. This is the **headline stakes feature** of M1.4.

### A.2 GDD / TDD grounding — this is the greybox seed of the Debt Clock

The quota is the **greybox first instance of the GDD's "Debt Clock" (GDD §10)**: *"Debt starts soft and
gets scary as you succeed… success is the threat."* The fiction is a laid-off engineer drowning in student
debt who inherits a junkyard and dives to pay it off (GDD §3, §1). A linear `$50 + $50/run` quota is the
**Act-1-forgiving** stub of that curve — the real debt curve (interest, creditors, soft deadlines, the
8-tab `economy_model.xlsx`) is **M2+/M3 tuning** (TDD §I economy line; `M1.4_Breakdown.md` §2 "NOT … a
meta/economy layer beyond the quota"). K2 is deliberately **a single gate + a wipe, not an economy.**

**Scope guardrail (Breakdown §2):** K2 is *configurable-not-balanced*. `quota_base=50`/`quota_step=50` are
Director sweep values surfaced as RunConfig knobs (and a preset), never finalized here. The all-off default
**disables the quota** so an unconfigured run reproduces the M1.0/M1.3 baseline byte-for-byte (the
load-bearing carried contract, Breakdown §2). The fun value (`quota_enabled = true`) ships in
`make_default_play_preset()`.

### A.3 The run/meta boundary — the load-bearing hard part (TDD §2/§3, `CLAUDE.md`)

`game_state.gd:1-9` states the rule: **meta-state persists** (SaveManager writes `meta.sav` from it);
**run-state is disposable** (wiped on extract/death/timeout). The quota system straddles both:

- **The quota target and the run number are META-STATE.** They must persist across runs (so the bar a run
  must clear was *set by the previous run's outcome*), escalate on a met quota, and **reset-to-defaults on
  a wipe.** They join the meta block (`game_state.gd:26-36`, `to_meta_dict()/from_meta_dict()`
  `game_state.gd:411-438`) and the save schema (`META_SCHEMA_VERSION`).
- **"Did this run meet the quota?" is RUN-STATE** — it is a per-run *evaluation*, derived from what the run
  banked/sold, discarded with the rest of run-state on run end.

The existing meta fields the wipe must reset: `money`, `salvage`, `lore`, `exposure`, `knowledge_level`,
`unlocked_recipes`, `banked_junk` (`game_state.gd:27-36`). K2 **adds** `quota_target` + `run_number`.

### A.4 The run lifecycle K2 hooks into (all real, all locked)

- `start_run(band_id, seed)` (`game_state.gd:86-106`) — resets run-state, binds `active_run_config`, emits
  `run_started`. **K2 reads the quota knobs from `active_run_config` here and ensures the meta quota is
  initialised** (first-ever run: `quota_target = quota_base`, `run_number = 1`).
- `extract_and_end_run()` (`game_state.gd:177-211`) — banks junk *identities* into `banked_junk`, persists
  meta (`SaveManager.save_meta(0)`), emits `haul_banked(banked_value)`, then `end_run(&"extract", …)`.
- `fail_run(cause)` (`game_state.gd:323-356`) — death/timeout: keeps a pockets subset, persists meta, emits
  `haul_banked(kept_value)`, then `end_run(cause, …)`.
- `end_run(reason, duration_s)` (`game_state.gd:235-244`) — the **single resolve point** all three outcomes
  route through; flips `run_active` off, clears the bag, emits the **locked-arity**
  `run_ended(reason, duration_s, max_depth_reached)`.
- `_run_ended` idempotency guard (`game_state.gd:64-70`) — first run-end wins; extract beats a same-frame
  timeout. The quota check + wipe must live *inside* this guarded path so they fire **exactly once** per run.
- `sell_banked_junk(source)` (`game_state.gd:271-294`) — F1's cash-out: sums `banked_junk` → `add_currency(&"money", total, source)`, clears the bank, `SaveManager.save_meta(0)`, returns a breakdown.
  **Called by the SellScreen** (`sell_screen.gd:128`), AFTER `run_ended`, while the tree is paused.
- `add_currency(kind, delta, source)` (`game_state.gd:247-253`) — the canonical money mutator + `currency_changed` emit. The quota's met-test compares against `money` *after* the sell credits it.

### A.5 The save schema K2 must bump (the standing rule)

`save_manager.gd:15` — `META_SCHEMA_VERSION := 2`. The ordered stepwise migration loop is
`save_manager.gd:75-90` (`while v < META_SCHEMA_VERSION: match v: …`). The standing rule (`CLAUDE.md` →
Saves; Breakdown §2 "the ONE exception"): **every schema change = bump + one ordered migration step + a QA
fixture.** K2 bumps **v2 → v3**, adds the `2:` case to the `match`, and adds a `meta_v2.sav` fixture +
a migration-test case following the template at `test_save_migration.gd:25-28`.

### A.6 The UI seams K2 integrates with

- **HUD quota readout:** `decision_hud.gd` — a pure-projection CanvasLayer (`decision_hud.gd:1-7`) that
  already renders Holding / Clock / Depth from EventBus signals. The quota line ("Quota $X / need $Y") is
  one more projected label, gated on `quota_enabled` so the all-off HUD is unchanged (`decision_hud.gd`
  R2/R3-cue gating is the precedent at `:280-289`).
- **Game-Over screen:** the loop today is `run_ended → SellScreen presents → continue_pressed →
  MainGame.start_new_run()` (`main_game.gd:138`, `sell_screen.gd:113-117,245-248`). K2 inserts a
  **GameOver beat on a quota MISS**: the SellScreen still tallies (the player sees what they earned, then
  that it wasn't enough), but Continue routes through the **wipe** before the next run, and the screen reads
  "QUOTA MISSED — wiped." This reuses the existing `continue_pressed`/`run_ended` plumbing (no new run-end
  signal, locked arity), with the wipe as a **separate meta op** triggered before `start_new_run()`.

### A.7 The RunConfig knob pattern K0 pre-declares

`run_config.gd` fronts each feature with a master `enabled` toggle + typed sub-knobs in an `@export_group`
(`run_config.gd:54-58` Meta group; `:57-58` R1 group). Every knob joins `to_flat_dict()`
(`run_config.gd:281-339`) for config-marked telemetry, and the preset sets non-default values in
`make_default_play_preset()` (`run_config.gd:428-500`) built on a never-mutated `RunConfig.new()`. **K0
pre-declares the K2 quota group; K2 only reads it.** Proposed group (K0's to add):

```gdscript
@export_group("Quota (K2)", "quota_")
## Master toggle. OFF (default) = no quota, no wipe — the M1.0/M1.3 baseline loop.
@export var quota_enabled: bool = false
## The quota the FIRST run must meet (Director: $50). Run 1's target.
@export var quota_base: int = 50
## How much the target rises each time the quota is MET (Director: +$50/run).
@export var quota_step: int = 50
```

These three are the only new RunConfig fields. They are **run-scoped configuration**, NOT meta-save state
(`run_config.gd:12-15`) — they parameterise *how the meta quota escalates*, but the live `quota_target` /
`run_number` live in `GameState` meta (A.3). The default play-preset sets `quota_enabled = true`
(base 50 / step 50 inherit the code defaults).

---

## (b) Pseudocode (against the real GameState / SaveManager / EventBus / UI APIs)

> All pseudocode is illustrative, typed-GDScript, against the as-built APIs cited in (a).
> **No arity change to `run_ended`** — quota-fail reuses it with a new `reason`; the wipe is a *separate*
> meta op. The check + escalation run *inside* the `_run_ended`-guarded paths so they fire exactly once.

### B.1 New meta-state + EventBus signals (K0 pre-declares the signals)

```gdscript
# game_state.gd — META block (joins money/salvage/lore/... at game_state.gd:27-36)
var run_number: int = 1        # 1-based; the run currently being played. Resets to 1 on wipe.
var quota_target: int = 0      # the Money bar THIS run must clear. 0 = "not yet initialised"
                               # (lazy-init at the first quota-enabled start_run from quota_base).

# event_bus.gd — K0 pre-declares (primitives only; telemetry-safe). Run-lifecycle group.
signal quota_evaluated(run_number: int, target: int, achieved: int, met: bool)   # fired once per run end (quota on)
signal quota_advanced(new_run_number: int, new_target: int)                      # fired when a quota is MET
signal meta_wiped(prev_run_number: int)                                          # fired when a MISS wipes meta
```

`quota_evaluated` is the single telemetry row for the gate (RG2 reads met-rate, achieved-vs-target
distribution by config). `quota_advanced` drives the HUD bump + the SellScreen "next quota" line.
`meta_wiped` lets the HUD/Telemetry/Game-Over react to a reset. All three are **additive** — no `run_ended`
arity change.

### B.2 When is the quota checked, and against what? (recommended shape — Director-confirm in Q1/Q2)

**Recommended: check on EVERY run end (extract/death/timeout), measured by cumulative `money` after the
sale.** Rationale below; alternatives in Open Questions Q1/Q2.

The quota is evaluated at the **single resolve point that already exists** — but `money` is only credited
when the SellScreen calls `sell_banked_junk()` *after* `run_ended` (sell-before-animate, `sell_screen.gd:128`).
So the clean seam is: **evaluate the quota in `sell_banked_junk()`, after the credit + save, before
returning** — that is the one place `money` is final for the run AND meta is already persisted. This keeps
the evaluation off `run_ended` (whose arity is locked) and lets the SellScreen/MainGame read the *result*.

```gdscript
# game_state.gd — append to sell_banked_junk(), AFTER add_currency + save_meta (game_state.gd:289-292),
# BEFORE `return breakdown`. ONE evaluation per run because sell_banked_junk is called once per run end.
func _evaluate_quota() -> Dictionary:
    # Inert unless the run was configured with the quota on. active_run_config is cleared by end_run()
    # (game_state.gd:241) BEFORE the SellScreen sells — so snapshot the quota config at start_run (B.3).
    if not _quota_active_this_run:
        return {"checked": false}
    var achieved: int = money            # CUMULATIVE money after this run's sale (recommended; see Q2)
    var met: bool = achieved >= quota_target
    EventBus.quota_evaluated.emit(run_number, quota_target, achieved, met)
    if met:
        # Escalate: bump the run number AND raise the next quota. Persisted below.
        run_number += 1
        quota_target += _quota_step_snapshot          # +$50 (snapshot, B.3)
        SaveManager.save_meta(0)                       # persist the advanced quota/run-number
        EventBus.quota_advanced.emit(run_number, quota_target)
        return {"checked": true, "met": true, "achieved": achieved, "target": quota_target}
    else:
        # MISS → the wipe is a SEPARATE meta op the SellScreen/MainGame triggers on Continue (B.4),
        # NOT here: we want the player to SEE the tally + the GameOver beat first, then wipe → fresh start.
        return {"checked": true, "met": false, "achieved": achieved, "target": quota_target}
```

**Why cumulative `money` and not this-run's banked value (recommended):** the Director's words are *"some
amount met."* Cumulative-money is the **forgiving Act-1 reading** (GDD §10 "keep Act 1 forgiving"): a great
run banks a buffer that carries forward, so a thin run after a fat one can still clear the (now-higher) bar.
A *banked-this-run-only* reading is harsher — every single run must independently clear its bar or wipe —
which is a more brutal roguelite. **This is a genuine fun/scope call → Q2, flagged for the Director.** The
mechanics below are identical either way; only `achieved`'s definition changes.

### B.3 Snapshotting the quota config at start_run (because active_run_config is cleared before the sell)

`end_run()` clears `active_run_config` (`game_state.gd:241`) *before* the SellScreen calls
`sell_banked_junk()` — so `_evaluate_quota()` cannot read the run config directly. Snapshot it at
`start_run`, alongside the lazy meta-init:

```gdscript
# game_state.gd — new run-state fields (disposable; reset each start_run)
var _quota_active_this_run: bool = false
var _quota_step_snapshot: int = 0

# game_state.gd — inside start_run(), after active_run_config is bound (game_state.gd:103-104):
var qc: RunConfig = active_run_config
_quota_active_this_run = qc != null and qc.quota_enabled
_quota_step_snapshot = qc.quota_step if qc != null else 0
if _quota_active_this_run:
    # Lazy meta-init on the first quota-enabled run (fresh profile OR just-wiped): seed the bar.
    if quota_target <= 0:
        quota_target = qc.quota_base
        run_number = 1
        # No save here — extract/fail will persist; or persist eagerly so a quit-before-extract keeps the bar.
```

### B.4 The wipe — the exact operation (Director FINAL: full roguelite wipe)

The wipe **resets every meta field to its code default** and **re-persists** through SaveManager's atomic
path, so the on-disk `meta.sav` reflects the wiped state (a quit-after-wipe stays wiped). It is a **single
meta op**, called *after* the player has seen the GameOver beat, *before* the next `start_run`.

```gdscript
# game_state.gd — the full roguelite wipe. Resets ALL meta-state to defaults, persists, signals.
# Called by MainGame on the GameOver→Continue path (B.6), NOT inside the run-end guard.
func wipe_meta() -> void:
    var prev_run_number := run_number
    # Reset EVERY meta field (game_state.gd:27-36) to its construction default.
    money = 0
    salvage = 0
    lore = 0
    exposure = 0
    knowledge_level = 0
    var empty_recipes: Array[StringName] = []
    unlocked_recipes = empty_recipes
    var empty_junk: Array[JunkItem] = []
    banked_junk = empty_junk
    # K2 meta: run number back to 1; quota back to "uninitialised" so the next quota-enabled
    # start_run re-seeds it from quota_base (B.3). A wipe puts you back at run 1, quota $50.
    run_number = 1
    quota_target = 0
    # Persist the wiped state through the SAME atomic write + .bak path (slot 0) as every other meta op.
    SaveManager.save_meta(0)
    # Fire AFTER the persist so observers (HUD/Telemetry/GameOver) read the settled state.
    EventBus.meta_wiped.emit(prev_run_number)
    EventBus.currency_changed.emit(&"money", 0, &"wipe")   # nudge any money-projection HUD to repaint to 0
```

**Boundary note:** `wipe_meta()` only ever touches **meta** fields — it never touches `run_active`,
`run_seed`, `run_inventory`, or the `_run_ended` guard. It runs *between* runs (after `end_run` cleared
run-state, before the next `start_run` rebuilds it), so there is no run-state for it to corrupt. This keeps
the run/meta boundary intact: the wipe is a pure meta reset.

### B.5 The SellScreen — quota outcome in the reward beat (ui-ux + general-purpose)

The SellScreen already tallies on all three causes (`sell_screen.gd:113-117`). K2 makes it also **render the
quota outcome** from the `_evaluate_quota()` result and **flag the GameOver state** so MainGame knows to
wipe on Continue.

```gdscript
# sell_screen.gd — _present() currently calls GameState.sell_banked_junk(source) (sell_screen.gd:128).
# sell_banked_junk now also evaluates the quota internally (B.2). The SellScreen reads the OUTCOME via a
# light getter so it stays pure-presentation and owns no quota truth:
var q := GameState.last_quota_result()     # {checked, met, achieved, target} — the cached B.2 return
if q.get("checked", false):
    if q["met"]:
        _quota_line.text = tr("SELL_QUOTA_MET").format({"target": q["target"]})   # "Quota cleared — next: $X"
        _pending_wipe = false
    else:
        _title_label.text = tr("SELL_TITLE_QUOTA_FAIL")   # "QUOTA MISSED" overrides EXTRACTED/RUN LOST
        _quota_line.text = tr("SELL_QUOTA_MISS").format({"achieved": q["achieved"], "target": q["target"]})
        _pending_wipe = true     # Continue will route through the wipe (B.6)
else:
    _quota_line.visible = false  # quota off → unchanged M1.3 reward beat
```

`last_quota_result()` is a trivial getter returning the cached dict from B.2 (run-state, cleared at next
`start_run`). It keeps the SellScreen a pure consumer (no quota math in the UI).

### B.6 MainGame — routing Continue through the wipe on a miss

```gdscript
# main_game.gd — today: _sell_screen.continue_pressed.connect(start_new_run) (main_game.gd:138).
# K2 inserts a wipe gate. The SellScreen flags _pending_wipe; expose it (or pass it on the signal — but
# continue_pressed is arity-0, so a getter is the lighter touch):
func _on_continue_pressed_loop() -> void:
    if _sell_screen.pending_wipe():          # the B.5 _pending_wipe flag
        GameState.wipe_meta()                # SEPARATE meta op — full roguelite reset (B.4)
    start_new_run()                          # fresh run: start_run re-seeds quota from base (B.3)
# Reconnect: _sell_screen.continue_pressed.connect(_on_continue_pressed_loop)
```

A wiped run is just a *normal* fresh run whose meta happens to be at defaults — `start_new_run()` needs no
special case. The next `start_run` sees `quota_target <= 0` and re-seeds it to `quota_base` (B.3), so the
player restarts at run 1 / $50.

### B.7 HUD quota readout (ui-ux, decision_hud.gd)

```gdscript
# decision_hud.gd — one more projected label, gated on quota_enabled (mirrors the R2/R3 gate at :280-289).
# Subscribe in _ready(): EventBus.quota_advanced.connect(_on_quota_advanced),
#                        EventBus.meta_wiped.connect(_on_meta_wiped),
#                        EventBus.run_started.connect(_refresh_quota)  # paint the bar at run start
func _refresh_quota(_a=null, _b=null) -> void:
    var cfg: RunConfig = GameState.active_run_config
    if cfg == null or not cfg.quota_enabled:
        _quota_label.visible = false
        return
    _quota_label.visible = true
    # "Run N · Quota: $achieved / $target" — achieved is the live cumulative money projection.
    _quota_label.text = tr("HUD_QUOTA").format({
        "run": GameState.run_number,
        "have": GameState.money,         # cumulative reading (matches B.2 recommended); or run_haul_value() per Q2
        "need": GameState.quota_target,
    })
```

The HUD reads cumulative `money` to match the recommended met-test (B.2). If Q2 resolves to
*banked-this-run-only*, the HUD's `have` becomes a live "banked-this-run" projection instead — the label
shape is unchanged.

### B.8 Save migration (v2 → v3) — SaveManager + GameState bridge

```gdscript
# save_manager.gd:15 — bump:
const META_SCHEMA_VERSION := 3

# save_manager.gd:75-90 — add the ordered case to the existing `match v:` loop:
        2:
            # v2 -> v3 (K2): quota_target + run_number added. Old saves predate the quota →
            # default to "uninitialised" so the first quota-enabled start_run re-seeds the bar
            # from quota_base (B.3), and run_number starts at 1.
            if not data.has("run_number"):
                data["run_number"] = 1
            if not data.has("quota_target"):
                data["quota_target"] = 0

# game_state.gd:411-438 — extend the meta bridge (the only two new keys):
func to_meta_dict() -> Dictionary:
    # ... existing money/salvage/.../banked_junk ...
    d["run_number"] = run_number
    d["quota_target"] = quota_target
    return d

func from_meta_dict(d: Dictionary) -> void:
    # ... existing reads ...
    run_number = d.get("run_number", 1)
    quota_target = d.get("quota_target", 0)
```

`quota_target = 0` on an old save is correct: a pre-K2 player who turns the quota on starts a fresh quota
ladder at $50 (B.3 lazy-init), without inheriting a phantom bar.

### B.9 QA fixture (qa-playtest-coordinator) — `meta_v2.sav` + migration-test case

Follow the template at `test_save_migration.gd:25-28`. A v2 fixture has all v1 fields **plus** `banked_junk`
(the field v2 added), at `schema_version = 2`, and **no** `run_number`/`quota_target`. Generate it with a
`gen_meta_v2_fixture.gd` mirroring `gen_meta_v1_fixture.gd`, commit the binary `tests/fixtures/meta_v2.sav`,
and add a case to `test_save_migration.gd`:

```gdscript
# test_save_migration.gd — new fixture + asserts (mirrors the v1 case):
const FIXTURE_V2_PATH := "res://tests/fixtures/meta_v2.sav"
# Frozen v2 values (must match gen_meta_v2_fixture.gd): money/salvage/lore/exposure/knowledge/recipes + banked_junk ids.
# After load_meta(slot) on the v2 fixture, assert:
#   1. schema_version == 3 (META_SCHEMA_VERSION).
#   2. migrated dict has run_number == 1 and quota_target == 0 (the v3 defaults).
#   3. GameState.run_number == 1, GameState.quota_target == 0 after from_meta_dict.
#   4. EVERY pre-existing v2 field (incl. banked_junk) survives intact.
#   5. Round-trip: save_meta re-serializes at v3 with a .bak preserved; reload restores the values.
```

The existing v1→v2 case stays green (the loop now runs v1→v2→v3 for the v1 fixture; assert it lands at v3
with both new defaults present). This satisfies the standing rule: bump + one migration step + a fixture.

### B.10 RunConfig wiring (K0 does it; K2 verifies)

- K0 adds the three `quota_*` `@export`s (A.7) and appends them to `to_flat_dict()` (after the LVL block at
  `run_config.gd:338`) so the CFG-marked telemetry snapshot carries them and the CFG-coverage assertion
  passes. K0 updates the knob counts in `tests/test_run_config.gd` / `tests/test_config_menu.gd`.
- K0 sets `c.quota_enabled = true` in `make_default_play_preset()` (`run_config.gd:428-500`) so the shipped
  fun stack has the quota on. Base 50 / step 50 inherit the code defaults — no extra preset lines needed.
- **Determinism:** the quota knobs never feed `fingerprint(seed+config)` — they touch no generation. The
  all-off control (`quota_enabled = false`) is byte-identical to M1.3 (no quota, no wipe, no signals, no HUD
  line). The neutral fp `e943ac9c8bc1` is unmoved.

---

## (c) Open Questions

> Each states the call + trade-offs. **Fun/scope calls are flagged "needs Director review" with a
> recommendation** (per the orchestrator loop step 7 + Phase-3 contract); the rest are
> technical/design calls Phase-3 fresh-eyes can resolve on merit.

### Q1 — *When* is the quota checked: every run end, or extract/sell only? **(needs Director review)**

- **Option A (recommended) — every run end.** Death/timeout with an unmet quota is a game over too. The
  Director's words: *"Every run there must be some amount met or it's a game over."* "Every run" reads as
  *all three outcomes*, and the seam (`sell_banked_junk` runs on all three, `sell_screen.gd:113-117`) makes
  this the natural fit. **Trade-off:** harsh — a death late in a thin run wipes you. But it makes death
  *matter* (today death is nearly consequence-free), which is exactly the stakes M1.4 wants.
- **Option B — extract/sell only.** Only a *successful* extraction is judged against the quota; death/timeout
  is "no progress, try again" (no wipe). Softer, more forgiving (GDD §10 Act-1 spirit). **Trade-off:** weakens
  the stakes — you can chip away death-free, and the only real failure is *not extracting enough*, not dying.
- **Recommendation: Option A**, because it is the literal reading of the work-order and the bigger stakes
  swing M1.4 is chasing — *but this is a fun/dial call the playtest should validate.* Both are one-line
  toggles in `_evaluate_quota` (gate on `reason == &"extract"` for B). Suggest shipping A and letting RG2's
  met-rate / wipe-rate distributions tell the Director if it's too punishing → dial to B in M1.5 if so.

### Q2 — "Met" by **cumulative money** or **this run's banked/sold value**? **(needs Director review)**

- **Option A (recommended) — cumulative `money` ≥ quota_target.** A run's surplus banks forward; a higher
  bar can be cleared by accumulated savings. Forgiving (GDD §10), and the quota reads as "your *total* must
  reach $N" — a savings target that rises. **Trade-off:** once you're comfortably ahead, the quota stops
  biting for several runs (the bar lags your balance).
- **Option B — this run's banked/sold value ≥ quota_target.** Every individual run must independently earn
  $target or wipe. Relentless, pure-roguelite pressure — exactly "every run there must be some amount met."
  **Trade-off:** brutal and swingy (one bad layout = wipe); and the bar+50/run means later runs demand a lot
  of fresh value *each* time with no carry-forward cushion. Likely too crushing for a greybox first cut.
- **Recommendation: Option A (cumulative).** It matches "give a reason why we keep getting money" (your
  *balance* is the thing at stake) and the Act-1-forgiving GDD note, and it's the gentler first cut to
  playtest. Mechanically identical wiring (B.2) — only `achieved`'s definition (`money` vs
  `run_haul_value()`-banked) and the HUD's `have` change. **Director picks the feel; the playtest confirms.**

### Q3 — Does a MET quota's escalation also persist on death/timeout, or only on a clean extract?

- This is downstream of Q1. If Q1=A (every run end), then a death where cumulative money already exceeds the
  bar *still advances the quota* (you survived the bar even though the run failed) — which may feel odd
  ("I died but the quota went up"). If Q1=B (extract only), advancement only ever happens on a clean extract,
  which is cleaner narratively.
- **Recommendation (technical):** tie escalation to the same trigger as the check (Q1). If Q1=A + Q2=A
  (cumulative), advancement-on-death is rare-but-coherent (your *savings* cleared the bar). Phase-3 can
  resolve this once Q1/Q2 are set; no separate Director call needed beyond Q1/Q2.

### Q4 — Quota persistence timing: eager-persist the seeded bar at start_run, or lazy at run end?

- B.3 lazy-inits `quota_target` at `start_run` but doesn't `save_meta` there (extract/fail will persist).
  **Risk:** a player who starts a quota run then *quits before any run-end* has `quota_target` un-persisted
  → on reload the bar re-seeds from `quota_base` again (harmless: same value). The only observable difference
  would be if `quota_base` changed between sessions (config edit) — an edge case in a greybox build.
- **Recommendation (technical, Phase-3 resolvable):** eager-`save_meta(0)` right after the lazy-init in B.3
  so the seeded bar is durable immediately. One extra atomic write per first-run-of-a-ladder — negligible.
  Leaning eager for robustness; no Director call.

### Q5 — Should the wipe clear `unlocked_recipes` / `banked_junk` / `exposure` too, or only currencies?

- Director FINAL is **"full roguelite wipe — reset meta-state to zero/defaults"** — which B.4 reads as
  *all* meta fields (`game_state.gd:27-36`), including `unlocked_recipes`, `banked_junk`, `exposure`,
  `knowledge_level`. In M1.4 greybox, `unlocked_recipes`/`knowledge_level` are unused (always empty/0), so
  this is currently *only* observable on `money` + any `banked_junk` not yet sold. **No ambiguity in M1.4** —
  flag it as *resolved by the FINAL disposition* (full reset), recorded here so a future milestone that
  populates recipes/knowledge doesn't silently re-scope the wipe without a Director re-confirm.
- **Recommendation:** wipe everything (B.4 as written). Note for M2+: when recipes/knowledge become real,
  re-surface "does the roguelite wipe really nuke *Knowledge* too?" — that's a meaningful stakes call then,
  trivial now.

### Q6 — Is there a confirm/"are you sure" before the wipe, or is it automatic on Continue?

- **(needs Director review — minor.)** A full wipe is destructive. Options: (a) automatic on Continue (the
  GameOver screen already *told* you it's a wipe — pressing Continue = "start over"); (b) a distinct
  "Start Over" button on the GameOver screen, separate from any "Quit". **Recommendation:** (a) automatic —
  it's a roguelite, the run already ended, and the GameOver title makes it unambiguous; a confirm dialog adds
  friction the genre doesn't want. ui-ux to make the GameOver copy explicit ("Meta wiped — starting over at
  Run 1 / $50"). Cheap to add a confirm later if testers fat-finger it.

### Q7 — Does the SellScreen still show the loot tally on a quota MISS, or jump straight to GameOver?

- **(needs Director review — minor, fun-texture.)** B.5 keeps the tally then overrides the title to "QUOTA
  MISSED" — the player sees *what they earned*, then that it wasn't enough, then the wipe on Continue. The
  alternative is a hard cut to a bare GameOver (no tally) for a starker "you failed" beat. **Recommendation:**
  keep the tally (B.5) — seeing the near-miss number ("$120 / needed $150") is more motivating than a blank
  fail screen, and it reuses the existing beat with one title swap. The GameOver *framing* (red title, "Run N
  ended — meta wiped") carries the stakes.

### Q8 — Telemetry: is `quota_evaluated` enough for RG2, or do we also need a per-run "quota_state" on the run_started row?

- **(technical, Phase-3 resolvable.)** `quota_evaluated(run_number, target, achieved, met)` (B.1) gives RG2
  the met-rate, wipe-rate, and achieved-vs-target distribution per config — the gate metrics. Stamping the
  *active* `quota_target`/`run_number` onto the existing `run_started` telemetry row (additive `data` field,
  like BUG6's inert-config stamp at `run_config.gd:360-362`) would let RG2 segment *in-progress* runs by
  quota pressure even without a clean end. **Recommendation:** ship `quota_evaluated` as the primary row;
  add the `run_started` `data` stamp if it's a one-liner in the Telemetry seam (it is — additive, no schema
  bump). Phase-3 / RG1 confirm.

---

## Summary of what K2 changes (for the build agent)

| File | Change | Owner |
|---|---|---|
| `data/run_config/run_config.gd` | (K0) add `quota_enabled/quota_base/quota_step` + to_flat_dict + preset `quota_enabled=true` | K0 |
| `systems/event_bus.gd` | (K0) pre-declare `quota_evaluated`, `quota_advanced`, `meta_wiped` | K0 |
| `systems/game_state.gd` | add `run_number`/`quota_target` meta + `_quota_active_this_run`/`_quota_step_snapshot` run-state; lazy-init + snapshot in `start_run`; `_evaluate_quota()` in `sell_banked_junk`; `last_quota_result()` getter; `wipe_meta()`; extend `to_meta_dict`/`from_meta_dict` | general-purpose |
| `systems/save_manager.gd` | bump `META_SCHEMA_VERSION` → 3; add the `2:` migration case | general-purpose |
| `ui/sell/sell_screen.gd` | render quota outcome + `pending_wipe()` flag + quota-fail title | ui-ux + general-purpose |
| `scenes/game/main_game.gd` | route `continue_pressed` through `wipe_meta()` on a miss | general-purpose |
| `ui/hud/decision_hud.gd` | quota readout line, gated on `quota_enabled` | ui-ux |
| `tests/fixtures/meta_v2.sav` + `gen_meta_v2_fixture.gd` | committed binary v2 fixture | qa |
| `tests/test_save_migration.gd` | v2→v3 migration case | qa |
| `ui/hud/hud_strings.csv`, `ui/sell/sell_strings.csv` | `HUD_QUOTA`, `SELL_QUOTA_MET/MISS`, `SELL_TITLE_QUOTA_FAIL` (tr keys) | ui-ux |

**Determinism:** all-off (`quota_enabled=false`) = M1.3 byte-for-byte; quota knobs never feed `fingerprint()`.
**Run/meta boundary:** quota target + run number are meta (persist, escalate, reset-on-wipe); the per-run
met-evaluation is run-state; the wipe is a pure meta op between runs.
**`run_ended` arity:** unchanged — quota-fail uses the existing path; the wipe is a separate meta op on Continue.

---

## Resolved Decisions (Phase 3)

> Fresh-eyes resolution (a different agent than the Phase-2 author). I read the real
> `game_state.gd`, `save_manager.gd`, `run_config.gd`, and the K0 contract to verify every proposed
> seam. The design is technically sound and the cited line numbers/APIs check out. I resolve the 8 Open
> Questions below, lock the technical ones on merit, and flag the two fun/stakes calls (Q1, Q2) plus the
> minor UX ones (Q6, Q7) for the Director with a clear recommendation each. I also caught **two
> implementation gaps the build agent must honor** (the eval-idempotency hole and the fail-path-credit
> ordering) — folded into the resolutions below.

### Q1 — Quota check timing: every run end vs extract-only. **NEEDS DIRECTOR REVIEW** (fun/stakes call)

**Recommendation: Option A — check on every run end (extract / death / timeout), but make it a config
knob so the Director can flip it without a code change.** K0 already pre-declares
`quota_check_timing` (`on_extract` / `on_any_run_end`) for exactly this — so this is *not* a
hard-coded policy; it is a swept knob. Ship the **preset** set to `on_any_run_end` (Option A), keep the
all-off/default at `on_extract` is wrong — the off-default is moot because `quota_enabled=false` gates
the whole feature, so set the **code default to `on_any_run_end`** and let the preset inherit it. The
playtest (RG2 wipe-rate distribution) then tells the Director whether to dial to `on_extract` in M1.5.

Rationale: (1) the work-order says *"Every run there must be some amount met or it's a game over"* —
"every run" is the literal reading. (2) Today death/timeout is nearly consequence-free (you keep
pockets, lose the rest, retry); gating it on the quota is the single biggest stakes lever M1.4 has. (3)
The seam is clean: `sell_banked_junk()` runs on **all three** outcomes (extract banks the full bag,
`fail_run` banks pockets, both flow to the SellScreen which calls `sell_banked_junk`), so `_evaluate_quota`
inside it naturally covers every end. For Option B, gate the eval on the run's `reason == &"extract"` —
one branch, already wired via the `_quota_active_this_run` snapshot which can also snapshot the end reason.

**Why a knob, not a hard choice:** this is a feel dial the playtest must validate, and we already paid
for the knob in K0. Hard-coding it would force a code change to re-tune. Director: confirm Option A ships
in the preset; the knob lets you change your mind from the CFG menu.

### Q2 — "Met" by cumulative money vs this-run's banked value. **NEEDS DIRECTOR REVIEW** (load-bearing fun call)

**Recommendation: Option A — cumulative `money` ≥ `quota_target`, shipped via the K0 `quota_basis`
knob (`cumulative_money`), so it too is swept not hard-coded.** Same logic as Q1: K0 pre-declares
`quota_basis` (`this_run_banked` / `cumulative_money`); set the code default + preset to `cumulative_money`.

Rationale: (1) The work-order's stated *intent* is *"a reason why we keep getting money"* — making your
**total balance** the thing at stake directly motivates accumulation; a this-run-only basis instead
motivates hitting a per-run threshold and makes surplus worthless. (2) GDD §10 "keep Act 1 forgiving" — a
cumulative basis lets a fat run buffer a thin one, which is the gentler first cut to playtest. (3)
Mechanically identical wiring; only `achieved`'s definition changes (`money` vs a banked-this-run sum) and
the HUD's `have` field.

**One correctness note the build agent MUST honor (Q2 interacts with the seam):** with
`quota_basis = cumulative_money`, `_evaluate_quota` reads `money` — which is only final **after**
`add_currency(&"money", total, source)` runs inside `sell_banked_junk` (`game_state.gd:289`). The
Phase-2 placement (append `_evaluate_quota` *after* `add_currency` + `save_meta`, before `return`) is
therefore **correct and required** — do not move the eval earlier. With `this_run_banked`, `achieved`
is the `total` local computed in `sell_banked_junk` (the sum just sold this call), captured before the
bank is cleared. The doc should expose `total` to `_evaluate_quota` (pass it as an arg) rather than
recompute, so both bases read from the same authoritative sum.

**Director note on the Q1×Q2 interaction (this is the real stakes texture):** the *spiciest* combo is
Q1=any-run-end × Q2=this-run-banked (every single dive, including a death, must independently clear a
rising bar or you wipe) — likely too crushing for a greybox first cut. The *gentlest* is Q1=extract-only ×
Q2=cumulative. **My recommendation (any-run-end × cumulative) is the middle**: death matters (a death that
leaves you below your *total* bar wipes you), but a healthy balance carries you. Recommend shipping the
middle and using RG2's wipe-rate to decide whether to harden (→ this_run_banked) or soften (→ extract-only).

### Q3 — Does a MET quota escalate on death/timeout, or only on a clean extract? **RESOLVED (technical).**

Tie escalation to the **same trigger as the check (Q1)** — they are one evaluation, not two. With the
recommended Q1=any-run-end × Q2=cumulative: if a death leaves cumulative `money ≥ target`, the bar
advances. This is **coherent, not odd** under the cumulative basis: the quota is a *savings* bar, and
your savings cleared it regardless of how the dive ended. The HUD/SellScreen copy should frame it as
"savings cleared the bar," not "you died but won" — a copy nuance for ui-ux, not a mechanic. No separate
Director call beyond Q1/Q2. **Lock:** escalation and check share `_evaluate_quota`; whatever Q1/Q2 resolve
to, escalation inherits it automatically (the pseudocode already does this).

### Q4 — Quota persistence timing: eager-persist at start_run, or lazy at run end? **RESOLVED (technical): eager.**

Eager-`save_meta(0)` immediately after the lazy-init seeds `quota_target` in `start_run` (B.3). Rationale:
(1) one extra atomic write per first-run-of-a-ladder is negligible (the same path `_make_run_inventory`
neighbours already exercise per run). (2) It makes the seeded bar durable the instant the ladder begins,
so a quit-before-any-run-end reloads at the correct bar even if `quota_base` was edited between sessions.
(3) It removes a latent inconsistency between in-memory and on-disk meta during the first run. **Lock:**
add `SaveManager.save_meta(0)` inside the `if quota_target <= 0:` block in B.3. **Caveat the build agent
must respect:** this is the *only* place `start_run` touches the save — guard it strictly behind
`_quota_active_this_run and quota_target <= 0` so a quota-off run never writes meta at start (preserving
the all-off control's zero-side-effects guarantee, and keeping `start_run` byte-neutral when the quota is off).

### Q5 — What does the wipe clear? **RESOLVED by Director-FINAL disposition (full reset) — confirmed exact field set.**

Director-FINAL is "full roguelite wipe — reset meta-state to zero/defaults." I verified the exact meta
field set against `game_state.gd:26-36` and `to_meta_dict()` (`:419-424`). `wipe_meta()` (B.4) must reset
**exactly these, and only these** (the meta block, nothing run-state):

| field | reset to | source line |
|---|---|---|
| `money` | `0` | `game_state.gd:27` |
| `salvage` | `0` | `:28` |
| `lore` | `0` | `:29` |
| `exposure` | `0` | `:30` |
| `knowledge_level` | `0` | `:31` |
| `unlocked_recipes` | empty `Array[StringName]` | `:32` |
| `banked_junk` | empty `Array[JunkItem]` | `:36` |
| `run_number` (K2) | `1` | new |
| `quota_target` (K2) | `0` (→ re-seed from `quota_base` next start_run) | new |

The B.4 pseudocode matches this exactly. **Two build-agent correctness notes:** (1) `wipe_meta` must use
**freshly-typed empty arrays** (`var empty: Array[StringName] = []` etc.) — assigning an untyped `[]` to a
typed field is a GDScript pitfall; B.4 does this correctly, keep it. (2) `wipe_meta` must NOT touch
`run_active`, `run_seed`, `run_inventory`, `active_run_config`, or `_run_ended` — it runs between runs
(after `end_run` cleared run-state), so there is no run-state to corrupt; the boundary note in B.4 is
correct. In M1.4 greybox `unlocked_recipes`/`knowledge_level` are always empty/0, so the only *observable*
wipe is `money` + any unsold `banked_junk`. **Flag forward (not a current call):** when M2+ populates
recipes/Knowledge, re-surface "does the roguelite wipe really nuke *Knowledge*?" — that becomes a real
stakes call then; trivial now. Recorded here so it isn't silently re-scoped.

### Q6 — Confirm dialog before the wipe? **NEEDS DIRECTOR REVIEW (minor UX).**

**Recommendation: automatic on Continue (Option a), no confirm dialog.** It's a roguelite; the run already
ended; the GameOver screen already told the player it's a wipe. A confirm dialog adds friction the genre
doesn't want, and there is no *accidental* path — pressing Continue after a "QUOTA MISSED — meta wiped"
screen is an explicit acknowledgement. ui-ux must make the GameOver copy unambiguous (e.g. "Meta wiped —
starting over at Run 1 / $50"). **Cheap to add a confirm later** if testers fat-finger it (one
`ConfirmationDialog` between `continue_pressed` and `wipe_meta`). Director: confirm "no confirm dialog for
the greybox cut." Minor — recommend deferring any confirm to a playtest finding.

### Q7 — SellScreen tally on a quota MISS, or hard-cut to GameOver? **NEEDS DIRECTOR REVIEW (minor, fun-texture).**

**Recommendation: keep the tally (B.5), override the title to "QUOTA MISSED."** Seeing the near-miss number
("$120 / needed $150") is more motivating and more legible than a blank fail screen, and it reuses the
existing reward beat with one title swap + one quota line — minimal build cost. The stakes are carried by
the *framing* (red title, "Run N ended — meta wiped"), not by hiding the tally. Director: confirm the
tally stays. Minor; recommend the recommended path unless the Director wants a starker fail beat.

### Q8 — Is `quota_evaluated` enough for RG2, or also stamp run_started? **RESOLVED (technical): both, if one-liner.**

`quota_evaluated(run_number, target, achieved, met)` is the **primary** gate row and is sufficient for the
core metrics RG2 needs (met-rate, wipe-rate, achieved-vs-target distribution per config). **Additionally**,
stamp the *active* `quota_target` + `run_number` onto the existing `run_started` telemetry `data` field
(additive, the BUG6 inert-config-stamp precedent at `run_config.gd:360-362`) so RG2 can segment
*in-progress / abandoned* runs by quota pressure even without a clean end. This is a one-line additive
stamp, no schema bump, no `run_ended` arity change. **Lock:** ship `quota_evaluated` as primary; add the
`run_started` `data` stamp (it is a one-liner). RG1 confirms the Telemetry seam accepts the extra `data` keys.

> **Signal-name reconciliation (K0 vs K2 — build-agent MUST resolve before dispatch):** K0's Phase-2 doc
> pre-declares the quota signals as `quota_changed(current, target, run_number)`, `quota_resolved(met,
> run_number, target)`, `meta_wiped(reason: StringName)`. K2's doc (B.1) names them `quota_evaluated(run_number,
> target, achieved, met)`, `quota_advanced(new_run_number, new_target)`, `meta_wiped(prev_run_number: int)`.
> **These diverge in both name and arity.** Per K0's OQ-8 ("each dependent Phase-2 design MUST cite the exact
> knob/signal names it reads; divergence is reconciled into the single-source doc before K0 the *code task* is
> dispatched"), **K0 is the single writer of `event_bus.gd` and its names win unless reconciled.** Recommended
> reconciliation (fold into K0 before it ships, since K2's names are richer for telemetry):
> - `quota_evaluated(run_number: int, target: int, achieved: int, met: bool)` — K2's name; carries `achieved`
>   which RG2 needs for the achieved-vs-target distribution (K0's `quota_resolved` drops it). **Adopt K2's.**
> - `quota_advanced(new_run_number: int, new_target: int)` — K2's; drives the HUD bump. K0 has no equivalent
>   (it folded advance into `quota_resolved`). **Adopt K2's.**
> - `meta_wiped(prev_run_number: int)` — **arity conflict**: K0 says `StringName reason`, K2 says
>   `int prev_run_number`. Recommend `meta_wiped(prev_run_number: int)` (K2's) — the only wipe cause in M1.4 is
>   a quota miss, so a `reason` is redundant; the prev run number is the useful telemetry. If a future wipe cause
>   appears, add a second param then. **Adopt K2's.**
> - K0's `quota_changed(current, target, run_number)` live-HUD signal: **not needed** — the HUD reads
>   `GameState.money`/`quota_target` directly on `run_started`/`quota_advanced`/`meta_wiped` (B.7), so a live
>   per-tick `quota_changed` is redundant. Recommend **dropping `quota_changed`** from K0's set (one fewer inert
>   signal). If a continuous HUD bar is wanted later, re-add it then.
>
> This reconciliation is a **technical merge**, resolvable on merit (richer telemetry + fewer redundant signals),
> not a Director call. K0's author must apply it in K0's single-writer window before the K2 build task is dispatched.

### Two implementation gaps I caught (build-agent MUST honor — not Open Questions, but load-bearing)

**Gap 1 — `_evaluate_quota` idempotency.** The Phase-2 design places `_evaluate_quota` inside
`sell_banked_junk()` and asserts "ONE evaluation per run because sell_banked_junk is called once per run
end." That is **true for the current SellScreen flow** but `sell_banked_junk` is **not** protected by the
`_run_ended` guard (`game_state.gd:271` — it has no idempotency check; an empty-bank call is a benign
no-op *for the sale* but `_evaluate_quota` would still fire and could **double-advance the quota** if the
function is ever called twice in a run, e.g. a retry path or a future caller). **Fix:** add a run-state
`_quota_evaluated_this_run: bool` flag (reset in `start_run` alongside the snapshot), and early-return
from `_evaluate_quota` (returning the cached `last_quota_result()`) if already set. This makes the eval
idempotent independent of how many times `sell_banked_junk` is called, matching the robustness of the
`_run_ended` guard. Cheap, and it future-proofs the seam.

**Gap 2 — quota-off `start_run` must stay byte-neutral.** Per Q4's lock, `start_run` now *can* call
`save_meta(0)` (eager seed). The build agent must guard it strictly behind
`_quota_active_this_run and quota_target <= 0` so a **quota-off run writes nothing at start** — preserving
the all-off control's "no meta side effects at run start" property and the byte-identical-to-M1.3
guarantee. Verified against `start_run` (`game_state.gd:86-106`): today it performs **no** `save_meta`,
so this guard keeps the off-path identical.

### Determinism / contract re-verification (all hold)

- `quota_enabled = false` default → no eval, no wipe, no save-at-start, no HUD line, no signal emits →
  M1.3 byte-identical. The quota knobs are post-generation / meta and **never feed `fingerprint()`**;
  the `e943ac9c8bc1` neutral fp is unmoved. ✓ (verified: no quota field touches band generation.)
- `run_ended` arity unchanged — quota-fail reuses the path with the existing `reason`; the wipe is a
  separate meta op on Continue. ✓ (`game_state.gd:235-244`, `end_run` untouched.)
- Save bump v2 → v3 with one ordered migration step + the `meta_v2.sav` fixture is the standing rule,
  correctly applied (B.8/B.9). The migration shape matches the existing `match v:` loop
  (`save_manager.gd:75-90`); the `2:` case defaulting `run_number=1`/`quota_target=0` is correct. ✓
- Run/meta boundary: `run_number` + `quota_target` are meta (persist via `to_meta_dict`/`from_meta_dict`,
  escalate on met, reset on wipe); the per-run "met?" + `_quota_*_this_run` snapshots are run-state
  (reset each `start_run`, never persisted). ✓ (verified against the `game_state.gd:26-70` field split.)

### Summary of Phase-3 dispositions

| OQ | Disposition | Resolution |
|---|---|---|
| Q1 (check timing) | **Director review** | Rec: any-run-end, shipped via the `quota_check_timing` knob (swept, not hard-coded). |
| Q2 (met basis) | **Director review** | Rec: cumulative money, via the `quota_basis` knob. Eval reads `money` after `add_currency` (placement is required, not optional). |
| Q3 (escalate on death) | Resolved | Shares `_evaluate_quota` with the check; inherits Q1/Q2. Coherent under cumulative. |
| Q4 (persist timing) | Resolved | Eager `save_meta(0)` at first-of-ladder, guarded `_quota_active_this_run and quota_target<=0`. |
| Q5 (wipe scope) | Resolved (Director-FINAL) | Full reset, exact 9-field table above; M2+ Knowledge-wipe flagged forward. |
| Q6 (confirm dialog) | **Director review** | Rec: no confirm (automatic on Continue); cheap to add later. |
| Q7 (tally on miss) | **Director review** | Rec: keep tally, override title to "QUOTA MISSED." |
| Q8 (telemetry) | Resolved | `quota_evaluated` primary + one-line `run_started` data stamp. |
| (extra) signal reconciliation | Resolved (technical) | Adopt K2's signal names/arities; drop K0's redundant `quota_changed`; fold into K0 before dispatch. |
| (extra) Gap 1 eval idempotency | Resolved | Add `_quota_evaluated_this_run` guard; eval idempotent regardless of caller count. |
| (extra) Gap 2 quota-off neutrality | Resolved | Guard the eager save behind the active+uninitialised condition. |

**Four items for the Director's Phase-3 review (the rest are locked on technical merit):** Q1, Q2, Q6, Q7.
Q1 and Q2 define how the stakes *feel* and are the load-bearing fun calls; Q6 and Q7 are minor UX texture.
The recommendation for all four is: ship the recommended option (any-run-end × cumulative; no confirm; keep
the tally), make the two stakes calls swept knobs so RG2's wipe-rate can re-tune them in M1.5 without a code
change.
