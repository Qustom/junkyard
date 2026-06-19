# J1 — Default play-preset + size-slider re-range (M1.3 spec)

**Milestone:** M1.3 — Legibility & Density · **Workstream:** Wave 1 — Foundation & correctness
**Task id:** J1 · **dependsOn:** none (the FIRST M1.3 task — every other density/spread task tunes against the new default scale, exactly as I1 was the foundation for M1.2)
**Assignees (build wave):** `general-purpose` (RunConfig factory/preset + CFG re-range + boot-load wiring + tests) · `game-director-designer` (this spec + the preset's exact knob values)
**Status:** Phase-2 design spec (this doc). Phase-3 fresh-eyes pass resolves §3 Open Questions before build.
**Companion docs:** `M1.3_Breakdown.md` §J1/§2/§5/§6 · `G4_findings_M1.2.md` §5 (the Director's F1 decisions — the source of this task) · `I1_level_scale.md` (the `lvl_` knobs + the 0.25-snap + the integer-px constraint J1 re-ranges) · `M1_As_Built.md` (run-launch + CFG seam) · `data/run_config/run_config.gd` · `ui/config/config_menu.gd` · `scenes/game/main_game.gd` `start_new_run()`

> **Scope guardrail (Breakdown §2):** J1 is **greybox + configurable-not-balanced**. It does TWO things: (1) introduce a **named default play-preset** the game/CFG boots into (the most-fun M1.2 stack), and (2) **re-range** the existing `lvl_size_mult` slider to `[4.0, 40.0]`. The **load-bearing M1.3 contract** is that the **code-level all-off `RunConfig` default is unchanged** — it stays the permanent baseline control (determinism fp=`e943ac9c8bc1`, telemetry comparability with M1.0/M1.1/M1.2). The preset is a *separate artifact*, the slider re-range is a *display range only*. J1 ships no new gameplay, no new opposition, no schema field beyond (possibly) a preset resource.

---

## 1. Goal & premise research

**The one sentence:** *Boot the game into the configuration the Director found most fun (level scale on, R1 hazard + R4 vision/maze on, R2/R3 off, big rooms) and let the room-size slider reach the sizes the Director actually liked — without ever disturbing the all-off control that anchors every cross-version comparison.*

### Why this task (the F1 finding)

`G4_findings_M1.2.md` §5 records the Director's M1.2 re-gate verdict (ITERATE → M1.3) and the F1 decision verbatim:

> **F1 — defaults.** Ship a **default play-preset** … keep the code-level all-off `RunConfig` default as the permanent telemetry+determinism control; the *game/CFG boots into* a separate named default preset. The preset = the most-fun stack **but with R2 and R3 OFF by default** (R1 hazard + R4 vision/maze ON, level scale ON ~19–25 rooms). *"Everything else is fine."*
>
> **F1 — bigger size slider.** … **`lvl_size_mult` ≥ 4.0 is the new floor** (4.0 = smallest), **max ≈ 40.0** (the Director found 40.0 good). Re-range the CFG slider (`RANGE_MULT`); the all-off control still uses `lvl_enabled=false` (size inert) so the determinism baseline (fp=e943ac9c8bc1) is untouched.

The §1/§3 evidence behind the preset choice (`G4_findings_M1.2.md` §1 sweep table, §3 I1):

- **The most-fun configs were level-scale-ON, R1+R4 stacks.** The two highest-engagement non-timeout cells were `lvl on / size 4.0 / rc 25 / R1,R4` (7 runs, median 32.8 s, depth 5/9, a real 4 death / 2 extract / 1 timeout spread) and `lvl on / size 4.0 / rc 19 / R1,R4` (6 runs, median 18.8 s, 3 extract / 3 death). These are the cells the Director is promoting.
- **R2/R3 stay OFF in the preset by Director call**, even though they fired (R2) or were config-trapped (R3). F1 is explicit: "R2 and R3 OFF by default." This is a *fun/tone* decision, already made — J1 just encodes it.
- **The size slider tops out too low.** `RANGE_MULT = Vector2(0.5, 4)` (`config_menu.gd:41`) caps the scrub slider at 4.0 — exactly the value the Director now wants as the *floor*. Every M1.2 size-4× run was scrubbing the slider's maximum. The Director went past it (typing into the SpinBox, which `allow_greater = true` permits) and found 40.0 good, so the slider must reach there natively.

### The load-bearing contract (why this is delicate)

The M1.1/M1.2 experiment design rests on **one permanent control**: a run with `all_oppositions_disabled()` true AND the `lvl_` group inert reproduces the M1.0 loop *byte-for-byte* (`fingerprint()` = `e943ac9c8bc1`) and *metric-for-metric* (the RG2 analyses segment cohorts partly by "is this the baseline?"). Three live test obligations enforce it today:

- `tests/test_level_scale_determinism.gd:59` — `var all_off := RunConfig.new()` and asserts `lvl_enabled == false`, `lvl_room_count == -1`, `lvl_size_mult == 1.0`. **A factory that mutated `RunConfig.new()` or the `.tres` would break this immediately.**
- `tests/test_rg1_m12_verify.gd:46` — `const BASELINE_FP := "e943ac9c8bc1"`; asserts the all-off band still byte-matches.
- `tests/test_run_config.gd:105` / `tests/test_config_menu.gd:42` — knob counts (36 knobs) + `has_full_coverage()`; a new preset must not change the *schema* (no new `@export` knob) or these counts shift.

So J1's first principle: **the preset is additive and downstream of the all-off default — it must never *be* the default.** The all-off `RunConfig.new()` / `run_config.tres` stays byte-identical; the preset is a *second, named* config the boot path and CFG choose to start from.

### What exists in-repo (real files / APIs)

**The all-off default `.tres`.** `data/run_config/run_config.tres` carries *no* `[resource]` overrides — every field sits at its script default (`run_config.gd`), so the `.tres` and `RunConfig.new()` are identical and both all-off. `ConfigMenu.DEFAULT_CFG_PATH` (`config_menu.gd:28`) points at it; `_load_default()` (`config_menu.gd:141`) `duplicate(true)`s it into the working config. **This file is the control — J1 does not touch it.**

**How a run launches today (the boot/start path).** `scenes/game/main_game.gd` `start_new_run()` (line 166) is the single run-entry seam:

```gdscript
# main_game.gd:178 — the menu produces the run's config; fall back to the all-off .tres.
var run_cfg: RunConfig = _config_menu.apply_and_get_config() if _config_menu != null else (load(RUN_CONFIG_PATH) as RunConfig)
```

`_config_menu` is `%ConfigMenu` (line 68). So **the config the run uses is whatever the CFG working config holds at Start.** And the CFG working config is seeded in `ConfigMenu._ready()`:

```gdscript
# config_menu.gd:130
func _ready() -> void:
    _cfg = _load_default()    # <-- duplicates the all-off .tres -> the menu opens all-off TODAY
    _build_ui()
    _assert_full_coverage()
    _refresh_all()
```

**This is the single line that decides "what the game boots into."** Today it boots all-off. J1's preset hooks in *here* (and in the equivalent fallback at `main_game.gd:178` when there is no CFG rail). There is **no separate "main menu vs run" autostart** — the CFG rail sits beside the Start button, and the run inherits the rail's current config; "boots into" therefore means "the CFG rail opens pre-filled with the preset."

**The size knob + its CFG range/step.** `lvl_size_mult` (`run_config.gd:155`, default `1.0`) projects to px/cell via `effective_cell_size_px(base)` = `round(16 * mult)` when `lvl_enabled`, else `base` (line 171). CFG ranges it with:

```gdscript
# config_menu.gd:41
const RANGE_MULT := Vector2(0.5, 4)   # the slider span J1 re-ranges to [4.0, 40.0]
# config_menu.gd:113
const FIELD_STEP := { "lvl_size_mult": 0.25 }   # 0.25 snap -> integer px/cell at 16-base
```

`_build_numeric` (line 380) builds an HSlider clamped to `RANGE_MULT` PLUS a SpinBox with `allow_greater = true` and `max_value = max(rng.y*100, 100000)` (line 407) — so **typing past the slider already works** (that's how the Director reached 40.0). J1 only re-ranges the *slider scrub convenience*; the SpinBox already accepts any value.

**The integer-px constraint (inherited from I1 Resolved F).** `lvl_size_mult` is 0.25-snapped so `round(16 * mult)` is always an exact integer px/cell, and the *same* effective cell size feeds materialise AND `JunkPlacer.plan(…, cell_size_px)` (`main_game.gd:204–217`) — no doorway seam, no loot mis-placement. At the new floor `4.0` → `16*4 = 64 px/cell`; at the max `40.0` → `16*40 = 640 px/cell`. (640 px/cell is a large but exact integer — see Open Q C for the rendering/camera question, which is the one genuinely new concern J1 introduces.)

**CFG coverage + Reset.** `has_full_coverage()` (line 159) cross-checks the bound manifest against the schema by reflection — it asserts *which knobs exist*, not their *values*, so a preset that only changes values does not affect coverage. **Reset** (`_on_reset_pressed`, line 548) reloads `_load_default()` — currently "reset to baseline (all off)" (the CSV string `CFG_RESET` = `"Reset to baseline (all off)"`, `config_strings.csv:4`). J1 must preserve a path to the all-off control *and* decide how "reset to the fun preset" coexists with it (Open Q E).

**Tests that pin the contract** (J1 must keep green / extend): `test_level_scale_determinism.gd` (all-off invariants + `lvl_size_mult` layout-invariance across mults — note it sweeps mults including values J1's new range covers), `test_rg1_m12_verify.gd` (BASELINE_FP), `test_config_menu.gd` (coverage + 36-knob count), `test_run_config.gd` (to_flat_dict completeness).

---

## 2. Design / approach + pseudocode

J1 has two clean, independent pieces and one contract guard.

### Piece A — the named default play-preset

**What the preset must encode (Director-locked, F1):**

| group | knob | preset value | rationale |
|---|---|---|---|
| LVL | `lvl_enabled` | `true` | level scale ON |
| LVL | `lvl_room_count` | `19` *(recommend; see OQ B)* | "~19–25 rooms"; 19 was the more-tested, shorter-run cell |
| LVL | `lvl_size_mult` | `4.0` | the new slider *floor*; the most-fun cell's size |
| R1 | `r1_enabled` | `true` | the pursuing hazard ON (the visceral cost) |
| R1 | `r1_*` magnitudes | the M1.2 most-fun cell's values | depth_threshold / chase_speed / catch_radius / catch_kills etc. — copy a known-good R1-on row (OQ D: which exact row) |
| R4 | `r4_enabled` | `true` | vision/maze ON |
| R4 | `r4_*` magnitudes | a NON-inert set (branch chance + a real `r4_lost_proxy_threshold` + vision radius) | F1's whole point is that the preset *exercises* R4; M1.2 ran it config-trapped (lost-proxy=0). The preset must ship sane R4 values so the re-gate actually sees it (pairs with BUG6's config-trap guard) |
| R2 | `r2_enabled` | `false` | Director: "R2 … OFF by default" |
| R3 | `r3_enabled` | `false` | Director: "R3 OFF by default" |
| Meta | `seed_override` | `-1` | auto seed (unchanged) |

> R1/R4 magnitudes are *configurable-not-balanced* — J1 should copy a concrete, known-good M1.2 R1+R4 row so the preset is a real playable stack rather than "enabled with zero magnitudes" (which would re-create the M1.2 config-trap). The exact source row is OQ D.

**Representation — RECOMMENDED: a factory method on `RunConfig`, plus a thin preset `.tres` that the boot path loads (belt-and-suspenders, see OQ A).** The recommendation is the **factory method** as the single source of truth, with the boot path calling it:

```gdscript
# run_config.gd — NEW static factory (illustrative; programmer writes typed GDScript).
# The all-off RunConfig.new() / run_config.tres are UNTOUCHED — this is a SECOND,
# named config built ON TOP of a fresh all-off instance, so the control is never the
# default and the determinism/telemetry baseline (fp=e943ac9c8bc1) is byte-identical.
static func make_default_play_preset() -> RunConfig:
    var c := RunConfig.new()          # starts from the all-off control
    # Level scale ON, ~19 rooms, big rooms (the new slider floor).
    c.lvl_enabled = true
    c.lvl_room_count = 19
    c.lvl_size_mult = 4.0
    # R1 pursuing hazard ON — copy a known-good M1.2 R1+R4 cell (OQ D).
    c.r1_enabled = true
    c.r1_depth_threshold = 0
    c.r1_chase_speed = 60.0           # placeholder: the most-fun row's value
    c.r1_catch_radius = 32.0
    c.r1_catch_kills = true
    c.r1_spawn_count = 1
    # R4 vision/maze ON, with NON-inert lost-proxy so the re-gate actually exercises it.
    c.r4_enabled = true
    c.r4_branch_chance_base = 0.25
    c.r4_max_branch_depth = 8
    c.r4_lost_proxy_threshold = 0.5   # NOT 0.0 — avoid the M1.2 config-trap (BUG6 pairs here)
    # R2 / R3 deliberately OFF (Director F1).
    # r2_enabled / r3_enabled stay false (all-off defaults).
    return c
```

**Boot/load — the one line that "boots into" the preset.** Change *only* where the CFG working config is seeded; leave `_load_default()` (the all-off duplicate) intact so Reset still reaches the control:

```gdscript
# config_menu.gd:130 — the menu opens PRE-FILLED with the fun preset instead of all-off.
func _ready() -> void:
    _cfg = _make_boot_config()        # was: _load_default()  (all-off)
    _build_ui()
    _assert_full_coverage()
    _refresh_all()

## The config the CFG rail opens into = the default play-preset (F1). Reset (below)
## still reaches the all-off control via _load_default(), so the permanent baseline
## stays one click away.
func _make_boot_config() -> RunConfig:
    return RunConfig.make_default_play_preset()

# _load_default() is UNCHANGED — it still duplicates the all-off .tres (the control).
```

And the no-CFG fallback in `main_game.gd:178` should match the boot intent so a headless/CFG-less launch also plays the preset (NOT the all-off default), while tests that construct `RunConfig.new()` directly still get the control:

```gdscript
# main_game.gd:178 — fall back to the PRESET (not the all-off .tres) when no CFG rail,
# so "what the game boots into" is consistent with the CFG path. Tests that want the
# control construct RunConfig.new()/load(run_config.tres) explicitly and are unaffected.
var run_cfg: RunConfig = _config_menu.apply_and_get_config() if _config_menu != null \
    else RunConfig.make_default_play_preset()
```

> Why factory-over-`.tres` as the primary: a `.tres` preset would be a second on-disk resource that can drift from the schema and needs its own load-path + null-guard; a static factory is one typed source of truth, trivially unit-testable (`assert make_default_play_preset().r1_enabled`), and physically *cannot* be confused with the all-off `.tres`. The `.tres` option is kept open in OQ A for the Director who prefers data-over-code, but it is strictly more surface for the same result.

### Piece B — re-range the size slider to `[4.0, 40.0]`

A one-constant change plus a step reconsideration:

```gdscript
# config_menu.gd:41 — was Vector2(0.5, 4); F1 re-range.
const RANGE_MULT := Vector2(4.0, 40.0)   # slider FLOOR 4.0 (Director's new minimum), max 40.0
```

- The slider handle now scrubs `[4.0, 40.0]`; the SpinBox (`allow_greater`, `min_value = rng.x = 4.0`) still types exact values **within and above** the range — but note its `min_value` now becomes `4.0` (was `0.5`), so the SpinBox can no longer type a sub-4.0 mult. **That is the intended effect** (4.0 is the floor), and it does NOT affect the all-off control because the control uses `lvl_enabled = false` → `effective_cell_size_px` ignores `lvl_size_mult` entirely (returns `base` = 16). The control's `lvl_size_mult` stays `1.0` in the schema; the slider floor only constrains what a *player-facing* edit can dial.
- **Step:** `FIELD_STEP["lvl_size_mult"] = 0.25` (line 114) still yields integer px/cell at 16-base (4-px increments). Across `[4.0, 40.0]` that is **145 slider stops** — fine functionally, but a coarser step (e.g. `0.5` → 8-px increments, still integer px/cell, 73 stops) scrubs faster across the now-10×-wider range. Step choice is OQ F (keep 0.25 for fine control vs. 0.5 for scrub speed). Either way the integer-px invariant from I1 Resolved F holds (`round(16*mult)` exact for any 0.25 or 0.5 multiple).
- **Coverage/`to_flat_dict` unaffected:** re-ranging a slider changes neither the schema nor the manifest; `has_full_coverage()` and `to_flat_dict()` are value-blind. No test counts change.

### Piece C — keep the all-off control reachable (the contract guard)

- **`_load_default()` stays all-off** → **Reset still produces the control.** The CSV `CFG_RESET = "Reset to baseline (all off)"` already names it correctly; J1 keeps Reset wired to `_load_default()`. (If the Director wants Reset to instead return to the *fun preset*, that is OQ E — recommend a second button, not repurposing Reset.)
- **`run_config.tres` / `RunConfig.new()` are byte-identical** → `test_level_scale_determinism.gd:59`, `test_rg1_m12_verify.gd` BASELINE_FP, and the to_flat_dict/coverage counts all stay green with no edits.
- **New test obligations (J1 adds):**
  1. `make_default_play_preset()` returns the F1 stack: `lvl_enabled && r1_enabled && r4_enabled && !r2_enabled && !r3_enabled`, `lvl_size_mult == 4.0`, `lvl_room_count == 19`, and R4 lost-proxy `!= 0.0` (the config-trap guard, pairs with BUG6).
  2. `RunConfig.new()` is STILL all-off after the factory exists (`all_oppositions_disabled()` true, `lvl_enabled` false) — proves the factory didn't leak into the default.
  3. `RANGE_MULT.x == 4.0 && RANGE_MULT.y == 40.0`; and a determinism assertion that an all-off run's `effective_cell_size_px(16) == 16` regardless of the slider floor (size is inert when `lvl_enabled` false).

### Files to create / touch (build wave — single-writer: J1 owns `run_config.gd` + `config_menu.gd` + CFG this wave, per Breakdown §5)

**Touch:**
- `data/run_config/run_config.gd` — add `static func make_default_play_preset() -> RunConfig`. (No change to any `@export` default — the all-off control is untouched.) *(general-purpose)*
- `ui/config/config_menu.gd` — `_ready()` seeds `_cfg` from the preset via `_make_boot_config()`; `RANGE_MULT` → `Vector2(4.0, 40.0)`; (optional) `FIELD_STEP` step tweak. `_load_default()` + Reset UNCHANGED. *(general-purpose)*
- `scenes/game/main_game.gd:178` — no-CFG fallback uses `make_default_play_preset()` (so boot intent is consistent), guarded so tests' explicit `RunConfig.new()` stays the control. *(general-purpose; watch the Wave-2 `main_game.gd` collision with J2/J4 — J1 lands first on `main`.)*
- `tests/test_run_config.gd` (or a new `tests/test_default_preset.gd`) — the three new obligations above. *(general-purpose)*

**Possibly create (only if OQ A → `.tres` representation):**
- `data/run_config/default_play_preset.tres` — a `RunConfig` `.tres` with the preset overrides, + a `PRESET_CFG_PATH` const the boot path loads. *(general-purpose)*

**Confirm NOT touched:**
- `data/run_config/run_config.tres` — the all-off control (byte-identical; fp guard).
- `systems/bandgen/band.gd` `fingerprint()` — unchanged.
- `systems/event_bus.gd` — no new signal (J1 is config-only).
- The schema's `@export` set / knob count — unchanged (factory adds a method, not a field), so `has_full_coverage()` and the 36-knob test stay green.

### Acceptance criteria (from Breakdown §J1, made concrete)

1. **Boots into the preset.** Launching the game opens the CFG rail pre-filled with the F1 stack (LVL on ~19 rooms / size 4.0, R1 on, R4 on with non-inert lost-proxy, R2/R3 off); pressing Start with no edits runs exactly that.
2. **Slider reaches the Director's range.** The `lvl_size_mult` slider scrubs `[4.0, 40.0]`; 40.0 is reachable on the handle (not just by typing). Size 40.0 = 640 px/cell materialises and is playable (OQ C verifies camera/rendering).
3. **All-off control intact.** `RunConfig.new()` / `run_config.tres` are all-off and byte-identical; `BASELINE_FP = e943ac9c8bc1` still matches; Reset ("Reset to baseline (all off)") still produces the control from the CFG rail.
4. **No schema/telemetry drift.** `has_full_coverage()` passes; the 36-knob count is unchanged; `to_flat_dict()` carries the preset's values (so RG2 sees the preset cohort) with no new keys.
5. **Config-trap-free preset.** The preset's R4 ships a non-zero `r4_lost_proxy_threshold` (and R1 real magnitudes) so the re-gate actually exercises both — no silently-inert enabled opposition (pairs with BUG6's guard).

---

## 3. Open Questions (Phase-3 fresh-eyes resolves; Director-review items flagged)

**A. Preset representation — static factory vs. `.tres` resource vs. a named-CFG constant?** *(engineering / data-vs-code call)*
Three shapes: (i) a `static func make_default_play_preset()` on `RunConfig` (one typed source, unit-testable, can't be confused with the all-off `.tres`); (ii) a second `default_play_preset.tres` the boot path loads (data-authorable by the Director without code, but a new file that can drift from the schema + needs a null-guard); (iii) inline the values in `config_menu._ready()` (smallest diff, but hides the preset from `main_game`'s fallback + from tests). **Recommendation: (i) the factory** — it is the single source of truth, trivially testable, and physically separate from the control. Offer (ii) as a follow-up if the Director wants to retune the preset from the editor without a code change. *Engineering recommendation is clear; flag only because "do we want a data-editable preset" is a mild Director preference.*

**B. Preset `lvl_room_count` — 19, 25, or expose the "~19–25" as a small spread?** *(Director / fun call — NEEDS DIRECTOR REVIEW)*
F1 says "~19–25 rooms." The two most-fun cells were rc 19 (median 18.8 s) and rc 25 (median 32.8 s, the richer death/extract/timeout spread). A single preset must pick one. **Recommendation: `19`** — the shorter, more-tested cell keeps the boot run snappy and J3 (per-room density) + J2 (enemy spread) will *fill* rooms so 19 big rooms won't read as empty; bump to 25 if density makes 19 feel thin. *Genuine fun/feel call — the Director picks the single boot value (or says "I want 25"). Recommend resolving at the J1 build or the first M1.3 sweep.*

**C. Is 640 px/cell at `lvl_size_mult = 40.0` a rendering / camera / generation problem?** *(build-time verification + possible Director scope call — NEEDS DIRECTOR REVIEW if it forces a lower max)*
At mult 40, px/cell = `16*40 = 640`; an 8×4-cell room = `5120 × 2560 px`, and a 19-room spine spans a *huge* world. Concerns: (1) the run uses a plain `$Player/Camera2D` (I1 Resolved D) — at 640 px/cell the player sees a tiny fraction of one room, which may be desirable (R4 fog/disorientation) or may read as "lost in a void"; (2) `JunkPlacer`/materialise integer math is fine (640 is exact), but does the generator's frontier/placement or the SocketSealer have any px-space assumption that strains at 5120-px pieces? (I1 says no — pure cell space — but verify at mult 40, not just mult 2/3 which is all `test_rg1_m12_verify.gd` exercised); (3) does player traversal time at mult 40 (≈10× a mult-4 room) blow past the M1 ~15-min experiment tier on a single dive? **Recommendation: ship max 40.0 as the Director asked, but the build worklog must record a manual smoke at mult 40 (camera reads OK, band materialises, no seam, run completes) — and if mult 40 is unplayable, surface a recommendation to cap lower (e.g. 24–32) rather than silently clamping.** *The number is the Director's (they "found 40.0 good"); the verification is the builder's; a forced lower cap would be a Director call.*

**D. Which exact M1.2 R1 (and R4) magnitudes does the preset copy?** *(tuning — sweep-grounded, mild Director input)*
The preset must encode *real* R1/R4 magnitudes (chase speed, catch radius, catch_kills, spawn_count; branch chance, vision, lost-proxy), not just `enabled = true`, or it re-creates the M1.2 zero-magnitude config-trap. The source should be a concrete known-good M1.2 row. **Recommendation: lift the R1+R4 magnitudes from the most-fun `lvl on / size 4.0 / rc 25 / R1,R4` cell's actual `run_config` snapshot in `playtest_data/M1.2/run_log_2026-06-19.jsonl`** (the literal values the Director played), with R4's `r4_lost_proxy_threshold` forced non-zero (M1.2 ran it at 0.0). The Phase-3 resolver / builder should read those exact values out of the log rather than guess. *Mostly mechanical (copy what was played); the only judgment is the lost-proxy value, which BUG6's guard also touches.*

**E. How does "reset to baseline (all-off)" coexist with "reset to the fun preset"?** *(UX / Director preference)*
Today Reset → all-off control, and the CSV string says so. After J1, the *boot* state is the preset, but Reset still goes all-off — so a Director who edits the preset and hits Reset lands on the control, not back on the preset. Options: (i) keep Reset = all-off control (one button), boot = preset — the control is always one click away (best for the experiment workflow); (ii) two buttons: "Reset to play-preset" + "Reset to baseline (all off)"; (iii) Reset → preset, and a smaller "load all-off control" affordance. **Recommendation: (ii) two explicit buttons** — the control must stay trivially reachable for determinism/telemetry work (the contract), and the Director also wants a fast "give me the fun defaults back." Keep the existing `CFG_RESET` string for the all-off button; add `CFG_RESET_PRESET`. *Small UX call; recommend (ii). If single-button is preferred, keep (i) so the control is never more than one click away.*

**F. `lvl_size_mult` step across the wider range — keep 0.25, or coarsen to 0.5?** *(UX — settled-able on merit)*
0.25 over `[4.0, 40.0]` = 145 stops (fine control, slow scrub); 0.5 = 73 stops (faster scrub, still integer px/cell at 16-base: 8-px increments). **Recommendation: keep `0.25`** — the SpinBox already gives exact entry, the slider's job is scrub, and 0.25 preserves the I1 integer-px invariant exactly; coarsening is a marginal convenience not worth diverging from I1. *No Director call needed; resolvable on merit.*

**G. Does the no-CFG fallback (`main_game.gd:178`) booting the preset break any headless test that relied on the all-off fallback?** *(build-time verification)*
Changing `main_game.gd:178`'s fallback from `load(run_config.tres)` (all-off) to `make_default_play_preset()` means a headless launch *without* a CFG rail now runs the preset. Some loop tests (`test_main_game_loop.gd`, `test_rg1_loop_verify.gd`, `test_duration_loop_reentry.gd`) drive `start_new_run()`; if any asserts baseline behaviour via this fallback, the change would flip them. **Recommendation: audit those tests at build; if any depends on the all-off fallback, have it stage an explicit `RunConfig.new()` via `GameState.stage_run_config` / a CFG stub rather than relying on the implicit fallback** — the explicit control path is what the determinism tests already do. *Pure build-time verification; the fix is "tests state their config explicitly," which is the healthier pattern anyway.*

---

## Resolved Decisions (Phase 3 — fresh-eyes, 2026-06-19)

Independent reviewer pass by a programmer-lens reviewer who did **not** author §1–§3. Verified every cited file/line/API against the real source (`data/run_config/run_config.gd`, `ui/config/config_menu.gd`, `scenes/game/main_game.gd`, `systems/game_state.gd`, `tests/test_level_scale_determinism.gd`, `tests/test_rg1_m12_verify.gd`, `tests/test_config_menu.gd`, `tests/test_run_config.gd`, `design/M1_2_Tasks/G4_findings_M1.2.md`, `design/M1_3_Tasks/BUG6_*.md`). **The doc's claims all hold up** — no build-breaking blind spots found. J1 is genuinely a two-line-and-a-factory change with a clean contract guard; the only real risks are the Director-judgment calls (B/C/D), which the author already flagged correctly.

### Verification corrections to the body (read before building)

All line/API citations were checked and are **accurate** as written. Specifically confirmed:

- ✅ **`config_menu.gd` citations exact:** `RANGE_MULT := Vector2(0.5, 4)` at **line 41**; `FIELD_STEP = {"lvl_size_mult": 0.25}` at **line 113**; `_ready()` → `_cfg = _load_default()` at **line 130–131**; `_load_default()` at **line 141** (`load(DEFAULT_CFG_PATH).duplicate(true)`, fresh `RunConfig.new()` fallback); `has_full_coverage()` at **line 159**; `_on_reset_pressed()` at **line 548** (`_cfg = _load_default(); _refresh_all()`); `_build_numeric` at **line 380**; the SpinBox `max_value = max(rng.y * 100.0, 100000.0)` + `allow_greater = true` at **lines 407–408**. The CSV `CFG_RESET` string is consumed at line 249 (`reset.text = tr("CFG_RESET")`).
- ✅ **`run_config.gd` citations exact:** `lvl_size_mult` default `1.0` at **line 155**; `effective_cell_size_px(base)` = `int(round(base * mult))` when `lvl_enabled` else `base` at **lines 171–174**; `all_oppositions_disabled()` is `not (r1_enabled or … or r4_enabled)` (lvl excluded) at **lines 163–164**; `to_flat_dict()` (lines 189–233) carries all knobs incl. the 3 `lvl_` keys.
- ✅ **Test citations exact:** `tests/test_level_scale_determinism.gd` line **59** is `var all_off := RunConfig.new()`, asserting `lvl_enabled==false / lvl_room_count==-1 / lvl_size_mult==1.0` at lines 60–62 — and it also generates with the all-off cfg vs the no-rc baseline and byte-matches `fingerprint()` (so a factory that mutated `RunConfig.new()`/the `.tres` fails here immediately, as the doc claims). `tests/test_rg1_m12_verify.gd` line **46** is `const BASELINE_FP := "e943ac9c8bc1"` (seed 12345 → 12 pieces). `tests/test_config_menu.gd` lines **42–44** assert `exported.size() == 36` (the doc's "36 knobs"). `tests/test_run_config.gd` line **105** prints the knob count from `to_flat_dict()`.
- ✅ **Boot/launch seam exact:** `main_game.gd:178` fallback reads `_config_menu.apply_and_get_config() if _config_menu != null else (load(RUN_CONFIG_PATH) as RunConfig)`, with `RUN_CONFIG_PATH := "res://data/run_config/run_config.tres"` at line 36 — verbatim as quoted. `JunkPlacer.plan(band, …, cell_size_px)` is at **line 213** (the doc says 204–217; the call sits inside that block — fine).
- ✅ **OQ-G API exists:** `GameState.stage_run_config(config)` is real (`game_state.gd:111`); `active_run_config` is the read-only field (line 59); `_default_run_config()` loads the all-off `.tres` (line 118). So OQ G's recommended fix ("tests stage an explicit `RunConfig.new()` rather than relying on the fallback") is mechanically available.
- ✅ **`run_config.tres` is the all-off control:** confirmed it carries no `[resource]` field overrides (every field at its script default), so `.tres` == `RunConfig.new()`, both all-off — the byte-identical control the contract rests on. J1 does not touch it.

One small clarification (not a correction): the doc says the SpinBox `min_value` for `lvl_size_mult` becomes `4.0` after the re-range. Confirmed — `_build_numeric` sets `spin.min_value = rng.x` for every field except `lvl_room_count` (line 404), so `RANGE_MULT.x = 4.0` does floor the SpinBox at 4.0. **This is the intended effect** and harmless to the control (which uses `lvl_enabled=false` → size inert), exactly as §B states.

### Resolved (technical / on-merit)

**A. Preset representation — factory vs `.tres` vs inline?** → **RESOLVED: ship the static factory `RunConfig.make_default_play_preset()` (Option i).** The author's recommendation is correct and I confirm it on merit. A factory is one typed source of truth, unit-testable without disk I/O, physically *cannot* be confused with the all-off `.tres` (it builds *on top of* a fresh `RunConfig.new()`), and is what both the CFG `_ready()` seed and the `main_game.gd:178` fallback call — one definition, two call sites. A second `.tres` (ii) adds a file that can silently drift from the schema and needs its own load-path + null-guard (the CFG already null-guards `_load_default()`; a preset `.tres` would need the same), for zero benefit over the factory. Inline (iii) is rejected outright — it hides the preset from the `main_game` fallback and from tests, defeating OQ-G's "tests state config explicitly" goal. *Defer (ii) to a later task only if the Director asks to retune the preset from the editor without a code change — but note the preset is configurable-not-balanced greybox, so editor-retuning is premature.* **Not a Director-review item** (data-vs-code is a settled engineering call here; the factory wins decisively).

**E. Reset-to-baseline vs reset-to-preset coexistence.** → **RESOLVED: keep Reset = all-off control (Option i), single button, for M1.3.** The author offered (ii) two buttons as the recommendation; on merit I **downgrade to (i)** for this iteration. The load-bearing requirement is that the all-off control stays trivially reachable for determinism/telemetry work — Option (i) satisfies that with zero new surface, zero new CSV string, zero change to `_on_reset_pressed`/`_load_default`. The Director's "give me the fun defaults back" need is already met by the *boot* state being the preset (a fresh CFG open = the preset) and by the factory being one call away if a second button is ever wanted. Adding a second button now is speculative UX for a greybox config panel the Director sweeps by hand. *Decision: keep the existing `CFG_RESET = "Reset to baseline (all off)"` wired to `_load_default()` unchanged; do NOT add `CFG_RESET_PRESET` in J1.* If, during the M1.3 sweep, the Director finds re-reaching the preset annoying, add the second button then (it's a 4-line follow-up). **Not a Director-review blocker.**

**F. Slider step across `[4.0, 40.0]` — keep 0.25 or coarsen to 0.5?** → **RESOLVED: keep `0.25` (no change to `FIELD_STEP`).** Author correct; confirmed on merit. The SpinBox already gives exact entry (the slider is pure scrub convenience), 145 stops over a 10×-wide range is a non-issue for a mouse drag, and 0.25 preserves the I1 integer-px invariant (`round(16 * mult)` exact at every 0.25 multiple: 4.0→64, 4.25→68, … 40.0→640). Coarsening to 0.5 is a marginal scrub-speed gain at the cost of diverging from the I1-ratified step for no real benefit. **Not a Director call.**

**G. Does the `main_game.gd:178` fallback change break headless loop tests?** → **RESOLVED on merit: yes, change the fallback to the preset AND audit the loop tests; the fix is "tests stage config explicitly."** Verified the seam: `start_new_run()` (line 166) takes the run config from `_config_menu.apply_and_get_config()` when a CFG rail exists, else the fallback at 178. Today the fallback loads the all-off `.tres`. Flipping it to `make_default_play_preset()` means any headless launch *without* a CFG rail now runs the preset (lvl on, R1+R4 on) — which **will** change behaviour for loop tests that drive `start_new_run()` and implicitly relied on the all-off fallback (`test_main_game_loop.gd`, `test_rg1_loop_verify.gd`, `test_duration_loop_reentry.gd`, and `test_rg1_m12_verify.gd` if it drives the loop). **Decision: the builder MUST audit those tests and, for any that asserts baseline behaviour, stage the control explicitly via `GameState.stage_run_config(RunConfig.new())` (or inject a CFG stub) rather than relying on the implicit fallback** — this is the healthier pattern and the determinism tests already construct `RunConfig.new()` directly (so the byte-match tests at `test_level_scale_determinism.gd`/`test_rg1_m12_verify.gd` that build the band from an explicit `RunConfig.new()` are **unaffected** — they never go through the `main_game` fallback). *Caveat for the builder:* if the audit shows a test depends on the fallback in a way that's awkward to stage explicitly, the safer fallback is to leave `main_game.gd:178` loading the all-off `.tres` and have **only** the CFG `_ready()` seed the preset (the CFG path is the only path the human playtest uses — BUG6 §5 confirms "the launch path is always CFG-mediated"). Surface that to the Director if the audit gets messy. **Recommendation: change the fallback to the preset for boot-intent consistency, but fall back to "CFG-only preset" if any loop test resists explicit staging.** Not a Director-review blocker either way.

### Flagged for Director (NOT self-resolved — vision / scope / fun calls)

**B. Preset `lvl_room_count` — 19 or 25?** → **⚠ NEEDS DIRECTOR REVIEW** (author's flag stands; confirmed a genuine fun/feel call). Both cells are the two highest-engagement non-timeout configs in `G4_findings_M1.2.md` §1 (verified at lines 39–40): rc 25 = 7 runs, median 32.8 s, depth 5/9, a full 4 death / 2 extract / 1 timeout spread; rc 19 = 6 runs, median 18.8 s, 3 extract / 3 death. *Recommendation: ship `19` as the boot value* — it's the shorter, snappier run, and J2 (enemy spread) + J3 (per-room density) will *fill* the 19 big rooms so they won't read empty; the Director can bump to 25 in the first M1.3 sweep if 19 feels thin once density lands. **But this is the Director's single boot number** — if they want the richer 25-room expedition as the first impression, say so. *Resolve at J1 build or the first M1.3 sweep; the factory makes it a one-line change.*

**C. 640 px/cell at `lvl_size_mult = 40.0` — rendering / camera / generation risk?** → **⚠ NEEDS DIRECTOR REVIEW IF it forces a lower max** (author's flag stands; this is the one genuinely new concern J1 introduces). Math verified: mult 40 → `round(16*40) = 640` px/cell (exact integer, so `JunkPlacer`/materialise integer math is safe); an 8×4-cell room ≈ 5120×2560 px; a 19-room spine is a *huge* world. I confirm the I1 finding that generation/seal are **pure cell-space** (`SocketSealer` ignores its cell-size param; `fingerprint()` is layout-only; the player is not parented under the scaled band, so traversal time scales ~10× a mult-4 room) — so there is **no determinism or seam risk** at mult 40. The open risks are all *experiential/perf*: (1) the plain `$Player/Camera2D` (I1 Resolved D) at 640 px/cell shows a tiny slice of one room — possibly great for R4 fog/disorientation, possibly "lost in a void"; (2) a single dive at mult 40 may blow well past the M1 ~15-min experiment tier; (3) very large materialised pieces *could* strain frame time (untested — `test_rg1_m12_verify.gd` only exercised the baseline catalog, and the I1 manual checks were at mult 2/3, not 40). **Recommendation: ship max 40.0 as the Director asked (they "found 40.0 good"), but the J1 build worklog MUST record a manual smoke at mult 40 — camera reads acceptably, the band materialises, no seam, the run completes — and if mult 40 is unplayable, surface a recommendation to cap lower (e.g. 24–32) rather than silently clamping.** The number is the Director's; the verification is the builder's; a forced lower cap would be a Director call.

**D. Exact M1.2 R1/R4 magnitudes the preset copies.** → **⚠ NEEDS DIRECTOR REVIEW on one value (the R4 lost-proxy); the rest is mechanical** (author's flag refined). The preset MUST encode *real* R1/R4 magnitudes, not `enabled=true` with zero magnitudes, or it re-creates the M1.2 zero-magnitude config-trap (the whole reason BUG6's guard exists). Confirmed the source exists: `playtest_data/M1.2/run_log_2026-06-19.jsonl` is present on disk (the file the author cites). **Decision for the builder: lift the R1+R4 magnitudes verbatim from the most-fun cell's actual `run_started.data` config snapshot in that log** — read the literal `r1_*` / `r4_*` values the Director played from the `lvl on / size 4.0 / rc {19 or 25} / R1,R4` cell (matching whichever rc the Director picks in B), so the preset is exactly what was found fun, not a guess. The §2 pseudocode's numbers (`r1_chase_speed = 60.0`, `r1_catch_radius = 32.0`, `r4_branch_chance_base = 0.25`, etc.) are **illustrative placeholders — the builder replaces them with the logged values, do not ship them as-authored.** *The one judgment call:* M1.2 ran R4 with `r4_lost_proxy_threshold = 0.0` (the config-trap), so the log has no good lost-proxy value to copy — the preset must ship a **non-zero** lost-proxy so the re-gate actually exercises R4. **Recommendation: `r4_lost_proxy_threshold = 0.5` as a first sweep value** (a backtrack/no-progress proxy fraction), flagged for the Director to adjust in the first M1.3 sweep; this is the value BUG6's config-trap guard also keys on (BUG6 warns when an enabled opposition is inert — a non-zero lost-proxy keeps R4 out of that warning). *Mostly mechanical (copy what was played); the lost-proxy is the only genuine new number, and it's configurable-not-balanced.*

### Cross-task note — BUG6 single-writer split (confirmed consistent)

Verified against `design/M1_3_Tasks/BUG6_hazard_debounce_and_config_traps.md`. Both docs agree on the Wave-1 ownership split and it is **consistent**:

- **J1 owns** the *edits* to `run_config.gd` (the `make_default_play_preset()` factory) and `config_menu.gd` (the `RANGE_MULT` re-range + the `_ready()` boot-seed via `_make_boot_config()`), per Breakdown §5's "`run_config.gd` single-writer: J1 owns `run_config.gd`/`config_menu.gd`/CFG this wave."
- **BUG6 owns** its *new method* `RunConfig.inert_enabled_oppositions() -> PackedStringArray` (added to `run_config.gd`) plus the CFG warn-line in `config_menu.gd` `_refresh_summary()`/chip-refresh that calls it, plus the Telemetry flag. BUG6's own header (lines 7–13) explicitly states "`J1` owns `run_config.gd`/`config_menu.gd` this wave — if BUG6's guard lands in CFG, BUG6 and J1 co-own those files and must be sequenced or merged carefully."

**The split is clean by *method/region*, not by file** — both tasks edit `run_config.gd` and `config_menu.gd`, but disjoint regions (J1: the factory + the size-range const + the boot-seed line; BUG6: the `inert_enabled_oppositions()` method + the warn-line). **Recommendation to the orchestrator: since both touch the same two files in Wave 1, sequence them on `main` rather than running them as fully independent parallel worktrees — land J1 first** (it's the dependency foundation for J2/J3/J4 anyway, `BlockedBy: none` but everything tunes against it), **then BUG6 rebases onto J1's `run_config.gd`/`config_menu.gd`.** This avoids the W1.1-2 multi-writer merge lesson the Breakdown §5 explicitly warns about. The two are *logically* disjoint (J1's preset *provides* the sane R4 lost-proxy that keeps BUG6's guard quiet; BUG6's guard *catches* any future trap J1's preset doesn't cover — they're complementary), so sequencing is purely a merge-hygiene precaution, not a design coupling.

> **One pre-declare reminder for Wave 1:** BUG6 §4.2c keeps its config-trap warning in CFG + Telemetry (no new EventBus signal). J1 adds no signal either (config-only). So **no `event_bus.gd` pre-declare is needed for J1/BUG6 in Wave 1** — confirmed consistent with Breakdown §6.

---

*Authored by `game-director-designer` as Phase-2 of M1.3's four-phase breakdown (`CLAUDE.md` → "Version breakdown authoring"). This doc sets the J1 contract; a Phase-3 fresh-eyes pass resolves §3, then the build wave (general-purpose) builds against it. The load-bearing invariant — the all-off `RunConfig` stays the byte-identical permanent control (fp=e943ac9c8bc1) and the preset is a separate artifact — is non-negotiable per Breakdown §2/§6.*

---

**Changelog**

- **2026-06-19 — Phase-2 spec authored.** Goal + premise research (G4 F1 finding verbatim; the all-off-control contract with its three live test obligations; real boot/CFG/run-launch APIs — `config_menu._ready()` as the "boots into" seam, `main_game.gd:178` fallback, `RANGE_MULT`/`FIELD_STEP`/`effective_cell_size_px`). Design: (A) a `make_default_play_preset()` factory + boot-load wiring that never mutates the all-off default, (B) `RANGE_MULT → [4.0, 40.0]`, (C) the contract guard keeping Reset/`.tres`/`RunConfig.new()` all-off, with new test obligations. 7 Open Questions (A–G) with Director-review flags on B (preset room_count) and C (640 px/cell at mult 40 playability).
- **2026-06-19 — Phase-3 fresh-eyes pass.** Independent programmer-lens verification of every cited file/line/API — **all claims hold up, no corrections needed** (the `config_menu.gd`/`run_config.gd`/test line numbers, the `main_game.gd:178` fallback, the 36-knob count, `BASELINE_FP=e943ac9c8bc1`, `GameState.stage_run_config`, and the all-off `.tres` == `RunConfig.new()` byte-identity all confirmed). Added `## Resolved Decisions (Phase 3)`: **resolved A/E/F/G on merit** (A → factory; **E downgraded from two-buttons to single Reset=all-off** for greybox simplicity; F → keep 0.25; G → flip the fallback to the preset + audit loop tests to stage config explicitly, with a CFG-only fallback if any test resists); **flagged B/C/D for Director** (B preset rc 19-vs-25; C 640 px/cell playability at mult 40 — confirmed determinism-safe, experiential-only, build must smoke-test; D copy R1/R4 magnitudes verbatim from `playtest_data/M1.2/run_log_2026-06-19.jsonl` with a non-zero `r4_lost_proxy_threshold≈0.5` as the one new number). **Confirmed the BUG6 single-writer split is consistent** (J1 owns the factory + size-range + boot-seed; BUG6 owns `inert_enabled_oppositions()` + the CFG warn-line — same two files, disjoint regions; recommend sequencing J1→BUG6 on `main`, no EventBus pre-declare needed).
