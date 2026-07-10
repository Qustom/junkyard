extends Node
## V6 / R7 golden-equivalence test for RNG.substream + RNG.substream_hashed.
##
## Run as a SCENE (not --script) so the RNG autoload resolves at compile time:
##   godot --headless --path Game res://tests/test_rng_substream.tscn
##
## PROOF OF BYTE-IDENTITY. The goldens below were captured from the OLD inline
## idioms (the five hand-rolled sub-stream sites) BEFORE migration, for a fixed
## (base, salt[, index]); each helper form must reproduce them byte-for-byte.
## A moved golden = a moved fingerprint = a BUG (V6's hard contract).
##
##   G1 pockets  — XOR / .seed-only        (base ^ POCKETS_RNG_SALT)   [MANDATORY:
##                 no other test covers the pockets-RANDOM derivation]
##   G2 exits    — XOR / .seed-only        (base ^ EXITS_RNG_SALT)
##   G3 junk     — hash single-mix / .seed+.state   (mix(base, _JUNK_SALT))
##   G4 flavor   — hash double-mix / .seed+.state    (mix(mix(base, salt), index))
##   G5 cross-guard (Finding A): substream(b,s) != substream_hashed(b,s) — the
##                 .seed-only vs .seed+.state protocols are DIFFERENT PCG streams.

# Salts mirror the production consts (game_state.gd:16/22, junk_placer.gd:26) and
# the flavor salt test_band_flavors.gd F5 uses. Goldens are pinned to these.
const POCKETS_RNG_SALT := 0x50434B54   # "PCKT"
const EXITS_RNG_SALT := 0x45584954     # "EXIT"
const JUNK_SALT := 0x4A554E4B          # "JUNK"
const FLAVOR_SALT := 0x57454152        # "WEAR" (test_band_flavors F5)

const BASE := 123456789
const RANGE_N := 10

# --- Goldens captured from the OLD idioms, pre-migration (2026-07-10) ---------
const G_POCKETS_RANDI := [407406641, 80537114, 2094092636, 2083198447, 197142708, 2439229414, 1323188977, 535476935]
const G_POCKETS_RANGE := [4, 9, 9, 0, 4, 6, 0, 4]   # randi_range(0,10) — the Fisher–Yates consumer shape
const G_EXITS_RANDI := [357694124, 125717591, 3185398692, 191171892, 1534060683, 2409352820, 1581833635, 1281126665]
const G_JUNK_RANDI := [88, 359112458, 1942689707, 2929100643, 384682975, 2280359705, 2300817681, 2955749735]
const G_FLAVOR_RANDI := [5675, 2495899459, 2105986556, 3703368332, 98771551, 3737262959, 712503437, 953673134]


func _ready() -> void:
	var failures: Array[String] = []

	# G1 — pockets: XOR / .seed-only. randi + the actual randi_range consumer.
	_check_randi(failures, "G1 pockets randi",
			RNG.substream(BASE, POCKETS_RNG_SALT), G_POCKETS_RANDI)
	_check_range(failures, "G1 pockets randi_range",
			RNG.substream(BASE, POCKETS_RNG_SALT), G_POCKETS_RANGE)

	# G2 — exits: XOR / .seed-only.
	_check_randi(failures, "G2 exits randi",
			RNG.substream(BASE, EXITS_RNG_SALT), G_EXITS_RANDI)

	# G3 — junk: hash single-mix / .seed+.state (index omitted).
	_check_randi(failures, "G3 junk randi",
			RNG.substream_hashed(BASE, JUNK_SALT), G_JUNK_RANDI)

	# G4 — flavor: hash double-mix / .seed+.state (index >= 0).
	_check_randi(failures, "G4 flavor randi",
			RNG.substream_hashed(BASE, FLAVOR_SALT, 0), G_FLAVOR_RANDI)

	# G5 — cross-guard (Finding A): same (base, salt), the two forms DIFFER.
	var xor_first := RNG.substream(BASE, JUNK_SALT).randi()
	var hashed_first := RNG.substream_hashed(BASE, JUNK_SALT).randi()
	if xor_first == hashed_first:
		failures.append("G5 cross-guard: substream and substream_hashed produced the SAME first draw (%d) for (base, salt) — the two protocols must differ (Finding A)" % xor_first)

	# Guard: substream sets .seed ONLY (state is a scrambled hash of the seed, not
	# the raw seed); substream_hashed sets .state = derived seed.
	var s := RNG.substream(BASE, JUNK_SALT)
	if s.state == (BASE ^ JUNK_SALT):
		failures.append("G5b: substream unexpectedly forced .state = seed (must set .seed ONLY)")

	if failures.is_empty():
		print("RNG SUBSTREAM: ALL GOLDENS PASS (5 derivations byte-identical + Finding-A cross-guard)")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("RNG SUBSTREAM FAIL: ", f)
		get_tree().quit(1)


func _check_randi(failures: Array[String], label: String,
		rng: RandomNumberGenerator, golden: Array) -> void:
	for i in golden.size():
		var got := rng.randi()
		if got != int(golden[i]):
			failures.append("%s[%d]: got %d, want %d" % [label, i, got, int(golden[i])])
			return


func _check_range(failures: Array[String], label: String,
		rng: RandomNumberGenerator, golden: Array) -> void:
	for i in golden.size():
		var got := rng.randi_range(0, RANGE_N)
		if got != int(golden[i]):
			failures.append("%s[%d]: got %d, want %d" % [label, i, got, int(golden[i])])
			return
