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

class_name JsonlWriter

var _path: String = ""
var _file: FileAccess = null
var _open_error: int = OK


func _init(path: String) -> void:
	_path = path
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


## Append one line. The caller passes an already-serialized JSON string; we add
## the trailing newline. No-op if the file never opened.
func append_line(line: String) -> void:
	if _file == null:
		return
	_file.seek_end()
	_file.store_line(line)


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
