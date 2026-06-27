extends Node
## Headless full-loop drive verification (G3) — the strongest G3 proof: programmatically
## drive the WHOLE M1 loop start→finish, MULTIPLE times per session, asserting the
## run/meta boundary holds and the lifecycle fires each run.
##
## Run as a SCENE (not --script) so the EventBus / GameState / Telemetry / SaveManager
## autoloads resolve (As-Built "Testing constraints": autoloads aren't compile-time
## globals under --script):
##   godot --headless res://tests/test_loop_drive.tscn
##
## This deliberately drives GameState's locked API directly (start_run / try_add /
## extract_and_end_run / fail_run / sell_banked_junk) rather than the MainGame scene,
## so it isolates the loop CONTRACT (the thing MainGame wires together) from scene
## geometry. It exercises:
##   Run 1: start → pick up junk → extract (bank identities) → sell (junk→Money).
##   Run 2: start fresh (run-state reset, meta persisted) → pick up → DEATH (pockets) → sell.
##   Run 3: start a third run to prove repeat startability after a fail.
## Asserts: run-state resets each run (fresh empty bag, run_active toggles), meta
## (money / banked_junk) behaves correctly, run_started + run_ended fire each run, the
## kept-pockets subset on death matches floor(haul * pockets_fraction), and a run is
## startable after both an extract and a fail. Prints one `LOOP OK — ...` line.

const RUN_RULES_PATH := "res://data/economy/run_rules.tres"


func _ready() -> void:
	get_tree().quit(_run())


func _make_item(id: StringName, value: int, size: int = 1) -> JunkItem:
	var it := JunkItem.new()
	it.id = id
	it.slot_size = size
	it.base_sell_value = value
	it.containment_flags = JunkItem.ContainmentFlag.PLACEABLE
	return it


func _run() -> int:
	var failures: Array[String] = []

	# --- Signal counters (per-run lifecycle must fire) -----------------------
	var started: Array = []
	var ended: Array = []
	EventBus.run_started.connect(func(band: StringName, seed: int) -> void: started.append([band, seed]))
	EventBus.run_ended.connect(func(reason: StringName, dur: float, depth: int) -> void: ended.append([reason, dur, depth]))

	# Clean meta slate so the money math is asserted from a known base.
	var empty: Array[JunkItem] = []
	GameState.banked_junk = empty.duplicate()
	GameState.money = 0

	var rules: RunRules = load(RUN_RULES_PATH) as RunRules
	var pockets_fraction: float = rules.pockets_fraction if rules != null else 0.20

	# ===================== RUN 1: extract → sell ============================
	GameState.start_run(&"near", 1001)
	if not GameState.run_active:
		failures.append("run1: run_active false after start_run")
	if GameState.run_inventory == null or not GameState.run_inventory.items.is_empty():
		failures.append("run1: bag not fresh+empty at run start")
	if started.size() != 1:
		failures.append("run1: run_started did not fire exactly once (%d)" % started.size())

	GameState.enter_band(&"near")
	GameState.run_inventory.try_add(_make_item(&"a", 30))
	GameState.run_inventory.try_add(_make_item(&"b", 20))
	var haul1: int = GameState.run_haul_value()
	if haul1 != 50:
		failures.append("run1: haul value %d, expected 50" % haul1)

	GameState.extract_and_end_run()
	if GameState.run_active:
		failures.append("run1: run_active still true after extract")
	if GameState.banked_junk.size() != 2:
		failures.append("run1: extract banked %d items, expected 2" % GameState.banked_junk.size())
	if ended.size() != 1 or ended[0][0] != &"extract":
		failures.append("run1: run_ended(extract) did not fire once")
	if GameState.money != 0:
		failures.append("run1: extract credited Money (%d); F2 sell owns that, not E1" % GameState.money)

	# Sell closes the loop: junk identities → Money at base_sell_value.
	var breakdown1: Array[Dictionary] = GameState.sell_banked_junk(&"extract")
	if breakdown1.size() != 2:
		failures.append("run1: sell breakdown %d rows, expected 2" % breakdown1.size())
	if GameState.money != 50:
		failures.append("run1: money after sell %d, expected 50" % GameState.money)
	if not GameState.banked_junk.is_empty():
		failures.append("run1: bank not cleared after sell")

	# ===================== RUN 2: fresh start → death → sell ================
	GameState.start_run(&"near", 2002)
	# Run-state reset proof: the bag from run 1 must NOT survive.
	if GameState.run_inventory == null or not GameState.run_inventory.items.is_empty():
		failures.append("run2: bag not reset to empty on new run")
	if not GameState.run_active:
		failures.append("run2: run_active false after second start_run")
	if started.size() != 2:
		failures.append("run2: run_started count %d, expected 2" % started.size())
	# Meta persisted across the run boundary.
	if GameState.money != 50:
		failures.append("run2: money %d did not persist across runs (expected 50)" % GameState.money)

	GameState.enter_band(&"near")
	# 100 total; pockets_fraction 0.20 → budget 20 → highest_value keeps the 20 item.
	GameState.run_inventory.try_add(_make_item(&"c", 80))
	GameState.run_inventory.try_add(_make_item(&"d", 20))
	var haul2: int = GameState.run_haul_value()
	var expected_budget: int = int(floor(float(haul2) * pockets_fraction))

	GameState.fail_run(&"death")
	if GameState.run_active:
		failures.append("run2: run_active true after fail_run")
	if ended.size() != 2 or ended[1][0] != &"death":
		failures.append("run2: run_ended(death) did not fire")
	# Kept pockets value must be <= budget and > 0 (the 20 item fits a budget of 20).
	var kept_value: int = 0
	for it in GameState.banked_junk:
		kept_value += it.base_sell_value
	if kept_value > expected_budget:
		failures.append("run2: kept pockets %d exceeds budget %d" % [kept_value, expected_budget])
	if kept_value <= 0:
		failures.append("run2: death kept nothing (expected a pockets subset of budget %d)" % expected_budget)

	var money_before_sell2: int = GameState.money
	GameState.sell_banked_junk(&"pockets")
	if GameState.money != money_before_sell2 + kept_value:
		failures.append("run2: sell of pockets credited %d, expected %d"
			% [GameState.money - money_before_sell2, kept_value])

	# ===================== RUN 3: repeat startability after a fail ==========
	GameState.start_run(&"near", 3003)
	if not GameState.run_active:
		failures.append("run3: could not start a third run after a fail")
	if not GameState.run_inventory.items.is_empty():
		failures.append("run3: bag not fresh on third run")
	if started.size() != 3:
		failures.append("run3: run_started count %d, expected 3" % started.size())
	# Leave it cleanly ended so no run-state leaks to other harnesses.
	GameState.extract_and_end_run()
	if ended.size() != 3:
		failures.append("run3: run_ended count %d, expected 3" % ended.size())

	# Tidy meta residue.
	GameState.banked_junk = empty.duplicate()

	# ===================== Verdict ==========================================
	if failures.is_empty():
		print("LOOP OK — 3 runs driven in one session: extract→sell banked 50→Money; "
			+ "fresh run reset run-state + persisted meta; death kept pockets ≤ budget and sold; "
			+ "run startable after both extract and fail; run_started/run_ended fired 3× each.")
		return 0
	for f in failures:
		printerr("LOOP FAIL: ", f)
	return 1
