class_name CaveBandConfig
extends Resource
## CaveBandConfig — tuning knobs for the CA caverns backend (M1.10 T0).
##
## Sibling of BandGenConfig (data/bandgen_config.gd); a BandProfile with
## backend == "cave" carries one as its backend_config. Authored in the
## inspector, referenced by band_three.tres (T3) as profile.backend_config.
##
## DETERMINISM (the B2 discipline transposed): EVERY branch-affecting field is
## an INTEGER. fill_pct is an integer percent compared against
## RNG.randi_range(0, 99); the smoothing rule is pure integer neighbour-
## counting; no float ever touches the layout path. There is deliberately NO
## float `nook_roughness` — roughness is `wall_threshold` + `smooth_passes`
## (M1.10 breakdown Phase-3 amendment #4).

## Grid extents in cells, INCLUDING the forced-wall border ring. The playable
## interior is (grid_width-2) x (grid_height-2). 56x56 is the M1.10 default
## (breakdown amendment #4 — band_three's authored extents).
@export var grid_width: int = 56
@export var grid_height: int = 56

## Initial wall density, integer percent (b3: "~45%; higher = tighter").
@export var fill_pct: int = 45

## CA smoothing passes (b3: "more passes = smoother, fewer islands (~4-5)").
@export var smooth_passes: int = 4

## The CA wall rule threshold: an interior cell becomes WALL when >=
## wall_threshold of its 8 neighbours are wall, FLOOR otherwise (b3's rule at
## 5). Lower = more wall = tighter/nookier. THE nook/roughness knob (Q7).
@export var wall_threshold: int = 5

## Flood regions with at least this many floor cells are CARVED into the main
## region (a deterministic connector corridor); smaller ones are discarded
## (filled to WALL). The b3 "connectivity threshold" knob.
@export var min_region_cells: int = 12

## Width of carved connector corridors, in cells. 2 matches the socket doorway
## width (authored sockets are 2-cell — band_generator.gd:399) so a carved
## throat is never tighter than a socket door (player-scale floor).
@export var carve_width: int = 2

## Synthetic-piece partition size: the kept floor is chunked into
## chunk_cells x chunk_cells tiles, one PlacedPiece per floor-bearing chunk.
## Sets the granularity of the depth axis / loot rolls / encounter rooms.
@export var chunk_cells: int = 8

## Whole-grid retry soft floor: if the kept+carved floor has fewer than
## min_floor_cells cells, discard and retry with a derived seed (the socket
## backend's retry model, band_generator.gd:60-79).
@export var min_floor_cells: int = 300

## Max whole-grid retries before emitting band_generation_failed and returning
## the best (largest-floor) attempt.
@export var max_attempts: int = 8

## Pixel size of one cell at materialisation (T1 consumes; JunkPlacer's
## instance-null fallback is 16 — junk_placer.gd:201 — keep these agreeing).
@export var cell_size_px: int = 16


## Fail-loud self-check the cave validate() branch runs. Returns problem
## strings; empty = valid. Guards degenerate authoring (S1 §10.1 Q7 posture).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if grid_width < 8:
		problems.append("CaveBandConfig: grid_width %d must be >= 8" % grid_width)
	if grid_height < 8:
		problems.append("CaveBandConfig: grid_height %d must be >= 8" % grid_height)
	if fill_pct < 0 or fill_pct > 100:
		problems.append("CaveBandConfig: fill_pct %d must be in 0..100" % fill_pct)
	if smooth_passes < 0:
		problems.append("CaveBandConfig: smooth_passes %d must be >= 0" % smooth_passes)
	if wall_threshold < 1 or wall_threshold > 8:
		problems.append("CaveBandConfig: wall_threshold %d must be in 1..8" % wall_threshold)
	if min_region_cells < 1:
		problems.append("CaveBandConfig: min_region_cells %d must be >= 1" % min_region_cells)
	if carve_width < 1:
		problems.append("CaveBandConfig: carve_width %d must be >= 1" % carve_width)
	if chunk_cells < 2:
		problems.append("CaveBandConfig: chunk_cells %d must be >= 2" % chunk_cells)
	if min_floor_cells < 1:
		problems.append("CaveBandConfig: min_floor_cells %d must be >= 1" % min_floor_cells)
	if max_attempts < 1:
		problems.append("CaveBandConfig: max_attempts %d must be >= 1" % max_attempts)
	if cell_size_px < 1:
		problems.append("CaveBandConfig: cell_size_px %d must be >= 1" % cell_size_px)
	# Q11: the grid/chunk geometry must permit >= 2 chunks, else the depth axis
	# degenerates to a single mega-piece (max_depth == 0, zero encounters).
	if grid_width >= 8 and grid_height >= 8 and chunk_cells >= 2:
		var chunks_x := (grid_width + chunk_cells - 1) / chunk_cells
		var chunks_y := (grid_height + chunk_cells - 1) / chunk_cells
		if chunks_x * chunks_y < 2:
			problems.append("CaveBandConfig: grid %dx%d / chunk_cells %d yields < 2 chunks (depth axis degenerate)"
					% [grid_width, grid_height, chunk_cells])
	return problems
