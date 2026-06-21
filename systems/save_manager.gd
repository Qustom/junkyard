extends Node
## SaveManager — the decided save architecture (TDD §3, research §9 `10_save_architecture.md`).
##
##   * State lives as typed values in memory (GameState); we serialize to disk
##     with FileAccess.store_var(value, full_objects = false) — object
##     serialization OFF, so there is no .tres code-execution risk, the blob is
##     compact, and it stays migration-friendly.
##   * Per-slot files: meta.sav (persists) + run.sav (resumable in-progress dive),
##     each carrying an integer schema_version.
##   * Migrations are an ordered, stepwise chain (v -> v+1 -> ...).
##   * Writes are atomic (tmp -> rename) with a .bak of the previous good file,
##     so autosave-on-sleep/extract can never corrupt meta-state.

const SAVE_ROOT := "user://saves"
const META_SCHEMA_VERSION := 3
const RUN_SCHEMA_VERSION := 1

func slot_dir(slot: int) -> String:
	return "%s/slot_%d" % [SAVE_ROOT, slot]

# --- Public API --------------------------------------------------------------
func save_meta(slot: int) -> Error:
	var data := GameState.to_meta_dict()
	data["schema_version"] = META_SCHEMA_VERSION
	return _atomic_store(slot_dir(slot) + "/meta.sav", data)

func load_meta(slot: int) -> Dictionary:
	var data := _load_var(slot_dir(slot) + "/meta.sav")
	if data.is_empty():
		return {}
	data = _migrate_meta(data)
	GameState.from_meta_dict(data)
	return data

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_dir(slot) + "/meta.sav")

# --- Atomic, backed-up write -------------------------------------------------
func _atomic_store(path: String, data: Dictionary) -> Error:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(data, false)  # full_objects = false — safe-by-default
	f.close()

	# Back up the previous good file before swapping in the new one.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")

	return DirAccess.rename_absolute(tmp, path)  # atomic on same filesystem

# --- Load with .bak fallback -------------------------------------------------
func _load_var(path: String) -> Dictionary:
	var d := _read_one(path)
	if d.is_empty() and FileAccess.file_exists(path + ".bak"):
		push_warning("Primary save unreadable, recovering from .bak: %s" % path)
		d = _read_one(path + ".bak")
	return d

func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var(false)  # full_objects = false, mirrors the write
	f.close()
	return v if v is Dictionary else {}

# --- Stepwise migration chain ------------------------------------------------
func _migrate_meta(data: Dictionary) -> Dictionary:
	var v: int = data.get("schema_version", 0)
	while v < META_SCHEMA_VERSION:
		match v:
			0:
				# v0 -> v1: example shape — set defaults for newly added fields.
				if not data.has("knowledge_level"):
					data["knowledge_level"] = 0
			1:
				# v1 -> v2 (E1): banked_junk added. Old saves have none; default
				# to an empty id list so from_meta_dict rehydrates to [].
				if not data.has("banked_junk"):
					data["banked_junk"] = []
			2:
				# v2 -> v3 (K2): run_number + quota_target added. Old saves predate
				# the quota → default to run 1 / "uninitialised" (0) so the first
				# quota-enabled start_run re-seeds the bar from quota_base.
				if not data.has("run_number"):
					data["run_number"] = 1
				if not data.has("quota_target"):
					data["quota_target"] = 0
		v += 1
		data["schema_version"] = v
	return data
