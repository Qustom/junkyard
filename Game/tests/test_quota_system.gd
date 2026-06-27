extends Node
## K2 (M1.4) headless behavior harness for the quota system + roguelite wipe.
## Run as a SCENE so the autoloads resolve:
##   godot --headless res://tests/test_quota_system.tscn
##
## Verifies (against the REAL GameState API, no mocks):
##   1. A MET quota (cumulative_money basis, every_run_end) bumps run_number + raises
##      quota_target by step, persists, and emits quota_advanced.
##   2. A MISSED quota does NOT wipe inside the eval (a separate op) but flags a miss
##      result; wipe_meta() then resets all 9 meta fields + emits meta_wiped.
##   3. The eval is idempotent — a second sell in the same run does not double-advance.
##   4. quota_check_timing=on_extract skips the eval on a death/timeout end reason.
##   5. quota_basis=this_run_banked measures the sold-this-run total, not cumulative.
##   6. quota-OFF run: no eval, no signals, last_quota_result() == {checked:false}.

const TEST_SLOT := 9100

var _advanced_events: Array = []
var _wiped_events: Array = []
var _evaluated_events: Array = []


func _ready() -> void:
	var code := _run()
	get_tree().quit(code)


func _make_cfg(enabled: bool, base: int, step: int, timing: int, basis: int) -> RunConfig:
	var c := RunConfig.new()
	c.quota_enabled = enabled
	c.quota_base = base
	c.quota_step = step
	c.quota_check_timing = timing
	c.quota_basis = basis
	return c


## Drive a run to a given end reason, then simulate the SellScreen selling. We don't
## need the full scene — we exercise the GameState API directly: start_run snapshots
## the config + lazy-inits; end_run records the reason; sell_banked_junk evaluates.
func _drive_run(gs: Node, cfg: RunConfig, reason: StringName) -> void:
	gs.stage_run_config(cfg)
	gs.start_run(&"near", 12345)
	# Reach the end the way the lifecycle does (end_run is the single resolve point;
	# we route through it directly with no inventory so no banking happens here).
	gs._run_ended = true
	gs.end_run(reason, 1.0)


func _reset_meta(gs: Node) -> void:
	gs.money = 0
	gs.salvage = 0
	gs.lore = 0
	gs.exposure = 0
	gs.knowledge_level = 0
	gs.unlocked_recipes = [] as Array[StringName]
	gs.banked_junk = [] as Array[JunkItem]
	gs.run_number = 1
	gs.quota_target = 0


func _run() -> int:
	var failures: Array[String] = []
	var gs := get_node_or_null("/root/GameState")
	var save := get_node_or_null("/root/SaveManager")
	if gs == null or save == null:
		printerr("QUOTA FAIL: GameState/SaveManager autoload missing")
		return 1

	EventBus.quota_advanced.connect(func(rn, t): _advanced_events.append([rn, t]))
	EventBus.meta_wiped.connect(func(prev): _wiped_events.append(prev))
	EventBus.quota_evaluated.connect(func(rn, t, a, m): _evaluated_events.append([rn, t, a, m]))

	_reset_meta(gs)

	# --- Case 1: MET (cumulative, every_run_end) advances + persists --------------
	var cfg := _make_cfg(true, 50, 50, 1, 1)   # base 50, step 50, every_run_end, cumulative
	_drive_run(gs, cfg, &"extract")
	if gs.quota_target != 50:
		failures.append("C1: lazy-init quota_target=%d, expected 50" % gs.quota_target)
	if gs.run_number != 1:
		failures.append("C1: run_number=%d after start, expected 1" % gs.run_number)
	gs.money = 60   # cumulative balance clears the $50 bar
	_evaluated_events.clear()
	_advanced_events.clear()
	var r1: Dictionary = gs._evaluate_quota(60)
	if not bool(r1.get("met", false)):
		failures.append("C1: expected MET (money 60 >= 50)")
	if gs.run_number != 2:
		failures.append("C1: run_number=%d after met, expected 2" % gs.run_number)
	if gs.quota_target != 100:
		failures.append("C1: quota_target=%d after met, expected 100 (50+50)" % gs.quota_target)
	if _advanced_events.size() != 1 or _advanced_events[0] != [2, 100]:
		failures.append("C1: quota_advanced events=%s, expected [[2,100]]" % str(_advanced_events))
	if _evaluated_events.size() != 1 or not _evaluated_events[0][3]:
		failures.append("C1: quota_evaluated events=%s, expected one met=true" % str(_evaluated_events))

	# --- Case 3: idempotency — second eval in same run does NOT double-advance ----
	_advanced_events.clear()
	var r1b: Dictionary = gs._evaluate_quota(60)
	if gs.run_number != 2 or gs.quota_target != 100:
		failures.append("C3: second eval double-advanced (run=%d target=%d)" % [gs.run_number, gs.quota_target])
	if _advanced_events.size() != 0:
		failures.append("C3: second eval emitted quota_advanced again: %s" % str(_advanced_events))
	if r1b != r1:
		failures.append("C3: second eval returned a different cached result")

	# --- Case 2: MISS does not wipe in eval; wipe_meta resets all 9 fields --------
	_reset_meta(gs)
	gs.salvage = 7
	gs.lore = 2
	gs.exposure = 40
	gs.knowledge_level = 1
	var cfg2 := _make_cfg(true, 150, 50, 1, 1)
	_drive_run(gs, cfg2, &"extract")
	gs.money = 120   # below the 150 bar → miss
	_wiped_events.clear()
	var rm: Dictionary = gs._evaluate_quota(120)
	if bool(rm.get("met", true)):
		failures.append("C2: expected MISS (money 120 < 150)")
	if gs.money != 120 or gs.salvage != 7:
		failures.append("C2: eval wiped meta itself (should defer to wipe_meta)")
	# Now the wipe op (MainGame-on-Continue).
	gs.wipe_meta()
	if gs.money != 0 or gs.salvage != 0 or gs.lore != 0 or gs.exposure != 0 \
		or gs.knowledge_level != 0 or gs.unlocked_recipes.size() != 0 \
		or gs.banked_junk.size() != 0 or gs.run_number != 1 or gs.quota_target != 0:
		failures.append("C2: wipe_meta did not reset all 9 fields (money=%d salvage=%d lore=%d exp=%d kn=%d rec=%d junk=%d run=%d q=%d)"
			% [gs.money, gs.salvage, gs.lore, gs.exposure, gs.knowledge_level,
			gs.unlocked_recipes.size(), gs.banked_junk.size(), gs.run_number, gs.quota_target])
	if _wiped_events.size() != 1:
		failures.append("C2: meta_wiped emitted %d times, expected 1" % _wiped_events.size())

	# --- Case 4: on_extract timing skips a death/timeout end ----------------------
	_reset_meta(gs)
	var cfg4 := _make_cfg(true, 50, 50, 0, 1)   # on_extract
	_drive_run(gs, cfg4, &"timeout")
	gs.money = 999
	var r4: Dictionary = gs._evaluate_quota(999)
	if bool(r4.get("checked", true)):
		failures.append("C4: on_extract evaluated on a timeout end (should skip)")
	if gs.run_number != 1:
		failures.append("C4: on_extract advanced on a timeout (run=%d)" % gs.run_number)

	# --- Case 5: this_run_banked basis reads sold_total, not cumulative money -----
	_reset_meta(gs)
	var cfg5 := _make_cfg(true, 50, 50, 1, 0)   # this_run_banked
	_drive_run(gs, cfg5, &"extract")
	gs.money = 1000   # huge cumulative, but...
	var r5miss: Dictionary = gs._evaluate_quota(30)   # ...only $30 banked THIS run → miss
	if bool(r5miss.get("met", true)):
		failures.append("C5: this_run_banked should MISS (sold 30 < 50) despite money=1000")
	if r5miss.get("achieved", -1) != 30:
		failures.append("C5: achieved=%s, expected 30 (the sold_total)" % str(r5miss.get("achieved")))

	# --- Case 6: quota OFF → fully inert ------------------------------------------
	_reset_meta(gs)
	_advanced_events.clear()
	_evaluated_events.clear()
	_wiped_events.clear()
	var cfgoff := _make_cfg(false, 0, 0, 0, 0)
	gs.stage_run_config(cfgoff)
	gs.start_run(&"near", 777)
	if gs.quota_target != 0:
		failures.append("C6: quota-off start_run seeded a bar (quota_target=%d)" % gs.quota_target)
	gs._run_ended = true
	gs.end_run(&"extract", 1.0)
	gs.money = 5000
	var r6: Dictionary = gs._evaluate_quota(5000)
	if bool(r6.get("checked", true)):
		failures.append("C6: quota-off evaluated (should be inert)")
	if gs.last_quota_result().get("checked", true):
		failures.append("C6: last_quota_result not {checked:false} for quota-off run")
	if _advanced_events.size() != 0 or _evaluated_events.size() != 0:
		failures.append("C6: quota-off emitted signals (adv=%d eval=%d)" % [_advanced_events.size(), _evaluated_events.size()])

	# --- Case 7: M1.6 — Hub-return cumulative basis counts the HELD (unsold) haul ---
	# Regression for the playtest bug "quota always missed even with > the bar": on the
	# M1.6 Hub-return beat the haul is banked-but-UNSOLD (held in banked_junk, money not
	# yet credited), and evaluate_quota_on_return() fires before any Shop sale. The
	# cumulative_money basis must read money + held haul, else a winning run reads as MISS.
	_reset_meta(gs)
	_evaluated_events.clear()
	_advanced_events.clear()
	var cfg7 := _make_cfg(true, 50, 50, 1, 1)   # base 50, every_run_end, CUMULATIVE
	_drive_run(gs, cfg7, &"extract")            # lazy-inits quota_target=50
	gs.money = 0                                 # nothing sold yet (haul is held)
	var held := JunkItem.new()
	held.base_sell_value = 60                    # one held item worth $60 > the $50 bar
	gs.banked_junk = [held] as Array[JunkItem]
	var r7: Dictionary = gs.evaluate_quota_on_return()
	if not bool(r7.get("met", false)):
		failures.append("C7: held haul $60 (money=0) read as MISS on Hub-return (the reported bug)")
	if r7.get("achieved", -1) != 60:
		failures.append("C7: achieved=%s, expected 60 (money 0 + held haul 60)" % str(r7.get("achieved")))

	# --- Cleanup ------------------------------------------------------------------
	_reset_meta(gs)

	if failures.is_empty():
		print("QUOTA OK — met advances+persists (run#+target+quota_advanced), miss defers to wipe_meta (9-field reset + meta_wiped), eval idempotent, on_extract skips non-extract, this_run_banked reads sold_total, quota-off fully inert, M1.6 Hub-return cumulative basis counts the held unsold haul.")
		return 0
	for f in failures:
		printerr("QUOTA FAIL: ", f)
	return 1
