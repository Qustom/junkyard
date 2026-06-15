extends SceneTree
## Headless verification for A3 in-dive clock (DiveClock).
##
## Boots the project headless (autoloads incl. EventBus/GameState present), builds
## a DiveClock with a SHORT config, simulates a dive via EventBus.run_started, and
## drives the drain by calling _process(delta) in a loop — _process is not pumped
## for a node we never add to the tree in a raw SceneTree --script run, so we call
## it directly, exactly as the engine would each idle frame. Asserts:
##   - dive_clock_changed fires (the meter has data),
##   - light reaches 0,
##   - dive_clock_timeout fires EXACTLY ONCE (guard holds on later frames),
##   - run_ended stops the drain with no timeout (separate sub-case),
##   - the guarded modify_light() refuels and re-drains correctly.
## Run: godot --headless --script res://tests/test_dive_clock.gd

const DIVE_CLOCK_PATH := "res://systems/dive_clock.gd"
const DIVE_CLOCK_CONFIG_PATH := "res://data/dive/dive_clock_config.gd"

var _changed_count: int = 0
var _last_current: float = -1.0
var _last_max: float = -1.0
var _timeout_count: int = 0


## Autoload global identifiers (EventBus/GameState) do not resolve as bare names
## inside a raw `SceneTree --script` tool run, so we fetch the singleton via the
## scene tree root (same pattern as tools/ci_smoke_test.gd) and use it locally.
var EventBus: Node


func _initialize() -> void:
	var failures: Array[String] = []

	EventBus = root.get_node_or_null("EventBus")
	if EventBus == null:
		printerr("DIVE CLOCK FAIL: EventBus autoload missing")
		quit(1)
		return

	# load() at runtime (not preload/const) so these scripts compile in the live
	# project context where the EventBus autoload global resolves — same reason
	# tools/ci_smoke_test.gd reaches autoloads via root. Untyped (Variant) to
	# avoid cross-file class_name resolution quirks in a tool-script run.
	var config_script: Variant = load(DIVE_CLOCK_CONFIG_PATH)
	var clock_script: Variant = load(DIVE_CLOCK_PATH)

	# Short budget so the loop finishes fast: 5 light, 10/s => 0.5s to empty.
	var config: Variant = config_script.new()
	config.max_light = 5.0
	config.start_light = 0.0
	config.drain_per_second = 10.0

	var clock: Variant = clock_script.new()
	clock.config = config
	# _ready() (which connects EventBus + sets process_mode) runs on tree entry;
	# we are not adding to the tree, so connect the signals manually as _ready would.
	EventBus.dive_clock_changed.connect(_on_changed)
	EventBus.dive_clock_timeout.connect(_on_timeout)
	# Wire the clock's own EventBus listeners (what _ready normally does).
	EventBus.run_started.connect(clock._on_run_started)
	EventBus.run_ended.connect(clock._on_run_ended)

	# --- Sub-case 1: full drain to timeout ----------------------------------
	EventBus.run_started.emit(&"test_band", 123)

	if not clock.is_active():
		failures.append("clock not active after run_started")
	if not is_equal_approx(clock.get_light(), config.max_light):
		failures.append("start light != max (%.2f != %.2f)" % [clock.get_light(), config.max_light])
	if _changed_count < 1:
		failures.append("dive_clock_changed did not fire on start")

	# Drive ~1.0s at 60 FPS (well past the 0.5s needed) so we keep ticking AFTER
	# zero to prove the guard prevents a second timeout.
	var delta := 1.0 / 60.0
	for _i in range(60):
		clock._process(delta)

	if not is_equal_approx(clock.get_light(), 0.0):
		failures.append("light did not reach 0 (%.4f)" % clock.get_light())
	if not is_equal_approx(_last_current, 0.0):
		failures.append("last dive_clock_changed current != 0 (%.4f)" % _last_current)
	if not is_equal_approx(_last_max, config.max_light):
		failures.append("dive_clock_changed maximum wrong (%.2f)" % _last_max)
	if _timeout_count != 1:
		failures.append("dive_clock_timeout fired %d times, expected exactly 1" % _timeout_count)
	if clock.is_active():
		failures.append("clock still active after timeout (should deactivate)")
	if _changed_count < 2:
		failures.append("dive_clock_changed fired too few times (%d)" % _changed_count)

	# --- Sub-case 2: run_ended stops the drain, fires NO timeout ------------
	_timeout_count = 0
	EventBus.run_started.emit(&"test_band", 123)  # re-arm: light full, guard reset
	clock._process(delta)                          # drain one frame
	var before_end: float = clock.get_light()
	EventBus.run_ended.emit(&"extract", 1.0, 2)    # extract: stop draining
	for _i in range(120):
		clock._process(delta)                      # should be no-ops now
	if not is_equal_approx(clock.get_light(), before_end):
		failures.append("clock kept draining after run_ended (%.4f -> %.4f)" % [before_end, clock.get_light()])
	if _timeout_count != 0:
		failures.append("run_ended path fired a timeout (%d)" % _timeout_count)
	if clock.is_active():
		failures.append("clock active after run_ended")

	# --- Sub-case 3: guarded modify_light refuels + re-drains to timeout ----
	_timeout_count = 0
	EventBus.run_started.emit(&"test_band", 123)   # full again, active, guard reset
	clock.modify_light(-config.max_light - 100.0)  # over-drain: must clamp to 0
	if not is_equal_approx(clock.get_light(), 0.0):
		failures.append("modify_light did not clamp to 0 (%.4f)" % clock.get_light())
	if _timeout_count != 1:
		failures.append("modify_light to zero did not fire exactly one timeout (%d)" % _timeout_count)
	# Refuel attempt after timeout: value clamps up but no second timeout, and the
	# clock stays inactive (timeout already consumed this dive).
	clock.modify_light(100.0)
	if not is_equal_approx(clock.get_light(), config.max_light):
		failures.append("modify_light did not clamp up to max (%.4f)" % clock.get_light())
	if _timeout_count != 1:
		failures.append("refuel after timeout changed timeout count (%d)" % _timeout_count)

	clock.free()

	if failures.is_empty():
		print("DIVE CLOCK OK — drains to 0, dive_clock_timeout fires exactly once, run_ended stops drain, modify_light clamps")
		quit(0)
	else:
		for f in failures:
			printerr("DIVE CLOCK FAIL: ", f)
		quit(1)


func _on_changed(current: float, maximum: float) -> void:
	_changed_count += 1
	_last_current = current
	_last_max = maximum


func _on_timeout() -> void:
	_timeout_count += 1
