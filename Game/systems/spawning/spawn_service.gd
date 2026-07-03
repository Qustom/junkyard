class_name SpawnService
extends Node
## SpawnService (M1.9 S0) — the policy-free spawn MECHANISM (exploration v2, Phase A).
##
## Owns instantiation, placement validation (the BUG7 entry-safe exclusion), the live-
## instance registry (+ per-instance spawn-cell bookkeeping), scoped cap-group / per-def
## cap enforcement, the run-end lifecycle (clear_all), the LOCKED
## setup(cfg, player, spawn_ctx) entity handshake, and the central
## opposition_event(id, &"spawned", depth, run_t_ms) emit. It NEVER decides what
## deserves to spawn — descriptor tables, fair-share, depth-scaled counts are policy
## (main_game today, EncounterBuilder from S3). The one boundary method is
## spawn(def, cell, ctx) -> Node.
##
## Lifetime: per-dive node, lazily created as a child of MainGame (NEVER under the band
## container — _clear_band() frees the container's children and the golden spawn-seam
## harness counts them). Group-resolved via &"spawn_service" so mid-run clients (S6b,
## the debug menu) find it without an autoload ref. Run-state ONLY — nothing here is
## ever persisted (run/meta boundary, TDD §2). Zero RNG: the service is a pure executor
## of (def, cell, ctx) instructions and never touches the generation stream; placement
## in this seam never feeds fingerprint().
##
## spawn_ctx reserved SERVICE-READ keys (all primitives, all optional — everything else
## in ctx is the policy-built, entity-read channel and passes through opaquely):
##   "depth": int        — payload for the &"spawned" emit (default 0).
##   "run_t_ms": int     — run-clock stamp for the emit; the service NEVER invents a
##                         clock (entities self-time; generation-time spawns pass 0).
##   "room_key": String  — per-room cap identity (str(piece.offset_cell)); the per-room
##                         tier only binds when both per_room_cap > 0 and a key is given.
##   "ignore_room_cap": bool — v2's explicit set-piece escape hatch: skips ONLY the
##                         per-room tier, never band/group ceilings. No S0 caller.

## K5i band-wide ceiling across ALL new-hazard types combined — RELOCATED here from
## main_game.gd (S0). main_game keeps a forwarding const so the committed golden tests
## (test_new_hazard_spawn.gd:44, test_rg1_m14_verify.gd:299/:403) read it unmodified.
## Enforced as the &"new_hazards" cap group registered by the policy per band; in
## Phase A the policy's own min() stops the loop one step earlier, so the two
## enforcement points agree by construction (belt-and-braces, byte-equivalent).
const NEW_HAZARD_BAND_CEILING: int = 48

## BUG7 entry-safe exclusion radius in CELL-WIDTHS — RELOCATED NEW_HAZARD_SPAWN_SAFE_CELLS
## (main_game keeps a forwarding const for the golden harness). Any candidate cell whose
## world centre is within this many cells of the entry spawn is refused: a couple of
## cells clears the largest hazard kill radius (feedback #7 frame-0 spawn-kill fix).
const SPAWN_SAFE_CELLS: float = 2.5

## Returned by spawn_cell_of() for a node this service never registered.
const UNREGISTERED_CELL := Vector2i.MAX

var _container: Node2D = null                # parent of spawned nodes (the band container)
var _cell_size_px: int = 16                  # cell→world projection scale (begin_band)
var _entry_pos: Vector2 = Vector2.INF        # BUG7 exclusion centre; INF = unarmed (no filter)
var _safe_dist_px: float = 0.0
var _player: Node2D = null                   # resolved once per band via the &"player" group
var _cfg: RunConfig = null                   # the run config threaded into every setup()
# Registry: def_id (StringName) -> Array[Dictionary] of entries
# { "node": Node, "cell": Vector2i, "room_key": String }. Single-writer discipline:
# only spawn/despawn/clear_all mutate it. Freed nodes are lazily compacted
# (is_instance_valid sweep on query) so an entity freed with the band (never
# individually despawned — all of today's hazards) can't inflate counts.
var _live: Dictionary = {}
var _cap_groups: Dictionary = {}             # group (StringName) -> ceiling (int)
var _def_groups: Dictionary = {}             # def_id -> cap_group recorded at spawn


func _enter_tree() -> void:
	add_to_group(&"spawn_service")


## Per-band arming. Called by the policy (start_new_run's spawn seam) after the band is
## materialised and BEFORE any spawn: stores the container ref + projection scale + the
## BUG7 exclusion inputs, resolves the player once (the exact main_game.gd:396-397
## null-safe expression, off the CONTAINER's tree so a bare out-of-tree harness works),
## and binds the run config the LOCKED setup() handshake threads into every entity.
## entry_pos == Vector2.INF leaves the service UNARMED (no entry exclusion) — the
## direct-test path.
func begin_band(container: Node2D, cell_size_px: int, entry_pos: Vector2,
		cfg: RunConfig) -> void:
	_container = container
	_cell_size_px = cell_size_px
	_entry_pos = entry_pos
	_safe_dist_px = SPAWN_SAFE_CELLS * float(cell_size_px)
	_cfg = cfg
	var tree := container.get_tree() if container != null else null
	_player = tree.get_first_node_in_group(&"player") as Node2D if tree != null else null


## Register (or re-register) a shared cap-group ceiling. A group not registered here is
## an absent tier (spawns referencing it pass unbounded — 0/absent = "tier off",
## matching the per_room_cap > 0 guard convention).
func set_cap_group(group: StringName, ceiling: int) -> void:
	_cap_groups[group] = ceiling


## THE boundary method (v2 §headline): validate → caps → instantiate → parent → place →
## reset interpolation → register → setup(cfg, player, ctx) → emit &"spawned".
## Returns the live node, or null on refusal (missing def/scene, entry-unsafe cell,
## cap full). The policy decides def/cell/ctx; the service only executes.
func spawn(def: OppositionDef, cell: Vector2i, ctx: Dictionary = {}) -> Node:
	if def == null or def.host_scene == null:
		push_error("SpawnService: def/host_scene missing for %s." % [def])
		return null
	if _container == null:
		push_error("SpawnService: spawn() before begin_band() — no container.")
		return null
	if not _cell_valid(cell):        # BUG7 re-check (belt-and-braces; non-binding when
		return null                  # the policy pre-filtered via valid_cells())
	if not _caps_allow(def, ctx):
		return null
	var hz := def.host_scene.instantiate() as Node2D
	if hz == null:
		push_error("SpawnService: host_scene for %s did not instantiate a Node2D." % def.id)
		return null
	_container.add_child(hz)
	hz.global_position = cell_to_world(cell)
	# M1.7 interp-ghost fix rides with instantiation: no one-frame render from origin.
	hz.reset_physics_interpolation()
	_register(def, hz, cell, String(ctx.get("room_key", "")))
	hz.setup(_cfg, _player, ctx)     # the LOCKED three-arg handshake (entities snapshot cfg)
	EventBus.opposition_event.emit(def.id, &"spawned",
		int(ctx.get("depth", 0)), int(ctx.get("run_t_ms", 0)))
	return hz


## Batch convenience: [{ "def": OppositionDef, "cell": Vector2i, "ctx": Dictionary }, …].
## Per-request independence is the contract (OQ-9 resolved): partial batches are fine,
## refusals leave a null IN PLACE, order preserved. No atomicity semantics.
func spawn_batch(reqs: Array) -> Array[Node]:
	var out: Array[Node] = []
	for r in reqs:
		out.append(spawn(r["def"], r["cell"], r.get("ctx", {})))
	return out


## Would spawn() succeed right now? Cap + placement pre-check, zero side effects.
func can_afford(def: OppositionDef, cell: Vector2i) -> bool:
	return def != null and def.host_scene != null \
		and _cell_valid(cell) and _caps_allow(def, {})


## Live (validity-swept) instance count for one def id.
func live_count(def_id: StringName) -> int:
	return _compact(def_id).size()


## Live (validity-swept) instances for one def id — S4's respawn-with-new-params
## enumeration (orchestrator adjudication #4).
func live_instances(def_id: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for e in _compact(def_id):
		out.append(e["node"])
	return out


## Band-wide live total across every registered def.
func live_total() -> int:
	var total := 0
	for def_id in _live:
		total += _compact(def_id).size()
	return total


## The cell a registered node was spawned at (adjudication #4: S4 respawns at the SAME
## cell without re-deriving placement). UNREGISTERED_CELL (Vector2i.MAX) if unknown.
func spawn_cell_of(node: Node) -> Vector2i:
	for def_id in _live:
		for e in _live[def_id]:
			if e["node"] == node:
				return e["cell"]
	return UNREGISTERED_CELL


## Explicit removal (Splitter parent death, timed expiry — S6b's; no S0 caller):
## de-register + queue_free.
func despawn(node: Node) -> void:
	_deregister(node)
	if node != null and is_instance_valid(node):
		node.queue_free()


## Run-end lifecycle: free every registered instance + reset ALL accounting (registry +
## cap groups). Called from _clear_band(); idempotent alongside the container-child free
## (queue_free on an already-freed node is guarded by is_instance_valid). Implicitly
## re-arms for the next begin_band().
func clear_all() -> void:
	for def_id in _live:
		for e: Dictionary in _live[def_id]:
			# Entries can hold nodes already freed with the band; a freed instance
			# can't pass through a typed Node local, so test the value in place.
			if is_instance_valid(e["node"]):
				(e["node"] as Node).queue_free()
	_live.clear()
	_cap_groups.clear()
	_def_groups.clear()


## The RELOCATED BUG7 cell filter (main_game.gd:468-469 verbatim): keep cells whose
## world centre is >= the safe radius from the entry spawn. Exposed as a queryable so
## the policy can FILTER-THEN-STRIDE at its exact current sequence point — refusing at
## spawn() instead would shift every stride index (different cells = behavior change).
## An unarmed service (entry_pos == Vector2.INF) filters nothing.
func valid_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		if _cell_valid(c):
			out.append(c)
	return out


## Band-global cell → world pixel, centred — the same projection as
## main_game._density_cell_to_world (:761-763), configured by begin_band(). Public
## (adjudication #5) so mid-run clients can project without reaching into main_game.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * _cell_size_px) \
		+ Vector2(_cell_size_px, _cell_size_px) * 0.5


## World pixel → band-global cell: the floor-division inverse of cell_to_world
## (adjudication #5 — S6b's mid-run splits snap the parent's world position to a cell;
## there is no spawn_world(), clients compose spawn(def, world_to_cell(pos), ctx)).
func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / float(_cell_size_px)).floor())


# --- internals ----------------------------------------------------------------

func _cell_valid(cell: Vector2i) -> bool:
	if _entry_pos == Vector2.INF:
		return true                  # unarmed (direct-test path) — no exclusion
	return cell_to_world(cell).distance_to(_entry_pos) >= _safe_dist_px


## Cap stack (OQ-5 resolved): the MINIMUM binds — a spawn must pass every applicable
## tier. Check order per_band → cap_group → per_room (cheapest first; per-room needs
## ctx room identity). 0 / unregistered / missing room_key = "tier absent".
## ignore_room_cap skips ONLY the per-room tier (a set-piece may crowd a room, never
## flood a band). Counts are live (validity-swept) registry counts.
func _caps_allow(def: OppositionDef, ctx: Dictionary) -> bool:
	if def.per_band_cap > 0 and _compact(def.id).size() >= def.per_band_cap:
		return false
	if def.cap_group != &"" and _cap_groups.has(def.cap_group):
		if _group_live_count(def.cap_group) >= int(_cap_groups[def.cap_group]):
			return false
	if def.per_room_cap > 0 and not bool(ctx.get("ignore_room_cap", false)):
		var room_key := String(ctx.get("room_key", ""))
		if room_key != "":
			var in_room := 0
			for e in _compact(def.id):
				if e["room_key"] == room_key:
					in_room += 1
			if in_room >= def.per_room_cap:
				return false
	return true


func _group_live_count(group: StringName) -> int:
	var total := 0
	for def_id in _def_groups:
		if _def_groups[def_id] == group:
			total += _compact(def_id).size()
	return total


func _register(def: OppositionDef, node: Node, cell: Vector2i, room_key: String) -> void:
	if not _live.has(def.id):
		_live[def.id] = []
	(_live[def.id] as Array).append({ "node": node, "cell": cell, "room_key": room_key })
	_def_groups[def.id] = def.cap_group


func _deregister(node: Node) -> void:
	for def_id in _live:
		var entries: Array = _live[def_id]
		for i in range(entries.size() - 1, -1, -1):
			if entries[i]["node"] == node:
				entries.remove_at(i)


## Validity sweep on query: drop entries whose node was freed without despawn() (all of
## today's hazards die with the band). Returns the surviving entries for def_id.
func _compact(def_id: StringName) -> Array:
	if not _live.has(def_id):
		return []
	var entries: Array = _live[def_id]
	for i in range(entries.size() - 1, -1, -1):
		# A freed instance can't pass through a typed Node local (see clear_all),
		# so test the entry's value in place.
		if not is_instance_valid(entries[i]["node"]):
			entries.remove_at(i)
	return entries
