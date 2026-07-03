class_name EncounterBuilder
extends RefCounted
## EncounterBuilder (M1.9 S3) — the opposition POLICY half (exploration v2, Phase C):
## decides WHAT deserves to spawn WHERE, then hands (def, cell, ctx) instructions to the
## policy-free SpawnService. Generation-time client (a) of the service: RNG-FREE stable
## walks over the already-graded band — placement is pure run-state and never feeds
## fingerprint(). Hard caps (per-room / per-band / cap-group ceilings) are the SERVICE's;
## the credit budget and every plan decision live HERE (budget-in-builder /
## caps-in-service, spec §0).
##
## ONE public entry point (`populate`) with two internal lanes, dispatched on the band's
## profile (spec §2.3):
##   • LEGACY lane — empty `opposition_deck` (band 1 / band_greybox): the K5 fair-share
##     machine relocated VERBATIM from main_game._spawn_new_hazards (main @ 6fbded1
##     :385-524, post-S0 shape), driven by the untouched rc.hpp_*/hbomb_*/hspike_* knobs
##     through the legacy adapter. Credits are NOT consulted (§7.2 Q5): the fair-share
##     ceiling split IS this lane's budget, byte-for-byte. All-off → empty active set →
##     zero spawn calls → the e943ac9c8bc1 baseline holds.
##   • DECK lane — non-empty `opposition_deck` (band_two, S7): the credit machine.
##     Budget = floor(BASE_CREDITS * instability(profile.band_depth)); deck filtered by
##     min_band against profile.band_depth (breakdown amendment 10); deterministic
##     authored-order draw (spawn_weight RESERVED this version — §7.2 Q6(iii)); per-def
##     spawn-card counts read off d.params["base_count"]/["count_per_depth"] (amendment
##     10); the service's caps are the hard stop and a refused spawn never spends budget.
## The generic levers overlay both lanes (§3.3): rc.oppositions_enabled is an ADDITIVE
## enable-list riding the deck machinery (never subtracts a band author's deck — §7.2
## Q6(i)); rc.param_overrides re-tunes DEF-DRIVEN params only, at ctx-merge time (§7.2
## Q6(ii) — legacy entity knobs stay driven by the rc fields entities snapshot at
## setup()). Both default empty = perfectly neutral = neither lane's baseline moves.

## TUNABLE (Director sweep at SG2; binds only on deck-driven bands + the extras lane —
## §7.2 Q5): the credit pool a band_depth-1 deck band gets before Instability scaling.
const BASE_CREDITS: int = 24

## K5i per-instance angular stride for the ping-pong's deterministic initial direction —
## the golden angle (~137.5°) so successive instances fan out without repeating, NO RNG.
## RELOCATED from main_game.NEW_HAZARD_GOLDEN_ANGLE (S3; no test reads it off MainGame).
const GOLDEN_ANGLE: float = 2.39996322972865332   # PI * (3 - sqrt(5))

## The legacy adapter's def paths (S0's authored defs). Loaded LAZILY — only for ACTIVE
## (enabled + non-neutral) types, so all-off loads NO def and NO scene (the exploration's
## guarantee; host_scene is an ExtResource, so def load == scene load).
const LEGACY_DEF_PATHS: Dictionary = {
	&"pingpong": "res://data/oppositions/pingpong.tres",   # K5a
	&"bomb": "res://data/oppositions/bomb.tres",           # K5b
	&"spike": "res://data/oppositions/spike.tres",         # K5c
}

## Canonical scan root for rc.oppositions_enabled ids (S0 §9: one def per
## res://data/oppositions/<id>.tres).
const OPPOSITION_DEF_ROOT: String = "res://data/oppositions/%s.tres"


## Instability I as a named static (§7.2 Q3, breakdown amendment 7): the GDD's
## "+15% per band DESCENDED", normalized so band 1 is the clean 1.0 baseline (a band-1
## extras sweep gets exactly BASE_CREDITS; band_two = 1.15). A function, not a system —
## M2's real I system (stats + loot + budget sharing one scalar) replaces this one
## call site.
static func instability(band_depth: int) -> float:
	return 1.0 + 0.15 * float(band_depth - 1)


## Pieces in the stable, deterministic walk order shared by every placement plan:
## depth_index ascending, then offset_cell (y, x) as tiebreak. THE single copy (§2.6.d):
## relocated from main_game._density_pieces_sorted; main_game keeps a thin forwarder so
## the retained R1 lane and the committed golden tests call this one implementation.
static func pieces_depth_sorted(band: Band) -> Array[PlacedPiece]:
	var pieces: Array[PlacedPiece] = []
	for p in band.pieces:
		if p.depth_index < 0:        # ungraded guard (mirrors _build_cell_depth_map)
			continue
		pieces.append(p)
	pieces.sort_custom(func(a: PlacedPiece, b: PlacedPiece) -> bool:
		if a.depth_index != b.depth_index:
			return a.depth_index < b.depth_index
		if a.offset_cell.y != b.offset_cell.y:
			return a.offset_cell.y < b.offset_cell.y
		return a.offset_cell.x < b.offset_cell.x)
	return pieces


## A piece's walkable floor cells in the SAME stable (y, x) order JunkPlacer uses. THE
## single copy (§2.6.d): relocated from main_game._density_sorted_cells (forwarder kept).
static func piece_sorted_cells(p: PlacedPiece) -> Array[Vector2i]:
	var cells: Array[Vector2i] = p.floor_cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return cells


## P10 VERBATIM (main_game._new_hazard_spawn_ctx relocated; main_game keeps a thin
## forwarder for the golden harness's three direct calls — §7.1 C2). Build the per-kind
## entity half of spawn_ctx for one placed instance (the LOCKED setup(cfg, player,
## spawn_ctx) third param):
##   ping-pong: "initial_dir" (deterministic golden-angle fan, NO RNG) + "room_bounds"
##              (the piece's floor-cell bbox in WORLD space).
##   spikes:    "phase_salt" (deterministic per-instance phase = depth_index * 131 + k).
##   bomb:      {} (its blast is radial; it ignores spawn_ctx).
## `index` is the CROSS-TYPE band-wide accumulator (spawned_total) — NOT a per-type
## index — so the fan threads through every type in spawn order (§2.2 step 6; the old
## main_game docstring mis-called this "per-type", corrected here per §7.1). `k` is the
## within-room index.
static func legacy_ctx(kind: StringName, p: PlacedPiece, k: int, index: int,
		room_bounds: Rect2) -> Dictionary:
	match kind:
		&"pingpong":
			return {
				"initial_dir": Vector2.from_angle(float(index) * GOLDEN_ANGLE),
				"room_bounds": room_bounds,
			}
		&"spike":
			return { "phase_salt": p.depth_index * 131 + k }
		_:   # bomb (and any future kind that needs no context)
			return {}


## True iff populate() would issue ZERO service calls for this (profile, rc) — the
## façade's pre-flight so the ALL-OFF path never even creates the SpawnService node
## (S0's "all-off loads nothing, builds nothing" rule, preserved through S3). Cheap and
## load-free on the all-off path: the deck/extras checks are pure emptiness tests and
## the legacy adapter only load()s defs for enabled + non-neutral types (none, when
## all-off).
func is_inert(profile: BandProfile, rc: RunConfig) -> bool:
	if rc == null:
		return true
	if profile != null and not profile.opposition_deck.is_empty():
		return false
	if not rc.oppositions_enabled.is_empty():
		return false
	return _legacy_active_specs(rc).is_empty()


## THE one public entry point. Dispatch (§2.3): non-empty deck => deck lane; else legacy
## lane. rc.oppositions_enabled extras ride the deck machinery in either case — appended
## id-deduped to the deck band's effective deck, or run as a seeded one-off deck on a
## deck-less band (neutral when empty). The caller (main_game's façade) has already
## armed `svc` (begin_band + the &"new_hazards" cap group).
func populate(band: Band, profile: BandProfile, rc: RunConfig, svc: SpawnService) -> void:
	if rc == null or band == null or svc == null:
		return
	var band_depth: int = profile.band_depth if profile != null else 1
	var deck: Array[OppositionDef] = _authored_deck(profile)
	var extras: Array[OppositionDef] = _extras_defs(rc, deck)
	if not deck.is_empty():
		# Deck-driven band: ONE deck walk over deck + extras (extras appended after the
		# authored entries — the band author's priority list stays the head of the draw),
		# ONE credit budget (§2.3/§3.3).
		var effective: Array[OppositionDef] = deck.duplicate()
		effective.append_array(extras)
		_populate_deck(band, effective, band_depth, rc, svc)
	else:
		# Band 1 / band_greybox: the byte-exact parity path. Credits never consulted.
		_populate_legacy(band, rc, svc)
		# Extras on a deck-less band seed a one-off deck through the same machinery at
		# the defs' authored spawn cards (instability(1) = 1.0 → exactly BASE_CREDITS).
		if not extras.is_empty():
			_populate_deck(band, extras, band_depth, rc, svc)


# --- Legacy lane: main_game._spawn_new_hazards relocated VERBATIM (the parity path) ---

## The K5 fair-share machine (P3-P10), statement-for-statement the post-S0
## main_game.gd:416-523 policy body. Deviating from the source ordering here breaks the
## byte-exact preset bar (§7.2 Q1) — the stride is computed AFTER svc.valid_cells()
## (filter-then-stride, §2.6.b), the clamps run per-room-cap → type slice → shared
## ceiling IN THAT ORDER (P7), and `spawned_total` (the CROSS-TYPE accumulator) threads
## into the ping-pong ctx fan (P10).
func _populate_legacy(band: Band, rc: RunConfig, svc: SpawnService) -> void:
	var active: Array[Dictionary] = _legacy_active_specs(rc)
	if active.is_empty():
		return   # all-off / neutral: zero service calls — the baseline holds
	var ceiling: int = SpawnService.NEW_HAZARD_BAND_CEILING   # P11: the constant is service-side
	var n_active: int = active.size()
	var base_share: int = ceiling / n_active
	var remainder: int = ceiling % n_active
	var spawned_total: int = 0                   # band-wide accumulator ACROSS all new types
	var pieces: Array[PlacedPiece] = pieces_depth_sorted(band)   # P4: the single shared walk

	for ti in n_active:
		if spawned_total >= ceiling:
			break
		var d: Dictionary = active[ti]
		# This type's fair slice of the ceiling; earlier descriptor-order types absorb
		# the remainder so the per-type slices sum to exactly the ceiling (L6 fix).
		var type_budget: int = base_share + (1 if ti < remainder else 0)
		var type_spawned: int = 0
		var base: int = d["base"]
		var per_depth: float = d["per_depth"]
		var per_room_cap: int = d["cap"]
		var def: OppositionDef = d["def"]
		var kind: StringName = d["kind"]

		# Walk pieces shallow-first so truncation starves the deepest pieces first
		# within a type, reproducibly (P3/P7 starvation semantics).
		for p in pieces:
			if spawned_total >= ceiling:
				break
			if type_spawned >= type_budget:
				break   # this type has used its fair slice — leave the rest for the others
			var depth: int = p.depth_index
			# BUG7 policy half (P5): never place a new hazard in the depth-0 entry piece.
			if depth <= 0:
				continue
			# P6: "more with depth" — base at depth 0, +per_depth per within-band depth.
			var n: int = base + int(floor(per_depth * float(depth)))
			if per_room_cap > 0:
				n = mini(n, per_room_cap)                    # P7, in
			n = mini(n, type_budget - type_spawned)          #   this
			n = mini(n, ceiling - spawned_total)             #   order
			if n <= 0:
				continue
			# P8: the service's BUG7 predicate applied BEFORE the stride (load-bearing —
			# a refuse-at-spawn design would shift every stride index).
			var cells: Array[Vector2i] = svc.valid_cells(piece_sorted_cells(p))
			if cells.is_empty():
				continue
			var room_bounds: Rect2 = _floor_bounds_world(cells, svc)
			var stride: int = maxi(cells.size() / maxi(n, 1), 1)   # P9
			for k in n:
				var cell: Vector2i = cells[(k * stride) % cells.size()]
				# The per-kind entity ctx (P10) + the S0 service-read reserved keys.
				var ctx: Dictionary = legacy_ctx(kind, p, k, spawned_total, room_bounds)
				ctx["depth"] = p.depth_index
				ctx["run_t_ms"] = 0   # band build ≈ run start; the service never invents a clock
				# The accumulators count SUCCESSFUL spawns. On this parity path the plan
				# already honors every cap the service checks, so refusal never happens
				# (test_encounter_builder asserts a refusal-free preset plan).
				if svc.spawn(def, cell, ctx) != null:
					spawned_total += 1
					type_spawned += 1


## The legacy adapter (§3.2): rc knob groups -> ordered active specs. Reproduces
## P1 (the descriptor table) + P2 (enabled ∧ non-neutral ∧ def-resolves pre-filter)
## exactly; row order = remainder priority (pingpong → bomb → spike), as today. The ONLY
## place the old knob names survive inside the builder. Type-specific entity knobs
## (hpp_speed, hbomb_blast_radius, …) never pass through here — entities snapshot rc at
## setup(), unchanged (S2 discipline).
func _legacy_active_specs(rc: RunConfig) -> Array[Dictionary]:
	var table: Array[Dictionary] = [
		{ "kind": &"pingpong", "enabled": rc.hpp_enabled, "base": rc.hpp_base_count,
			"per_depth": rc.hpp_count_per_depth, "cap": rc.hpp_per_room_cap },
		{ "kind": &"bomb", "enabled": rc.hbomb_enabled, "base": rc.hbomb_base_count,
			"per_depth": rc.hbomb_count_per_depth, "cap": rc.hbomb_per_room_cap },
		{ "kind": &"spike", "enabled": rc.hspike_enabled, "base": rc.hspike_base_count,
			"per_depth": rc.hspike_count_per_depth, "cap": rc.hspike_per_room_cap },
	]
	var out: Array[Dictionary] = []
	for row in table:
		if not row["enabled"]:
			continue   # type off → never load its def/scene (all-off-equivalent)
		if int(row["base"]) <= 0 and float(row["per_depth"]) <= 0.0:
			continue   # neutral knobs → no node for this type (all-off-equivalent)
		var def := load(LEGACY_DEF_PATHS[row["kind"]]) as OppositionDef
		if def == null or def.host_scene == null:
			push_error("EncounterBuilder: opposition def missing at %s."
				% LEGACY_DEF_PATHS[row["kind"]])
			continue
		row["def"] = def
		out.append(row)
	return out


# --- Deck lane: the credit machine (exploration v2, concretized per §7) ---------------

## Deck-driven population. Deterministic and RNG-free: authored deck order IS the draw
## order (id-deduped upstream; spawn_weight RESERVED — §7.2 Q6(iii)); pieces walk the
## same stable shallow-first order as the legacy lane (one discipline); counts come off
## the def's spawn card in `params` (amendment 10), overlaid by rc.param_overrides at
## ctx-merge time (§7.2 Q6(ii)). The budget binds spend; the SERVICE's caps
## (per_room/per_band/cap_group) are the hard stop — a refused spawn never spends.
func _populate_deck(band: Band, deck: Array[OppositionDef], band_depth: int,
		rc: RunConfig, svc: SpawnService) -> void:
	var budget: int = int(floor(float(BASE_CREDITS) * instability(band_depth)))
	var eligible: Array[OppositionDef] = []
	for d in deck:
		if band_depth >= d.min_band:   # min_band gates off the PROFILE's depth (amendment 10)
			eligible.append(d)
	if eligible.is_empty():
		return
	var spawned_total: int = 0   # lane-wide accumulator (threads the ping-pong fan, like legacy)
	for p in pieces_depth_sorted(band):
		if budget <= 0:
			break
		if p.depth_index <= 0:
			continue   # entry safety (P5) holds for deck bands too
		# Cells + bounds are per-PIECE (def-independent): filter-then-stride, one compute.
		var cells: Array[Vector2i] = svc.valid_cells(piece_sorted_cells(p))
		if cells.is_empty():
			continue
		var room_bounds: Rect2 = _floor_bounds_world(cells, svc)
		for d in eligible:
			if budget <= 0:
				break
			var params: Dictionary = _effective_params(d, rc)
			var n: int = int(params.get("base_count", 0)) \
				+ int(floor(float(params.get("count_per_depth", 0.0)) * float(p.depth_index)))
			if n <= 0:
				continue
			var stride: int = maxi(cells.size() / maxi(n, 1), 1)
			for k in n:
				if budget < d.credit_cost:
					break   # spending stops exactly at exhaustion
				var cell: Vector2i = cells[(k * stride) % cells.size()]
				var ctx: Dictionary = legacy_ctx(d.id, p, k, spawned_total, room_bounds)
				ctx["depth"] = p.depth_index
				ctx["run_t_ms"] = 0
				ctx["room_key"] = str(p.offset_cell)   # per-room cap identity (S0 reserved key)
				ctx["params"] = params                 # the ctx-merged def-driven knob bag
				if svc.spawn(d, cell, ctx) != null:    # service refuses at its caps
					budget -= d.credit_cost            # refusal does NOT decrement
					spawned_total += 1


## The authored deck, typed + id-deduped (first occurrence wins) + fail-loud on broken
## entries. BandProfile.opposition_deck is Array[Resource] (S1 Q5 — retightening is a
## noted post-integration follow-up), so entries are cast here.
func _authored_deck(profile: BandProfile) -> Array[OppositionDef]:
	var out: Array[OppositionDef] = []
	if profile == null:
		return out
	var seen: Dictionary = {}
	for r in profile.opposition_deck:
		var d := r as OppositionDef
		if d == null or d.host_scene == null:
			push_error("EncounterBuilder: profile '%s' deck entry is not a valid OppositionDef (%s)."
				% [profile.id, str(r)])
			continue
		if seen.has(d.id):
			continue   # id-deduped: the band author's FIRST entry wins
		seen[d.id] = true
		out.append(d)
	return out


## rc.oppositions_enabled -> loaded defs (the ADDITIVE enable-list, §7.2 Q6(i)).
## List order is the draw order; ids already in the authored deck (or repeated in the
## list) are deduped — the lever appends, never overrides. Lazy: an empty list loads
## nothing (the all-off guarantee extends to the lever).
func _extras_defs(rc: RunConfig, deck: Array[OppositionDef]) -> Array[OppositionDef]:
	var out: Array[OppositionDef] = []
	if rc == null or rc.oppositions_enabled.is_empty():
		return out
	var seen: Dictionary = {}
	for d in deck:
		seen[d.id] = true
	for id in rc.oppositions_enabled:
		if seen.has(id):
			continue
		var def := load(OPPOSITION_DEF_ROOT % String(id)) as OppositionDef
		if def == null or def.host_scene == null:
			push_error("EncounterBuilder: oppositions_enabled id '%s' has no def at %s."
				% [id, OPPOSITION_DEF_ROOT % String(id)])
			continue
		seen[id] = true
		out.append(def)
	return out


## The def's spawn-card/knob bag with rc.param_overrides overlaid (String or StringName
## keyed — the .tres/JSON side authors String keys). DEF-DRIVEN params only (§7.2
## Q6(ii)): the legacy lane never calls this, so legacy entity knobs stay single-driven.
func _effective_params(d: OppositionDef, rc: RunConfig) -> Dictionary:
	var out: Dictionary = d.params.duplicate(true)
	if rc == null or rc.param_overrides.is_empty():
		return out
	var entry: Variant = rc.param_overrides.get(String(d.id),
		rc.param_overrides.get(d.id, null))
	if entry is Dictionary:
		for k: Variant in (entry as Dictionary):
			out[String(k)] = (entry as Dictionary)[k]
	return out


## The encompassing Rect2 of a piece's (already-filtered, sorted) floor cells projected
## to WORLD space via the service's cell_to_world — the same projection main_game's
## _piece_floor_bounds_world uses (svc is armed with the same cell size), so the
## ping-pong reflects within the identical room rect (§7.1 C3: bounds stay policy-side).
func _floor_bounds_world(cells: Array[Vector2i], svc: SpawnService) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var bounds := Rect2(svc.cell_to_world(cells[0]), Vector2.ZERO)
	for c in cells:
		bounds = bounds.expand(svc.cell_to_world(c))
	return bounds
