extends Node
## Headless verification for V7 (M1.12) — JsonlWriter size-capped rotation.
##
## Runs as a SCENE (not --script), matching the suite's uniform invocation
## convention (Resolved Decision #7 of V7_telemetry_rotation.md):
##   godot --headless res://tests/test_jsonl_writer_rotation.tscn
##
## JsonlWriter is a bare RefCounted seam with NO autoload/EventBus knowledge
## (per its own docstring), so this test never touches Telemetry/EventBus — it
## drives the writer directly at a tiny cap and asserts the on-disk rotation
## contract:
##   1. A single rotation (a batch that crosses the cap exactly once) rolls the
##      OLDER lines to `<path>.1` and keeps only the newer line(s) in the active
##      file at the SAME well-known path — with nothing lost across the two
##      files for that one rotation.
##   2. Sustained overflow across MANY appends causes repeated rotations; ring
##      depth stays exactly 1 (each new rotation replaces `.1`, it never grows a
##      chain) — the oldest content is correctly gone, not silently
##      accumulated. This is the documented, accepted lossy-but-bounded
##      behavior under sustained overflow (Resolved Decision #2).
##   3. A brand-new `JsonlWriter` at the SAME path (simulating a Settings
##      toggle-off/on, or a later process launch) re-reads the TRUE on-disk
##      length rather than assuming empty — so a tiny remaining margin to the
##      cap still rotates promptly instead of writing unbounded new bytes past
##      the cap first.

const JsonlWriterScript := preload("res://systems/telemetry/jsonl_writer.gd")

const TEST_PATH := "user://telemetry/_test_rotation.jsonl"
const BAK_PATH := TEST_PATH + ".1"

# "line N 0123456789" is 17 chars for single-digit N (0-9) -> +1 newline = 18
# bytes per append_line call. Fixed width keeps the rotation arithmetic exact.
const LINE_BYTES := 18
const CAP := 50  # rotates once size+18 > 50, i.e. once 2 lines (36B) are on disk


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	var failures: Array[String] = []

	_cleanup()

	# --- Case 1: exactly one rotation, nothing lost -------------------------
	# line0 (size 0->18, guarded from rotating on an empty file), line1
	# (18->36, still under cap), line2 (36+18=54>50 -> rotates the file
	# holding line0+line1 to `.1`, then line2 lands in a fresh active file).
	var w := JsonlWriterScript.new(TEST_PATH, CAP)
	if not w.is_open():
		printerr("ROTATION FAIL: writer did not open (err %d)" % w.get_open_error())
		return 1
	for i in range(3):
		w.append_line("line %d 0123456789" % i)
	w.close()

	if not FileAccess.file_exists(BAK_PATH):
		failures.append("Case 1: expected a '.1' generation after crossing the cap once, found none")
	var active1 := _line_count(TEST_PATH)
	var bak1 := _line_count(BAK_PATH)
	if active1 != 1:
		failures.append("Case 1: expected 1 line in the active file (the newest), found %d" % active1)
	if bak1 != 2:
		failures.append("Case 1: expected 2 lines rolled into '.1' (the older ones), found %d" % bak1)
	if active1 + bak1 != 3:
		failures.append("Case 1: lines lost or duplicated across one rotation: active=%d + .1=%d != 3" % [active1, bak1])
	var bak1_text := FileAccess.get_file_as_string(BAK_PATH)
	if bak1_text.find("line 0 ") == -1 or bak1_text.find("line 1 ") == -1:
		failures.append("Case 1: '.1' does not contain the expected rolled lines 0 and 1")
	var active1_text := FileAccess.get_file_as_string(TEST_PATH)
	if active1_text.find("line 2 ") == -1:
		failures.append("Case 1: active file does not contain the expected newest line 2")

	# --- Case 2: sustained overflow -> ring depth stays 1 (not a chain) -----
	# Reopen at the SAME path (this also exercises the toggle-reopen path) and
	# write 7 more lines (3..9) at the same tiny cap. Multiple further
	# rotations WILL occur; each one replaces '.1' rather than accumulating,
	# so the oldest content (line 0, line 1, and the mid-run lines) must be
	# gone — only the final two generations survive. This is the accepted,
	# documented lossy-but-bounded behavior under sustained overflow, not a
	# bug: an unattended long-running writer stays bounded at ~2x the cap
	# instead of growing forever.
	var w2 := JsonlWriterScript.new(TEST_PATH, CAP)
	for i in range(3, 10):
		w2.append_line("line %d 0123456789" % i)
	w2.close()

	var active2 := _line_count(TEST_PATH)
	var bak2 := _line_count(BAK_PATH)
	var total_written := 10
	if active2 + bak2 >= total_written:
		failures.append("Case 2: sustained overflow should have dropped some older content (ring depth 1), but active=%d + .1=%d >= %d written" % [active2, bak2, total_written])
	if active2 == 0 or bak2 == 0:
		failures.append("Case 2: expected BOTH an active file and a '.1' generation to still exist, got active=%d .1=%d" % [active2, bak2])
	var bak2_text := FileAccess.get_file_as_string(BAK_PATH)
	if bak2_text.find("line 0 ") != -1 or bak2_text.find("line 1 ") != -1:
		failures.append("Case 2: '.1' still contains line 0/1 from the FIRST rotation — ring depth exceeded 1 (should have been replaced)")

	# --- Case 3: reopen at the same path re-reads the TRUE on-disk size -----
	# (never assumes a fresh writer object means an empty/zero file), so a cap
	# set just above the pre-existing size still rotates promptly rather than
	# needing a full new cap's worth of bytes first.
	_cleanup()
	var w3 := JsonlWriterScript.new(TEST_PATH, 1_000_000)  # cap huge: no rotation expected yet
	for i in range(5):
		w3.append_line("seed line %d" % i)
	w3.close()  # simulate set_enabled(false)

	var w4 := JsonlWriterScript.new(TEST_PATH, 1_000_000)  # simulate set_enabled(true): reopen same path
	w4.append_line("seed line 5")
	w4.close()
	if FileAccess.file_exists(BAK_PATH):
		failures.append("Case 3: reopening at the same path caused an unexpected rotation against a large cap")
	var total_after_reopen := _line_count(TEST_PATH)
	if total_after_reopen != 6:
		failures.append("Case 3: expected 6 lines after reopen+append (no rotation), found %d" % total_after_reopen)

	var on_disk_size := FileAccess.get_file_as_bytes(TEST_PATH).size()
	var w5 := JsonlWriterScript.new(TEST_PATH, on_disk_size + 5)  # cap barely above current size
	w5.append_line("this line alone should trigger rotation almost immediately")
	w5.close()
	if not FileAccess.file_exists(BAK_PATH):
		failures.append("Case 3: reopen did not re-read the true on-disk length — rotation failed to fire at a cap set just above the existing size")

	_cleanup()

	if failures.is_empty():
		print("JSONL ROTATION OK — a single overflow rotates to one '.1' generation with nothing lost; sustained overflow keeps ring depth at 1 (bounded, not chained); reopening at the same path re-reads the true on-disk length.")
		return 0
	for f in failures:
		printerr("ROTATION FAIL: ", f)
	return 1


func _line_count(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := 0
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() != "":
			n += 1
	f.close()
	return n


func _cleanup() -> void:
	for p in [TEST_PATH, BAK_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
