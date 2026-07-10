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
## ONE public entry point (`populate`), ONE internal lane — the DECK lane (V3, M1.12:
## the legacy K5 fair-share machine was retired; band_greybox now carries a real deck of
## pingpong/bomb/spike, so band 1 routes through the same credit machine as every other
## band — "exactly one way to add an opposition"):
##   • DECK lane — the credit machine. Budget = BandProfile.opposition_credits when > 0
##     (band_greybox = 48, the preserved K5 body density), else
##     floor(BASE_CREDITS * instability(profile.band_depth)) (band_two/three/four); deck
##     filtered by min_band against profile.band_depth (breakdown amendment 10);
##     deterministic authored-order draw (spawn_weight RESERVED — §7.2 Q6(iii)); per-def
##     spawn-card counts read off d.params["base_count"]/["count_per_depth"] (amendment
##     10); the service's caps are the hard stop (per-room + per-band + the &"new_hazards"
##     cap-group ceiling 48) and a refused spawn never spends budget; placements are
##     EVEN-SPREAD across the eligible piece depth range per def (FBM19/FB2 — deepest
##     pieces reachable by construction, see _populate_deck). All-off → every card neutral
##     → is_inert() true → zero spawn calls → the e943ac9c8bc1 baseline holds.
## The generic levers overlay both lanes (§3.3): rc.oppositions_enabled is an ADDITIVE
## enable-list riding the deck machinery (never subtracts a band author's deck — §7.2
## Q6(i)); rc.param_overrides re-tunes DEF-DRIVEN params only, at ctx-merge time (§7.2
## Q6(ii) — legacy entity knobs stay driven by the rc fields entities snapshot at
## setup()). Both default empty = perfectly neutral = neither lane's baseline moves.
## Deck rows may be S9 DeckEntry wrappers (def + deck-only param_overrides), unwrapped
## in _authored_deck; ctx-merge precedence is def params < deck-entry overrides <
## rc.param_overrides (breakdown deck-driven-def conventions, D-RAT-2 delivery).

## TUNABLE (Director sweep at SG2; binds only on deck-driven bands + the extras lane —
## §7.2 Q5): the credit pool a band_depth-1 deck band gets before Instability scaling.
const BASE_CREDITS: int = 24

## K5i per-instance angular stride for the ping-pong's deterministic initial direction —
## the golden angle (~137.5°) so successive instances fan out without repeating, NO RNG.
## RELOCATED from main_game.NEW_HAZARD_GOLDEN_ANGLE (S3; no test reads it off MainGame).
const GOLDEN_ANGLE: float = 2.39996322972865332   # PI * (3 - sqrt(5))

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
## (S0's "all-off loads nothing, builds nothing" rule). Cheap and load-free on the
## all-off path: the extras check is a pure emptiness test and the neutral-deck test
## reads only already-loaded def params.
##
## V3 (M1.12): with band_greybox now carrying a K5 deck (pingpong/bomb/spike), a
## NON-EMPTY deck no longer implies "builds something": an all-off rc leaves every card
## NEUTRAL (base_count 0, count_per_depth 0 after the merge) → zero demand → zero spawns.
## The `_deck_all_neutral` fast-path is the direct replacement for the retired
## `_legacy_active_specs(rc).is_empty()` clause — it keeps the byte-exact all-off scene
## tree (no empty SpawnService node) for greybox. band_two's charger/splitter carry real
## authored magnitudes → not neutral → false → builds (correct, unchanged).
func is_inert(profile: BandProfile, rc: RunConfig) -> bool:
	if rc == null:
		return true
	if not rc.oppositions_enabled.is_empty():
		return false
	if profile == null or profile.opposition_deck.is_empty():
		return true
	return _deck_all_neutral(profile, rc)


## True iff EVERY card in the profile's authored deck has zero effective spawn demand
## (base_count <= 0 AND count_per_depth <= 0) under the full ctx-merge (def params <
## deck-entry overrides < rc.param_overrides). The exact analog of the retired
## `_legacy_active_specs` neutrality test, generalized to the deck lane. Load-free: the
## deck defs are already resolved on the profile; only params dictionaries are read.
func _deck_all_neutral(profile: BandProfile, rc: RunConfig) -> bool:
	var deck_overrides: Dictionary = {}
	var deck: Array[OppositionDef] = _authored_deck(profile, deck_overrides)
	for d in deck:
		var params: Dictionary = _effective_params(d, rc, deck_overrides)
		if int(params.get("base_count", 0)) > 0 \
				or float(params.get("count_per_depth", 0.0)) > 0.0:
			return false
	return true


## THE one public entry point. Dispatch (§2.3): non-empty deck => deck lane; else legacy
## lane. rc.oppositions_enabled extras ride the deck machinery in either case — appended
## id-deduped to the deck band's effective deck, or run as a seeded one-off deck on a
## deck-less band (neutral when empty). The caller (main_game's façade) has already
## armed `svc` (begin_band + the &"new_hazards" cap group).
func populate(band: Band, profile: BandProfile, rc: RunConfig, svc: SpawnService) -> void:
	if rc == null or band == null or svc == null:
		return
	var band_depth: int = profile.band_depth if profile != null else 1
	var credits_override: int = profile.opposition_credits if profile != null else 0
	var deck_overrides: Dictionary = {}   # def id -> deck-entry override bag (S9)
	var deck: Array[OppositionDef] = _authored_deck(profile, deck_overrides)
	var extras: Array[OppositionDef] = _extras_defs(rc, deck)
	# V3 (M1.12): ONE lane. Deck + extras (extras appended after the authored entries —
	# the band author's priority list stays the head of the draw), ONE credit budget
	# (§2.3/§3.3). A deck-less band with no extras spawns nothing; the extras lever seeds
	# a one-off deck through the same machinery. The retired legacy K5 lane is now the
	# band_greybox deck (pingpong/bomb/spike), so band 1 routes here like every other band.
	var effective: Array[OppositionDef] = deck.duplicate()
	effective.append_array(extras)
	if effective.is_empty():
		return
	_populate_deck(band, effective, band_depth, rc, svc, deck_overrides, credits_override)


# --- Deck lane: the credit machine (exploration v2, concretized per §7) ---------------

## Deck-driven population. Deterministic and RNG-free: authored deck order IS the draw
## order (id-deduped upstream; spawn_weight RESERVED — §7.2 Q6(iii)); counts come off
## the def's spawn card in `params` (amendment 10), overlaid by the S9 deck-entry
## overrides then rc.param_overrides at ctx-merge time (precedence: def params <
## deck-entry overrides < rc.param_overrides — §7.2 Q6(ii) + breakdown deck-driven-def
## conventions). The budget binds spend; the SERVICE's caps (per_room/per_band/
## cap_group) are the hard stop — a refused spawn never spends.
##
## FBM19/FB2 (Director-directed): DEF-MAJOR + DEPTH-SPREAD. The original piece-major
## shallow-first walk let the credit budget + per-band caps exhaust on the shallow
## pieces, so every deck placement clustered at the band entry and the deep half held
## nothing new. Now each def's placements are EVEN-SPREAD across the eligible piece
## depth range (the J2 even_spread precedent, main_game._hazard_spawn_depths mode 1):
## per def, the plan size is bounded UP FRONT by the budget and its own per_band_cap
## (load-bearing — an unbounded plan would burn its deep slots on refusals and
## re-cluster shallow), then placement i targets piece round(i/(n-1) * (P-1)) over the
## depth-sorted eligible list — t=1 maps to the DEEPEST piece by construction; a
## single placement lands mid-band. Still zero RNG, stable order (authored def order,
## shallow→deep within a def), same per-piece valid_cells/filter-then-stride
## discipline. Neutral cards (demand 0) are skipped unchanged; the legacy lane and
## the all-off/band_greybox controls are untouched by construction (this lane only
## runs on deck bands / the extras lever).
func _populate_deck(band: Band, deck: Array[OppositionDef], band_depth: int,
		rc: RunConfig, svc: SpawnService, deck_overrides: Dictionary = {},
		credits_override: int = 0) -> void:
	# V3 (M1.12): a positive per-profile override (BandProfile.opposition_credits) wins
	# over the standard depth-scaled pool; 0 = the current behaviour for every other band
	# (band_two/three/four unchanged). band_greybox sets 48 to preserve the historical K5
	# body density (the old NEW_HAZARD_BAND_CEILING).
	var budget: int = credits_override if credits_override > 0 \
		else int(floor(float(BASE_CREDITS) * instability(band_depth)))
	var eligible: Array[OppositionDef] = []
	for d in deck:
		if band_depth >= d.min_band:   # min_band gates off the PROFILE's depth (amendment 10)
			eligible.append(d)
	if eligible.is_empty():
		return
	# The eligible piece table, computed ONCE (def-independent): the stable
	# shallow-first walk, minus the entry piece (P5) and pieces with no BUG7-valid
	# cells. Cells + bounds keep the one-compute filter-then-stride discipline.
	var pieces: Array[PlacedPiece] = []
	var piece_cells: Array = []              # Array of Array[Vector2i], parallel to pieces
	var piece_bounds: Array[Rect2] = []
	for p in pieces_depth_sorted(band):
		if p.depth_index <= 0:
			continue   # entry safety (P5) holds for deck bands too
		var cells: Array[Vector2i] = svc.valid_cells(piece_sorted_cells(p))
		if cells.is_empty():
			continue
		pieces.append(p)
		piece_cells.append(cells)
		piece_bounds.append(_floor_bounds_world(cells, svc))
	if pieces.is_empty():
		return
	var spawned_total: int = 0   # lane-wide accumulator (threads the ping-pong fan, like legacy)
	for d in eligible:
		if budget <= 0:
			break
		var params: Dictionary = _effective_params(d, rc, deck_overrides)
		# The def's TOTAL spawn-card demand across the eligible pieces (base + ramp).
		var demand: int = 0
		for p in pieces:
			demand += int(params.get("base_count", 0)) \
				+ int(floor(float(params.get("count_per_depth", 0.0)) * float(p.depth_index)))
		if demand <= 0:
			continue   # neutral card — skipped, no spend (unchanged)
		# Plan size = demand bounded by affordability + the def's own per-band cap.
		var n_plan: int = demand
		if d.credit_cost > 0:
			n_plan = mini(n_plan, budget / d.credit_cost)
		if d.per_band_cap > 0:
			n_plan = mini(n_plan, d.per_band_cap)
		if n_plan <= 0:
			continue
		# Pass 1 — assign placements to pieces by even spread (deepest reachable);
		# the per-piece tallies feed the within-room cell stride in pass 2.
		var assign: Array[int] = []
		var per_piece: Dictionary = {}       # piece index -> assigned count
		for i in n_plan:
			var t: float = 0.5 if n_plan <= 1 else float(i) / float(n_plan - 1)
			var pi: int = int(round(t * float(pieces.size() - 1)))
			assign.append(pi)
			per_piece[pi] = int(per_piece.get(pi, 0)) + 1
		# Pass 2 — execute in shallow→deep order (assign is monotonic in i).
		var k_within: Dictionary = {}        # piece index -> next within-room k
		for pi in assign:
			if budget < d.credit_cost:
				break   # spending stops exactly at exhaustion
			var p: PlacedPiece = pieces[pi]
			var cells: Array[Vector2i] = piece_cells[pi]
			var k: int = int(k_within.get(pi, 0))
			k_within[pi] = k + 1
			var stride: int = maxi(cells.size() / maxi(int(per_piece[pi]), 1), 1)
			var cell: Vector2i = cells[(k * stride) % cells.size()]
			var ctx: Dictionary = legacy_ctx(d.id, p, k, spawned_total, piece_bounds[pi])
			ctx["depth"] = p.depth_index
			ctx["run_t_ms"] = 0
			ctx["room_key"] = str(p.offset_cell)   # per-room cap identity (S0 reserved key)
			ctx["params"] = params                 # the ctx-merged def-driven knob bag
			if svc.spawn(d, cell, ctx) != null:    # service refuses at its caps
				budget -= d.credit_cost            # refusal does NOT decrement
				spawned_total += 1


## The authored deck, typed + id-deduped (first occurrence wins) + fail-loud on broken
## entries. BandProfile.opposition_deck is Array[Resource] (S1 Q5 — retightening is a
## noted post-integration follow-up); rows are EITHER plain OppositionDefs OR S9
## DeckEntry wrappers (mixed array, back-compat) — wrappers are unwrapped to the def
## here so gating/costing/ordering see one uniform typed deck. Each wrapper's
## non-empty param_overrides is recorded into `deck_overrides` (def id -> bag) for
## the ctx-time merge; dedup keeps the FIRST occurrence's overrides too (a later
## duplicate's overrides are dropped with the duplicate, same first-wins rule).
func _authored_deck(profile: BandProfile, deck_overrides: Dictionary = {}) -> Array[OppositionDef]:
	var out: Array[OppositionDef] = []
	if profile == null:
		return out
	var seen: Dictionary = {}
	for r in profile.opposition_deck:
		var raw: Resource = r
		var overrides: Dictionary = {}
		if r is DeckEntry:
			var entry := r as DeckEntry
			raw = entry.def
			overrides = entry.param_overrides
		var d := raw as OppositionDef
		if d == null or d.host_scene == null:
			push_error("EncounterBuilder: profile '%s' deck entry is not a valid OppositionDef (%s)."
				% [profile.id, str(r)])
			continue
		if seen.has(d.id):
			continue   # id-deduped: the band author's FIRST entry wins
		seen[d.id] = true
		out.append(d)
		if not overrides.is_empty():
			deck_overrides[d.id] = overrides
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


## The def's spawn-card/knob bag with the S9 deck-entry overrides then
## rc.param_overrides overlaid, in that order — the LOCKED precedence
## def params < deck-entry overrides < rc.param_overrides (rc keys are String or
## StringName; deck_overrides is keyed by def id, its bags author String keys —
## both normalized to String on merge). DEF-DRIVEN params only (§7.2 Q6(ii)):
## the legacy lane never calls this, so legacy entity knobs stay single-driven.
func _effective_params(d: OppositionDef, rc: RunConfig,
		deck_overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = d.params.duplicate(true)
	var deck_ov: Variant = deck_overrides.get(d.id, null)
	if deck_ov is Dictionary:
		for k: Variant in (deck_ov as Dictionary):
			out[String(k)] = (deck_ov as Dictionary)[k]
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
