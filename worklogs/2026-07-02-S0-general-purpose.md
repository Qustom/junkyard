# Worklog — S0 SpawnService extraction + OppositionDef data layer + EventBus pre-declare

- **Date:** 2026-07-02
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 1)
- **Branch:** general-purpose/S0
- **Commit:** 84785cf5bc208296ae683a1f96b07247955afac1

## What changed
Opposition migration Phase A (zero behavior change): extracted the *mechanism half* of
`main_game._spawn_new_hazards` into a policy-free per-dive `SpawnService` (lazy child of
MainGame, group `&"spawn_service"`, run-state only, zero RNG) — instantiation, BUG7
entry-safe validation (`valid_cells()` invoked at the exact filter-then-stride sequence
point), live registry + spawn-cell bookkeeping, cap groups (`&"new_hazards"` = 48 through
the service; R1's 64 stays legacy per §9/OQ-3), run-end `clear_all()`, the LOCKED
`setup(cfg, player, spawn_ctx)` handshake, and the central
`opposition_event(id, &"spawned", depth, run_t_ms)` emit. Policy (descriptor table,
fair-share, depth-scaled counts) stays in `main_game`, now calling `svc.spawn()`. The 4
shipped hazards are authored as `OppositionDef.tres` (ids = legacy telemetry kinds;
`host_scene` = current `.tscn` unchanged; lazy def-load preserves the all-off
loads-nothing rule). EventBus M1.9 block pre-declared (`opposition_event`,
`opposition_killed_player` declared-but-silent until S2, `debug_run_dirtied` for S4, +
the `dive_requested` doc-comment amendment — NO new routing signal, per amendment 1);
GameState gained the inert S8 staging seam (`_pending_dive_band` + self-subscribe +
`consume_pending_dive_band()`), unread until S3.

## Files touched
- `Game/systems/spawning/spawn_service.gd` — **new**: the policy-free spawn mechanism
  (surface per breakdown amendment 6 + spec §9/OQ-10). `NEW_HAZARD_BAND_CEILING` (48) and
  `SPAWN_SAFE_CELLS` (2.5) relocated here.
- `Game/data/oppositions/opposition_def.gd` — **new**: `OppositionDef` Resource (full v2
  field set; id/host_scene/cap_group load-bearing in Phase A; params/param_schema minimal
  — S2 completes).
- `Game/data/oppositions/{pingpong,bomb,spike,pursuer}.tres` — **new**: the 4 shipped
  hazards as data (`pursuer` is loaded by nothing in S0; `cap_group = &""` — its R1 seam
  is untouched).
- `Game/scenes/game/main_game.gd` — thinned `_spawn_new_hazards` (policy shell, statements
  byte-equivalent); `_ensure_spawn_service()`; `_clear_band()` calls `clear_all()`;
  descriptor rows carry `def_path` only (legacy `HPP/HBOMB/HSPIKE_SCENE_PATH` deleted per
  §9/OQ-11); forwarding consts `NEW_HAZARD_BAND_CEILING`/`NEW_HAZARD_SPAWN_SAFE_CELLS`
  re-exported so the committed golden tests read them off MainGame unmodified.
  `_new_hazard_spawn_ctx` stays here unchanged (the tests call it off the mg instance).
  `_spawn_r1_hazards` + both R1 plans + `R1_DENSITY_BAND_CEILING`: untouched.
- `Game/systems/event_bus.gd` — M1.9 pre-declare block (sole edit this milestone) + the
  `dive_requested` doc-comment amendment. No arity changes; legacy signals untouched.
- `Game/systems/game_state.gd` — the inert dive-band staging seam (S8 §3; S0 is the
  designated Wave-1 writer).
- `Game/tests/test_spawn_service.gd` / `.tscn` — **new** run-as-scene service test
  (synthetic def + runtime-built stub scene probing `setup()`).
- `*.uid` files for the new scripts (godot-generated on import).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] All-off fingerprint **byte-identical**: `test_bandgen_determinism.tscn` green
  (fp `e943ac9c8bc1` on sample seed) + `test_corridor_lever.tscn` green (pins
  `BASELINE_FP := "e943ac9c8bc1"`)
- [x] Golden K5 seam harness `test_new_hazard_spawn.tscn` green **UNMODIFIED** (all-off →
  0 nodes; per-room counts; ceiling saturation at 48; byte-identical position
  determinism; per-kind ctx; BUG7)
- [x] `test_pingpong_hazard` / `test_bomb_hazard` / `test_spike_hazard` /
  `test_pursuing_hazard` / `test_per_room_density` / `test_hazard_spread` green unedited
- [x] All RG verifies green: `test_rg1_loop_verify`, `test_rg1_m12_verify`,
  `test_rg1_m13_verify`, `test_rg1_m14_verify`, `test_rg1_m15_verify`
- [x] Preset cohort parity: `test_rg1_m14_verify` re-proves the default play preset
  spawns ≥1 of each new-hazard kind bounded by per-room cap + the 48 ceiling through the
  now-service-backed seam, and that the preset does not leak into the all-off control
  (spec DoD item 6: covered by the determinism case + the RG verifies)
- [x] New `res://tests/test_spawn_service.tscn` green: spawn/parent/place/setup/single
  `&"spawned"` emit; cap_group refuses at ceiling + `can_afford` flips; independent
  `per_band_cap`; registry counts/instances/spawn_cell_of round-trip (unregistered →
  `Vector2i.MAX`); free-without-despawn validity sweep; `clear_all` teardown +
  accounting reset; BUG7 entry-safe `valid_cells()`/`spawn()` refusal + unarmed
  pass-through; `spawn_batch` order with nulls in place; `ignore_room_cap`; no-RNG
  determinism; `world_to_cell(cell_to_world(c)) == c`; staging round-trip
  (`dive_requested(&"band_two")` → consume returns `&"band_two"`, second consume `&""`)
- [x] Definition of done met: *"All-off RunConfig fingerprint e943ac9c8bc1 byte-identical;
  every test_rg1_m1\* verify + test_new_hazard_spawn green UNMODIFIED; preset spawns the
  same cohort; new test_spawn_service green; import + smoke green."* — all above.

## Design deviations
Two minor implementation-level notes (also appended to `design/DESIGN_DEVIATIONS.md`):

1. **Cap-group accounting is live-registry-derived, not a monotonic counter.** Spec §6.1's
   illustrative pseudocode sketched `_cap_groups: group -> {ceiling, count}` (a counter
   incremented per spawn). Implemented instead as ceiling-only storage with counts computed
   from the validity-swept live registry, so spawn/despawn/free stay coherent with
   `live_count()` by construction (single source of truth). Consequence: a node freed
   mid-run re-opens cap headroom for mid-run clients (S6b+); in Phase A this is never
   observable — nothing spawns mid-run and the policy's own `min()` binds first, so all
   fingerprints/positions are byte-identical (verified). Recommendation: Reviewed.
2. **Untyped locals in the registry sweep.** `_compact()`/`clear_all()` read registry
   nodes into untyped locals: assigning an already-freed instance to a typed `Node` var
   raises a runtime script error in Godot 4.6 (caught by the new test's
   free-without-despawn case). Pure internals; no surface change. Recommendation: Reviewed.

Spec-sanctioned surface widenings (per §9/OQ-10, "document in the worklog"):
`valid_cells()`, `live_total()`, `begin_band()`, `set_cap_group()`,
`live_instances(def_id)`, spawn-cell bookkeeping + `spawn_cell_of()`, public
`cell_to_world()`/`world_to_cell()`. `spawn_world()` does NOT exist (OQ-3(ii)).
`begin_band` uses the §6.1 pseudocode signature `(container, cell_size_px, entry_pos,
cfg)` (the §3.1 body text's `safe_dist_px` variant is superseded by §6.1 — the service
derives the radius from its own `SPAWN_SAFE_CELLS`).

## Handoffs / follow-ups
- S2: entities dual-emit (`opposition_event` non-spawn vocabulary +
  `opposition_killed_player` at the `*_kills` gates); completes `params`/`param_schema`.
- S3: EncounterBuilder consumes the service + `consume_pending_dive_band()`; moves the
  descriptor-table policy out of `main_game`; R1 loop relocation.
- S4: emits `debug_run_dirtied`; uses `live_instances`/`spawn_cell_of` for
  respawn-with-new-params.
- Reserved ctx keys locked for S3/S6: `"depth"`, `"run_t_ms"`, `"room_key"`
  (= `str(p.offset_cell)`), `"ignore_room_cap"`.
