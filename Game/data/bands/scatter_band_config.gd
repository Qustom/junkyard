class_name ScatterBandConfig
extends Resource
## ScatterBandConfig — tuning knobs for the open-field arena backend (M1.11 U0).
##
## Sibling of BandGenConfig / CaveBandConfig; a BandProfile with
## backend == "scatter" carries one as its backend_config. Authored in the
## inspector, referenced by band_four.tres (U3) as profile.backend_config.
##
## DETERMINISM (the B2 discipline, third transposition): EVERY branch-affecting
## field is an INTEGER. Densities/biases are integer percents compared against
## RNG.randi_range(0, 99); spacing is integer Chebyshev distance; no float ever
## touches the layout path. There is deliberately no float knob of any kind.
##
## NO retry fields (U0 RD-5): scatter generation cannot undershoot — floor =
## interior − cover, and cover is bounded by the stratum count (RD-4), so
## min_floor_cells / max_attempts would be untestable dead code. The backend
## always has requested_seed == resolved_seed.

## Arena extents in cells, INCLUDING the forced-wall border ring. The playable
## interior is (grid_width-2) x (grid_height-2). Wide aspect = the sightline
## identity (entry west, gate east — the long axis IS the band). 56x36 puts the
## floor area (~1.7-1.8k cells post-cover) in the same class as band_three's
## cave (~1.5k) — U3 tunes its own authored point (RD-3).
@export var grid_width: int = 56
@export var grid_height: int = 36

## THE experience dial (b1: sparse-deadly vs dense-stealth): integer percent
## chance that each sampling stratum stamps a cover footprint. 0 = empty arena.
## Note: connectivity/player-scale are knob-INDEPENDENT (RD-6 holds at 100).
@export var cover_density_pct: int = 25

## Minimum Chebyshev distance (cells, edge-to-edge) between any two cover
## footprints. >= 3 guarantees a 2-cell walkable (2x2-open) gap between covers
## — the anti-maze / connectivity-by-construction floor. HARD validate() clamp
## (RD-8/RD-9: spacing 2 admits 1-wide impassable slots).
@export var min_cover_spacing: int = 3

## Cover keeps at least this many floor cells clear of the border ring — the
## guaranteed all-floor perimeter road that makes disconnection impossible
## (RD-6). >= 2 keeps the rim 2x2-open (player-scale by construction).
@export var border_margin: int = 2

## Cover footprint size mix — integer weights over the fixed shape catalog
## (index 0: 1x1 pillar · 1: 2x1 low wall · 2: 1x2 low wall · 3: 2x2 wreck).
## Weighted pick via an integer cumulative table (the _weighted_pick idiom).
@export var cover_w_1x1: int = 4
@export var cover_w_2x1: int = 2
@export var cover_w_1x2: int = 2
@export var cover_w_2x2: int = 3

## Rim-vs-center density shift, integer percent in -100..100 (b1's
## edge_cover_bias). Positive pushes cover toward the rim (open killing-center),
## negative toward the center. 0 = uniform. Applied as an integer scale of
## cover_density_pct per stratum zone (two-zone model, RD-17).
@export var edge_cover_bias_pct: int = 0

## Height (rows) of the protected all-floor E-W lane — the constructed
## long-sightline guarantee (RD-15; the S11 identity bar reads it).
## >= 2 keeps the lane itself 2x2-open. The lane row is seed-picked.
@export var clear_lane_width: int = 3

## Synthetic-piece partition size (the cave idiom verbatim): one PlacedPiece
## per floor-bearing chunk_cells x chunk_cells tile. Sets the depth-axis /
## loot-roll / encounter-room granularity.
@export var chunk_cells: int = 8

## Pixel size of one cell at materialisation (U1/T1 path consumes; JunkPlacer's
## instance-null fallback is 16 — junk_placer.gd:198-201 — keep agreeing).
@export var cell_size_px: int = 16


## Fail-loud self-check the scatter validate() branch runs. Returns problem
## strings; empty = valid. The clamps ARE the by-construction proof's teeth
## (RD-8): a config outside these ranges could break connectivity/player-scale
## or the depth economy, so it must never generate.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if grid_width < 12:
		problems.append("ScatterBandConfig: grid_width %d must be >= 12" % grid_width)
	if grid_height < 12:
		problems.append("ScatterBandConfig: grid_height %d must be >= 12" % grid_height)
	if cover_density_pct < 0 or cover_density_pct > 100:
		problems.append("ScatterBandConfig: cover_density_pct %d must be in 0..100" % cover_density_pct)
	if min_cover_spacing < 3:
		problems.append("ScatterBandConfig: min_cover_spacing %d must be >= 3 (spacing 2 admits 1-wide impassable slots — RD-8)" % min_cover_spacing)
	if border_margin < 2:
		problems.append("ScatterBandConfig: border_margin %d must be >= 2 (the 2x2-open perimeter road)" % border_margin)
	if cover_w_1x1 < 0 or cover_w_2x1 < 0 or cover_w_1x2 < 0 or cover_w_2x2 < 0:
		problems.append("ScatterBandConfig: cover weights must each be >= 0")
	if cover_w_1x1 + cover_w_2x1 + cover_w_1x2 + cover_w_2x2 < 1:
		problems.append("ScatterBandConfig: cover weight sum must be >= 1")
	if edge_cover_bias_pct < -100 or edge_cover_bias_pct > 100:
		problems.append("ScatterBandConfig: edge_cover_bias_pct %d must be in -100..100" % edge_cover_bias_pct)
	if clear_lane_width < 2 or clear_lane_width > grid_height - 2:
		problems.append("ScatterBandConfig: clear_lane_width %d must be in 2..%d (interior height)" % [clear_lane_width, grid_height - 2])
	if chunk_cells < 2:
		problems.append("ScatterBandConfig: chunk_cells %d must be >= 2" % chunk_cells)
	if cell_size_px < 1:
		problems.append("ScatterBandConfig: cell_size_px %d must be >= 1" % cell_size_px)
	# Depth-axis geometry (RD-8, CORRECTED formula): the entry chunk is always
	# at chunk-column 0 (entry cell x = 1) and the entry row is lane-aligned
	# (~vertical centre), so the seed-independent BFS lower bound is
	# chunks_x - 1, NOT the corner-to-corner sum. chunks_x >= 5 guarantees
	# max_depth >= 4 on every seed (every chunk is floor-bearing on an arena).
	if grid_width >= 12 and chunk_cells >= 2:
		var chunks_x := (grid_width + chunk_cells - 1) / chunk_cells
		if chunks_x < 5:
			problems.append("ScatterBandConfig: grid_width %d / chunk_cells %d yields chunks_x %d < 5 (max_depth >= 4 bar unreachable — RD-8)"
					% [grid_width, chunk_cells, chunks_x])
	return problems
