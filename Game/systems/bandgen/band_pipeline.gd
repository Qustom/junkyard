class_name BandPipeline
extends RefCounted
## BandPipeline — the profile-driven band orchestrator (M1.9 S1, band Phase A).
##
## generate(profile, seed, rc) is a PURE FUNCTION of its inputs, same as the
## generator it wraps. Phase A adds NO generation behaviour: for a
## socket+linear/branchy+empty-stages profile it byte-matches the direct
## BandGenerator path (test_band_pipeline_parity is the proof; the
## test_bandgen_determinism assertions transfer wholesale). The determinism
## key is (profile + seed + rc): the profile is the band's CONTENT identity,
## rc remains the per-run experiment overlay flowing untouched to the
## generator's interior hooks (room count, corridor weights, r4 branching).
##
## RNG DISCIPLINE: this class rolls ZERO randomness. The reseed
## (RNG.seed_from) happens inside BandGenerator._generate_once exactly as
## today; grading is RNG-free; there is no draw before/between/after stages.
##
## Stage order replicates the AS-BUILT generation block (main_game.gd:209-215):
## generate -> [S5 stage hook] -> grade + return distance. The SEAL stays a
## MATERIALISATION concern (SocketSealer at main_game.gd:881) and is NOT
## invoked here — fingerprint-neutral either way, but Phase A copies reality.
## Population (JunkPlacer / oppositions) stays DOWNSTREAM, unchanged.


func generate(profile: BandProfile, seed: int, rc: RunConfig = null) -> Band:
	# --- Fail-loud profile validation (never a silent fallback) ----------
	if profile == null:
		push_error("BandPipeline: null profile")
		return null
	var problems := profile.validate()
	if not problems.is_empty():
		for p in problems:
			push_error(p)
		return null

	# --- Phase-A wiring guards -------------------------------------------
	if profile.backend != "socket":
		push_error("BandPipeline: backend '%s' is not wired in M1.9 (socket only — profile '%s')"
				% [profile.backend, profile.id])
		return null
	if not profile.principles.is_empty() or not profile.flavors.is_empty():
		# S5 lands the stage contract; until then a stage-bearing profile is
		# an authoring error, not something to silently skip (control safety).
		push_error("BandPipeline: profile '%s' declares principle/flavor stages before S5 wired them"
				% profile.id)
		return null

	# --- STAGES 1+2: backend + archetype = today's generator, verbatim ---
	# The socket grow loop IS the linear/branchy archetype: branch topology
	# is keyed off backend_config.branch_chance and the rc r4_* levers at
	# the exact same draw sites as today (band_generator.gd:308-329). Same
	# args, same retry loop, same _derive_seed chain, same RNG reseed.
	var cfg := profile.backend_config as BandGenConfig
	var catalog: Array[ZonePieceData] = profile.piece_pool.pieces
	var band := BandGenerator.new().generate(seed, cfg, catalog, rc)
	if band == null or band.pieces.is_empty():
		push_error("BandPipeline: generation produced no pieces (profile '%s', seed %d)"
				% [profile.id, seed])
		return band

	# STAGE HOOK (S5): principles/flavors + provisional grade land here —
	# after the backend delegation (+ guards), before seal and before the
	# final grade. S5 is the sole Wave-2 writer of this file; it replaces
	# the stage-bearing guard above with the real loop (per-stage sub-seed
	# contract, seed ⊕ stage.salt). Nothing runs here in Phase A.

	# --- STAGES 6-7: today's exact generation-block order ----------------
	# (main_game.gd:213-215). Grade + return distance here; the SEAL stays
	# at materialisation (main_game.gd:881) and is NOT invoked here.
	var grader := DepthGrader.new()
	grader.grade(band)
	grader.compute_return_distance(band)

	# Population (JunkPlacer / oppositions) stays DOWNSTREAM, unchanged —
	# the exploration's clean handoff seam. S3 rewires the consumer.
	return band
