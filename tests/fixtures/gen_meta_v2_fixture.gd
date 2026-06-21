extends SceneTree
## Generator for the committed v2 meta-save fixture (K2, M1.4).
##
## Writes tests/fixtures/meta_v2.sav as a BINARY blob via the exact same
## mechanism SaveManager uses on disk — FileAccess.store_var(dict, false)
## (object serialization OFF). This pins the *pre-K2* v2 on-disk format: a v2 meta
## dict that carries ALL the v1 fields PLUS `banked_junk` (the field E1 added at
## v1->v2), at schema_version = 2, and crucially has NO `run_number`/`quota_target`
## key (those are what the v2->v3 migration adds).
##
## Regenerate (only when the historical v2 shape itself must change — which it
## should not, that is the point of a frozen fixture):
##   godot --headless --script res://tests/fixtures/gen_meta_v2_fixture.gd
##
## The known values below are mirrored by EXPECT_V2_* in test_save_migration.gd —
## change them in lockstep if you ever regenerate. They deliberately DIFFER from the
## v1 fixture's values so the test can tell the two fixtures apart.

const FIXTURE_PATH := "res://tests/fixtures/meta_v2.sav"

func _initialize() -> void:
	# The v2 meta shape, exactly as a pre-K2 (post-E1) build would have written it:
	# schema_version = 2, a `banked_junk` id list present, and NO run_number/quota_target.
	# banked_junk holds an EMPTY id list so the test does not depend on specific catalog
	# ids surviving — the migration's job is to preserve the key + add the v3 defaults.
	var banked_ids: Array = []
	var v2: Dictionary = {
		"schema_version": 2,
		"money": 2500,
		"salvage": 17,
		"lore": 4,
		"exposure": 31,
		"knowledge_level": 1,
		"unlocked_recipes": ["recipe_gamma"],
		"banked_junk": banked_ids,
	}

	var abs_path := ProjectSettings.globalize_path(FIXTURE_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())

	var f := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	if f == null:
		printerr("GEN FAIL: cannot open %s (err %d)" % [FIXTURE_PATH, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_var(v2, false)  # full_objects = false — mirrors SaveManager._atomic_store
	f.close()

	print("GEN OK — wrote v2 meta fixture to ", FIXTURE_PATH)
	quit(0)
