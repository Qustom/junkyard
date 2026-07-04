class_name SplitterHazard
extends CharacterBody2D
## SplitterHazard (S6b, M1.9) — "Fault": the slow-pursuer hazard that SPLITS on a
## thrown-item kill. The proof of the mid-run `svc.spawn` client — v2 client (b):
## children are spawned mid-run, in reaction to a player-caused throw-death, through
## the exact same SpawnService boundary the builder uses (capped by the same registry,
## logged by the same central &"spawned" emit). Two defs share this one script:
## `splitter` (the deck-placed parent) and `splitter_child` (never deck-listed — it
## only ever arrives via the parent's death hook). The child .tscn is a thin variant
## of the parent scene setting `def_id`/greybox exports (get_def_id() must equal the
## def's id on a bare instance — the def-schema host-contract check).
##
## Composition (S2 components; spec Resolved Decisions Q10):
##   ChaseMove      — the slow toward-player steer (chase_speed = move_speed, no
##                    per-depth scaling; walls stop it — refuge is a feature).
##   LethalContact  — mode &"radius": flat catch_radius distance test, BUG6 rising-
##                    edge latch, emit-always + the L5 `kills` gate (children are
##                    gated too; GameState._run_ended owns run-end idempotency).
##   ThrowInteraction — the S2 death seam: `death_handler` set here, so a ThrownItem
##                    kill routes to _handle_throw_death (split, then free SELF via
##                    svc.despawn — return true = "do not free me again").
##
## DETERMINISM (spec §1.4, Q7 resolved): splits are legitimately RUN-STATE — they
## happen strictly after generation, through a service that cannot reach the
## generation RNG, so no number of splits can move the band fingerprint. Child cells
## are still derived DETERMINISTICALLY-per-split from the parent position (the fixed
## _ring_offset table, NO RNG) for testability + uniform RNG-free discipline.
##
## Params (from the def's knob bag, ctx-merged by the deck lane; per-instance ctx
## overrides win — the v2 override tier the parent uses to hand children their
## speed/generations): move_speed, catch_radius, aggro_radius, child_count,
## child_speed_mult, generations, split_on, child_spread, child_despawn_s (+ the
## base_count / count_per_depth spawn-card keys read by the S3 builder, not by this
## host).
##
## AGGRO LATCH (FBM19/FB3, Director-directed): the splitter IDLES until the player
## first comes within `aggro_radius` px, then latches aggro PERMANENTLY (no de-aggro
## — once it has seen you, it follows). LethalContact still ticks while idle, so
## walking into a dormant Fault is still a catch. `aggro_radius = 0` = legacy
## always-chase (the neutral back-compat value; the child def ships 0 — shards are
## born of player aggression and chase from frame one). Pure run-state distance
## test, NO RNG.
##
## ALL-OFF: no deck lists it and `oppositions_enabled` is empty by default, so this
## scene is never instantiated — the e943ac9c8bc1 control is untouched. This entity
## NEVER calls the global RNG autoload.

## One def path per id under res://data/oppositions/ (the S0 §9 layout — the same
## root EncounterBuilder scans for oppositions_enabled ids).
const DEF_PATH_FMT := "res://data/oppositions/%s.tres"
## The cross-def reference: the def the death hook spawns (§2.2 — never in a deck).
const CHILD_DEF_ID := &"splitter_child"

## Split-burst greybox juice (presentation only — spec §6): a quick hot flash at the
## death point so "I threw → it split" reads causally. Tween-safe headless.
const BURST_COLOR := Color(0.85, 0.85, 0.95)
const BURST_GROW := 1.6
const BURST_TIME_S := 0.18
## Parent-only "unstable shiver" (spec §6) — pure presentation, physics-driven.
const JITTER_PX := 1.5

## The def identity of THIS instance (&"splitter" or &"splitter_child") — set per
## .tscn variant so a bare (un-setup) instance already reports the right id for the
## schema host-contract check and thrown_item's kind resolution.
@export var def_id: StringName = &"splitter"
## Greybox blob look (spec §6): the child is literally the parent silhouette at
## ~half scale, one shade brighter — "it made smaller copies of itself".
@export var blob_radius: float = 20.0
@export var blob_color: Color = Color(0.4, 0.5, 0.6)

var _cfg: RunConfig = null          # snapshot at setup (bomb_hazard.gd:61 discipline)
var _player: Node2D = null
var _ctx: Dictionary = {}           # per-instance spawn context (v2 override tier)
var _params: Dictionary = {}        # effective knob bag: own def params <- ctx["params"]
var _move_speed: float = 0.0        # resolved speed (ctx "move_speed" override wins)
var _generations: int = 0           # remaining split depth (ctx "generations" wins)
var _aggro_radius: float = 0.0      # FB3 wake distance (px); <= 0 = legacy always-chase
var _aggroed: bool = false          # FB3 permanent latch — set once, never cleared
var _despawn_left: float = 0.0      # child_despawn_s countdown; <= 0 = no mercy timer
var _spawn_time: float = 0.0        # host-owned self-timed run clock (R1 §4 pattern)
var _own_def: OppositionDef = null  # lazy-loaded by def_id (already resource-cached)

var _move: ChaseMove = null
var _lethal: LethalContact = null
var _throw: ThrowInteraction = null

@onready var _tell: Polygon2D = $Tell


func _ready() -> void:
	# Q4 discipline: adopt .tscn-declared components when present, instance defaults
	# otherwise. The refs below fix the tick order in host code order.
	_move = OppositionComponent.acquire(self, ChaseMove) as ChaseMove
	_lethal = OppositionComponent.acquire(self, LethalContact) as LethalContact
	_throw = OppositionComponent.acquire(self, ThrowInteraction) as ThrowInteraction
	# The S6b seam: a throw-kill resolves HERE (split-then-free, return true) with
	# ZERO thrown_item.gd edits (the S2 locked delegation shape).
	_throw.death_handler = _handle_throw_death
	_seat_tell()


## LOCKED family signature — setup(cfg, player, spawn_ctx). Reads its knob bag from
## its OWN def's params, overlaid by ctx["params"] (the deck lane's merged bag /
## the parent's child bag), then the discrete per-instance ctx overrides
## ("move_speed", "generations", "kills") — the v2 per-instance tier.
func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
	_cfg = cfg
	_player = player
	_ctx = spawn_ctx
	_spawn_time = 0.0
	_params = _resolve_effective_params(spawn_ctx)
	_move_speed = float(spawn_ctx.get("move_speed", _params.get("move_speed", 0.0)))
	_generations = int(spawn_ctx.get("generations", _params.get("generations", 0)))
	_aggro_radius = float(_params.get("aggro_radius", 0.0))
	_aggroed = _aggro_radius <= 0.0   # 0 = legacy always-chase; re-setup re-derives (S4 respawn)
	_despawn_left = float(_params.get("child_despawn_s", 0.0))
	var p := {
		"chase_speed": _move_speed,       # slow pursuer — ChaseMove verbatim reuse
		"speed_per_depth": 0.0,           # no depth scaling (the parent is a constant)
		"contact_radius": float(_params.get("catch_radius", 0.0)),
		"kills": _resolve_kills(spawn_ctx),
		"def_id": def_id,
		"emit_family": &"new_hazard_killed",   # K5 hazard-kills-player family (kind = id)
		"lethal_mode": &"radius",              # auto per-frame flat-radius test + BUG6 latch
		"latch_rearm": true,
		"throw_mode": &"die",                  # inert — death_handler overrides resolution
	}
	_move.bind(self, player, p, spawn_ctx)
	_lethal.bind(self, player, p, spawn_ctx)   # re-setup starts un-latched (BUG6)
	_throw.bind(self, player, p, spawn_ctx)
	_seat_tell()


func _physics_process(delta: float) -> void:
	if _player == null or _cfg == null or not is_instance_valid(_player):
		return                                 # the family guard, verbatim
	_spawn_time += delta
	# Optional mercy timer (Q4 knob; ratified default 0 = OFF — the lasting mess IS
	# the consequence). A timed expiry is a plain removal: NO split (split_on is a
	# death-qualifier and this is not a throw-death), registry kept honest via despawn.
	if _despawn_left > 0.0:
		_despawn_left -= delta
		if _despawn_left <= 0.0:
			_free_self()
			return
	var depth: int = GameState.current_depth_index   # ONE live depth read (BUG2)
	# FB3 aggro latch: idle until the player first comes within _aggro_radius, then
	# chase forever (no de-aggro). Plain run-state distance test — deterministic, no RNG.
	if not _aggroed \
			and global_position.distance_to(_player.global_position) <= _aggro_radius:
		_aggroed = true
	if _aggroed:
		_move.tick_chase(delta, depth)   # slow steer; walls stop it (refuge intact)
	_lethal.tick(delta)                # radius test -> BUG6 latch -> emit -> L5 gate
	                                   # (ticks while idle too — bumping a dormant
	                                   # Fault is still a catch)
	if _tell != null and def_id != CHILD_DEF_ID:
		# Parent-only faint shiver — the "unstable" Fault read (presentation only).
		_tell.position = Vector2(sin(_spawn_time * 9.0), cos(_spawn_time * 7.0)) * JITTER_PX


## The host-owned self-timed run clock (both signal families share this timestamp).
func run_clock_ms() -> int:
	return int(_spawn_time * 1000.0)


## Stable telemetry/def id (S2 Q5 rider — service-spawned nodes get auto-uniquified
## names; this keeps thrown_item's kind + the registry honest for both defs).
func get_def_id() -> StringName:
	return def_id


## The resolved pursuit speed (children read back ~parent x child_speed_mult) —
## exposed for tests/debug; not a gameplay surface.
func current_move_speed() -> float:
	return _move_speed


## The thrown-item death seam (S2 locked shape): ThrownItem calls this after its
## emit pair; the ThrowInteraction routes to death_handler (below). TRUE = "I
## handled my own death — do not free me again."
func resolve_throw_death(killer_ctx: Dictionary) -> bool:
	return _throw.resolve_throw_death(killer_ctx)


# --- The death-spawn hook (the point of the task) ---------------------------------

## A qualifying throw-death: split (if this tier still has generations left), then
## free SELF via svc.despawn (keeps the live registry honest — a freed parent
## re-opens cap headroom for the children being spawned after it, per the Wave-1
## live-registry canon). Both split_on values (&"throw_death" / &"any_death")
## qualify here — a throw kill always splits; M1 has no non-throw removal, so
## &"any_death" is a forward-compat knob, not a live branch.
func _handle_throw_death(_killer_ctx: Dictionary) -> bool:
	if _generations > 0:
		_do_split()
	_free_self()
	return true


## Request child_count children from the service at deterministic-per-split cells
## (fixed ring around the parent — NO RNG, Q7/Q9 resolved). Cap refusal is graceful
## and silent-correct: a null from svc.spawn simply means that shard does not appear
## (the safety ceiling doing its job); each refusal logs one &"split_refused" row
## (the SG2 cap-pressure signal). One &"split" row marks the split itself —
## hazard-lifecycle vocabulary, kept off both death channels (L1 precedent).
##
## FBM19/FB1: a split at the death point is GAMEPLAY, not room dressing — the child
## ctx sets "ignore_entry_safety" + "ignore_room_cap" so placement policy meant for
## generation-time spawn-camping (the BUG7 entry radius, per_room_cap=2) cannot
## silently swallow shards mid-run (a parent killed near the band entry, or a second
## parent dying in the same room, previously "just didn't split"). The REAL ceilings
## still refuse: per_band_cap=8 + the &"new_hazards" group cap (D-RAT-2's "children
## capped by the service registry" holds; &"split_refused" telemetry stays for those).
func _do_split() -> void:
	var svc := get_tree().get_first_node_in_group(&"spawn_service") as SpawnService
	if svc == null:
		return   # no service (no band) — nothing to spawn into
	var child_def := load(DEF_PATH_FMT % String(CHILD_DEF_ID)) as OppositionDef
	if child_def == null or child_def.host_scene == null:
		push_error("SplitterHazard: child def missing at %s." % [DEF_PATH_FMT % String(CHILD_DEF_ID)])
		return
	var depth: int = GameState.current_depth_index
	var ms: int = run_clock_ms()
	var n: int = int(_params.get("child_count", 0))
	var spread: float = float(_params.get("child_spread", 0.0))
	var child_speed: float = _move_speed * float(_params.get("child_speed_mult", 1.0))
	# The child's own def bag + rc.param_overrides — the same DEF-DRIVEN merge the
	# deck lane applies (EncounterBuilder._effective_params discipline), so Director
	# sweeps of splitter_child params reach mid-run children too.
	var child_params := _effective_def_params(child_def, _cfg)
	for k in n:
		var cell: Vector2i = svc.world_to_cell(global_position + _ring_offset(k, n, spread))
		var child_ctx := {
			"params": child_params,
			"move_speed": child_speed,          # the live lever: parent speed x mult
			"generations": _generations - 1,    # children of the default tier are TERMINAL
			"split_index": k,
			"cell": cell,
			"depth": depth,                     # C6: the central &"spawned" emit payload
			"run_t_ms": ms,
			"ignore_entry_safety": true,        # FB1: shards spawn where the parent died
			"ignore_room_cap": true,            # FB1: per_room_cap is generation dressing
		}
		if _ctx.has("room_key"):
			child_ctx["room_key"] = _ctx["room_key"]   # honest per-room accounting
		if svc.spawn(child_def, cell, child_ctx) == null:
			# Refused at per_band_cap / the &"new_hazards" ceiling / an invalid cell:
			# the shard is dropped, never retried (§2.5).
			EventBus.opposition_event.emit(def_id, &"split_refused", depth, ms)
	EventBus.opposition_event.emit(def_id, &"split", depth, ms)
	_spawn_burst()


## De-register + free through the service (registry stays honest); plain queue_free
## when no service exists (bare-harness path).
func _free_self() -> void:
	var svc := get_tree().get_first_node_in_group(&"spawn_service") as SpawnService
	if svc != null:
		svc.despawn(self)
	else:
		queue_free()


## The k-th of n points on a circle of radius spread_px — a PURE function of
## (k, n, spread): deterministic-per-split, NO RNG (Q7). First child straight up.
static func _ring_offset(k: int, n: int, spread_px: float) -> Vector2:
	if n <= 0:
		return Vector2.ZERO
	var angle: float = -PI / 2.0 + TAU * float(k) / float(n)
	return Vector2(cos(angle), sin(angle)) * spread_px


# --- Param resolution --------------------------------------------------------------

## Effective knob bag: own def params (lazy-loaded by def_id — the def is already
## resource-cached by whoever spawned us) overlaid by ctx["params"] (the deck lane's
## rc.param_overrides-merged bag, or the parent's child bag).
func _resolve_effective_params(ctx: Dictionary) -> Dictionary:
	var d := _own_def_res()
	var out: Dictionary = d.params.duplicate(true) if d != null else {}
	var merged: Variant = ctx.get("params")
	if merged is Dictionary:
		for k: Variant in (merged as Dictionary):
			out[String(k)] = (merged as Dictionary)[k]
	return out


## The L5 gate source: the def's typed `kills` field (new defs have no legacy rc
## knob), with a per-instance ctx override for harness/sweep use.
func _resolve_kills(ctx: Dictionary) -> bool:
	var d := _own_def_res()
	var def_kills: bool = d.kills if d != null else true
	return bool(ctx.get("kills", def_kills))


func _own_def_res() -> OppositionDef:
	if _own_def == null:
		_own_def = load(DEF_PATH_FMT % String(def_id)) as OppositionDef
	return _own_def


## Mirror of EncounterBuilder._effective_params (kept in-sync by hand — a 6-line
## merge; S6b may not touch the builder): def params + rc.param_overrides overlay.
static func _effective_def_params(d: OppositionDef, rc: RunConfig) -> Dictionary:
	var out: Dictionary = d.params.duplicate(true)
	if rc == null or rc.param_overrides.is_empty():
		return out
	var entry: Variant = rc.param_overrides.get(String(d.id),
		rc.param_overrides.get(d.id, null))
	if entry is Dictionary:
		for k: Variant in (entry as Dictionary):
			out[String(k)] = (entry as Dictionary)[k]
	return out


# --- Greybox tell (inline placeholder — no sprite sheets, no AnimationTree) --------

## Seat the blob look: a 12-gon "soft blob" silhouette, scaled/tinted per variant
## (parent ~1.4x player, child the same silhouette at ~half scale, one shade
## brighter — the "it made smaller copies of itself" read, spec §6). Filter OFF is
## project-wide; a bare instance seats itself in _ready for the schema harness.
func _seat_tell() -> void:
	if _tell == null:
		return
	_tell.color = blob_color
	if _tell.polygon.is_empty():
		_tell.polygon = _blob_points(blob_radius)


static func _blob_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## One-shot split burst at the exact death point (spec §6): the parent visibly
## "comes apart" — quick hot flash, pop-and-fade. Parented under the band container
## (our parent) so it survives our free and dies with the band. Pure presentation.
func _spawn_burst() -> void:
	var holder := get_parent()
	if holder == null:
		return
	var burst := Polygon2D.new()
	burst.polygon = _blob_points(blob_radius)
	burst.color = BURST_COLOR
	holder.add_child(burst)
	burst.global_position = global_position
	var tw := burst.create_tween()
	tw.tween_property(burst, "scale", Vector2(BURST_GROW, BURST_GROW), BURST_TIME_S)
	tw.parallel().tween_property(burst, "modulate:a", 0.0, BURST_TIME_S)
	tw.tween_callback(burst.queue_free)
