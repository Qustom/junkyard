# Worklog — FBM-A1 Ambusher rework: hide-pursue-pounce stalker

- **Date:** 2026-07-05
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.10 (FBM — Director playtest-feedback fix)
- **Branch:** worktree-agent-a9eeb9f02b8208f38
- **Commit:** 6d10683379249d7da704a2523646a20b1ebf626f

## What changed
Reworked the M1.10 Ambusher ("The Lurker") from a one-shot trap into a **hide-pursue-pounce
stalker** per the Director's directive. Three fixes: (1) the orange telegraph wedge (`$Tell`)
is now hidden while concealed — it was the "floating orange arrow at rest" the Director saw;
Concealment now gates its alpha too. (2) The one-shot `_spent`/husk terminal is gone: after
the first pounce the host enters STALKER mode — every RECOVER→DORMANT re-hides (invisible +
un-hittable, floor-smudge still tracking), and while DORMANT the host ticks the REUSED
`ChaseMove` to pursue the player, closing the gap to re-arm and re-pounce indefinitely until
killed. (3) A new `track_speed` knob (hidden-pursuit speed, default 130 px/s) maps to
ChaseMove's `chase_speed`; `re_hide_s` default bumped 0.0→0.6 s as the inter-pounce breath
(→ ChargeLane's cooldown_s). ChargeLane / ChaseMove / all shared components untouched —
orchestrated entirely from the host.

## Files touched
- `Game/scenes/hazards/ambusher_hazard.gd` — dropped `_spent`/one-shot; added `_chase`
  (ChaseMove) acquire+bind; `track_speed`→`chase_speed`/`speed_per_depth=0` in `_resolve_params`;
  `_physics_process` ticks ChaseMove while `_has_pounced` and lane DORMANT; DORMANT hook now
  always re-hides; `_conceal.telegraph_tell = _tell` wiring; `is_spent()`→`is_stalking()`;
  DEFAULTS gain `track_speed:130.0`, `re_hide_s:0.6`.
- `Game/scenes/hazards/components/concealment.gd` — new `telegraph_tell` node ref +
  `_set_wedge_alpha()`; `hide_conceal()` sets wedge alpha 0, `reveal()` sets it 1; removed the
  now-dead `spend()` husk method.
- `Game/data/oppositions/ambusher.tres` — params `track_speed:130.0`, `re_hide_s:0.6`; schema
  gains a `track_speed` row (float 0–300) and re_hide_s default→0.6 (keeps params↔schema
  bijection + `default==params` green).
- `Game/ui/config/config_strings.csv` — new `CFG_FIELD_AMBUSHER_TRACK_SPEED` gloss; re_hide_s
  gloss reworded to "inter-pounce pause" (no longer "one-shot").
- `Game/tests/test_ambusher.gd` — case (a)/(b) assert `$Tell` alpha 0 at rest / 1 on reveal;
  case (g) rewritten from one-shot→STALKER (first pounce, re-hide, hidden pursuit closes
  distance, re-pounce); removed `_await_spent`; success string updated.
- `changelog.txt` — Ambusher entry rewritten IN PLACE to its final stalker state.

## Checks run
- [x] `godot --headless --path Game --import` clean (no GDScript parse errors; only the
  pre-existing harmless `.translation`-not-built resource-load warnings)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `res://tests/test_ambusher.tscn` → **T2a OK** (first ambush pounce; post-pounce hidden
  pursuit closes distance; re-pounce loop; revealed-window throw-kill; `$Tell` invisible at
  rest / shown on reveal; off-by-default fp `e943ac9c8bc1` unmoved; deterministic)
- [x] `res://tests/test_opposition_def_schema.tscn` → **DEF SCHEMA OK** (9 defs; params↔schema
  bijection holds with the new `track_speed`)
- [x] definition of done met: "test_ambusher green for the new stalker behavior; schema green;
  import + smoke green; off-by-default fp unmoved."

## "junk just stops" — root cause
It was NOT a throw-kill bug in the revealed window (throw-kill in TELEGRAPH/CHARGE/RECOVER
already worked — Concealment re-joins the "hazard" group + layer 16 on reveal). It was the
one-shot **husk**: `spend()` left the body on `collision_layer` 16 (solid) but OUT of the
"hazard" group (unkillable). A throw at a spent husk hit a solid body, resolved as `_miss()`,
and re-dropped — "stops and does nothing." Removing the husk (the stalker loop never spends)
eliminates the state entirely: revealed = solid + killable, hidden = layer 0 pass-through.

## Design deviations
none — on-spec with the FBM-A1 brief and the Director's directive (keep attacking; go invisible
after each pounce; follow the player hiding+pouncing). `track_speed` default 130 px/s chosen
within the brief's 120–150 band (player ~200 px/s → relentless but out-walkable); `re_hide_s`
default 0.6 s. Both are tunable knobs.

## Handoffs / follow-ups
Behavior is a Director fun/tone call (relentlessness of the stalk, track_speed/re_hide_s feel) —
surface at the re-gate playtest. No blockers. Do NOT merge/publish (orchestrator republishes).
