extends Node
## Headless save-migration test for G5 — meta schema v1 -> v2.
##
## Closes the wave-3 E1/schema deviation: E1 bumped the meta schema 1->2 to add
## `banked_junk`, but the TDD rule "a QA fixture on every schema change" had no
## fixture. This test loads a COMMITTED, binary v1 meta fixture
## (tests/fixtures/meta_v1.sav, written objects-OFF exactly like a real save) and
## runs it through the REAL SaveManager path — _load_var -> _migrate_meta ->
## from_meta_dict — then asserts the migrated v2 state.
##
## Run as a SCENE (not --script) so the GameState / SaveManager autoloads resolve
## as compile-time globals, per M1_As_Built "Testing constraints (headless)":
##   godot --headless res://tests/test_save_migration.tscn
##
## Asserts:
##   1. schema_version == 2 (META_SCHEMA_VERSION) after migration.
##   2. banked_junk defaults to [] in the migrated dict, and GameState.banked_junk
##      rehydrates to an empty typed Array[JunkItem] without crashing.
##   3. Every pre-existing v1 field (money/salvage/lore/exposure/knowledge_level/
##      unlocked_recipes) survives intact with its frozen v1 value.
##   4. Round-trip: re-save the migrated state via save_meta, confirm it
##      re-serializes at v2, and that the atomic write left a .bak of the prior
##      good file (the .bak path is exercised + preserved).
##
## TEMPLATE for future schema bumps (N -> N+1): add a stepwise case in
## SaveManager._migrate_meta, commit a binary meta_v<N>.sav fixture (via
## gen_meta_v1_fixture.gd's pattern), then add a case here that loads it, asserts
## the new field's default + survival of old fields, and round-trips once.

const FIXTURE_PATH := "res://tests/fixtures/meta_v1.sav"
const TEST_SLOT := 9001  # high slot id so we never collide with a real save

# Frozen v1 values — MUST match tests/fixtures/gen_meta_v1_fixture.gd.
const EXPECT_MONEY := 1337
const EXPECT_SALVAGE := 42
const EXPECT_LORE := 9
const EXPECT_EXPOSURE := 73
const EXPECT_KNOWLEDGE := 3
const EXPECT_RECIPES := ["recipe_alpha", "recipe_beta"]

# K2 (M1.4): the v2 fixture (post-E1, pre-K2). Frozen values MUST match
# tests/fixtures/gen_meta_v2_fixture.gd; they DIFFER from v1 so the two are distinct.
const FIXTURE_V2_PATH := "res://tests/fixtures/meta_v2.sav"
const TEST_SLOT_V2 := 9002
const EXPECT_V2_MONEY := 2500
const EXPECT_V2_SALVAGE := 17
const EXPECT_V2_LORE := 4
const EXPECT_V2_EXPOSURE := 31
const EXPECT_V2_KNOWLEDGE := 1
const EXPECT_V2_RECIPES := ["recipe_gamma"]


func _ready() -> void:
	# Run BOTH migration cases: v1 (now v1->v2->v3) AND v2 (v2->v3). Either failing
	# fails the whole test (the headless harness reads the exit code).
	var code := _run()
	if code == 0:
		code = _run_v2()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var save := get_node_or_null("/root/SaveManager")
	if gs == null or save == null:
		printerr("MIGRATION FAIL: GameState or SaveManager autoload missing")
		return 1

	# --- Sanity: the committed fixture exists --------------------------------
	# We deliberately do NOT regenerate it here — a missing fixture is a hard
	# failure so the on-disk v1 format stays pinned in the repo.
	if not FileAccess.file_exists(FIXTURE_PATH):
		printerr("MIGRATION FAIL: missing v1 fixture %s (regenerate via gen_meta_v1_fixture.gd, then commit it)" % FIXTURE_PATH)
		return 1

	# --- Confirm the fixture really is a pre-E1 v1 shape ---------------------
	# Read it raw the same way SaveManager does, before any migration touches it.
	var raw := _read_raw(FIXTURE_PATH)
	if raw.get("schema_version", -1) != 1:
		failures.append("fixture schema_version is %s, expected 1 (fixture is not v1)" % str(raw.get("schema_version", -1)))
	if raw.has("banked_junk"):
		failures.append("fixture already has a banked_junk key — a true v1 save must NOT")

	# --- Stage the fixture into a real slot and load via the production path --
	# Copy the committed binary into user://saves/slot_<TEST_SLOT>/meta.sav, then
	# call SaveManager.load_meta() so the FULL path runs: _load_var (+.bak
	# fallback) -> _migrate_meta -> GameState.from_meta_dict.
	var slot_meta: String = save.slot_dir(TEST_SLOT) + "/meta.sav"
	_clean_slot(save, TEST_SLOT)
	DirAccess.make_dir_recursive_absolute(slot_meta.get_base_dir())
	var copy_err := DirAccess.copy_absolute(FIXTURE_PATH, slot_meta)
	if copy_err != OK:
		printerr("MIGRATION FAIL: could not stage fixture into slot (err %d)" % copy_err)
		_clean_slot(save, TEST_SLOT)
		return 1

	var migrated: Dictionary = save.load_meta(TEST_SLOT)

	# --- Assert 1: migrated to current schema --------------------------------
	if migrated.get("schema_version", -1) != save.META_SCHEMA_VERSION:
		failures.append("post-migration schema_version == %s, expected %d"
			% [str(migrated.get("schema_version", -1)), save.META_SCHEMA_VERSION])

	# --- Assert 2: banked_junk default + rehydration -------------------------
	if not migrated.has("banked_junk"):
		failures.append("migration did not add a banked_junk key")
	elif not (migrated["banked_junk"] is Array) or not (migrated["banked_junk"] as Array).is_empty():
		failures.append("migrated banked_junk is not an empty Array (got %s)" % str(migrated.get("banked_junk")))
	# from_meta_dict (called inside load_meta) must rehydrate to an empty TYPED
	# array without crashing. Verify both emptiness and the element type contract.
	if gs.banked_junk.size() != 0:
		failures.append("GameState.banked_junk rehydrated to %d items, expected 0" % gs.banked_junk.size())
	gs.banked_junk.append(null)        # typed-array smoke: Array[JunkItem] accepts null
	gs.banked_junk.pop_back()
	var typed_empty: Array[JunkItem] = []
	gs.banked_junk = typed_empty       # confirm the property still accepts a typed Array[JunkItem]

	# --- Assert 3: pre-existing v1 fields survived intact --------------------
	if gs.money != EXPECT_MONEY:
		failures.append("money %d != expected %d" % [gs.money, EXPECT_MONEY])
	if gs.salvage != EXPECT_SALVAGE:
		failures.append("salvage %d != expected %d" % [gs.salvage, EXPECT_SALVAGE])
	if gs.lore != EXPECT_LORE:
		failures.append("lore %d != expected %d" % [gs.lore, EXPECT_LORE])
	if gs.exposure != EXPECT_EXPOSURE:
		failures.append("exposure %d != expected %d" % [gs.exposure, EXPECT_EXPOSURE])
	if gs.knowledge_level != EXPECT_KNOWLEDGE:
		failures.append("knowledge_level %d != expected %d" % [gs.knowledge_level, EXPECT_KNOWLEDGE])
	if gs.unlocked_recipes.size() != EXPECT_RECIPES.size():
		failures.append("unlocked_recipes has %d entries, expected %d"
			% [gs.unlocked_recipes.size(), EXPECT_RECIPES.size()])
	else:
		for i in EXPECT_RECIPES.size():
			if String(gs.unlocked_recipes[i]) != EXPECT_RECIPES[i]:
				failures.append("unlocked_recipes[%d] == %s, expected %s"
					% [i, String(gs.unlocked_recipes[i]), EXPECT_RECIPES[i]])

	# --- Assert 3b (K2): v1->v3 also added the quota defaults ----------------
	# The migration loop now runs v1->v2->v3 for the v1 fixture, so the v3 step must
	# have added run_number=1/quota_target=0 (the pre-K2 player starts a fresh ladder).
	if migrated.get("run_number", -1) != 1:
		failures.append("v1->v3 run_number == %s, expected 1" % str(migrated.get("run_number", -1)))
	if migrated.get("quota_target", -1) != 0:
		failures.append("v1->v3 quota_target == %s, expected 0" % str(migrated.get("quota_target", -1)))
	if gs.run_number != 1:
		failures.append("GameState.run_number == %d after v1 load, expected 1" % gs.run_number)
	if gs.quota_target != 0:
		failures.append("GameState.quota_target == %d after v1 load, expected 0" % gs.quota_target)

	# --- Assert 4: round-trip + .bak exercised -------------------------------
	# save_meta over the freshly-migrated slot: _atomic_store copies the existing
	# meta.sav -> meta.sav.bak before swapping in the new file. After this the
	# slot must re-serialize at the current schema AND a .bak must exist.
	var save_err: int = save.save_meta(TEST_SLOT)
	if save_err != OK:
		failures.append("round-trip save_meta failed (err %d)" % save_err)
	var bak_path: String = slot_meta + ".bak"
	if not FileAccess.file_exists(bak_path):
		failures.append("atomic write did not preserve a .bak of the prior good meta.sav")
	# Reload to confirm the re-serialized file is a clean v2.
	gs.money = 0  # scribble so a stale read is detectable
	var reread: Dictionary = save.load_meta(TEST_SLOT)
	if reread.get("schema_version", -1) != save.META_SCHEMA_VERSION:
		failures.append("re-saved meta did not reload at v%d" % save.META_SCHEMA_VERSION)
	if gs.money != EXPECT_MONEY:
		failures.append("round-trip lost money: reloaded %d, expected %d" % [gs.money, EXPECT_MONEY])

	# --- Cleanup: never leave a test slot behind ----------------------------
	_clean_slot(save, TEST_SLOT)
	# Leave meta-state on a clean slate for any harness that runs after us.
	var clean: Array[JunkItem] = []
	gs.banked_junk = clean
	gs.money = 0
	gs.salvage = 0
	gs.lore = 0
	gs.exposure = 0
	gs.knowledge_level = 0
	gs.unlocked_recipes = [] as Array[StringName]
	gs.run_number = 1
	gs.quota_target = 0

	# --- Verdict -------------------------------------------------------------
	if failures.is_empty():
		print("SAVE MIGRATION OK — v1 meta fixture migrates to v3 (banked_junk defaults to [], run_number=1/quota_target=0 added, existing fields intact, round-trip re-serializes at the current schema with .bak preserved).")
		return 0
	for f in failures:
		printerr("MIGRATION FAIL (v1): ", f)
	return 1


## K2 (M1.4): the v2->v3 migration case. Loads the COMMITTED binary v2 fixture (post-E1,
## pre-K2: all v1 fields + banked_junk, schema_version=2, NO run_number/quota_target),
## runs it through the REAL SaveManager path, and asserts it lands at v3 with the quota
## defaults added, every prior v2 field intact, and a clean round-trip + .bak.
func _run_v2() -> int:
	var failures: Array[String] = []

	var gs := get_node_or_null("/root/GameState")
	var save := get_node_or_null("/root/SaveManager")
	if gs == null or save == null:
		printerr("MIGRATION FAIL (v2): GameState or SaveManager autoload missing")
		return 1

	if not FileAccess.file_exists(FIXTURE_V2_PATH):
		printerr("MIGRATION FAIL (v2): missing v2 fixture %s (regenerate via gen_meta_v2_fixture.gd, then commit it)" % FIXTURE_V2_PATH)
		return 1

	# Confirm the fixture really is a pre-K2 v2 shape: schema 2, has banked_junk, NO quota.
	var raw := _read_raw(FIXTURE_V2_PATH)
	if raw.get("schema_version", -1) != 2:
		failures.append("fixture schema_version is %s, expected 2 (fixture is not v2)" % str(raw.get("schema_version", -1)))
	if not raw.has("banked_junk"):
		failures.append("v2 fixture is missing banked_junk — a true v2 save MUST have it")
	if raw.has("run_number") or raw.has("quota_target"):
		failures.append("v2 fixture already has run_number/quota_target — a true v2 save must NOT")

	# Stage + load via the production path.
	var slot_meta: String = save.slot_dir(TEST_SLOT_V2) + "/meta.sav"
	_clean_slot(save, TEST_SLOT_V2)
	DirAccess.make_dir_recursive_absolute(slot_meta.get_base_dir())
	var copy_err := DirAccess.copy_absolute(FIXTURE_V2_PATH, slot_meta)
	if copy_err != OK:
		printerr("MIGRATION FAIL (v2): could not stage fixture into slot (err %d)" % copy_err)
		_clean_slot(save, TEST_SLOT_V2)
		return 1

	var migrated: Dictionary = save.load_meta(TEST_SLOT_V2)

	# Assert 1: migrated to the current schema (v3).
	if migrated.get("schema_version", -1) != save.META_SCHEMA_VERSION:
		failures.append("post-migration schema_version == %s, expected %d"
			% [str(migrated.get("schema_version", -1)), save.META_SCHEMA_VERSION])

	# Assert 2: quota defaults added (run_number=1, quota_target=0), both in the dict
	# and reflected on GameState after from_meta_dict.
	if migrated.get("run_number", -1) != 1:
		failures.append("v2->v3 run_number == %s, expected 1" % str(migrated.get("run_number", -1)))
	if migrated.get("quota_target", -1) != 0:
		failures.append("v2->v3 quota_target == %s, expected 0" % str(migrated.get("quota_target", -1)))
	if gs.run_number != 1:
		failures.append("GameState.run_number == %d after v2 load, expected 1" % gs.run_number)
	if gs.quota_target != 0:
		failures.append("GameState.quota_target == %d after v2 load, expected 0" % gs.quota_target)

	# Assert 3: every pre-existing v2 field survived intact.
	if gs.money != EXPECT_V2_MONEY:
		failures.append("money %d != expected %d" % [gs.money, EXPECT_V2_MONEY])
	if gs.salvage != EXPECT_V2_SALVAGE:
		failures.append("salvage %d != expected %d" % [gs.salvage, EXPECT_V2_SALVAGE])
	if gs.lore != EXPECT_V2_LORE:
		failures.append("lore %d != expected %d" % [gs.lore, EXPECT_V2_LORE])
	if gs.exposure != EXPECT_V2_EXPOSURE:
		failures.append("exposure %d != expected %d" % [gs.exposure, EXPECT_V2_EXPOSURE])
	if gs.knowledge_level != EXPECT_V2_KNOWLEDGE:
		failures.append("knowledge_level %d != expected %d" % [gs.knowledge_level, EXPECT_V2_KNOWLEDGE])
	if gs.unlocked_recipes.size() != EXPECT_V2_RECIPES.size():
		failures.append("unlocked_recipes has %d entries, expected %d"
			% [gs.unlocked_recipes.size(), EXPECT_V2_RECIPES.size()])
	else:
		for i in EXPECT_V2_RECIPES.size():
			if String(gs.unlocked_recipes[i]) != EXPECT_V2_RECIPES[i]:
				failures.append("unlocked_recipes[%d] == %s, expected %s"
					% [i, String(gs.unlocked_recipes[i]), EXPECT_V2_RECIPES[i]])
	# banked_junk was an empty id list in the v2 fixture → rehydrates to empty.
	if gs.banked_junk.size() != 0:
		failures.append("banked_junk rehydrated to %d items, expected 0" % gs.banked_junk.size())

	# Assert 4: round-trip + .bak.
	var save_err: int = save.save_meta(TEST_SLOT_V2)
	if save_err != OK:
		failures.append("round-trip save_meta failed (err %d)" % save_err)
	if not FileAccess.file_exists(slot_meta + ".bak"):
		failures.append("atomic write did not preserve a .bak of the prior good meta.sav")
	gs.money = 0  # scribble so a stale read is detectable
	var reread: Dictionary = save.load_meta(TEST_SLOT_V2)
	if reread.get("schema_version", -1) != save.META_SCHEMA_VERSION:
		failures.append("re-saved meta did not reload at v%d" % save.META_SCHEMA_VERSION)
	if gs.money != EXPECT_V2_MONEY:
		failures.append("round-trip lost money: reloaded %d, expected %d" % [gs.money, EXPECT_V2_MONEY])

	# Cleanup.
	_clean_slot(save, TEST_SLOT_V2)
	var clean: Array[JunkItem] = []
	gs.banked_junk = clean
	gs.money = 0
	gs.salvage = 0
	gs.lore = 0
	gs.exposure = 0
	gs.knowledge_level = 0
	gs.unlocked_recipes = [] as Array[StringName]
	gs.run_number = 1
	gs.quota_target = 0

	if failures.is_empty():
		print("SAVE MIGRATION OK — v2 meta fixture migrates to v3 (run_number=1/quota_target=0 added, all v2 fields intact, round-trip re-serializes at the current schema with .bak preserved).")
		return 0
	for f in failures:
		printerr("MIGRATION FAIL (v2): ", f)
	return 1


## Read a meta blob raw (objects-OFF), mirroring SaveManager._read_one, so we can
## inspect the fixture's *pre-migration* shape.
func _read_raw(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var(false)
	f.close()
	return v if v is Dictionary else {}


## Remove a slot's meta.sav, .tmp, and .bak so each run starts clean and we leave
## nothing behind.
func _clean_slot(save: Node, slot: int) -> void:
	var dir: String = save.slot_dir(slot)
	var meta: String = dir + "/meta.sav"
	for p in [meta, meta + ".bak", meta + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	# Drop the now-empty test slot dir so the harness leaves nothing behind.
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)
