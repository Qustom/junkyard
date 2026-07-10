extends RefCounted
## V3 (M1.12) — the SHARED fixed band set for the K5 legacy→deck equivalence proof.
##
## Used by BOTH capture_greybox_k5_fixture.gd (records the pre-migration legacy plan)
## and test_greybox_deck_equivalence.gd (replays the post-migration deck plan) so the
## two compare on byte-identical bands. Pure hand-built graded linear bands (mirroring
## test_new_hazard_spawn._make_band / test_encounter_builder._make_band): piece at
## depth d has areas[d] floor cells in a contiguous block at x base d*100 (so a spawned
## node's x identifies its owning room). Deterministic, no pipeline, no RNG.

## The area arrays for each named band. Fixed, deterministic.
##   small       — 3 rooms (test_new_hazard_spawn (i) shape).
##   preset_deep — the 15-depth band from test_encounter_builder._case_preset_parity,
##                 deep enough that all three preset kinds spawn (the ramps bite ≥ depth 7).
##   realistic   — ~19 rooms over depths 0..15 mirroring the play-preset's worked greybox
##                 estimate (run_config.gd:847-853), the historical-density reference band.
const AREAS := {
	"small": [4, 9, 16],
	"preset_deep": [16, 25, 36, 49, 64, 100, 120, 64, 81, 100, 64, 81, 100, 64, 81],
	"realistic": [16, 25, 36, 49, 64, 81, 100, 64, 81, 100, 64, 81, 100, 64, 81, 100, 64, 81, 100],
}


## All named bands as { name -> Band }. Callers own freeing via free_all().
static func all_bands() -> Dictionary:
	var out := {}
	for name: String in AREAS:
		out[name] = make_band(AREAS[name])
	return out


## A graded linear band from an area array (verbatim the test_*_._make_band shape).
static func make_band(areas: Array) -> Band:
	var band := Band.new()
	var max_depth: int = areas.size() - 1
	for d in areas.size():
		var area: int = areas[d]
		var p := PlacedPiece.new()
		p.piece_id = StringName("piece_room_%d" % d)
		p.offset_cell = Vector2i(d * 100, 0)
		p.depth_index = d
		p.depth_norm = float(d) / float(max_depth) if max_depth > 0 else 0.0
		var cells: Array[Vector2i] = []
		for k in area:
			cells.append(Vector2i(d * 100 + (k % 20), k / 20))
		p.floor_cells = cells
		band.pieces.append(p)
	band.entry_piece = band.pieces[0]
	band.deepest_piece = band.pieces[band.pieces.size() - 1]
	band.max_depth = max_depth
	return band


## The BUG7 entry spawn position for a band (entry piece's first floor cell, centred).
static func entry_pos(band: Band, cell_px: int) -> Vector2:
	var cell: Vector2i = band.entry_piece.floor_cells[0]
	return Vector2(cell * cell_px) + Vector2(cell_px, cell_px) * 0.5


static func free_all(bands: Dictionary) -> void:
	for name: String in bands:
		var band: Band = bands[name]
		for p in band.pieces:
			if p.instance != null and is_instance_valid(p.instance):
				p.instance.free()
