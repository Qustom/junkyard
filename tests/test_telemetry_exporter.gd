extends SceneTree
## Headless verification for DLV2 — TelemetryExporter (web telemetry export).
##
## The browser download (`JavaScriptBridge.download_buffer`) cannot run headless, so
## this proves the PURE, platform-agnostic half of the exporter: that it assembles the
## exact bytes of the on-disk log and the correct self-labelling filename. The web side
## (the actual download) is verified by a human on the itch build (Chromium).
##
## Asserts:
##   - read_log_bytes() with no log → empty (never errors);
##   - read_log_bytes() after writing a known JSONL → byte-identical to what was written;
##   - download_filename() == "run_log_<BuildVersion.id()>.jsonl";
##   - is_supported() == OS.has_feature("web") (false under a headless desktop run);
##   - trigger_download() is an inert no-op (false) off-web, even with non-empty bytes.
## Run: godot --headless --script res://tests/test_telemetry_exporter.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var log_path := TelemetryExporter.LOG_PATH

	# Clean slate: remove any existing log so the "no log" assertions are real.
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)

	# 1) No log yet → empty bytes, has_log() false, never errors.
	if not TelemetryExporter.read_log_bytes().is_empty():
		failures.append("read_log_bytes() should be empty when no log exists")
	if TelemetryExporter.has_log():
		failures.append("has_log() should be false when no log exists")

	# 2) Write a known JSONL log, then assert read_log_bytes() is byte-identical.
	var sample := "{\"v\":1,\"type\":\"run_started\"}\n{\"v\":1,\"type\":\"run_ended\"}\n"
	var expected_bytes := sample.to_utf8_buffer()
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		printerr("DLV2 FAIL: could not write sample log at %s" % log_path)
		quit(1)
		return
	f.store_string(sample)
	f.close()

	if not TelemetryExporter.has_log():
		failures.append("has_log() should be true after writing the log")

	var read_back := TelemetryExporter.read_log_bytes()
	if read_back != expected_bytes:
		failures.append("read_log_bytes() != written bytes (got %d, expected %d)"
			% [read_back.size(), expected_bytes.size()])

	# 3) Filename is self-labelling by build id.
	var expected_name := "run_log_%s.jsonl" % BuildVersion.id()
	if TelemetryExporter.download_filename() != expected_name:
		failures.append("download_filename() == %s, expected %s"
			% [TelemetryExporter.download_filename(), expected_name])

	# 4) Platform guard matches OS.has_feature("web") and is inert off-web.
	if TelemetryExporter.is_supported() != OS.has_feature("web"):
		failures.append("is_supported() must equal OS.has_feature(\"web\")")
	if not OS.has_feature("web"):
		# Off-web: trigger/export are no-ops even with real bytes — must not touch JS.
		if TelemetryExporter.trigger_download(expected_bytes, expected_name):
			failures.append("trigger_download() must return false off-web")
		if TelemetryExporter.export():
			failures.append("export() must return false off-web")

	# Cleanup.
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)

	if failures.is_empty():
		print("DLV2 EXPORTER OK")
		quit(0)
	else:
		for msg in failures:
			printerr("DLV2 FAIL: %s" % msg)
		quit(1)
