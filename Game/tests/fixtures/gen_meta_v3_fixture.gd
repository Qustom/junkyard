extends SceneTree
## Generator for the committed v3 meta-save fixture (M1.6 M3).
##
## Writes tests/fixtures/meta_v3.sav as a BINARY blob via the exact same
## mechanism SaveManager uses on disk — FileAccess.store_var(dict, false)
## (object serialization OFF). This pins the *pre-M3* v3 on-disk format: a v3 meta
## dict that carries ALL the v1 fields PLUS `banked_junk` (v1->v2) PLUS the K2
## pair `run_number`/`quota_target` (v2->v3), at schema_version = 3, and crucially
## has NO `owned_items` key (that is what the v3->v4 migration adds).
##
## Regenerate (only when the historical v3 shape itself must change — which it
## should not, that is the point of a frozen fixture):
##   godot --headless --script res://tests/fixtures/gen_meta_v3_fixture.gd
##
## The known values below are mirrored by EXPECT_V3_* in test_save_migration.gd —
## change them in lockstep if you ever regenerate. They deliberately DIFFER from the
## v1 and v2 fixtures' values so the test can tell the three fixtures apart.

const FIXTURE_PATH := "res://tests/fixtures/meta_v3.sav"

func _initialize() -> void:
	# The v3 meta shape, exactly as a pre-M3 (post-K2) build would have written it:
	# schema_version = 3, a `banked_junk` id list present, run_number/quota_target
	# present, and NO owned_items. banked_junk holds an EMPTY id list so the test does
	# not depend on specific catalog ids surviving — the migration's job is to preserve
	# the keys + add the v4 default.
	var banked_ids: Array = []
	var v3: Dictionary = {
		"schema_version": 3,
		"money": 3700,
		"salvage": 22,
		"lore": 8,
		"exposure": 55,
		"knowledge_level": 2,
		"unlocked_recipes": ["recipe_delta", "recipe_epsilon"],
		"banked_junk": banked_ids,
		"run_number": 4,
		"quota_target": 200,
	}

	var abs_path := ProjectSettings.globalize_path(FIXTURE_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())

	var f := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	if f == null:
		printerr("GEN FAIL: cannot open %s (err %d)" % [FIXTURE_PATH, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_var(v3, false)  # full_objects = false — mirrors SaveManager._atomic_store
	f.close()

	print("GEN OK — wrote v3 meta fixture to ", FIXTURE_PATH)
	quit(0)
