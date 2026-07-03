# Worklog — S6a New hazard #1: Charger "The Wrecker" (data + one new component — the Phase-E proof)

- **Date:** 2026-07-03
- **Subagent:** general-purpose (programmer) — **also delivering the character-animator half as the
  inline greybox placeholder per D-RAT-4** (no PixelLab run in M1.9; the wedge silhouette + per-state
  tell palette below ARE the S6a placeholder-sprite deliverable, code-drawn)
- **Milestone:** M1.9 (Wave 4, parallel worktree)
- **Branch:** general-purpose/S6a
- **Commit:** 250cee1465b17d48b1546937cfc21f06ffa86c23

## What changed
The canonical "content = data" proof: adding the Charger cost **one new movement component
(`ChargeLane`) + one def (`charger.tres`) + the Actor-host shell/scene + a test** — zero edits to any
existing file. `ChargeLane` owns the three-beat FSM (DORMANT → TELEGRAPH 0.5s → locked-vector CHARGE
520px/s → RECOVER 1.2s, cooldown folded into DORMANT) with a swept-segment tunnel-proof lethal test
fed into `LethalContact`'s **pre-existing `&"external"` seam** (`apply_contact(hit, can_catch)` — S2
landed it for us; the OQ-1 "S6a may have to add it" contingency did NOT bite). Wake = reused
`ProximityTrigger` (aggro_range → proximity_radius, per the OQ-2 resolution). Tells = reused
`TelegraphFSM` driven by the host (rust-steel dormant → amber→red escalating wind-up + committed-lane
strip → alarm-red dash → stunned grey-blue recovery; directional wedge rotates to the locked lane).
Dash-invulnerability (D-RAT-2: def default `throwable_while_charging=true`, band_two deck overrides
to `false`) = pure `&"hazard"`-group toggling — a mid-dash throw resolves `_miss()` and re-drops;
`thrown_item.gd` untouched (adjudication #4 verified). Wall-crash bonus-stun knob ships
(`wall_crash_recover_mult` def `1.0`, deck ≈2.0 per D-RAT-2). Ships OFF: not in any lever, preset, or
deck; `min_band = 2` hard-gates to band_two (adjudication #1); all-off fp `e943ac9c8bc1` pinned by
`test_charger` case 2.

## Files touched (all NEW — file-disjoint from S4/S6b/S7 by construction)
- `Game/scenes/hazards/components/charge_lane.gd` — **the ONE new component**: host-ticked
  (`tick(delta)`, S2 base contract — no self `_physics_process`), snapshot `_configure`, swept lethal
  sweep → `lethal.apply_contact`, group-toggle throwability, `on_state_changed` host hook. RNG-free.
- `Game/scenes/hazards/charger_hazard.gd` — the Actor-host family skeleton (guard, self-timed run
  clock, fixed acquire/tick order, `spawn_ctx["params"]` resolve with a `DEFAULTS` mirror of the def,
  `get_def_id()`/`resolve_throw_death()` seams) + the greybox tells + the S0-locked telemetry emits
  (`&"telegraph"` on wind-up, `&"state"` on charge/recover/dormant — Correction 1; `&"hit_player"` /
  gated `opposition_killed_player` live in the reused LethalContact — Correction 2).
- `Game/scenes/hazards/charger.tscn` — root `Charger` (CharacterBody2D, layer hazard(16), mask
  world(2), group `hazard`, r=16 body), directional wedge `Tell` (34×28px, reads heavier than the
  r=14 player), runtime-built `LaneRect` telegraph strip.
- `Game/data/oppositions/charger.tres` — id `&"charger"`, display "The Wrecker" (D-RAT-2), actor,
  cost 2 / weight 1.0 / **min_band 2** / cap_group `&"new_hazards"` / per_room 1 / per_band 4;
  13 params + bijective schema (spec §2.1 defaults; `trap_if_neutral` on `charge_speed`).
- `Game/tests/test_charger.gd` + `.tscn` — 11 case groups (def card + DEFAULTS-mirror, all-off gate +
  fp pin, FSM timing + locked vocabulary, lane-lock dodge, kills gate + BUG6 latch ×1, wall stop +
  ×2 bonus stun, non-lethal outside CHARGE, throw miss/re-drop vs recovery punish vs throwable
  default, RNG audit, deterministic deck placement through the REAL builder+service with
  per_band_cap/min_band binding, tell-renders guard).
- `*.uid` files for the two new scripts + the test.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**
- [x] `test_charger` → **S6a OK** (all 11 case groups)
- [x] `test_opposition_def_schema` → **DEF SCHEMA OK — 5 defs** (charger swept by the dynamic
  per-def bijection/shape/host-contract net; no test edit needed — kept file-disjoint from S6b,
  charger-specific card pins live in `test_charger` case 1 instead)
- [x] `test_opposition_components` → **golden frame traces byte-identical** (no existing entity touched)
- [x] `test_spawn_service`, `test_encounter_builder` → OK (all-off fp `e943ac9c8bc1` pinned twice)
- [x] full hazard suite: `test_pingpong_hazard`, `test_bomb_hazard`, `test_spike_hazard`,
  `test_pursuing_hazard`, `test_new_hazard_spawn`, `test_hazard_spread` → all OK
- [x] `test_band_pipeline_parity`, `test_bandgen_determinism` → fp `e943ac9c8bc1` unmoved
- [x] `test_config_menu` (89/89 legacy rows intact), `test_run_config` (90-knob flat dict) → OK
- [x] DoD met: "all-off fp unmoved; def passes the params↔schema check; deterministic placement
  (same seed+config → same spawn set); test_charger (telegraph timing, dash kill gated by kills,
  wall stop, latch/telemetry events); menu section auto-appears (S4's net — complete param_schema
  authored; S4 verifies its half); worklog + commit SHA + deviations." ✓

## The proof's measured cost (the SG3 watch-item, per OQ-1/§0)
**Def + ONE new behavior component held.** `ChargeLane` is the only new behavior script; the swept
detector + group-toggle live inside it against existing seams. `LethalContact`'s `&"external"` mode
already existed (S2 built it for S6a — breakdown amendment 4), so **zero shared-file edits** were
needed. Honest cost beyond the slogan: the thin per-entity **host shell** (`charger_hazard.gd` +
`charger.tscn`) — the same Actor-family skeleton every shipped hazard carries (guard/clock/acquire/
tell constants/emit sites); it adds no new behavior surface. See deviation D1.

## Design deviations
Appended to `design/DESIGN_DEVIATIONS.md` (D1–D4): host-shell script as the honest proof cost ·
`kills` promoted into params/schema · spawn-card `base_count=1`/`count_per_depth=0.0` authored ·
gloss CSV rows deferred to integration (S4 owns `ui/config/` this wave).

## Handoffs / follow-ups
- **S7:** deck entry references `&"charger"`; set the D-RAT-2 deck overrides
  (`throwable_while_charging → false`, `wall_crash_recover_mult → ~2.0`) via its deck mechanism.
- **S4/integration:** add the 13 `CFG_FIELD_CHARGER_*` rows to `ui/config/config_strings.csv`
  (keys are authored in the schema; the CSV was left untouched to stay file-disjoint — D4).
- **SG2:** sweep `recover_s` hardest (the core feel knob); watch tangential wall grazes
  false-triggering the crash bonus (OQ-7 rider).
