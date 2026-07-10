class_name QuotaLadder
extends RefCounted
## QuotaLadder — the K2 headline-stakes quota, split out of GameState (M1.12 V4).
## Owns the meta ladder (run_number / quota_target) + the per-run evaluation state.
## Owned by GameState as a plain RefCounted sub-object (NOT an autoload — count
## stays six). Holds NO live run-state: the run's money / sold-total / held-haul are
## passed IN by GameState at eval time, preserving the run/meta boundary.
##
## OQ1 (V4): the four scalar snapshots the monolith carried on GameState
## (_quota_active_this_run / _quota_step_snapshot / _quota_check_timing_snapshot /
## _quota_basis_snapshot) COLLAPSE to one held RunConfig reference. end_run() nulls
## GameState.active_run_config BEFORE eval, but RunConfig is RefCounted, so a held
## _qc reference keeps the config alive to read at eval time. The config is a
## documented read-only invariant (never field-mutated after start_run), so reading
## _qc.quota_* at eval yields exactly what start_run would have snapshotted.

# --- META-STATE (persists; serialized by GameState.to_meta_dict) -------------
var run_number: int = 1        # 1-based; the run currently being played. Resets to 1 on wipe.
var quota_target: int = 0      # the Money bar THIS run must clear. 0 = "not yet initialised".

# --- per-run eval state (was 7 fields on GameState; RUN-STATE, never persisted) --
var _qc: RunConfig                          # the run's held quota config (collapses the 4 snapshots)
var _end_reason: StringName = &""           # the run's end reason (for on_extract gating)
var _evaluated_this_run: bool = false
var _result: Dictionary = {"checked": false}

## K2 (M1.4): called by GameState.start_run. Captures the run's quota config and
## resets the per-run eval state. On the first quota-enabled run of a ladder (fresh
## profile OR just-wiped) it lazy-seeds the bar from quota_base and returns true so
## GameState (which owns the save call) persists the seeded bar. Returns false
## otherwise — a quota-OFF run writes NOTHING (preserving the all-off control's
## byte-identical-to-baseline guarantee).
func begin_run(qc: RunConfig) -> bool:
	_qc = qc
	_end_reason = &""
	_evaluated_this_run = false
	_result = {"checked": false}
	var active := qc != null and qc.quota_enabled
	if active and quota_target <= 0:
		quota_target = qc.quota_base
		run_number = 1
		return true   # GameState calls SaveManager.save_meta(0)
	return false

## K2 (M1.4): remember the run's end reason BEFORE active_run_config is cleared, so
## evaluate() can honor quota_check_timing's on_extract option. Called from end_run().
func set_end_reason(reason: StringName) -> void:
	_end_reason = reason

## K2 (M1.4): evaluate this run against the quota. Mutates the quota META
## (run_number / quota_target) ONLY on a met quota, and never wipes here (a miss is
## wiped by MainGame on Continue). Idempotent via _evaluated_this_run (Gap 1): a
## second call in the same run returns the cached result, so it can never
## double-advance. `money_now`/`sold_total`/`held_haul` are Economy values passed in:
##   - achieved = (money_now + held_haul) for cumulative_money (basis 1),
##   - achieved = sold_total for this_run_banked (basis 0).
func evaluate(money_now: int, sold_total: int, held_haul: int) -> Dictionary:
	if _evaluated_this_run:
		return _result
	var active := _qc != null and _qc.quota_enabled
	if not active:
		_result = {"checked": false}
		return _result
	# Honor quota_check_timing: on_extract (0) only evaluates on a clean extract;
	# every_run_end (1) evaluates on extract/death/timeout alike.
	if _qc.quota_check_timing == 0 and _end_reason != &"extract":
		_result = {"checked": false}
		return _result
	_evaluated_this_run = true
	var achieved: int = (money_now + held_haul) if _qc.quota_basis == 1 else sold_total
	var met: bool = achieved >= quota_target
	EventBus.quota_evaluated.emit(run_number, quota_target, achieved, met)
	if met:
		# Escalate: bump the run number AND raise the next quota, then persist.
		run_number += 1
		quota_target += _qc.quota_step
		SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.
		EventBus.quota_advanced.emit(run_number, quota_target)
		_result = {"checked": true, "met": true, "achieved": achieved, "target": quota_target}
	else:
		# MISS → the wipe is a SEPARATE meta op MainGame triggers on Continue.
		# `target` reported here is the bar that was MISSED (not yet escalated).
		_result = {"checked": true, "met": false, "achieved": achieved, "target": quota_target}
	return _result

## K2 (M1.4): the cached result of this run's quota evaluation, for the SellScreen.
## Returns {"checked": false} until/unless evaluate() ran this run.
func last_result() -> Dictionary:
	return _result

## K2 (M1.4): reset the quota meta to construction defaults (the roguelite wipe
## fans out here from GameState.wipe_meta) so the next quota-enabled start_run
## re-seeds the bar from quota_base (run 1).
func wipe() -> void:
	run_number = 1
	quota_target = 0
