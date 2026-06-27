extends Node
## GameState — holds both run-state and meta-state, and enforces the boundary
## between them (TDD §2/§3: "strict separation of run-state vs. meta-state").
##
##   meta-state  → persists across runs (SaveManager writes meta.sav from it).
##   run-state   → disposable; wiped on extract or death/timeout.
##
## The push/cash-out loop lives here: unbanked haul is run-state and is lost
## (minus a "pockets" fraction) on death; banked value flows into meta money.

const INVENTORY_CONFIG_PATH := "res://data/inventory/inventory_config.tres"  # D1: bag size source
const RUN_RULES_PATH := "res://data/economy/run_rules.tres"  # E3: pockets-drop tuning (data-driven)
# E3 pockets RNG salt: combined with run_seed to seed a LOCAL RandomNumberGenerator
# for the `random` pockets policy (B3 sub-stream pattern). Never reseed the global
# RNG autoload mid-run — that would perturb layout/placement determinism.
const POCKETS_RNG_SALT := 0x50434B54  # "PCKT"
# K7 (M1.4) exits RNG salt: combined with run_seed to seed a LOCAL RandomNumberGenerator
# for the random exit-gate placement (B3/E3 sub-stream pattern, like POCKETS/JUNK). Exit
# placement is pure run-state at materialisation time, downstream of generation, so it
# NEVER feeds fingerprint(); the local sub-stream keeps it reproducible per run without
# ever touching the global RNG autoload. "EXIT" = 0x45584954.
const EXITS_RNG_SALT := 0x45584954  # "EXIT"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"  # E1: rehydrate banked_junk ids on load
# M1.1 R0: the all-off default run config. Used when a run starts without an
# explicit config so an unconfigured run reproduces the M1.0 baseline exactly.
const DEFAULT_RUN_CONFIG_PATH := "res://data/run_config/run_config.tres"
# E1 #8: one gate per band at a fixed hand-authored offset from spawn, kept as a
# single tunable constant (no seeded placement in M1). A band/test scene reads
# this so the extract-vs-push distance is identical every run.
const GATE_SPAWN_OFFSET := Vector2(160.0, 0.0)

# --- META-STATE (persists; serialized by SaveManager) ------------------------
var money: int = 0
var salvage: int = 0
var lore: int = 0
var exposure: int = 0          # 0–100 Heat model (TDD §3)
var knowledge_level: int = 0   # gates acts/bands (GDD §12)
var unlocked_recipes: Array[StringName] = []
# E1 #6: junk identities banked on extract, carried across runs until F2 sells
# them. Holds the actual JunkItem resources in memory (so F2 can itemize the
# payoff); persisted/rehydrated by id through the JunkCatalog (objects-off save).
var banked_junk: Array[JunkItem] = []
# K2 (M1.4): the headline-stakes quota meta. Both are META-STATE — they persist
# across runs, escalate when a quota is met, and reset to these defaults on a
# roguelite wipe. The live quota_target was *set by the previous run's outcome*;
# the per-run "did this run meet it?" evaluation is RUN-STATE (below), not these.
var run_number: int = 1        # 1-based; the run currently being played. Resets to 1 on wipe.
var quota_target: int = 0      # the Money bar THIS run must clear. 0 = "not yet initialised"
                               # (lazy-init at the first quota-enabled start_run from quota_base).
# M1.6 (M0): owned shop purchases — a META inventory of catalog ids (mirrors
# unlocked_recipes exactly: a flat StringName list, objects-OFF-friendly). Persists
# across runs; reset on wipe_meta(). Default empty = "owns nothing" = today's
# behaviour (no shop existed). M3 fills the catalog + the buy effects + the persist
# wiring (the v3->v4 bump); M0 lands the surface at neutral defaults — declaring it
# changes nothing until M3's Shop calls purchase().
var owned_items: Array[StringName] = []

# --- RUN-STATE (disposable) --------------------------------------------------
var run_active: bool = false
var run_seed: int = 0
var current_band: StringName = &""
var current_depth: int = 0
var unbanked_value: int = 0    # value carried but not yet banked at a gate
# BUG1 (M1.1): monotonic ms stamped at start_run; basis for run duration on every
# end path. Run-state (disposable, never persisted). 0 until a run starts.
var _run_start_ms: int = 0
# BUG2 (M1.1): live within-band depth. Run-scoped (disposable, never persisted);
# reset to 0 in start_run, fed into run_ended.depth_reached at end_run. The scene
# driver (MainGame) resolves the player's piece → depth and calls set_current_depth().
var current_depth_index: int = 0    # depth_index of the piece the player is in NOW (entry == 0)
var max_depth_reached: int = 0      # the deepest depth_index reached this run (the gate metric)
var current_dist_to_gate: int = 0   # dist_to_gate of the piece the player is in NOW ("how far home"); == depth on the linear spine, diverges once R4 branches
var run_inventory: RunInventory      # D1: the carried-junk slot bag; fresh each run, never banked
# M1.1 R0: the active run's opposition/cost-axis configuration. Run-scoped (NOT
# meta — never persisted). Populated at start_run (from a config the caller staged
# via stage_run_config(), else the all-off default that reproduces M1.0 exactly).
# Read-only to other systems: they read GameState.active_run_config, never mutate it.
# Reset to null on run end (cleared with the rest of run-state).
var active_run_config: RunConfig
# M1.1 R0: a config staged by MainGame/CFG BEFORE start_run; consumed (and cleared)
# at start_run. Lets the run-start API stay locked (start_run(band_id, seed)) while
# still letting the Config menu feed the run. null → start_run uses the all-off default.
var _staged_run_config: RunConfig
# M1.6 (M0): the DIVE-staged config slot — distinct from _staged_run_config above.
# M4's P-debug overlay writes this (stage_dive_config) when the Director sets a config
# from the Menu/Hub; M2's dive scene reads it on self-start via dive_config_or_default()
# and feeds it to stage_run_config() before start_run(). It is NOT run-state (it must
# survive the Menu→Hub→Dive scene swaps the router does) and NOT persisted (a debug
# director knob, not meta the player owns). null → the dive uses make_default_play_preset()
# (the existing main_game.gd:223 fallback), so the dive is fully playable before M4 lands.
var _dive_config: RunConfig
# E3 #122: single "run is ending" idempotency guard. extract_and_end_run() and
# fail_run() are the two outcomes of one event; the first to resolve sets this and
# any later caller early-returns, so a same-frame extract+timeout tie can't double-
# bank or fire run_ended twice. start_run() resets it. On a literal same-frame tie
# whichever runs first wins — wire extract ahead of timeout so reaching the gate
# is honored (the player-friendly resolution; E3 Open questions).
var _run_ended: bool = false

# K2 (M1.4): per-run quota evaluation state — RUN-STATE (disposable, never
# persisted). Snapshotted at start_run from active_run_config because end_run()
# clears active_run_config BEFORE the SellScreen sells (the eval cannot re-read
# the config later). The cached _quota_result is read by SellScreen via
# last_quota_result(); _quota_evaluated_this_run makes the eval idempotent
# regardless of how many times sell_banked_junk is called in a run (Gap 1).
var _quota_active_this_run: bool = false
var _quota_step_snapshot: int = 0
var _quota_check_timing_snapshot: int = 0   # 0=on_extract, 1=every_run_end (RunConfig enum)
var _quota_basis_snapshot: int = 0          # 0=this_run_banked, 1=cumulative_money
var _quota_end_reason: StringName = &""     # the run's end reason (for on_extract gating)
var _quota_evaluated_this_run: bool = false
var _quota_result: Dictionary = {"checked": false}

# E3: cached pockets-drop tuning, loaded once. Authored at RUN_RULES_PATH; falls
# back to a code-default RunRules if the .tres is missing so the fail path is safe.
var run_rules: RunRules

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	# E3: clock timeout is a FAILED run — route it through the shared fail path.
	EventBus.dive_clock_timeout.connect(_on_dive_clock_timeout)
	run_rules = load(RUN_RULES_PATH) as RunRules
	if run_rules == null:
		push_warning("RunRules missing at %s; using code defaults (0.20 / highest_value)." % RUN_RULES_PATH)
		run_rules = RunRules.new()

# --- Run lifecycle -----------------------------------------------------------
func start_run(band_id: StringName, seed: int) -> void:
	run_active = true
	_run_ended = false   # E3: fresh run → run-end guard clear
	_run_start_ms = Time.get_ticks_msec()   # BUG1: bracket the whole run (wall-clock ms)
	run_seed = seed
	current_band = band_id
	current_depth = 0
	# BUG2: reset live within-band depth (player starts at entry == 0).
	current_depth_index = 0
	max_depth_reached = 0
	current_dist_to_gate = 0
	unbanked_value = 0
	run_inventory = _make_run_inventory()   # D1: fresh, empty bag sized from config
	# M1.1 R0: bind the active run config. Prefer a config staged by MainGame/CFG;
	# otherwise fall back to the all-off default so an unconfigured run (existing
	# tests, the M1.0 flow) reproduces the M1.0 baseline EXACTLY. Consume the staging
	# slot so it can't leak into a later run.
	active_run_config = _staged_run_config if _staged_run_config != null else _default_run_config()
	_staged_run_config = null
	# K2 (M1.4): snapshot the quota config for this run (active_run_config is cleared
	# by end_run() before the SellScreen sells, so the eval cannot re-read it later)
	# and reset the per-run evaluation state. All snapshots default to the all-off
	# values when there is no config, so a quota-off run is fully inert here.
	var qc: RunConfig = active_run_config
	_quota_active_this_run = qc != null and qc.quota_enabled
	_quota_step_snapshot = qc.quota_step if qc != null else 0
	_quota_check_timing_snapshot = qc.quota_check_timing if qc != null else 0
	_quota_basis_snapshot = qc.quota_basis if qc != null else 0
	_quota_end_reason = &""
	_quota_evaluated_this_run = false
	_quota_result = {"checked": false}
	if _quota_active_this_run and quota_target <= 0:
		# Lazy meta-init on the first quota-enabled run of a ladder (fresh profile OR
		# just-wiped): seed the bar from quota_base, run 1. Q4 lock: eager-persist so
		# the seeded bar is durable immediately (a quit-before-any-run-end reloads at
		# the correct bar). Gap 2: this is the ONLY place start_run touches the save,
		# guarded STRICTLY behind active+uninitialised so a quota-OFF run writes NOTHING
		# at start (preserving the all-off control's byte-identical-to-M1.3 guarantee).
		quota_target = qc.quota_base
		run_number = 1
		SaveManager.save_meta(0)
	RNG.seed_from(seed)
	EventBus.run_started.emit(band_id, seed)

## M1.1 R0: the CFG/MainGame seam. Stage the config the NEXT start_run() will adopt.
## Keeps the locked start_run(band_id, seed) signature intact. A null arg (or never
## calling this) means the next run uses the all-off default = M1.0 baseline.
func stage_run_config(config: RunConfig) -> void:
	_staged_run_config = config

## M1.1 R0: load the all-off default config (M1.0 control). Falls back to a fresh
## all-off RunConfig.new() if the .tres is missing, so a run is never left without
## a config — and that fallback is, by definition, all-off too.
func _default_run_config() -> RunConfig:
	var cfg: RunConfig = load(DEFAULT_RUN_CONFIG_PATH) as RunConfig
	if cfg == null:
		push_warning("RunConfig missing at %s; using all-off RunConfig.new()." % DEFAULT_RUN_CONFIG_PATH)
		cfg = RunConfig.new()
	return cfg

# --- M1.6 (M0): dive-staged config seam (M4 writes, M2's dive reads) ----------
## M1.6 (M0): M4's P-debug overlay stages the Director's chosen RunConfig here from
## the Menu/Hub. Survives the router's scene swaps (it is neither run-state nor meta —
## a debug director knob). A null arg clears it back to the play-preset default.
func stage_dive_config(config: RunConfig) -> void:
	_dive_config = config

## M1.6 (M0): the dive self-start seam. M2's dive _ready() reads this to resolve its
## RunConfig: the M4-staged config if the Director set one, else make_default_play_preset()
## (the existing main_game.gd:223 fallback). So the dive is fully playable before M4
## lands the overlay. Never returns null. (M2 then feeds the result into stage_run_config.)
func dive_config_or_default() -> RunConfig:
	if _dive_config != null:
		return _dive_config
	return RunConfig.make_default_play_preset()

## D1: construct a fresh run-state bag, reading max_slots once from the authored
## InventoryConfig. The capacity *value* is config-derived; the live bag stays
## run-state (rebuilt every start_run, never persisted).
func _make_run_inventory() -> RunInventory:
	var inv := RunInventory.new()
	var cfg: InventoryConfig = load(INVENTORY_CONFIG_PATH) as InventoryConfig
	if cfg != null:
		inv.max_slots = cfg.base_max_slots
	else:
		push_warning("InventoryConfig missing at %s; using RunInventory default." % INVENTORY_CONFIG_PATH)
	return inv

# E3: debug-only death trigger. With no enemies in M1, the `debug_kill` action (key
# K) is the stand-in that emits player_died(&"death") so the death cause + pockets
# math are exercisable in demos. Only fires during an active run; ignored otherwise.
# Not a shipped player-facing failure — timeout is. _unhandled_input keeps it from
# stealing keys from focused UI.
func _unhandled_input(event: InputEvent) -> void:
	if run_active and event.is_action_pressed(&"debug_kill"):
		EventBus.player_died.emit(&"death")

func enter_band(band_id: StringName) -> void:
	current_band = band_id
	current_depth += 1
	EventBus.band_entered.emit(band_id, current_depth)

## Shared read helper (orchestrator-seeded contract for wave 4): sum of
## base_sell_value across the current run bag. Pure read, run-state only — no
## mutation, no signals. Consumed by E2's decision HUD ("Holding: N"), E3's
## pockets math, and F2's sell tally so they never recompute this independently.
func run_haul_value() -> int:
	var total: int = 0
	if run_inventory != null:
		for item in run_inventory.items:
			if item != null:
				total += item.base_sell_value
	return total

## Bank the unbanked haul at a gate → commits to meta money.
func bank_haul() -> void:
	add_currency(&"money", unbanked_value, &"extraction")
	EventBus.haul_banked.emit(unbanked_value)
	unbanked_value = 0

## E1: the canonical run-state → meta-state transfer at the extract gate.
## Banks the carried junk *identities* into meta (decision #6 — NOT converted to
## Money here; F2 owns the sell), persists meta, then ends the run through the
## existing lifecycle so A3's clock + Telemetry react to one `run_ended`.
## Allows a zero-haul extract (decision #7): an empty bag still banks nothing,
## emits haul_banked(0), and ends the run with cause &"extract".
##
## NOTE (orchestrator-directed): reuses run_ended + haul_banked rather than a new
## run_end(cause, payload) signal — one lifecycle, no parallel run-end path.
func extract_and_end_run() -> void:
	# E3 #122: idempotency — first run-end wins. If a timeout/death already resolved
	# this run (or extract was called twice), do nothing rather than double-bank.
	if _run_ended:
		return
	_run_ended = true

	var duration_s: float = _elapsed_s()   # BUG1: real elapsed run time (was hardcoded 0.0)
	if run_inventory != null:
		var moved: Array[JunkItem] = run_inventory.items.duplicate()  # snapshot before end_run clears it
		for item in moved:
			if item != null:
				banked_junk.append(item)

	var banked_value: int = 0
	if run_inventory != null:
		for item in run_inventory.items:
			if item != null:
				banked_value += item.base_sell_value

	# Persist the updated meta synchronously (atomic write + .bak). SaveManager's
	# only persist-meta entry point is save_meta(slot); use the default slot 0.
	# A higher layer (save/slot UI, not yet built in M1) will own slot selection.
	SaveManager.save_meta(0)

	EventBus.haul_banked.emit(banked_value)

	# end_run() flips run_active off, clears the bag (run-state wipe), and emits
	# run_ended(&"extract", duration_s, current_depth).
	end_run(&"extract", duration_s)

	# Belt-and-suspenders run-state reset (end_run already cleared the bag).
	unbanked_value = 0
	current_depth = 0

## BUG1 (M1.1): real elapsed seconds since start_run, via the monotonic engine
## clock (Time.get_ticks_msec). Single source so extract/death/timeout agree.
## Wall-clock (pause-inclusive) per BUG1 doc §8 Decision 1; run-end fires before the
## sell screen pauses, so no pause window is inside this interval. Raw float seconds,
## no rounding at the source (RG2 buckets at analysis time).
func _elapsed_s() -> float:
	return float(Time.get_ticks_msec() - _run_start_ms) / 1000.0

## BUG2 (M1.1): the single mutator for live within-band depth. The scene-side driver
## (MainGame) calls this when it resolves the player's piece, passing both metrics
## (Decision 4). Edge-triggered on depth_index: only emits depth_changed when the
## depth actually changes, so same-piece ticks produce no signal traffic. dist_home
## ("how far home") is always refreshed so R2/R4 can read it live even mid-piece.
func set_current_depth(idx: int, dist_home: int) -> void:
	current_dist_to_gate = dist_home   # always refresh "how far home"
	if idx == current_depth_index:
		return                         # no-op on same-depth ticks → no signal spam
	current_depth_index = idx
	max_depth_reached = maxi(max_depth_reached, current_depth_index)
	# depth_changed is pre-declared on EventBus (orchestrator, commit 2450cde); BUG2
	# only EMITS it, never declares it.
	EventBus.depth_changed.emit(current_depth_index, max_depth_reached)

func end_run(reason: StringName, duration_s: float) -> void:
	run_active = false
	# K2 (M1.4): remember the run's end reason BEFORE active_run_config is cleared, so
	# _evaluate_quota (run later from the SellScreen) can honor quota_check_timing's
	# on_extract option (evaluate only on a clean extract). Run-state; reset each start_run.
	_quota_end_reason = reason
	if run_inventory != null:        # D1: wipe the bag so it never survives into the next run
		run_inventory.clear_run()
	# M1.1 R0: the active config is run-state — clear it on run end. The next run
	# re-binds it in start_run (staged config, else the all-off default).
	active_run_config = null
	# BUG2: report the MAX within-band depth, not the stuck band-entry counter.
	# extract/death/timeout all route through here, so this fixes all three at once.
	EventBus.run_ended.emit(reason, duration_s, max_depth_reached)

# --- Ledger ------------------------------------------------------------------
func add_currency(kind: StringName, delta: int, source: StringName) -> void:
	match kind:
		&"money": money += delta
		&"salvage": salvage += delta
		&"lore": lore += delta
		_: push_error("Unknown currency: %s" % kind)
	EventBus.currency_changed.emit(kind, delta, source)

# --- M1.6 (M0): buy economy (neutral until M3's Shop calls it) ----------------
## M1.6 (M0): the buy-economy entry point. Debits `price` Money through the canonical
## ledger (add_currency, so Telemetry sees ONE currency_changed(&"money", -price, &"shop")),
## records the owned id, persists meta (atomic + .bak), and signals. Returns true iff the
## purchase went through. Reject paths (negative price, already-owned, can't-afford) emit
## purchase_failed and return false WITHOUT mutating money/owned_items. The run/meta
## boundary holds: purchases are pure meta (no run-state). Catalog-agnostic primitives —
## ShopItem is M3's type; M3 calls purchase(item.id, item.cost) and does its UI-side
## guards before calling (the owns() guard here is the belt-and-braces double-buy block).
func purchase(item_id: StringName, price: int) -> bool:
	if price < 0:
		EventBus.purchase_failed.emit(item_id, price, money)
		return false
	if owns(item_id):
		EventBus.purchase_failed.emit(item_id, price, money)   # already owned → no double-buy
		return false
	if money < price:
		EventBus.purchase_failed.emit(item_id, price, money)   # can't afford
		return false
	add_currency(&"money", -price, &"shop")   # ONE ledger event; mirrors sell_banked_junk's credit
	owned_items.append(item_id)
	SaveManager.save_meta(0)                   # atomic write + .bak, slot 0 (every meta op's path)
	EventBus.item_purchased.emit(item_id, price, money)   # money = post-debit balance
	return true

## M1.6 (M0): does the player own this purchase? Pure read (M3's effects gate on it).
func owns(item_id: StringName) -> bool:
	return owned_items.has(item_id)

## F1: convert the whole banked junk pile → Money at each item's base_sell_value.
## This is the loop-closing cash-out: E1/E3 bank item IDENTITIES into meta
## (decision: Option B, "bank items not Money"); Money only increments here, when
## F2's sell screen calls this. Steps:
##   1. build a per-item breakdown {id, name, value} so F2 can itemize the payoff,
##      summing the total,
##   2. clear banked_junk (the items are consumed by the sale),
##   3. credit the total through the canonical ledger mutation add_currency(&"money",
##      total, source) — ONE currency_changed event for the lot (Telemetry's
##      currency-in hook; F2 animates per-item purely from the returned breakdown),
##   4. persist meta synchronously (atomic write + .bak) so the new Money total and
##      the emptied bank survive,
##   5. return the breakdown.
## `source` tags the credit so a failed-run sale (E3 pockets) can be analyzed as
## &"pockets" vs a clean extract &"sell"/&"extract" (Telemetry currency-in-by-source).
## Selling an empty bank is a safe no-op: total 0, add_currency(0) is benign, returns [].
func sell_banked_junk(source: StringName = &"sell") -> Array[Dictionary]:
	var breakdown: Array[Dictionary] = []
	var total: int = 0
	for item in banked_junk:
		if item == null:
			continue
		breakdown.append({
			"id": item.id,
			"name": item.display_name,
			"value": item.base_sell_value,
		})
		total += item.base_sell_value

	# Consume the pile: the items are gone once sold.
	var empty: Array[JunkItem] = []
	banked_junk = empty

	# One ledger event for the lot (emits currency_changed(&"money", total, source)).
	add_currency(&"money", total, source)

	# Persist the new Money total + emptied bank (slot 0; same path as E1/E3).
	SaveManager.save_meta(0)

	# K2 (M1.4): evaluate the quota AFTER the credit + save — `money` is only final
	# for the run here (Q2 lock). `total` is the sum just sold this call (the
	# this_run_banked basis reads it; the cumulative_money basis reads `money`).
	_evaluate_quota(total)

	return breakdown


## K2 (M1.4): evaluate this run against the quota. Run-state only — it mutates the
## quota META (run_number/quota_target) ONLY on a met quota, and never wipes here
## (a miss is wiped by MainGame on Continue, after the player sees the tally). Inert
## unless the run was configured with the quota on (_quota_active_this_run snapshot).
## Idempotent via _quota_evaluated_this_run (Gap 1): a second call in the same run
## returns the cached result, so it can never double-advance the quota regardless of
## how many times sell_banked_junk is invoked. `sold_total` is the value sold THIS
## call (the this_run_banked basis); cumulative_money reads the post-credit `money`.
func _evaluate_quota(sold_total: int) -> Dictionary:
	if _quota_evaluated_this_run:
		return _quota_result
	if not _quota_active_this_run:
		_quota_result = {"checked": false}
		return _quota_result
	# Honor quota_check_timing: on_extract (0) only evaluates on a clean extract;
	# every_run_end (1) evaluates on extract/death/timeout alike.
	if _quota_check_timing_snapshot == 0 and _quota_end_reason != &"extract":
		_quota_result = {"checked": false}
		return _quota_result
	_quota_evaluated_this_run = true
	# Compute `achieved` by the basis: cumulative_money (1) reads the running balance
	# PLUS the still-held (unsold) haul — on the M1.6 Hub-return beat the dive's haul is
	# banked-but-unsold, so `money` alone would read a winning run as a MISS; _held_haul_value()
	# is 0 on the sell path (pile already emptied) so that path stays `money` exactly.
	# this_run_banked (0) reads only what was banked this run (sold_total == held haul value).
	var achieved: int = (money + _held_haul_value()) if _quota_basis_snapshot == 1 else sold_total
	var met: bool = achieved >= quota_target
	EventBus.quota_evaluated.emit(run_number, quota_target, achieved, met)
	if met:
		# Escalate: bump the run number AND raise the next quota, then persist.
		run_number += 1
		quota_target += _quota_step_snapshot
		SaveManager.save_meta(0)
		EventBus.quota_advanced.emit(run_number, quota_target)
		_quota_result = {"checked": true, "met": true, "achieved": achieved, "target": quota_target}
	else:
		# MISS → the wipe is a SEPARATE meta op MainGame triggers on Continue: we want
		# the player to SEE the tally + the QUOTA MISSED beat first, then wipe → fresh.
		# `target` reported here is the bar that was MISSED (not yet escalated).
		_quota_result = {"checked": true, "met": false, "achieved": achieved, "target": quota_target}
	return _quota_result


## K2 (M1.4): the cached result of this run's quota evaluation, for the SellScreen
## (pure consumer — no quota math in the UI). Run-state: cleared at next start_run.
## Returns {"checked": false} until/unless _evaluate_quota ran this run.
func last_quota_result() -> Dictionary:
	return _quota_result


## M1.6 (M0): evaluate the quota on the GUARANTEED Hub-return beat, DECOUPLED from
## sell_banked_junk (where K2 used to live, game_state.gd:~350). M2's Hub-return
## controller calls this when a dive resolves so the quota-eval + MISS readout fire
## independent of whether the player ever visits the Shop to sell — closing the
## "re-dive without selling skips the wipe" roguelite hole. The MISS-wipe itself stays
## a separate meta op M2 triggers (wipe_meta) AFTER the player sees the QUOTA MISSED
## beat, exactly as MainGame did on Continue today — this only EVALUATES, never wipes.
##
## Basis: for this_run_banked (0) the basis is the HELD banked_junk value (what the
## dive brought home), NOT "what was sold this call" — sums base_sell_value over the
## live banked_junk pile (the same math as run_haul_value/_sum_values). For
## cumulative_money (1) it reads the live `money`, identical to sell-time. The existing
## _quota_evaluated_this_run idempotency guard then makes M3's later sell_banked_junk()
## a safe NO-OP re-eval (it returns the cached result), so the quota can never
## double-advance regardless of how the Hub-return + a Shop sale interleave.
## Returns the cached/computed result dict (mirrors last_quota_result's shape).
func evaluate_quota_on_return() -> Dictionary:
	return _evaluate_quota(_held_haul_value())


## M1.6 fix: the value of the haul brought home but NOT yet sold — sums base_sell_value
## over the live banked_junk pile (the same math as run_haul_value/_sum_values). On the
## Hub-return beat the haul is HELD (unsold), so `money` alone excludes it; the
## cumulative_money quota basis must add this so a winning run isn't read as a MISS just
## because the player hasn't visited the Shop yet. On the sell path banked_junk is already
## emptied before _evaluate_quota, so this returns 0 and the basis stays `money` exactly.
func _held_haul_value() -> int:
	var held_value: int = 0
	for item in banked_junk:
		if item != null:
			held_value += item.base_sell_value
	return held_value


## K2 (M1.4): the full roguelite wipe (Director FINAL). Resets EVERY meta field to
## its construction default, re-persists through SaveManager's atomic write + .bak so
## a quit-after-wipe stays wiped, and signals observers. A SEPARATE meta op called by
## MainGame on the GameOver→Continue path AFTER the player saw the QUOTA MISSED beat,
## BEFORE the next start_run (which re-seeds the quota from quota_base). It touches
## ONLY meta — never run_active/run_seed/run_inventory/active_run_config/_run_ended
## (it runs between runs, after end_run cleared run-state, so there is no run-state to
## corrupt). Freshly-TYPED empty arrays (an untyped [] would not match the typed field).
func wipe_meta() -> void:
	var prev_run_number := run_number
	money = 0
	salvage = 0
	lore = 0
	exposure = 0
	knowledge_level = 0
	var empty_recipes: Array[StringName] = []
	unlocked_recipes = empty_recipes
	var empty_junk: Array[JunkItem] = []
	banked_junk = empty_junk
	# M1.6 (M0): owned shop purchases are META → a roguelite wipe clears them too.
	# Freshly-TYPED empty array (an untyped [] would not match the typed field). This
	# runs whether or not owned_items persists to disk (RD-4) — the in-memory reset is
	# unconditional; only the to_meta_dict/from_meta_dict persistence is M3's (the v3->v4 bump).
	var empty_owned: Array[StringName] = []
	owned_items = empty_owned
	# K2 meta: back to run 1 / "uninitialised" so the next quota-enabled start_run
	# re-seeds the bar from quota_base (run 1, quota $50).
	run_number = 1
	quota_target = 0
	# Persist the wiped state through the SAME atomic path (slot 0) as every meta op.
	SaveManager.save_meta(0)
	# Fire AFTER the persist so observers (HUD/Telemetry/GameOver) read settled state.
	EventBus.meta_wiped.emit(prev_run_number)
	# Nudge any money-projection HUD to repaint to 0.
	EventBus.currency_changed.emit(&"money", 0, &"wipe")

func add_exposure(delta: int) -> void:
	var before := exposure
	exposure = clampi(exposure + delta, 0, 100)
	EventBus.exposure_changed.emit(exposure)
	for t in [25, 50, 75, 100]:
		if before < t and exposure >= t:
			EventBus.exposure_threshold_crossed.emit(t)

# E3: death stand-in for M1 (no enemies yet). The debug_kill input action emits
# player_died(&"death"); both that and the clock timeout below converge on the one
# shared fail path so there is a SINGLE drop code path (no parallel pockets math).
func _on_player_died(_cause: StringName) -> void:
	fail_run(&"death")

# E3: clock timeout (A3) is a failed run — the shipped player-facing failure in M1.
func _on_dive_clock_timeout() -> void:
	fail_run(&"timeout")

## E3: the FAILURE counterpart to extract_and_end_run(). On death/timeout the run
## ends unsuccessfully: the player keeps only a "pockets" subset of the carried
## haul (whole items up to floor(pre_value * pockets_fraction)) and loses the rest.
## Mirrors extract's run-state → meta-state transfer, just on a subset:
##   1. resolve kept items, 2. append them to banked_junk, 3. persist meta,
##   4. emit haul_banked(kept_value) for parity with extract,
##   5. end_run(cause, ...) so the single run_ended(cause, ...) fires (the rest of
##      the bag is discarded by end_run's clear_run() — never banked).
## Idempotent via the shared _run_ended guard (#122): a same-frame extract wins.
func fail_run(cause: StringName) -> void:
	if _run_ended:
		return
	_run_ended = true

	var duration_s: float = _elapsed_s()   # BUG1: real elapsed run time (was hardcoded 0.0)
	var pre_value: int = run_haul_value()
	var kept: Array[JunkItem] = _resolve_pockets()
	var kept_value: int = _sum_values(kept)
	var lost_value: int = pre_value - kept_value

	# Same run-state → meta-state transfer as extract, but only the kept subset.
	# Everything else is dropped when end_run() wipes the bag below.
	for item in kept:
		if item != null:
			banked_junk.append(item)

	# Persist the kept pockets synchronously via the SAME atomic write + .bak path
	# as extract (slot 0). Kept pockets are a real, persistent meta gain.
	SaveManager.save_meta(0)

	# Parity with extract: report the kept amount through haul_banked. run_ended is
	# fixed-arity (reason, duration_s, depth) so value_lost can't ride on it — it's
	# surfaced here for observers and printed below for the telemetry seam (G1).
	EventBus.haul_banked.emit(kept_value)
	print("E3 fail_run cause=%s pre_value=%d kept_value=%d lost_value=%d items_kept=%d depth=%d"
		% [cause, pre_value, kept_value, lost_value, kept.size(), current_depth])

	# end_run() flips run_active off, clears the bag (discarding the lost remainder),
	# and emits run_ended(cause, duration_s, current_depth) — the one run-end signal.
	end_run(cause, duration_s)

	unbanked_value = 0

## E3: choose the whole items the player keeps — fill a value budget, keeping items
## intact so F2 can itemize exactly what survived. Budget = floor(pre_value *
## pockets_fraction). Policy orders the candidates; HIGHEST_VALUE saves the best
## find first. Edge case: budget > 0 but the cheapest item exceeds it → empty
## pockets (a legible, fair outcome). Pure read on run_inventory (no mutation).
func _resolve_pockets() -> Array[JunkItem]:
	var kept: Array[JunkItem] = []
	if run_inventory == null or run_inventory.items.is_empty() or run_rules == null:
		return kept

	var pre_value: int = run_haul_value()
	var budget: int = int(floor(float(pre_value) * run_rules.pockets_fraction))
	if budget <= 0:
		return kept

	var ordered: Array[JunkItem] = run_inventory.items.duplicate()
	match run_rules.pockets_policy:
		RunRules.PocketsPolicy.HIGHEST_VALUE:
			ordered.sort_custom(func(a: JunkItem, b: JunkItem) -> bool:
				return a.base_sell_value > b.base_sell_value)
		RunRules.PocketsPolicy.LOWEST_VALUE:
			ordered.sort_custom(func(a: JunkItem, b: JunkItem) -> bool:
				return a.base_sell_value < b.base_sell_value)
		RunRules.PocketsPolicy.RANDOM:
			# Deterministic shuffle via a LOCAL RNG (B3 sub-stream pattern): seed from
			# run_seed ^ salt so the order is reproducible per run and never touches
			# the global RNG autoload. RNG has no shuffle(), so Fisher–Yates here.
			var rng := RandomNumberGenerator.new()
			rng.seed = run_seed ^ POCKETS_RNG_SALT
			for i in range(ordered.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var tmp: JunkItem = ordered[i]
				ordered[i] = ordered[j]
				ordered[j] = tmp

	var spent: int = 0
	for item in ordered:
		if item == null:
			continue
		if spent + item.base_sell_value <= budget:
			kept.append(item)
			spent += item.base_sell_value
	return kept

## E3: sum base_sell_value over an item subset (kept pockets). Mirrors
## run_haul_value()'s math but on an arbitrary array rather than the live bag.
func _sum_values(subset: Array[JunkItem]) -> int:
	var total: int = 0
	for item in subset:
		if item != null:
			total += item.base_sell_value
	return total

# --- Save bridge (SaveManager reads/writes these) ----------------------------
func to_meta_dict() -> Dictionary:
	# E1: persist banked junk by id (String), not Resource refs — the save model
	# is objects-OFF (FileAccess.store_var(..., false)). from_meta_dict rehydrates
	# the JunkItem resources by looking each id up in the JunkCatalog.
	var banked_ids: Array[String] = []
	for item in banked_junk:
		if item != null:
			banked_ids.append(String(item.id))
	# M1.6 (M3): persist owned shop purchases by id as Strings (objects-OFF, like
	# banked_junk's id list). from_meta_dict rehydrates to a typed Array[StringName].
	var owned_strings: Array[String] = []
	for oid in owned_items:
		owned_strings.append(String(oid))
	return {
		"money": money, "salvage": salvage, "lore": lore,
		"exposure": exposure, "knowledge_level": knowledge_level,
		"unlocked_recipes": unlocked_recipes,
		"banked_junk": banked_ids,
		# K2 (M1.4): quota meta — persists/escalates/resets-on-wipe.
		"run_number": run_number,
		"quota_target": quota_target,
		# M1.6 (M3): owned shop purchases — added at META v3->v4. Old saves predate the
		# shop; the v3->v4 migration defaults this to [] so from_meta_dict reads "owns nothing".
		"owned_items": owned_strings,
	}

func from_meta_dict(d: Dictionary) -> void:
	money = d.get("money", 0)
	salvage = d.get("salvage", 0)
	lore = d.get("lore", 0)
	exposure = d.get("exposure", 0)
	knowledge_level = d.get("knowledge_level", 0)
	var recipes: Array[StringName] = []
	for r in d.get("unlocked_recipes", []):
		recipes.append(StringName(r))
	unlocked_recipes = recipes
	# E1: rehydrate banked_junk from persisted ids via the catalog. Unknown ids
	# (e.g. a retired .tres) are skipped with a warning rather than crashing load.
	banked_junk = _rehydrate_banked_junk(d.get("banked_junk", []))
	# K2 (M1.4): quota meta. Pre-K2 saves migrate to run_number=1/quota_target=0
	# (the v2->v3 migration adds them); the defaults here match for a raw read.
	run_number = d.get("run_number", 1)
	quota_target = d.get("quota_target", 0)
	# M1.6 (M3): owned shop purchases. Pre-shop (v3) saves migrate to [] (the v3->v4
	# step adds the key); rehydrate to a typed Array[StringName].
	var owned: Array[StringName] = []
	for o in d.get("owned_items", []):
		owned.append(StringName(o))
	owned_items = owned

## E1: map persisted junk ids back to their JunkItem resources via the catalog.
func _rehydrate_banked_junk(ids: Array) -> Array[JunkItem]:
	var result: Array[JunkItem] = []
	if ids.is_empty():
		return result
	var by_id: Dictionary = _build_catalog_index()
	for raw in ids:
		var key := StringName(raw)
		var item: JunkItem = by_id.get(key, null)
		if item != null:
			result.append(item)
		else:
			push_warning("banked_junk: no catalog entry for id %s; dropping." % key)
	return result

## E1: build a { id: JunkItem } lookup from the authored JunkCatalog.
func _build_catalog_index() -> Dictionary:
	var by_id: Dictionary = {}
	var cat: JunkCatalog = load(JUNK_CATALOG_PATH) as JunkCatalog
	if cat == null:
		push_warning("JunkCatalog missing at %s; banked_junk cannot rehydrate." % JUNK_CATALOG_PATH)
		return by_id
	for item in cat.items:
		if item != null:
			by_id[item.id] = item
	return by_id
