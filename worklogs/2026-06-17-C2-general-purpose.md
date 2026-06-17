# Worklog — C2 Junk pickup in the band

- **Date:** 2026-06-17
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1
- **Branch:** general-purpose/C2-junk-pickup
- **Commit:** 5adacac6a8203f7b06c4e26c1d36b4187d6be274 (implementation commit; this worklog SHA line is fixed via a no-op amend on top, so the recorded SHA names a commit containing the full C2 change)

## What changed
Built the C2 integration capstone that ties content (C1b), generation (B2), depth
(B3), interaction (A2), and inventory (D1) into the loop's first half: find junk →
grab junk → fill a limited bag. Three pieces:
- `JunkPickup` (Area2D) — a world entity that draws its greybox from `JunkItem`
  data, listens for `EventBus.interaction_requested(&"junk", target)` (A2 owner
  pattern, copied from `ExtractGate`), hands accept/reject to D1's `RunInventory`,
  fires `junk_picked_up`, and only leaves the world on accept (full bag → red
  flash, junk stays).
- `JunkSpawner` (Node) — a pure consumer of B3's `JunkPlacer.plan()`; `populate()`
  instantiates one pickup per plan entry via the shared `spawn_one()` factory, also
  subscribed to `EventBus.junk_dropped` so D2's drop-to-swap re-spawns a grabbable
  pickup through the same path.
- EventBus signals `junk_picked_up`, `junk_dropped`, `band_populated`.

## Files touched
- `systems/event_bus.gd` — added `junk_picked_up(item_id, value, slot_size, world_pos, accepted)`, `junk_dropped(item, world_pos)`, `band_populated(count)`.
- `entities/junk_pickup/junk_pickup.gd` — `class_name JunkPickup` pickup entity (greybox draw, A2 interact handler, accept/reject, reject flash).
- `entities/junk_pickup/junk_pickup.tscn` — scene: `JunkPickup(Area2D)` → `Collision`, `Greybox(Node2D)`, `Interactable(id &"junk", prompt "Grab")`.
- `systems/spawning/junk_spawner.gd` — `class_name JunkSpawner`; `populate()` + `spawn_one()` + `junk_dropped` re-spawn.
- `tests/test_junk_pickup.gd` + `tests/test_junk_pickup.tscn` — headless acceptance test.

## Checks run
- [x] `godot --headless --import` clean (no parse errors)
- [x] `godot --headless res://tests/test_junk_pickup.tscn` → JUNK PICKUP OK (exit 0)
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0)
- [x] `godot --headless res://tests/test_band_depth.tscn` → BAND DEPTH OK (B3 not regressed)
- [x] `godot --headless --script res://tests/test_run_inventory.gd` → INV OK (D1 not regressed)
- [x] definition of done met: junk spawns in the generated band; interacting picks it up, removes it, adds to run inventory; a pickup event fires on EventBus (Telemetry-visible); full-bag rejection leaves junk in world; drop re-spawn verified.

### Test run command + outputs

```
$ export PATH="$HOME/.local/bin:$PATH"
$ godot --headless res://tests/test_junk_pickup.tscn
JUNK PICKUP OK — populated 24 pickups from B3 plan (seed 12345); accept added 'junk_scrap_bolt' ($3, 1 slot) and freed it; full-bag reject left the junk in-world; drop re-spawned via spawn_one.
ERROR: 2 resources still in use at exit (run with --verbose for details).   # harmless: test does not free the band's remaining in-world pickups before quit; exit code is 0.
(exit 0)

$ godot --headless --script res://tools/ci_smoke_test.gd
SMOKE OK — M0 architecture spike healthy   (exit 0)

$ godot --headless res://tests/test_band_depth.tscn
BAND DEPTH OK — graded 12 pieces (max_depth=11), planned 24 junk items; value rises with depth (shallow $31.9 -> deep $121.6), ... (exit 0)

$ godot --headless --script res://tests/test_run_inventory.gd
INV OK — D1 slot inventory verified ... (exit 0)
```

The test runs as a `.tscn` (not `--script`) because it needs the EventBus / RNG /
GameState autoloads, which are not registered as globals under `--script` — same
constraint B3's `test_band_depth.tscn` documented.

## Design deviations
The C2 spec skeleton predates B3/D1 shipping; the build follows the orchestrator's
resolved recommendations and the real codebase APIs. All deviations are from the
spec's own *skeleton*, not from the resolved recommendations:

1. **Spawner consumes B3's plan; no own weighting / `RNG.stream`.** The spec's
   `JunkSpawner.populate(band, container)` rolled its own item selection via
   `RNG.stream("junk_spawn")` + `_pick_weighted`. That stream API does not exist,
   and B3 already owns deterministic placement (item selection, depth scaling,
   weighting, density). `populate(plan, container)` is now a pure consumer of
   `JunkPlacer.plan()` — it adds no RNG draws (any per-anchor spawn probability is
   already folded into B3's density curve). This is the documented B3/C2 scope seam.
2. **Direct invocation after generation, not a fire-and-forget signal** — per the
   C2 spec recommendation (spawning has a hard ordering + data dependency).
3. **`JunkItem.base_sell_value`** (not the skeleton's `base_value`); item ref comes
   from B3's plan as a depth-scaled `duplicate(true)` (final value).
4. **`junk_picked_up` payload includes `slot_size`** — `junk_picked_up(item_id,
   value, slot_size, world_pos, accepted)`, primitives-only, value snapshotted at
   pickup (per recommendation). Added `band_populated(count)` Telemetry hook and
   `junk_dropped(item, world_pos)`.
5. **Reject UX**: pickup `_flash_rejected()` (red pulse) + junk stays in world,
   keyed off D1's `can_accept()`/`is_full()` — the same truth D2's panel reads. The
   prompt-side "won't fit" cue lives in A2/D2's prompt projection, not duplicated here.

## Handoffs / follow-ups
- **D2 one-line follow-up (NOT done here — D2 files untouched):** D2's drop gesture
  must `EventBus.junk_dropped.emit(removed_item, drop_world_pos)` after
  `RunInventory.remove_at()`, so the already-wired spawner re-spawns a grabbable
  pickup. The spawner subscribes and re-spawns via `spawn_one()` into the band
  container registered by the last `populate()` call. Until D2 emits it, drop-to-swap
  re-spawn is dormant (the path is tested directly here by emitting `junk_dropped`).
- **Spawner needs a container registered** before `junk_dropped` re-spawns work
  (set by `populate()`); a drop outside a populated band is a no-op by design.
- Telemetry: confirm `junk_picked_up` / `band_populated` are in its watch list (no
  code needed beyond the signals existing).
