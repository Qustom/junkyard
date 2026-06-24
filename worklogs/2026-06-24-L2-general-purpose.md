# Worklog — L2 Spawn-room pursuer (#6)

- **Date:** 2026-06-24
- **Subagent:** general-purpose (the programmer)
- **Milestone:** M1.5
- **Branch:** general-purpose/L2
- **Commit:** 1f4f67d02ede2d2f81e9bbdb4951c713d120dcd3

## What changed
The pursuing `HazardEntity` becomes a **room-bound slow patrol** (Director-LOCKED #6): when
`r1_spawn_room_only` is ON and it learned its spawn-room bounds, it paces between two RNG-free
endpoints inside the room at `r1_patrol_speed` and **chases only while the player is inside that
room** (`_room_bounds.has_point`); outside, it keeps patrolling (never despawns/freezes). Catch
fires **only while chasing** (the catch test stays inside the factored-out `_chase()`; `_patrol()`
is pure locomotion). It emits `EventBus.hazard_pursuer_state(state, depth, run_t_ms)` on rising-edge
`&"patrol"`/`&"chase"` transitions. `main_game.gd` now threads each pursuer's spawn-room bounds (the
owning piece's floor-cell bbox in world space) into `setup`'s new 3-arg-family `spawn_ctx`. The
play-preset turns it on; the code-level all-off defaults stay off/0.0 (chase-everywhere, byte-
identical).

### How `room_bounds` was threaded through the two R1 spawn helpers (Option A, RD-1)
`HazardEntity.setup` widened to the K5 3-arg family `setup(cfg, player, spawn_ctx := {})`
(back-compatible — `spawn_ctx.get("room_bounds", Rect2())`; the existing 2-arg call sites + test
fixtures still compile). Both R1 spawn helpers return positions only, so:
- **J2 spread** (`_spawn_r1_hazards`): added `_piece_bounds_at_world(band, pos)` — resolves the
  band-global cell under the placed world position, finds the owning piece (`floor_cells.has(cell)`),
  and returns `_piece_floor_bounds_world(_density_sorted_cells(p))`. Threaded as `spawn_ctx`.
- **J3 density** (`_populate_room_density`): `_density_spawn_positions` is **left byte-identical**
  (it has a golden-snapshot contract in `test_per_room_density.gd (f2)`). Added a PARALLEL plan
  helper `_density_spawn_bounds(band, rc)` returning `Array[Rect2]` in the SAME iteration/order/length;
  `_populate_room_density` now zips position[i] with bounds[i]. This keeps R1's frozen plan untouched
  while still giving each density hazard its room bounds.

Empty/unknown bounds OR `r1_spawn_room_only==false` ⇒ today's chase-everywhere behaviour (the AWAKE
branch falls through; RD-4 fail-safe — never freeze/crash).

## Files touched
- `scenes/hazards/hazard_entity.gd` — widened `setup` to 3-arg family; added `_room_bounds`,
  RNG-free patrol endpoints, `_chase()` (factored-out, catch lives here only), `_patrol()` +
  `_confine_to_room()` clamp, `_emit_pursuer_state()` rising-edge mark; room-bound gate in
  `_physics_process`.
- `scenes/game/main_game.gd` — J2 spread threads `_piece_bounds_at_world`; J3 density threads the
  new parallel `_density_spawn_bounds` plan; `_density_spawn_positions` UNCHANGED (golden contract).
- `data/run_config/run_config.gd` — preset line only: `r1_spawn_room_only = true`,
  `r1_patrol_speed = 28.0` (≈half of chase 56). Code-level all-off defaults untouched.
- `tests/test_pursuing_hazard.gd` (+`.tscn`) — added 5 L2 cases: in-room chase+catch, out-of-room
  patrol/no-catch (incl. just-outside-the-rect no-catch), `r1_spawn_room_only` off → chase-everywhere
  unchanged, empty-bounds fail-safe, `r1_patrol_speed==0` idle-pivot; + `hazard_pursuer_state` sink.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `test_run_config.tscn` → R0 OK (89 knobs, all-off control intact)
- [x] `test_corridor_lever.tscn` → J4 OK (all-off fp byte-matches **e943ac9c8bc1**)
- [x] `test_rg1_m14_verify.tscn` → RG1 M1.4 VERIFY OK (uses the R1 spawn helpers; all-off fp e943ac9c8bc1)
- [x] `test_pursuing_hazard.tscn` → PURSUING HAZARD OK (incl. all 5 new L2 cases)
- [x] `test_new_hazard_spawn.tscn` → K5i OK (K5 spawn_ctx path not regressed)
- [x] `test_per_room_density.tscn` → J3 OK (golden positions `(f2)` byte-unchanged)
- [x] `test_hazard_spread.tscn` → J2 OK; `test_pingpong_hazard.tscn` → K5a OK; `test_rg1_m13_verify.tscn` → OK
- [x] definition of done met: `r1_spawn_room_only=false` byte-identical chase-everywhere; `=true`
  patrols + chases iff `has_point`, catch only while chasing; fp e943ac9c8bc1 unmoved; signal
  rising-edge only; no save change; preset turns it on.

## Design deviations
none. All decisions follow the locked spec: Option A bounds (RD-1), catch only in `_chase` (RD-2),
immediate re-entry resume (RD-3), empty-bounds → chase-everywhere (RD-4), rising-edge
`hazard_pursuer_state` (RD-5), minimal knob set (RD-6), RNG-free pace-endpoints (RD-7), preset
`r1_patrol_speed=28.0` per DR-L2-2's ≈half-of-chase recommendation.

Implementation note (not a deviation): J3 used a **parallel `_density_spawn_bounds` helper** rather
than changing `_density_spawn_positions`'s return type, to preserve that helper's byte-frozen
`Array[Vector2]` golden contract. This is consistent with RD-1's intent (thread real room bounds
through the J3 loop) and the M1.3/M1.4 "don't refactor R1's frozen plan" guard.

## Handoffs / follow-ups
- DR-L2-2 (whether the M1.5 preset should also lower `r1_chase_speed` for the room-bound feel) is a
  Director sweep value left at the existing preset `r1_chase_speed=56.0`; `r1_patrol_speed=28.0` is
  the slow-pace start. RG1 can sweep both.
