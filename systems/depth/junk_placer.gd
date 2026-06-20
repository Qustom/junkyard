class_name JunkPlacer
extends RefCounted
## JunkPlacer — the deterministic, depth-scaled junk PLACEMENT PLANNER (B3).
##
## Given a GRADED Band (DepthGrader has run) + a DepthCurve + a JunkCatalog, it
## returns a deterministic PLAN: an Array of placement entries
##     { "world_pos": Vector2, "item": JunkItem, "depth": int }
## where `item` is a duplicate(true) of a catalog template with base_sell_value
## scaled by the depth value curve, and tier >= the depth's tier threshold.
##
## SCOPE SEAM (B3 owns the plan; C2 owns the spawn): this planner does NOT
## instantiate JunkPickup entities, touch inventory, or emit junk_picked_up. C2's
## spawner consumes this plan to build the interactive pickups. The planner may
## optionally emit EventBus.junk_spawned(item_id, depth) for placement/telemetry.
##
## DETERMINISM — RNG sub-stream (B3 adaptation of the spec):
## The RNG autoload exposes no fork()/stream(); reseeding the global RNG
## mid-generation would desync the layout stream. So junk rolls draw from a LOCAL
## RandomNumberGenerator seeded from band.resolved_seed combined with a fixed
## integer salt. This guarantees (a) same seed -> same plan, and (b) junk rolls
## never perturb (and are never perturbed by) the layout RNG. The autoload RNG is
## NOT touched here.

## Fixed salt mixed into band.resolved_seed for the junk sub-stream. Any stable
## constant works; this keeps the junk stream distinct from the layout stream.
const _JUNK_SALT := 0x4A554E4B  # "JUNK"


## Build the deterministic placement plan. Pure function of (band, curve,
## catalog): no global state mutated, the autoload RNG untouched. Returns an
## Array[Dictionary] of { world_pos: Vector2, item: JunkItem, depth: int }.
##
## If `emit_events` is true, emits EventBus.junk_spawned(item_id, depth) per
## planned item (placement/telemetry hook; NOT junk_picked_up — that's C2's).
## I1 (M1.2): `cell_size_override` lets MainGame plan loot world-coords against the
## SAME effective px-per-cell that materialisation scales the band to (= round(16 *
## lvl_size_mult)). Pickups are parented to the band container at raw world coords —
## NOT as children of the scaled piece nodes — so without this they would cluster at
## the 1x (16-px) coords and land outside/atop scaled rooms at any mult != 1.0. Default
## -1 = "use each piece's authored cell_size_px" (the baseline path, byte-for-byte the
## old behaviour: at mult 1.0 the override is 16, identical to the piece export).
## J3 (M1.3): `loot_density_per_area` scales the per-piece junk count by ROOM AREA when
## > 0 (big rooms get proportionally more interest). 0.0 = OFF — byte-for-byte the M1.2
## behaviour (the depth curve's flat count only). Rides this same local _JUNK_SALT
## sub-stream (reproducible from seed+config, never the global RNG). Built but SHIPS OFF
## and is NEVER preset-on (it contradicts depth_curve.gd's "don't flood deep rooms").
func plan(band: Band, curve: DepthCurve, catalog: JunkCatalog,
		emit_events: bool = false, cell_size_override: int = -1,
		loot_density_per_area: float = 0.0) -> Array:
	var out: Array = []
	if band == null or curve == null or catalog == null:
		return out
	if catalog.items.is_empty():
		return out

	# Local sub-stream — see class docstring. Deterministic from the band seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = _substream_seed(band.resolved_seed)
	rng.state = rng.seed

	# Pre-index catalog items by tier eligibility once (templates, never mutated).
	for p in band.pieces:
		var d := p.depth_norm

		# 1. How much junk here (expected count -> seeded probabilistic integer).
		# J3: when loot_density_per_area > 0, scale the expected count by ROOM AREA (in
		# LVL_LOOT_AREA_UNIT-cell units) BEFORE the seeded round, so big rooms hold more
		# interest. At 0.0 (the default/preset) this is the bare curve count — identical
		# float fed to _seeded_round, so the sub-stream draws byte-for-byte as in M1.2.
		var expected := curve.expected_count(d)
		if loot_density_per_area > 0.0:
			var area_units := float(p.floor_cells.size()) / float(RunConfig.LVL_LOOT_AREA_UNIT)
			expected = expected + loot_density_per_area * expected * (area_units - 1.0)
		var count := _seeded_round(expected, rng)
		if count <= 0:
			continue

		# 2. What minimum tier this depth unlocks.
		var min_tier := curve.min_tier(d)

		# 3. Eligible templates (tier >= the depth gate). Fall back to the whole
		#    catalog if nothing qualifies, so a steep gate never empties a piece.
		var eligible := _eligible_indices(catalog, min_tier)
		if eligible.is_empty():
			eligible = _eligible_indices(catalog, 1)
		if eligible.is_empty():
			continue

		# 4. Deterministic walkable floor cells for placement (stable sort).
		var cells := _sorted_floor_cells(p)
		if cells.is_empty():
			continue
		# I1: use the caller's effective px-per-cell when provided (size-mult runs), else
		# the piece's authored cell_size_px (baseline). Shared with materialise so loot
		# lands inside the scaled rooms (no mis-placement at mult != 1.0).
		var cell_size_px := cell_size_override if cell_size_override > 0 else _cell_size_px(p)

		var value_mult := curve.value_mult(d)
		for _i in count:
			var template_idx := _weighted_pick(catalog, eligible, rng)
			var template: JunkItem = catalog.items[template_idx]

			# duplicate(true): isolates each pickup. We only mutate the scalar
			# base_sell_value, so a duplicate gives independent value with no
			# shared state (B3 open-Q: duplicate semantics).
			var item := template.duplicate(true) as JunkItem
			item.base_sell_value = int(round(float(template.base_sell_value) * value_mult))

			var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var world_pos := _cell_to_world(cell, cell_size_px)

			out.append({
				"world_pos": world_pos,
				"item": item,
				"depth": p.depth_index,
			})

			if emit_events:
				EventBus.junk_spawned.emit(item.id, p.depth_index)

	return out


## Stable fingerprint of a plan (ordered "pos|id|value" hashed). Same seed ->
## byte-identical string; used by the headless test's determinism assertion.
func plan_fingerprint(planned: Array) -> String:
	var parts := PackedStringArray()
	for e in planned:
		var item: JunkItem = e["item"]
		parts.append("%s|%s|%d" % [e["world_pos"], item.id, item.base_sell_value])
	return "|".join(parts).sha256_text()


# --- Internals ---------------------------------------------------------------

## Mix band seed + fixed salt into a distinct, deterministic sub-stream seed.
## Boost-style integer hash-combine, masked to a valid 63-bit int (mirrors the
## generator's _derive_seed style).
func _substream_seed(band_seed: int) -> int:
	var h := band_seed
	var mixed := (_JUNK_SALT + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
	h = (h ^ mixed) & 0x7FFFFFFFFFFFFFFF
	return h


## Probabilistic round: integer floor + a seeded coin for the fractional part.
func _seeded_round(x: float, rng: RandomNumberGenerator) -> int:
	var lo := int(floor(x))
	var frac := x - float(lo)
	return lo + (1 if (frac > 0.0 and rng.randf() < frac) else 0)


## Catalog indices whose item tier >= min_tier, in stable catalog order.
func _eligible_indices(catalog: JunkCatalog, min_tier: int) -> Array[int]:
	var out: Array[int] = []
	for i in catalog.items.size():
		var it: JunkItem = catalog.items[i]
		if it != null and it.tier >= min_tier:
			out.append(i)
	return out


## Weighted pick over a subset of catalog indices using the catalog's
## index-aligned spawn_weights, drawn from the local sub-stream. Integer
## cumulative table built per call over the (small) eligible set.
func _weighted_pick(catalog: JunkCatalog, indices: Array[int],
		rng: RandomNumberGenerator) -> int:
	const SCALE := 1000
	var cum: Array[int] = []
	var running := 0
	for idx in indices:
		var w := 1.0
		if idx < catalog.spawn_weights.size():
			w = maxf(catalog.spawn_weights[idx], 0.0)
		var iw := int(round(w * SCALE))
		if iw <= 0:
			iw = 1
		running += iw
		cum.append(running)
	var roll := rng.randi_range(0, running - 1)
	for k in cum.size():
		if roll < cum[k]:
			return indices[k]
	return indices[indices.size() - 1]  # defensive


## Walkable floor cells of a piece in a stable sorted order (y then x) so the
## placement draw is reproducible regardless of authored cell order.
func _sorted_floor_cells(p: PlacedPiece) -> Array[Vector2i]:
	var cells := p.floor_cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return cells


func _cell_size_px(p: PlacedPiece) -> int:
	if p.instance != null:
		return p.instance.cell_size_px
	return 16  # B1 authored default


## Band-global cell -> world pixel position, centred in the cell.
func _cell_to_world(cell: Vector2i, cell_size_px: int) -> Vector2:
	return Vector2(cell * cell_size_px) + Vector2(cell_size_px, cell_size_px) * 0.5
