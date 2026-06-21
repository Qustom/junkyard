# K5i — New-hazard spawn-seam integration · Phase-2 design

**Milestone:** M1.4 (Stakes, Variety & Legibility) · **Wave 3** (Danger variety).
**Task:** K5i — wire K5a (ping-pong), K5b (bomb), K5c (rotating spikes) into the existing
hazard spawn seam with per-type **depth-scaled counts** + per-type configs, reusing the
existing placement helpers without duplicating the placement math per type.
**Role:** general-purpose (programmer). **Single writer** on `scenes/game/main_game.gd`'s
`_spawn_*` seam this wave (Breakdown §5 Wave 3; §4 `K5i BlockedBy: K5a,K5b,K5c`).
**Authored:** 2026-06-21 (Phase 2). **Status:** Open Questions un-resolved (Phase 3 resolves).

> **Reconciliation note (siblings).** At authoring time `K5a_pingpong_hazard.md`,
> `K5b_bomb_hazard.md`, `K5c_rotating_spikes_hazard.md` are not yet written. This doc designs
> the **seam contract** the three entities plug into, derived from the **K0-declared knob set**
> (`design/M1_4_Tasks/K0_foundation_knobs_signals.md:201-229`) and the as-built R1 seam. Where a
> per-type entity decision is load-bearing for K5i, it is called out as **"reconcile with K5x"**
> so Phase 3 / the entity authors and K5i converge. The three contracts K5i imposes on every new
> hazard scene are: (1) a `setup(cfg: RunConfig, player: Node2D) -> void` method matching the
> `HazardEntity` shape (`scenes/hazards/hazard_entity.gd:83`); (2) the scene roots a `Node2D`
> placed by `global_position`; (3) the scene self-gates / reads only the snapshotted `cfg` (never
> re-reads `GameState.active_run_config`), exactly as `HazardEntity` does.

---

## (a) Research — the seam being extended (files/APIs by path + line)

### A.1 The spawn entry point and its all-off discipline

`scenes/game/main_game.gd:282` — `start_new_run()` calls `_spawn_r1_hazards(run_cfg, band)`
**after** the band is materialised + graded (`_materialise_band` set `_band_cell_size_px` at
`:234`) and after `_spawn_r4_nodes()` (`:272`). This is the one place per-dive danger nodes are
created. K5i adds **one sibling call** here — `_spawn_new_hazards(run_cfg, band)` — immediately
after `_spawn_r1_hazards(...)`, mirroring R1's gating exactly.

The load-bearing disciplines this seam already enforces, which K5i MUST preserve verbatim
(`:285-329`, `:288-294` doc comment):

- **Fully gated → byte-identical all-off control.** With every new-hazard `*_enabled == false`
  (the K0 default, `K0:202/212/224`) the loop must instantiate **no node, load no scene**, so an
  unconfigured run is the M1.0 baseline byte-for-byte (the carried contract, Breakdown §2/§6;
  fp=`e943ac9c8bc1`). R1's gate is the pattern: `if rc == null or not rc.r1_enabled: return`
  (`:300-301`) then a count check (`:304-305`).
- **Placement is pure run-state on the already-graded band.** No RNG, never feeds
  `fingerprint()` (`:292-294` "Placement is pure run-state on the ALREADY-GRADED band (no RNG,
  never feeds fingerprint())"). New-hazard placement is **run-state** like R1 (Breakdown §6:
  *"New-hazard spawn placement (K5) is pure run-state (never feeds fingerprint()), like the R1
  hazards"*).
- **Lifecycle ownership via the band container.** Every node goes into `_band_container`
  (`:321/:347`) so `_clear_band()` frees it with the band (run-state, never persisted).
- **Config snapshot binding.** `hz.setup(rc, player)` (`:323/:349`) hands the entity its config
  snapshot + the player (resolved once via the `"player"` group, `:310`), so the entity never
  re-reads `active_run_config` mid-run.

### A.2 The two placement helpers K5i reuses (no per-type duplication)

K5i's whole point is to place three new hazard types **through the existing placement math**,
not to re-derive it three times. The two reusable helpers:

1. **`_hazard_spawn_position(band, depth, index) -> Vector2`** (`:502-515`). The stable per-depth
   placement API (`:501` "the stable internal API J3 (per-room density) reuses"). Collects floor
   cells of pieces at `clampi(depth, 0, _band_max_depth(band))` in piece order, wraps
   `index % cells.size()` across them, returns a centred world pixel; falls back to
   `_entry_spawn_position(band)` (`:511`) if no graded floor cell at that depth. This is exactly
   "place hazard #i at depth d" — the depth-scaled loop needs nothing else.

2. **`_density_spawn_positions(band, rc) -> Array[Vector2]`** (`:359-397`) and its support
   (`_density_pieces_sorted` `:422`, `_density_sorted_cells` `:439`, `_density_cell_to_world`
   `:449`, `_density_area` `:405`, `_is_corridor` `:415`). The deterministic **per-room** plan:
   walks pieces depth-sorted (`:369`), strides `n` hazards across **each room's own sorted floor
   cells** (`:391-395`), with per-room cap + a band-wide ceiling (`:370/:385`). This is the
   "around the room" placement the bomb + spikes want (Breakdown §K5b "Spawns randomly per room",
   K5c "placed in part of a room"). **Note:** `_density_spawn_positions` is currently hard-wired
   to the R1 knobs (`rc.r1_per_room_density` `:361`, `rc.r1_density_*` `:363-364`). K5i must
   **parameterise the per-room placement** so the three new types can drive it with their own
   `*_base_count` / `*_count_per_depth` / `*_per_room_cap` knobs — see §(b) `_per_room_positions`.

`_hazard_spawn_depths(band, rc) -> Array[int]` (`:460-483`) is the J2 depth distribution
(single_gate / even_spread / curve over `r1_spawn_count`). K5i does **not** reuse the J2
*distribution modes* (those are R1-knob-bound); instead the new hazards use the simpler
**`base_count + count_per_depth * depth`** count law (§(b)) per the K0 knob shape.

### A.3 The K0-declared per-type knobs (the config K5i consumes)

K0 pre-declares the per-type groups at off/neutral defaults
(`K0:201-229`). The shape is identical across the three (this is what lets K5i dispatch them
through one generalized helper):

| type | enable | base count | depth scale | per-room cap | type-specific (entity-owned) |
|---|---|---|---|---|---|
| ping-pong | `hpp_enabled` | `hpp_base_count` | `hpp_count_per_depth` | `hpp_per_room_cap` | `hpp_speed` |
| bomb | `hbomb_enabled` | `hbomb_base_count` | `hbomb_count_per_depth` | `hbomb_per_room_cap` | `hbomb_trigger_radius`, `hbomb_blast_radius`, `hbomb_fuse_s` |
| spikes | `hspike_enabled` | `hspike_base_count` | `hspike_count_per_depth` | `hspike_per_room_cap` | `hspike_rotation_speed`, `hspike_arm_length` |

The **first four columns are the spawn-seam knobs K5i reads**; the type-specific columns are
read by the *entity* in its `setup(cfg, player)` (K5i never touches them — it only passes `rc`).
Every knob defaults off/neutral (`bool→false`, `int→0`, `float→0.0`) so all-off = M1.0.

### A.4 The shared `setup(cfg, player)` contract

`scenes/hazards/hazard_entity.gd:83` — `func setup(cfg: RunConfig, player: Node2D) -> void`
snapshots `_cfg = cfg`, resolves `_player`, seats initial state. **Every K5 entity exposes the
same signature** (the reconciliation contract above), so K5i's instantiate-loop is type-agnostic:
`node.setup(rc, player)` regardless of which of the three it built. Because each entity self-gates
on its own `*_enabled` inside `setup`/`_physics_process` (R1's pattern, `hazard_entity.gd:95`),
even a stray instance is inert when its type is off — but K5i's gate means none is built anyway.

### A.5 The band-wide perf ceiling precedent

R1's J3 density has a **band-global accumulator** truncating at `RunConfig.R1_DENSITY_BAND_CEILING`
= 64 (`run_config.gd:37`, enforced `main_game.gd:370/:385`). K5i needs the **same guard across
all new hazard types combined** (OQ-3) — three uncapped per-depth budgets stacking on top of R1
could spawn hundreds of `_physics_process` nodes. Precedent: a single `const` ceiling +
a running accumulator shared across the per-type dispatch.

---

## (b) Pseudocode — the generalized depth-scaled spawn loop + per-type dispatch

All against the real helpers. New code lives in `main_game.gd` only (single-writer). Per-type
data (scene path, knob accessors) is a small **descriptor table**, so the loop body is written
once and the three types differ only by data — no copy-pasted placement math.

```gdscript
# --- K5i (M1.4): new-hazard scene paths (loaded lazily, only when the type is on) ---
const HPP_SCENE_PATH   := "res://scenes/hazards/pingpong_hazard.tscn"     # reconcile K5a
const HBOMB_SCENE_PATH := "res://scenes/hazards/bomb_hazard.tscn"         # reconcile K5b
const HSPIKE_SCENE_PATH := "res://scenes/hazards/rotating_spikes_hazard.tscn"  # reconcile K5c

# Band-wide ceiling across ALL new hazard types COMBINED (OQ-3). Separate from R1's
# R1_DENSITY_BAND_CEILING (R1 keeps its own budget); this bounds K5a+K5b+K5c together so
# three stacked per-depth budgets can't flood the band with _physics_process nodes.
const NEW_HAZARD_BAND_CEILING: int = 48   # sweep target; perf guard, Director may retune

# A descriptor per new hazard type: the scene path + the four spawn-seam knobs, read off rc.
# This is the ONLY per-type data; the spawn loop below is written ONCE and dispatched over it.
# (kind StringName is for telemetry: new_hazard_killed(kind,...) / a spawn-count row.)
func _new_hazard_descriptors(rc: RunConfig) -> Array[Dictionary]:
	return [
		{ "kind": &"pingpong", "path": HPP_SCENE_PATH, "enabled": rc.hpp_enabled,
		  "base": rc.hpp_base_count, "per_depth": rc.hpp_count_per_depth, "cap": rc.hpp_per_room_cap },
		{ "kind": &"bomb", "path": HBOMB_SCENE_PATH, "enabled": rc.hbomb_enabled,
		  "base": rc.hbomb_base_count, "per_depth": rc.hbomb_count_per_depth, "cap": rc.hbomb_per_room_cap },
		{ "kind": &"spikes", "path": HSPIKE_SCENE_PATH, "enabled": rc.hspike_enabled,
		  "base": rc.hspike_base_count, "per_depth": rc.hspike_count_per_depth, "cap": rc.hspike_per_room_cap },
	]


# --- K5i (M1.4): new-hazard spawn entry — sibling of _spawn_r1_hazards -------------
## Spawn the 3 M1.4 hazard types into the graded band, each with a per-type depth-scaled
## count placed through the EXISTING placement helpers. FULLY GATED: with every *_enabled
## false (K0 default) no descriptor is enabled → nothing loaded/instantiated → all-off ==
## M1.0 byte-for-byte. Placement is PURE run-state on the already-graded band: NO RNG,
## never feeds fingerprint() (like R1). Nodes go into _band_container so _clear_band()
## frees them; setup(rc, player) binds the snapshot. Called from start_new_run() right
## after _spawn_r1_hazards (K5i single-writer seam).
func _spawn_new_hazards(rc: RunConfig, band: Band) -> void:
	if rc == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var spawned_total: int = 0   # band-wide accumulator ACROSS all new types (OQ-3 ceiling)

	for desc in _new_hazard_descriptors(rc):
		if not desc["enabled"]:
			continue   # type off → never load its scene (all-off-equivalent for that type)
		if spawned_total >= NEW_HAZARD_BAND_CEILING:
			break
		var scene := load(desc["path"]) as PackedScene
		if scene == null:
			push_error("MainGame: new-hazard scene missing at %s." % desc["path"])
			continue
		# The deterministic placement PLAN for this type: a pure function of (band, rc, desc).
		# Reuses the per-room density helpers (see _per_room_positions) so the placement math
		# is written ONCE; this loop is the only impure half (scene-tree mutation).
		var positions: Array[Vector2] = _per_room_positions(
			band, desc["base"], desc["per_depth"], desc["cap"],
			NEW_HAZARD_BAND_CEILING - spawned_total)   # remaining global budget
		for pos in positions:
			var hz := scene.instantiate() as Node2D
			_band_container.add_child(hz)
			hz.global_position = pos
			hz.setup(rc, player)      # shared setup(cfg, player) contract (A.4)
			spawned_total += 1


# --- K5i (M1.4): the generalized per-room depth-scaled placement plan --------------
## The ordered world positions for ONE new hazard type, computed PURELY from (band) + the
## type's (base, per_depth, cap, remaining_budget) knobs — NO RNG, NO node state, so the
## same inputs yield a byte-identical list (the determinism contract, like
## _density_spawn_positions). Generalizes _density_spawn_positions: instead of R1's
## area-scaled count it uses the "more with depth" law
##     n_room = base + floor(per_depth * depth_index)
## per ROOM, capped per room (cap) and truncated by the remaining band-wide budget. Strides
## the n hazards across THAT room's own sorted floor cells (the "around the room" placement
## the bomb/spikes want) via the SAME _density_sorted_cells / _density_cell_to_world helpers.
func _per_room_positions(band: Band, base: int, per_depth: float, per_room_cap: int,
		remaining_budget: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if base <= 0 and per_depth <= 0.0:
		return out                       # neutral knobs → no node (all-off for this type)
	var budget: int = maxi(remaining_budget, 0)
	if budget <= 0:
		return out

	# Walk pieces in the SAME stable depth-sorted order J3 uses, so truncation is reproducible.
	for p in _density_pieces_sorted(band):     # reuses :422 — depth_index asc, (y,x) tiebreak
		if out.size() >= budget:
			break
		var depth: int = p.depth_index
		# "More with depth": base at depth 0, +per_depth per within-band depth (J3-style floor).
		var n: int = base + int(floor(per_depth * float(depth)))
		if per_room_cap > 0:
			n = mini(n, per_room_cap)
		n = mini(n, budget - out.size())       # never exceed the shared remaining budget
		if n <= 0:
			continue
		# Stride n hazards across THIS room's own floor cells, index-deterministic (no RNG) —
		# reuses J3's stable cell helpers so placement is byte-identical run-to-run.
		var cells: Array[Vector2i] = _density_sorted_cells(p)   # :439
		if cells.is_empty():
			continue
		var stride: int = maxi(cells.size() / maxi(n, 1), 1)
		for k in n:
			var cell: Vector2i = cells[(k * stride) % cells.size()]
			out.append(_density_cell_to_world(cell))            # :449
	return out
```

**Wire-up (the single new call in `start_new_run`):**

```gdscript
	_spawn_r1_hazards(run_cfg, band)
	_spawn_new_hazards(run_cfg, band)   # K5i — K5a/b/c, gated off/neutral by default
```

**Why this shape satisfies the contract**

- **No per-type placement duplication.** `_per_room_positions` is written once and dispatched
  over the descriptor table; the three types differ only by their four-knob data row + scene path.
- **"More with depth" is per-depth, per-room** (`base + floor(per_depth * depth_index)`), computed
  inside the room walk — the natural fit for `_density_pieces_sorted` which already carries
  `depth_index`. (OQ-1 weighs this against a total-count-scaled-by-max_depth alternative.)
- **"Around the room"** comes free: striding each room's own `_density_sorted_cells` is exactly
  J3's "spread across THIS room's own floor cells" (`:391`), which reads as scattered placement.
- **Shared seam, cleanly.** Both `_hazard_spawn_position` (per-depth, single point) and the J3
  `_density_*` helpers stay R1's; K5i adds `_per_room_positions` as a **generalization** of
  `_density_spawn_positions` (same cell helpers, different count law) rather than a fork. (OQ-2
  asks whether to refactor `_density_spawn_positions` to call the generalized helper, or leave R1's
  intact and only share the cell helpers — the pseudocode above takes the **share-the-cell-helpers,
  don't-refactor-R1** path to keep R1's fingerprint-frozen plan untouched.)
- **Determinism guaranteed.** `_per_room_positions` reads only band topology + integer knobs, no
  RNG, no node state → byte-identical list per `(band, rc)`. It is run-state placement on the
  graded band; it never writes the generator, so it cannot move `fingerprint()` (the all-off
  control's fp stays `e943ac9c8bc1` because all-off → every descriptor disabled → empty plan).
- **Combined perf ceiling.** One `spawned_total` accumulator across the descriptor loop +
  `NEW_HAZARD_BAND_CEILING`, passed as the shrinking `remaining_budget` into each type's plan,
  bounds K5a+K5b+K5c **together** (R1 keeps its own separate `R1_DENSITY_BAND_CEILING`).

### Test updates (the spawn-seam tests)

- **`tests/test_hazard_spread.gd`** — J2 stays the R1 depth-distribution contract (untouched).
  Add a focused K5i block (or a new `tests/test_new_hazard_spawn.gd` if the file gets long —
  OQ-5) driving `_per_room_positions(band, base, per_depth, cap, budget)` directly on the same
  hand-built graded band (`_make_graded_band`): assert (i) **all-off** `base=0,per_depth=0 → []`;
  (ii) **depth scaling** — a deeper room earns `>=` a shallower one for `per_depth>0`, and
  `base>0` puts hazards in every room; (iii) **per-room cap** bounds the per-room count;
  (iv) **band ceiling** — total never exceeds the passed `budget`/`NEW_HAZARD_BAND_CEILING`;
  (v) **determinism** — two calls byte-identical.
- **`tests/test_per_room_density.gd`** — J3 stays the R1 density contract (untouched: it still
  drives `_density_spawn_positions`). Add an assertion that `_density_spawn_positions` is
  **unchanged** by K5i (R1's plan didn't regress when the cell helpers were shared) — i.e. the J3
  golden positions still match (guards OQ-2's "don't refactor R1" decision).
- **`tests/test_config_menu.gd` knob count** — K0 already bumps it for the new knobs; K5i adds no
  knobs, so no count change here (K5i only consumes K0's `hpp_*/hbomb_*/hspike_*`).
- Both spawn-seam test scenes (`tests/test_hazard_spread.tscn`, `tests/test_per_room_density.tscn`)
  already exist and are modified in the working tree — confirm they still boot under the new code.

---

## (c) Open Questions

**OQ-1 — Per-depth-spawn vs total-count-scaled-by-max_depth.**
The pseudocode computes the count **per room** as `base + floor(per_depth * depth_index)` (more
hazards the deeper the room). The alternative is a **band total** `N = base + floor(per_depth *
band.max_depth)` then distributed across depths via the J2 `_hazard_spawn_depths` machinery
(reusing single_gate/even_spread/curve) + `_hazard_spawn_position`.
- *Per-room (chosen in pseudocode):* matches "more with depth" literally and per-room ("around
  the room"); reuses the J3 density helpers the bomb/spikes already want; naturally fills big deep
  rooms. Cost: count is implicit (sum over rooms), harder to set a precise "I want exactly 5"
  budget; depends on how many rooms exist at each depth.
- *Band-total + J2 distribution:* gives a precise total knob and reuses the richer J2 distribution
  modes; but those modes are R1-knob-bound (`r1_spawn_distribution`) and the new types have no
  distribution knob in K0 — adding one widens K0's locked knob set, and "around the room" placement
  is weaker (`_hazard_spawn_position` wraps `index % cells`, less "scattered per room").
- **Trade-off / recommendation:** per-room (as written) is the smaller, more faithful change and
  reuses exactly the helpers the bomb/spikes need; band-total only wins if the Director wants a
  precise total budget per type. **Needs Phase-3 confirm** that "more with depth" = per-room
  (not a band total). Lean per-room.

**OQ-2 — Shared vs per-type placement: refactor `_density_spawn_positions`, or only share the
cell helpers?** K5i's `_per_room_positions` duplicates the *room-walk + stride* skeleton of
`_density_spawn_positions` (`:359-397`) with a different count law.
- *Share-cell-helpers, don't refactor R1 (chosen):* `_per_room_positions` is a new function that
  calls the same `_density_pieces_sorted` / `_density_sorted_cells` / `_density_cell_to_world`;
  R1's `_density_spawn_positions` is byte-untouched → its fingerprint-frozen plan can't regress.
  Cost: ~15 lines of skeleton repeated.
- *Refactor R1 to call the generalized helper:* one placement function, R1 passes its area-scaled
  count via a callback/param. DRY-er, but it **touches R1's plan** — any subtle reordering risks
  moving the J3 golden positions / all-off behaviour, and R1 has a frozen determinism contract.
- **Trade-off:** the M1.x house style favours "don't touch the frozen baseline path" (Breakdown
  §2/§6). Lean **share-cell-helpers, don't refactor** (as written); the duplication is small and
  the safety is large. **Confirm in Phase 3.**

**OQ-3 — Combined perf ceiling: shared budget across all three vs per-type ceilings, and the
value.** The pseudocode uses ONE `NEW_HAZARD_BAND_CEILING` (=48) shared across K5a+K5b+K5c,
**separate** from R1's `R1_DENSITY_BAND_CEILING` (=64).
- *Shared single ceiling (chosen):* bounds the total new-hazard node count regardless of how many
  types are on — the real perf cost is total `_physics_process` bodies. Cost: a type spawned last
  can be starved if earlier types ate the budget (descriptor order matters — currently
  pingpong→bomb→spikes).
- *Per-type ceiling:* each type gets its own cap; no starvation, but three uncapped-ish budgets can
  stack (worst case 3× the bodies) — the thing the ceiling exists to prevent.
- Also open: **does R1's budget count toward the same ceiling?** Keeping them separate (chosen)
  means a fully-loaded run is R1's 64 + new 48 = up to 112 hazard bodies + the player + pickups.
  Is that within the greybox perf envelope on the web export target (Breakdown re-gate ships to
  itch)? The bomb's proximity check + spikes' rotation + pingpong's `move_and_slide` are each
  cheap, but 112 `_physics_process` nodes warrants a headless tick-time sanity check.
- **Trade-off / recommendation:** shared ceiling (predictable total) with descriptor order
  documented; the per-room caps (`*_per_room_cap`, MUST be >0 in the preset per K0:206) already
  bound the common case, so the band ceiling is the safety net. **Value (48) is a Director sweep
  knob — flag for review; verify the combined-load tick time in RG1.**

**OQ-4 — Any RNG, or pure-deterministic?** The "around the room" / "spawns randomly per room"
wording (Breakdown §K5b) reads as *random* placement, but R1's J3 achieves a *scattered* look
**deterministically** (index-stride over sorted cells, no RNG) and the seam contract forbids
global RNG mid-generation (Breakdown §6).
- *Pure deterministic (chosen):* identical to J3 — striding sorted cells looks scattered enough,
  stays run-state, never risks the all-off fingerprint, fully unit-testable (the tests assert
  byte-identical lists). No new sub-stream.
- *Local sub-stream `run_seed ^ salt`:* if the Director wants genuinely varied positions, route a
  **local** RNG (the B3/E3 pattern, Breakdown §6) seeded `run_seed ^ K5I_SALT` — never the global
  RNG — so it's reproducible per seed and never touches `fingerprint()`. Slightly more "alive"
  placement at the cost of a salt constant + a seedable plan.
- **Trade-off / recommendation:** start **pure-deterministic** (as written) — it satisfies "around
  the room" via striding, matches the J3 precedent, and is the simplest determinism-safe choice;
  promote to a local sub-stream only if the Director judges the striped placement too regular at
  playtest. **Needs Director taste call (fun/legibility) — flag for review; recommend pure
  deterministic for RG1.**

**OQ-5 — Where do the K5i tests live?** Append to `tests/test_hazard_spread.gd` (keeps spawn-seam
tests co-located, but mixes J2-R1 and K5i concerns in one file) vs a new
`tests/test_new_hazard_spawn.gd` + `.tscn` (cleaner separation, one more test scene to register in
CI). **Trade-off:** co-located is less wiring now; a dedicated file is clearer as the new-hazard
surface grows. Lean **dedicated file** (`test_new_hazard_spawn`) since K5i introduces a distinct
helper (`_per_room_positions`) with its own contract. **Phase-3 / qa to confirm CI registration.**

**OQ-6 — Reconciliation gaps with K5a/b/c (entity contracts).** K5i assumes each entity (1) exposes
`setup(cfg, player)`, (2) roots a `Node2D` positioned by `global_position`, (3) reads its
type-specific knobs from the snapshotted `cfg`. **Open until the sibling designs land:** does the
**bomb** need its room's bounds (to keep its blast inside the room) or is a world position enough?
Does the **ping-pong** hazard need its room's wall rects at spawn (to know where to bounce), and if
so, must K5i pass the `PlacedPiece` / `floor_cells` into `setup` (a contract widening) rather than
just a `Vector2`? Does the **spikes** hazard need its room centre vs a floor cell? If any entity
needs more than a world position, the `setup` contract widens to `setup(cfg, player, piece)` (or a
spawn-context struct) — **a seam change K5i owns and must reconcile with the three entity authors
in Phase 3.** Recommendation: keep `setup(cfg, player)` and let entities that need room bounds read
their own overlap at runtime (cheaper than widening the contract for all three); revisit if K5a's
bounce genuinely needs authored wall rects.

---

## Resolved Decisions (Phase 3)

> Fresh-eyes resolution, 2026-06-21, resolving the four K5 hazard docs (K5a/K5b/K5c/K5i) + K0 as ONE coherent family.
> K5i is the integration seam, so it must converge with all three entity authors. **K0 is NOT yet landed** (verified: no
> `hpp_*`/`hbomb_*`/`hspike_*` knobs in `run_config.gd`, no new-hazard signals in `event_bus.gd`), so the names below are
> still soft and **K0 must adopt them before it is dispatched.** Several K5i descriptor-table corrections below are
> load-bearing for the spawn loop to compile against the real entities.

### CROSS-CUTTING — naming coherence (corrections to K5i's descriptor table + scene paths)

The locked family scheme (audited against the as-built `r1_`/`lvl_` contiguous-prefix house style, `run_config.gd:57/192`):

| type | config prefix | `class_name` | LOCKED scene path | telemetry `kind` |
|---|---|---|---|---|
| ping-pong | `hpp_` | `PingPongHazard` | `scenes/hazards/pingpong_hazard.tscn` | `&"pingpong"` |
| bomb | `hbomb_` | `BombHazard` | `scenes/hazards/bomb_hazard.tscn` | `&"bomb"` |
| spikes | `hspike_` | `SpikeHazard` | `scenes/hazards/spike_hazard.tscn` | `&"spike"` |

**Corrections to K5i's §(b) pseudocode:**
- `HSPIKE_SCENE_PATH := "res://scenes/hazards/rotating_spikes_hazard.tscn"` → **`"res://scenes/hazards/spike_hazard.tscn"`**
  (K5c authors the file as `spike_hazard.tscn`).
- The descriptor `{ "kind": &"spikes", … }` → **`{ "kind": &"spike", … }`** (singular, matching K5c's
  `new_hazard_killed(&"spike", …)` emit and RG2's cohort key).
- The bomb's per-type knobs the *entity* reads are **`hbomb_trigger_radius` / `hbomb_fuse_s` / `hbomb_blast_radius`** (K0
  names — see K5b Resolved Decisions; K5b's design had named them `h_bomb_proximity_radius`/`h_bomb_pulse_seconds`). K5i
  does NOT read these (it only reads the four spawn-seam knobs `*_enabled/*_base_count/*_count_per_depth/*_per_room_cap`),
  so this is only a comment-table fix, not a logic change. K5i's four-knob descriptor columns are unchanged and correct.

### CROSS-CUTTING — shared `setup()` contract (RESOLVES K5i OQ-6)

The entity docs diverged: K5a wanted `setup(cfg, player, initial_dir, room_bounds)`, K5c wanted
`setup(cfg, player, phase_salt)`, K5b/K5i wanted `setup(cfg, player)`. **LOCKED family signature:
`setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void`** — ONE call site, heterogeneous per-type
context behind a small `Dictionary` (chosen over widening to `setup(cfg, player, piece)` for all three because the bomb
needs nothing, ping-pong needs direction+bounds, spikes needs a phase salt — three different needs, one signature).

**K5i builds `spawn_ctx` per type** in the spawn loop and passes it to `setup`:
- ping-pong: `{ "initial_dir": Vector2.from_angle(index * GOLDEN_ANGLE), "room_bounds": <piece floor-cell bbox Rect2> }`
  (OQ-6 resolved: K5i DOES compute the room rect for the ping-pong's clamp — see below).
- spikes: `{ "phase_salt": p.depth_index * 131 + k }` (the deterministic per-instance phase K5c §2.4 specifies).
- bomb: `{}` (ignores it — its blast is radial, no room bounds needed; K5b Q-new).

This is a contract widening K5i OWNS (it's the spawn-seam writer), and it stays file-disjoint: K5i edits only
`main_game.gd`, each entity edits only its own files, the shared shape is the documented `spawn_ctx` key set. **K5i's
spawn loop changes** from `hz.setup(rc, player)` to `hz.setup(rc, player, _build_spawn_ctx(desc, p, index))`, where
`_build_spawn_ctx` returns the per-`kind` Dictionary above. To build the ping-pong's `room_bounds`, K5i needs the
*piece* the position came from — so `_per_room_positions` must return `(position, piece, within_room_index)` tuples
(or the spawn loop iterates pieces directly), a small refactor noted in OQ-6 resolution below.

### Per-doc resolutions (OQ-1 … OQ-6)

- **OQ-1 (per-depth-spawn vs total-count-scaled) — RESOLVED: per-room `base + floor(per_depth * depth_index)`, as
  written.** It matches "more with depth" literally + per-room ("around the room"), reuses the J3 density helpers the
  bomb/spikes already want, and naturally fills big deep rooms. Band-total + J2 distribution only wins for a precise total
  budget, which the work-order doesn't ask for, and would require adding a distribution knob to K0's locked set. All three
  entity docs (K5a §2.4, K5b §2.1, K5c §2.4) agree with this per-room law. Technical merit — resolved.

- **OQ-2 (refactor `_density_spawn_positions` vs share cell helpers) — RESOLVED: share the cell helpers, DON'T refactor
  R1.** `_per_room_positions` is a NEW function calling the same `_density_pieces_sorted` / `_density_sorted_cells` /
  `_density_cell_to_world`; R1's `_density_spawn_positions` stays byte-untouched so its fingerprint-frozen plan can't
  regress. The ~15 lines of repeated room-walk skeleton are a cheap price for not touching the frozen baseline path (the
  M1.x house rule, Breakdown §2/§6). Keep the `test_per_room_density.gd` golden-position regression assertion §"Test
  updates" specifies. Technical merit — resolved.

- **OQ-3 (combined perf ceiling) — RESOLVED: ONE shared `NEW_HAZARD_BAND_CEILING` across K5a+K5b+K5c, separate from
  R1's `R1_DENSITY_BAND_CEILING`; value flagged `**NEEDS DIRECTOR REVIEW**` + RG1 perf check.** A single shared ceiling
  bounds the real cost (total `_physics_process` bodies) regardless of how many types are on; per-type ceilings let three
  budgets stack (the thing the ceiling exists to prevent). Keep R1's 64 separate (R1 has its own frozen budget). The
  descriptor order (pingpong→bomb→spikes) determines starvation order under the shared budget — **document it in the code
  comment** so it's intentional, not accidental. The combined worst case is R1's 64 + new ceiling: at the proposed 48 that
  is up to **112 hazard `_physics_process` bodies** + player + pickups. **Two action items:**
  1. **`**NEEDS DIRECTOR REVIEW**` — the ceiling value (48).** It is a perf/fun guard the Director sweeps; recommend
     48 as the starting cap. The per-room caps (`*_per_room_cap`, MUST be >0 in the preset per K0) already bound the common
     case, so the band ceiling is the safety net, rarely hit in normal play.
  2. **RG1 must run a headless tick-time sanity check** at the worst-case combined load (R1 at its ceiling + all three new
     types at theirs) on the web-export target, since the re-gate ships to itch. The three new checks are individually
     cheap (bomb proximity distance test, spike ≤3 segment tests, ping-pong `move_and_slide` + reflect), but 112 bodies
     warrants a measured confirmation, not an assumption. Add this to RG1's verify checklist.

- **OQ-4 (any RNG vs pure-deterministic) — RESOLVED: pure-deterministic stride, NO RNG, for RG1.** Striding sorted cells
  looks scattered enough to satisfy "around the room," stays run-state, never risks the all-off fingerprint
  (`e943ac9c8bc1`), and is fully unit-testable (byte-identical lists). This matches the J3 precedent and all three entity
  docs' placement resolutions. **`**NEEDS DIRECTOR REVIEW**` (deferred):** if the Director judges the striped placement too
  regular at playtest, promote to a local `run_seed ^ K5I_SALT` sub-stream (the B3/E3 pattern — NEVER the global RNG,
  NEVER feeding `fingerprint()`) as a contained follow-up. Recommend pure-deterministic for RG1; the taste call is the
  Director's after seeing it. Non-negotiable constraint either way: never global RNG, never feeds fingerprint.

- **OQ-5 (where K5i tests live) — RESOLVED: a dedicated `tests/test_new_hazard_spawn.gd` + `.tscn`.** K5i introduces a
  distinct helper (`_per_room_positions`) with its own contract (all-off → []; depth scaling; per-room cap; shared band
  ceiling; determinism); a dedicated file keeps it separate from J2's R1 depth-distribution concerns in
  `test_hazard_spread.gd` and is clearer as the new-hazard surface grows. **qa MUST register the new `.tscn` in the CI
  smoke-test scene list.** Keep the §"Test updates" assertion that `_density_spawn_positions` (J3) is byte-unchanged by
  K5i (guards the OQ-2 "don't refactor R1" decision). Process call — qa confirms CI registration at build time.

- **OQ-6 (entity setup reconciliation) — RESOLVED via the shared `spawn_ctx` Dictionary (above).** Concretely, per the
  three entity Resolved Decisions:
  - **ping-pong** NEEDS its room rect (K5a OQ-1 resolved: rect-clamp + wall-bounce) and an initial direction (K5a OQ-4:
    fixed per-index). K5i supplies both via `spawn_ctx`. So K5i's `_per_room_positions` must expose the *piece* each
    position came from (to compute the floor-cell bounding-box `Rect2`). Minimal refactor: have the spawn loop iterate
    `_density_pieces_sorted(band)` itself and call a per-piece placement helper, so it holds the `PlacedPiece p` in scope
    when building `spawn_ctx` — rather than `_per_room_positions` returning bare `Vector2`s. (The placement MATH is
    unchanged; only the loop structure changes so the piece is in scope.)
  - **spikes** needs only a `phase_salt` int (K5c OQ-5) — `p.depth_index * 131 + within_room_index`, in scope from the
    same per-piece loop.
  - **bomb** needs NOTHING beyond the world position (K5b Q-new: its blast is radial, can't leak rooms). Empty `spawn_ctx`.
  This RESOLVES K5i OQ-6's "does setup widen?" — yes, to the optional `spawn_ctx: Dictionary = {}` third param, which K5i
  builds per-type. The contract stays type-agnostic at the call site (one `setup(rc, player, ctx)` line) while feeding each
  entity exactly what it needs. No entity is forced to accept params it ignores beyond the single optional Dictionary.

### Summary — what K5i must change vs its Phase-2 pseudocode

1. Scene path `HSPIKE_SCENE_PATH` → `spike_hazard.tscn`; descriptor `kind` `&"spikes"` → `&"spike"`.
2. Spawn loop iterates pieces (via `_density_pieces_sorted`) so the `PlacedPiece` is in scope; build a per-`kind`
   `spawn_ctx` Dictionary; call `hz.setup(rc, player, spawn_ctx)`.
3. ping-pong `spawn_ctx`: `initial_dir` (fixed per-index) + `room_bounds` (piece floor-cell bbox `Rect2`).
   spikes `spawn_ctx`: `phase_salt` (`depth_index * 131 + k`). bomb `spawn_ctx`: `{}`.
4. Document the descriptor order (pingpong→bomb→spikes) as the intentional shared-ceiling starvation order.
5. Add the RG1 worst-case (112-body) headless tick-time check to the verify checklist.
6. Tests live in a new `tests/test_new_hazard_spawn.{gd,tscn}`, registered in CI; keep the J3 byte-unchanged guard.
