class_name TelemetryExporter
extends RefCounted
## TelemetryExporter (DLV2) — pull the telemetry JSONL out of a *web* build.
##
## WHY THIS EXISTS: on a desktop build `user://telemetry/run_log.jsonl` is a real
## file on disk and the proven "zip %APPDATA% and send" tester flow retrieves it. On
## a WEB build `user://` maps to the browser's IndexedDB-backed VFS — readable from
## GDScript via `FileAccess`, but NOT reachable by that desktop flow. RG2's web re-gate
## is 100% dependent on getting the `.jsonl` back, so DLV2 adds an in-game way to
## download the log straight to the player's browser Downloads (Director: "web must
## carry data").
##
## DESIGN BOUNDARY: this is a pure READER. It never writes telemetry, never touches
## the schema/arity, never adds an EventBus signal — determinism is untouched. It only
## reads the existing log and hands the bytes to the browser.
##
## SPLIT FOR TESTABILITY: `read_log_bytes()` + `download_filename()` are pure and run
## headless (a test can write a known log and assert the exact bytes/name come back).
## `trigger_download()` is the web-only side-effect (calls `JavaScriptBridge`), which a
## headless run can never exercise — `export()` ties them together with the platform
## guard.
##
## DOWNLOAD IDIOM: Godot 4's `JavaScriptBridge.download_buffer(buffer, name, mime)` is
## the engine's built-in wrapper around the Blob + `<a download>` click — it is the
## current 4.6 idiom and is more robust than a hand-rolled `JavaScriptBridge.eval`
## shim (the engine handles object lifetime / cross-origin Blob URLs). It MUST be
## called from a user interaction (a button press) or the browser blocks it — which is
## exactly how the SellScreen wires it.

## The log we export. Single source of truth: the schema module's LOG_PATH.
const LOG_PATH: String = TelemetrySchema.LOG_PATH

## JSONL is line-delimited JSON; this MIME keeps it readable/saveable as text. The
## browser may still override based on the `.jsonl` extension (harmless).
const MIME_TYPE: String = "application/x-ndjson"


## True only on an actual web export. The control is shown/enabled only here; on
## desktop the export is a no-op (desktop keeps its on-disk retrieval flow).
static func is_supported() -> bool:
	return OS.has_feature("web")


## Whether there is anything to export yet (a log file exists). Lets the UI disable
## the control + show a "no telemetry yet" hint instead of downloading an empty file.
static func has_log() -> bool:
	return FileAccess.file_exists(LOG_PATH)


## Read the raw JSONL bytes from the VFS. Returns an empty PackedByteArray if the log
## does not exist (no run logged yet) — never errors. Pure + headless-testable.
static func read_log_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(LOG_PATH):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(LOG_PATH)


## Self-labelling download name, e.g. "run_log_m1-20260619-691d9da.jsonl", so a batch
## of tester downloads is trivially cohorted by build for RG2. Pure + headless-testable.
static func download_filename() -> String:
	return "run_log_%s.jsonl" % BuildVersion.id()


## Hand the bytes to the browser as a download. WEB-ONLY side effect: on any non-web
## platform this is an inert no-op (returns false) so calling it on desktop is safe.
## Returns true when the download was actually triggered (web + non-empty log).
static func trigger_download(bytes: PackedByteArray, filename: String) -> bool:
	if not is_supported():
		return false
	if bytes.is_empty():
		return false
	# Godot 4 built-in: builds a Blob from the buffer and clicks a transient
	# `<a download>` for us. Must run inside a user gesture (button press) or the
	# browser blocks it.
	JavaScriptBridge.download_buffer(bytes, filename, MIME_TYPE)
	return true


## The one call the UI makes. Reads the current log and (on web, if non-empty) starts
## the browser download. Returns true if a download was triggered, false otherwise
## (desktop, or no log yet) — the UI uses this to drive a confirm/hint message.
static func export() -> bool:
	if not is_supported():
		return false
	var bytes := read_log_bytes()
	if bytes.is_empty():
		return false
	return trigger_download(bytes, download_filename())
