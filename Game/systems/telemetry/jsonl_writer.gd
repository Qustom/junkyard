extends RefCounted
## JsonlWriter — a dumb, append-only line writer (G1).
##
## Intentionally has NO knowledge of EventBus, autoloads, or the schema: you hand
## it a path and feed it strings. This is the seam G2 unit-tests directly (write
## rows, read them back, assert each line is parseable JSON with the envelope
## fields) WITHOUT booting the Telemetry autoload — which matters because autoload
## globals don't resolve under `godot --headless --script` (see M1_As_Built
## "Testing constraints").
##
## Lifecycle: `new(path)` ensures the parent dir exists and opens the file in
## append mode (creating it if absent, never truncating an existing log).
## `append_line(s)` writes `s + "\n"`. `flush()` forces a durability sync;
## `close()` flushes and releases the handle. `is_open()` reports state.
##
## Crash-safety note (G1 recommendation): callers flush on run_ended, on
## tree-exit, and opportunistically on high-value events. Event volume per run is
## tiny (tens of lines) so frequent flushes are effectively free and a mid-run
## crash still preserves the funnel-defining rows.
##
## Rotation (V7, M1.12): size-capped, one rolled `.1` generation. `_open()`
## re-reads the TRUE on-disk length every time (never a cached/assumed 0), so a
## mid-session Settings toggle (close then reopen the same path) or a later
## process launch never fools the cap into under-counting pre-existing bytes.
## When the next `append_line()` would push the file past `_max_bytes`, the
## CURRENT active file is rolled aside to `<path>.1` (replacing any older `.1`)
## and a fresh, empty file is opened at the same well-known `path` — so every
## reader that looks up the schema's `LOG_PATH` (TelemetryExporter, the dozen
## hardcoded-path tests) keeps finding "the log" at the same name, rotated or
## not. Mirrors `save_manager.gd`'s atomic tmp/`.bak` rename idiom. Schema-blind:
## takes pre-serialized strings, never inspects row shape, never bumps
## SCHEMA_VERSION — this is a file-lifecycle change only.

class_name JsonlWriter

const DEFAULT_MAX_BYTES: int = 2 * 1024 * 1024   # 2 MB soft cap (TelemetrySchema.MAX_LOG_BYTES mirrors this)

var _path: String = ""
var _file: FileAccess = null
var _open_error: int = OK
var _max_bytes: int = DEFAULT_MAX_BYTES
var _size_bytes: int = 0                          # true on-disk length, refreshed on every _open()


func _init(path: String, max_bytes: int = DEFAULT_MAX_BYTES) -> void:
	_path = path
	_max_bytes = max_bytes
	_open(path)


## Open (or re-open) the log in append mode, creating the parent dir first. Safe
## to call when already open (no-op). On failure `_open_error` carries the code
## and `is_open()` stays false; callers (Telemetry) degrade gracefully — telemetry
## is best-effort and must never crash the game.
func _open(path: String) -> void:
	if _file != null:
		return
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	# READ_WRITE preserves an existing file; WRITE_READ creates a fresh one.
	# FileAccess has no append mode flag, so open then seek to end.
	if FileAccess.file_exists(path):
		_file = FileAccess.open(path, FileAccess.READ_WRITE)
	else:
		_file = FileAccess.open(path, FileAccess.WRITE_READ)
	if _file == null:
		_open_error = FileAccess.get_open_error()
		push_warning("JsonlWriter: could not open %s (err %d); telemetry disabled for this session." % [path, _open_error])
		return
	_open_error = OK
	_file.seek_end()
	_size_bytes = _file.get_length()  # true on-disk size, re-read every open — never assumed


## Append one line. The caller passes an already-serialized JSON string; we add
## the trailing newline. No-op if the file never opened. Rotates EXISTING
## content out of the way first if this append would cross `_max_bytes` — never
## rotates on the very first line into an empty file (guards against one
## oversized line looping forever).
func append_line(line: String) -> void:
	if _file == null:
		return
	var added := line.to_utf8_buffer().size() + 1  # +1 for store_line's trailing "\n"
	if _size_bytes > 0 and _size_bytes + added > _max_bytes:
		_rotate()
		if _file == null:  # rotation failed to reopen; degrade gracefully
			return
	_file.seek_end()
	_file.store_line(line)
	_size_bytes += added


## Roll the current active file aside to `<path>.1` (dropping any older `.1`)
## and open a fresh, empty file at the same well-known `path`. Mirrors
## `save_manager.gd`'s atomic tmp-then-rename idiom, reversed: here the OLD
## file becomes the backup generation instead of the new one.
func _rotate() -> void:
	_file.flush()
	_file.close()
	_file = null
	var bak_path := _path + ".1"
	if FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)          # ring depth 1 — drop the OLDER .1
	DirAccess.rename_absolute(_path, bak_path)        # this session's overflow -> .1
	_file = FileAccess.open(_path, FileAccess.WRITE_READ)  # fresh, empty, at the SAME name
	if _file == null:
		_open_error = FileAccess.get_open_error()
		push_warning("JsonlWriter: rotation could not reopen %s (err %d)" % [_path, _open_error])
		return
	_open_error = OK
	_size_bytes = 0


func flush() -> void:
	if _file != null:
		_file.flush()


func close() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func is_open() -> bool:
	return _file != null


func get_open_error() -> int:
	return _open_error


func get_path() -> String:
	return _path
