extends SceneTree
## Generator for the committed v1 meta-save fixture (G5).
##
## Writes tests/fixtures/meta_v1.sav as a BINARY blob via the exact same
## mechanism SaveManager uses on disk — FileAccess.store_var(dict, false)
## (object serialization OFF). This pins the *pre-E1* on-disk format: a v1 meta
## dict that carries the original fields and crucially has NO `banked_junk` key.
##
## Regenerate (only when the historical v1 shape itself must change — which it
## should not, that is the point of a frozen fixture):
##   godot --headless --script res://tests/fixtures/gen_meta_v1_fixture.gd
##
## The known values below are mirrored by EXPECT_* in test_save_migration.gd —
## change them in lockstep if you ever regenerate.

const FIXTURE_PATH := "res://tests/fixtures/meta_v1.sav"

func _initialize() -> void:
	# The v1 meta shape, exactly as a pre-E1 build would have written it:
	# schema_version = 1 and NO `banked_junk` key. Object serialization is OFF,
	# so every value is a plain built-in (ints + an Array of String recipe ids).
	var v1: Dictionary = {
		"schema_version": 1,
		"money": 1337,
		"salvage": 42,
		"lore": 9,
		"exposure": 73,
		"knowledge_level": 3,
		"unlocked_recipes": ["recipe_alpha", "recipe_beta"],
	}

	var abs_path := ProjectSettings.globalize_path(FIXTURE_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())

	var f := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	if f == null:
		printerr("GEN FAIL: cannot open %s (err %d)" % [FIXTURE_PATH, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_var(v1, false)  # full_objects = false — mirrors SaveManager._atomic_store
	f.close()

	print("GEN OK — wrote v1 meta fixture to ", FIXTURE_PATH)
	quit(0)
