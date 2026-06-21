# Worklog — K5b Bomb hazard

- **Date:** 2026-06-21
- **Subagent:** general-purpose
- **Milestone:** M1.4 (Wave 3 — Danger variety)
- **Branch:** general-purpose/K5b-bomb
- **Commit:** 7626ae0988ca966b33a8450b12b5f9e33b95bfcd (worklog self-reference is to the prior
  HEAD of this same logical commit; the live HEAD after this final worklog update is one hash
  later — `git log --oneline -1` on branch `general-purpose/K5b-bomb` is authoritative)

## What changed
Built the **BombHazard** greybox entity — a stationary `Node2D` committed proximity bomb.
It sits inert showing an idle proximity ring; when the player's centre crosses
`hbomb_proximity_radius` it COMMITS (emits `bomb_pulse_started`), pulses for
`hbomb_pulse_seconds` with an accelerating throb, then detonates. A player whose centre is
within `hbomb_blast_radius` at the detonation frame dies (`new_hazard_killed(&"bomb", …)`
telemetry row + `GameState.fail_run(&"death")`); otherwise it fizzles. No-defuse: leaving the
ring mid-pulse does not cancel. One-shot — frees itself after the explode flash. Reads the K0
`hbomb_*` knobs only; touches no shared file (run_config, event_bus, main_game). Detonation is
driven by an accumulated `_pulse_t` float in `_physics_process`, never a tween callback, so it
runs correctly headless; the tweens are pure juice.

## Files touched
- `scenes/hazards/bomb_hazard.gd` — new BombHazard entity (IDLE→PULSING→EXPLODED state machine,
  distance-test arm/blast, inline Polygon2D tells + R1 tween-flash idiom).
- `scenes/hazards/bomb_hazard.tscn` — Node2D scene (group `hazard`) with `IdleRing` + `Core`
  Polygon2D children; no collision shape (the player walks over it).
- `tests/test_bomb_hazard.gd` + `.tscn` — headless scene test mirroring `test_pursuing_hazard`:
  commit-on-proximity (one `bomb_pulse_started`, pulse window holds) → fatal detonation, fizzle
  survival, committed-no-defuse, all-off inert.

## Checks run
- [x] `godot --headless --import` clean (no bomb/test parse errors; only pre-existing missing
  `*.en.translation` resource warnings, unrelated to K5b).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → `SMOKE OK` (exit 0).
- [x] `godot --headless res://tests/test_bomb_hazard.tscn` → `BOMB HAZARD OK` (exit 0).
- [x] `godot --headless res://tests/test_bandgen_determinism.tscn` → `fp=e943ac9c8bc1` (unmoved;
  exit 0). All-off = no instances = byte-identical baseline.
- [x] Definition of done met: entity script/scene + test exist; IDLE→PULSING→EXPLODE matches
  §2.2; lethality is a script distance test routed through the existing `fail_run(&"death")`;
  no edits to `event_bus.gd` / `run_config.gd` / `main_game.gd`; committed-no-defuse and
  outside-blast-survives verified; `bomb_pulse_started` fires once per arm edge.

## Design deviations
- **`setup(cfg, player, spawn_ctx)` ignoring the dict** — used the LOCKED Phase-3 cross-cutting
  family signature `setup(cfg: RunConfig, player: Node2D, _spawn_ctx: Dictionary = {})`; the
  bomb ignores `spawn_ctx` (radial blast confined by radius, not room walls). On-spec per the
  Resolved Decisions cross-cutting #3. Not a deviation of substance.
- **Signal names follow the as-built K0 / task brief, not the Phase-2 draft pseudocode** — the
  Phase-2 doc body referenced `bomb_armed` / `bomb_detonated`; the as-built `event_bus.gd` (K0)
  and the Resolved Decisions section declare `bomb_pulse_started(depth, run_t_ms)` (on arm) and
  `new_hazard_killed(kind, depth, run_t_ms)` (on fatal detonation). Used the as-built names. A
  fizzle emits no kill row (per the locked "no separate `bomb_detonated`" contract).
- **Knob names: as-built `hbomb_proximity_radius` / `hbomb_pulse_seconds`** — the Resolved
  Decisions table proposed renaming these to `hbomb_trigger_radius` / `hbomb_fuse_s`, but K0 as
  landed on `main` declares `hbomb_proximity_radius` / `hbomb_pulse_seconds` (confirmed in
  `run_config.gd` + the task brief's verified API). Used the as-built names; semantics unchanged.
- Otherwise none of substance.

## Handoffs / follow-ups
- **K5i** owns the spawn-seam wiring in `main_game.gd` (gated on `hbomb_enabled`): instantiate
  `bomb_hazard.tscn` at deterministic-stride per-room positions, `add_child` into
  `_band_container`, then `setup(active_run_config, player)`. Depth-scaled count per §2.1:
  `n = floor(hbomb_base_count + hbomb_count_per_depth * depth_index)`, capped by
  `hbomb_per_room_cap`.
- **character-animator** polish (sprite/AnimationTree feel) deferred; the inline Polygon2D tells
  + tweens are the greybox deliverable.
