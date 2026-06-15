extends SceneTree
## Headless CI smoke test (QA workflow #3, TDD §4 "Headless smoke test in CI").
##
## Boots the project headless, exercises the M0 architecture spike (autoloads,
## seeded-RNG determinism, save round-trip + migration, Resource loading), and
## exits non-zero on any failure so red CI blocks a merge. Run with:
##
##   godot --headless --script res://tools/ci_smoke_test.gd

func _initialize() -> void:
	var failures: Array[String] = []

	# --- Autoloads present ---------------------------------------------------
	for name in ["EventBus", "RNG", "GameState", "SaveManager", "AudioDirector", "Telemetry"]:
		if root.get_node_or_null(name) == null:
			failures.append("autoload missing: %s" % name)

	var rng := root.get_node_or_null("RNG")
	var save := root.get_node_or_null("SaveManager")
	var gs := root.get_node_or_null("GameState")

	# --- Seeded-RNG determinism: same seed -> same sequence ------------------
	if rng:
		rng.seed_from(12345)
		var a := [rng.randi(), rng.randi(), rng.randi()]
		rng.seed_from(12345)
		var b := [rng.randi(), rng.randi(), rng.randi()]
		if a != b:
			failures.append("RNG not deterministic for a fixed seed: %s vs %s" % [a, b])

	# --- Save round-trip + atomic write + load ------------------------------
	if save and gs:
		gs.money = 4242
		gs.salvage = 7
		gs.lore = 3
		var err: int = save.save_meta(99)
		if err != OK:
			failures.append("save_meta failed: err %d" % err)
		gs.money = 0
		gs.salvage = 0
		gs.lore = 0
		save.load_meta(99)
		if gs.money != 4242 or gs.salvage != 7 or gs.lore != 3:
			failures.append("save/load round-trip lost data: money=%d salvage=%d lore=%d" % [gs.money, gs.salvage, gs.lore])

	# --- Migration: a v0 blob upgrades to current schema --------------------
	if save:
		var migrated: Dictionary = save._migrate_meta({"schema_version": 0, "money": 1})
		if migrated.get("schema_version") != save.META_SCHEMA_VERSION:
			failures.append("migration did not reach current schema_version")

	# --- Resource loads as data ---------------------------------------------
	var item: Resource = load("res://data/items/sample_junk.tres")
	if item == null or item.base_value != 12:
		failures.append("sample item Resource failed to load with expected data")

	# --- Verdict -------------------------------------------------------------
	if failures.is_empty():
		print("SMOKE OK — M0 architecture spike healthy")
		quit(0)
	else:
		for f in failures:
			printerr("SMOKE FAIL: ", f)
		quit(1)
