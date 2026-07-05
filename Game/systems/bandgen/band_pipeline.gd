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
## S5 flavor stages draw ONLY from local sub-streams seeded
## _stage_seed(band.resolved_seed, cfg.salt, index) — the JunkPlacer pattern —
## so the grow loop's draw sequence is untouched by any stage.
##
## Stage order replicates the AS-BUILT generation block (main_game.gd:209-215):
## generate -> S5 flavor stages (empty flavors = zero flavor code — the
## control path is literally the S1 parity path) -> grade + return distance.
## The SEAL stays a MATERIALISATION concern (SocketSealer at main_game.gd:881)
## and is NOT invoked here — it runs downstream of this whole function, hence
## still after all flavor floor mutation; it is grade-neutral (floor_cells are
## captured pre-seal), so the canonical tail grade here is equivalent to a
## post-seal grade (S5 spec §10 C1).
## Population (JunkPlacer / oppositions) stays DOWNSTREAM, unchanged — an
## injected set-piece gets depth-appropriate loot automatically.


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

	# --- Wiring guards (M1.10: socket + cave wired; scatter still fail-loud) --
	# Cave dispatch (T0): the socket path's statements below stay VERBATIM in the
	# same order, and the ONLY additions on that path are `backend == "cave"`
	# string compares (no draws, no state), so band_greybox/band_two byte-identity
	# is structural (test_band_pipeline_parity proves it). The cave+flavors
	# fail-loud lives in BandProfile.validate() (single location; the pipeline's
	# validate-then-fail flow at :38-42 enforces it).
	if profile.backend != "socket" and profile.backend != "cave":
		push_error("BandPipeline: backend '%s' is not wired in M1.10 (socket + cave only — profile '%s')"
				% [profile.backend, profile.id])
		return null
	if not profile.principles.is_empty():
		# S5 wired the FLAVOR stage contract only; no principle stage exists in
		# M1.9. A principle-bearing profile is an authoring error, not
		# something to silently skip (control safety).
		push_error("BandPipeline: profile '%s' declares principle stages — none are wired in M1.9"
				% profile.id)
		return null
	for fcfg in profile.flavors:
		# Fail-loud on an unknown flavor config type BEFORE generating: an
		# unrecognised stage in an authored profile is an authoring error
		# (control safety — same posture as the pre-S5 guard this replaced).
		if not (fcfg is SetPieceInjectConfig or fcfg is WearDecayConfig):
			push_error("BandPipeline: profile '%s' carries an unknown flavor config type '%s'"
					% [profile.id, fcfg.get_class() if fcfg != null else "null"])
			return null

	# --- STAGES 1+2: backend dispatch (T0) -------------------------------
	var band: Band
	if profile.backend == "cave":
		# CAVE (M1.10): the CA caverns backend. rc accepted, IGNORED (every
		# as-built rc generation hook is socket-interior; test C7 pins it).
		var cave_cfg := profile.backend_config as CaveBandConfig
		band = CaveBackend.new().generate(seed, cave_cfg, rc)
	else:
		# SOCKET: today's generator, verbatim. The socket grow loop IS the
		# linear/branchy archetype: branch topology is keyed off
		# backend_config.branch_chance and the rc r4_* levers at the exact same
		# draw sites as today (band_generator.gd:308-329). Same args, same retry
		# loop, same _derive_seed chain, same RNG reseed.
		var cfg := profile.backend_config as BandGenConfig
		# I1 catalog swap (S3, §7.2 Q6(iv) / S1 §10.1 Q3): lvl_enabled + an authored
		# piece_pool_ext swaps in the extended pool — the exact config-dependent swap the
		# main_game call site used to do (Resolved G), relocated here so the profile fully
		# owns generation content. lvl off / ext absent → piece_pool (the all-off fp and
		# every ext-less profile are byte-untouched).
		var catalog: Array[ZonePieceData] = profile.piece_pool.pieces
		if rc != null and rc.lvl_enabled and profile.piece_pool_ext != null \
				and not profile.piece_pool_ext.pieces.is_empty():
			catalog = profile.piece_pool_ext.pieces
		band = BandGenerator.new().generate(seed, cfg, catalog, rc)
	if band == null or band.pieces.is_empty():
		push_error("BandPipeline: generation produced no pieces (profile '%s', seed %d)"
				% [profile.id, seed])
		return band

	# --- Post-backend invariant (cave only): cell-level connectivity ASSERT --
	# The backend guarantees one FLOOR component by construction (keep-largest +
	# deterministic carve + player-scale pass); this is the invariant's teeth at
	# the pipeline seam, reusing the existing checker. Fail-loud, never a silent
	# fix (ASSERT posture, connectivity_guarantee.gd:14-24).
	if profile.backend == "cave":
		ConnectivityGuarantee.new().enforce(band, ConnectivityGuarantee.Mode.ASSERT)

	# --- STAGES 3-5 (S5): flavor loop + connectivity invariant ------------
	# Guarded so a profile with empty flavors runs ZERO flavor code — the
	# band_greybox control path is byte-identical to the S1 parity path.
	var grader := DepthGrader.new()
	if not profile.flavors.is_empty():
		grader.grade(band)  # provisional grade (RNG-free, idempotent) — the
		                    # depth gates (min_depth_norm / depth_bias) need it
		var conn := ConnectivityGuarantee.new()
		for i in profile.flavors.size():
			var fcfg: Resource = profile.flavors[i]
			var stage := _stage_for(fcfg)
			if stage == null:
				continue  # unreachable: validated above; defensive
			stage.apply(band, profile, _stage_seed(band.resolved_seed, _stage_salt(fcfg), i))
			if stage.mutates_pieces():
				grader.grade(band)  # re-grade so later stages gate correctly
			# Connectivity invariant after EVERY stage (§10 Q7): CARVE (journal
			# revert) after floor-reshaping stages, ASSERT after pure-socket ones.
			if stage.reshapes_floor():
				conn.enforce(band, ConnectivityGuarantee.Mode.CARVE, stage.journal())
			else:
				conn.enforce(band, ConnectivityGuarantee.Mode.ASSERT)

	# --- STAGES 6-7: today's exact generation-block order ----------------
	# (main_game.gd:213-215). Canonical grade + return distance here; the SEAL
	# stays at materialisation (main_game.gd:881) and is NOT invoked here.
	grader.grade(band)
	grader.compute_return_distance(band)

	# Population (JunkPlacer / oppositions) stays DOWNSTREAM, unchanged —
	# the exploration's clean handoff seam. S3 rewires the consumer.
	return band


# --- S5 stage plumbing (config-type -> stage dispatch + sub-seed derivation) --

## Map an (already-validated) flavor config Resource to a fresh stage instance.
func _stage_for(fcfg: Resource) -> BandFlavorStage:
	if fcfg is SetPieceInjectConfig:
		return SetPieceInjectStage.new(fcfg)
	if fcfg is WearDecayConfig:
		return WearDecayStage.new(fcfg)
	return null


func _stage_salt(fcfg: Resource) -> int:
	if fcfg is SetPieceInjectConfig:
		return (fcfg as SetPieceInjectConfig).salt
	if fcfg is WearDecayConfig:
		return (fcfg as WearDecayConfig).salt
	return 0


## Per-stage sub-seed: hash_combine(hash_combine(resolved_seed, salt), index)
## using the generator's boost-style mix (band_generator.gd:352-362 — kept
## local so band_generator.gd stays untouched). The flavors-array index
## disambiguates two instances of the same stage in one profile.
static func _stage_seed(resolved_seed: int, salt: int, index: int) -> int:
	var h := _mix(resolved_seed, salt)
	return _mix(h, index)


static func _mix(h: int, v: int) -> int:
	# h ^= v + 0x9e3779b9 + (h<<6) + (h>>2)  (masked to stay in 64-bit range)
	var mixed := (v + 0x9E3779B9 + ((h << 6) & 0x7FFFFFFFFFFFFFFF) + (h >> 2))
	return (h ^ mixed) & 0x7FFFFFFFFFFFFFFF
