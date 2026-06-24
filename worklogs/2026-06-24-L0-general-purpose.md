# Worklog — L0 Foundation: knob + signal pre-declare

- **Date:** 2026-06-24
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.5
- **Branch:** general-purpose/L0
- **Commit:** a937df7a74b45d18594d67d95d550ef89977cc28

## What changed
Single-writer foundation pass for M1.5: pre-declared the 8 new lever knobs, 4 new EventBus
signals, and the CFG menu structural rows for all 8 knobs, so the Wave-2 build tasks (L1/L2/L5)
only READ knobs + EMIT pre-declared signals and never touch these three shared files again.
DECLARE + WIRE only — no throw/pursuer/kill behaviour (that is L1/L2/L5). All new lever knobs
default off/neutral; the three `*_kills` default `true` (= today's lethal K5 behaviour, the
all-off-equivalent). The all-off `RunConfig` default stays byte-identical (fp `e943ac9c8bc1`).

## Files touched
- `data/run_config/run_config.gd` — declared 8 `@export var` knobs: throw group (new
  `@export_group("L1 Throwing", "throw_")`: `throw_enabled:bool=false`, `throw_speed:float=180.0`,
  `throw_max_range:float=320.0`); spawn-room pursuer in the existing `r1_` group
  (`r1_spawn_room_only:bool=false`, `r1_patrol_speed:float=0.0`); and `hpp_kills`/`hbomb_kills`/
  `hspike_kills` (`bool=true`) in their existing K5 groups. Added all 8 to `to_flat_dict()`.
  `make_default_play_preset()` untouched (per the lock — presets come with L1/L2).
- `systems/event_bus.gd` — declared the 4 M1.5 signals with the locked arities:
  `item_thrown(item_id, depth, run_t_ms)`, `throw_missed(item_id, depth, run_t_ms)`,
  `throw_killed_hazard(item_id, kind, depth, run_t_ms)`, `hazard_pursuer_state(state, depth, run_t_ms)`.
  Declared only (emitters are L1/L2). L5 declares no signal.
- `ui/config/config_menu.gd` — new `throw_` SECTIONS entry; new `throw_` MANIFEST list +
  appended `r1_spawn_room_only`/`r1_patrol_speed` to `r1_` and the three `*_kills` to their K5
  MANIFEST lists; FIELD_RANGE rows (`throw_speed`→RANGE_SPEED, `throw_max_range`→RANGE_VIEW,
  `r1_patrol_speed`→RANGE_SPEED); the `throw_` prefix in `_prefix_of`. Coverage assertion stays green.
- `ui/config/config_strings.csv` — stub CSV keys `CFG_SEC_THROW`/`CFG_GLOSS_THROW` + per-field
  labels for the 8 new knobs.
- `tests/test_config_menu.gd` — bumped the hard exported-field count `81 → 89` + extended the
  arithmetic comment (see deviation below re 88 vs 89).
- `tests/test_run_config.gd` — added the 8 new knobs to `expected_keys`.

## Checks run
- [x] `godot --headless --import` clean — no GDScript parse errors (only pre-existing first-pass
      `.translation` regen notices, which settle on the second import; exit 0).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0).
- [x] `godot --headless res://tests/test_run_config.tscn` → R0 OK, all 89 flat-dict knobs (exit 0).
- [x] `godot --headless res://tests/test_config_menu.tscn` → CONFIG MENU OK, 89/89 knobs bound +
      reachable, Reset returns all-off baseline (exit 0).
- [x] All-off fingerprint byte-identical `e943ac9c8bc1`: `test_corridor_lever.tscn` (hard-asserts
      `BASELINE_FP`) → J4 OK; `test_bandgen_determinism.tscn` → BANDGEN OK fp=e943ac9c8bc1 (both exit 0).
- [x] Definition of done met: "DECLARE + WIRE the 8 knobs + 4 signals + CFG rows + bump knob-count
      tests; all-off default stays byte-identical fp; no behaviour." Verified above.

## Design deviations
- **Knob-count number: the lock says 88, the correct number is 89.** The M1.5 Phase-4 lock states
  "Current knob count = 81 … M1.5 adds 8 → final 88" — but `81 + 8 = 89`, an off-by-one arithmetic
  slip in the spec (the per-group breakdown 3 throw_ + 2 r1_ + 3 *_kills = 8 is correct; only the
  sum is wrong). The as-built schema is verifiably 72 `@export var` + 9 `@export_enum` = 81 pre-L0,
  +8 new `@export var` = 80 var + 9 enum = **89** exported fields. `test_config_menu.gd`'s coverage
  assertion confirmed all 89 are bound + reachable; the only failure at 88 was the hardcoded sanity
  number. I set the test to **89** (the load-bearing reality) and annotated the comment. The knob
  *set / names / types / defaults / signals* are exactly as locked — only the spec's sum digit
  differs. **Recommend the Director note 89 as the correct M1.5 final count** (no design change).
- `throw_speed`/`throw_max_range` magnitude defaults set to `180.0`/`320.0` (sensible greybox) per
  the L0 doc's "pick sensible magnitude defaults"; inert while `throw_enabled=false` (no projectile
  spawns), so they do not move the all-off fingerprint (verified). On-spec.

## Handoffs / follow-ups
- L1/L2/L5 (Wave 2) read these knobs + emit these signals; they must NOT re-edit run_config.gd /
  event_bus.gd / the CFG structural rows. L1/L2 layer the fun values into `make_default_play_preset()`.
- Director: confirm the M1.5 final knob count is **89** (the lock's "88" was an arithmetic slip).
