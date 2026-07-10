extends Node
## GameState — the run lifecycle core + the meta facade. Enforces the boundary
## between run-state and meta-state (TDD §2/§3: "strict separation of run-state vs.
## meta-state").
##
##   meta-state  → persists across runs (SaveManager writes meta.sav from it).
##   run-state   → disposable; wiped on extract or death/timeout.
##
## M1.12 V4: the meta economy and the K2 quota were split into two owned RefCounted
## sub-objects (NOT autoloads — the autoload count stays six):
##   _economy (systems/economy.gd)      → currencies, buy/sell, banked junk, pockets.
##   _quota   (systems/quota_ladder.gd) → the run_number/quota_target ladder + eval.
## GameState remains a FACADE over them: every moved field is forwarded with a
## getter+setter property (so the ~38 callers read/assign/mutate-in-place unchanged),
## and every moved method is a one-line delegate. Live run-state (run_inventory,
## run_seed, run_active…) stays on this core and is PASSED INTO the sub-objects at
## call time, never stored by them — so the run/meta boundary is enforced by the type
## seam, not just convention. The three straddling flows (start_run / sell / fail /
## wipe) are the explicit coordinator methods below.
##
## The push/cash-out loop lives here: unbanked haul is run-state and is lost
## (minus a "pockets" fraction) on death; banked value flows into meta money.

const INVENTORY_CONFIG_PATH := "res://data/inventory/inventory_config.tres"  # D1: bag size source
# K7 (M1.4) exits RNG salt: combined with run_seed to seed a LOCAL RandomNumberGenerator
# for the random exit-gate placement (B3/E3 sub-stream pattern). Exit placement is pure
# run-state at materialisation time, downstream of generation, so it NEVER feeds
# fingerprint(); the local sub-stream keeps it reproducible per run without ever touching
# the global RNG autoload. "EXIT" = 0x45584954. Kept on GameState (read cross-file as
# GameState.EXITS_RNG_SALT by main_game.gd + the exit tests). (The pockets salt moved to
# Economy with resolve_pockets — it had zero external readers.)
const EXITS_RNG_SALT := 0x45584954  # "EXIT"
# M1.1 R0: the all-off default run config. Used when a run starts without an
# explicit config so an unconfigured run reproduces the M1.0 baseline exactly.
const DEFAULT_RUN_CONFIG_PATH := "res://data/run_config/run_config.tres"
# E1 #8: one gate per band at a fixed hand-authored offset from spawn, kept as a
# single tunable constant (no seeded placement in M1). A band/test scene reads
# this so the extract-vs-push distance is identical every run. Read cross-file as
# GameState.GATE_SPAWN_OFFSET, so it stays on the facade.
const GATE_SPAWN_OFFSET := Vector2(160.0, 0.0)

# --- OWNED SUB-OBJECTS (M1.12 V4) --------------------------------------------
# Plain RefCounted data holders, constructed at field-init (autoload construction).
# NOT autoloads (DR-4 — count stays six). Economy._init loads RunRules.
var _economy := Economy.new()
var _quota := QuotaLadder.new()

# --- META-STATE forwarded to _economy (getter+setter keeps read/assign/mutate) ---
var money: int:
	get:
		return _economy.money
	set(value):
		_economy.money = value
var salvage: int:
	get:
		return _economy.salvage
	set(value):
		_economy.salvage = value
var lore: int:
	get:
		return _economy.lore
	set(value):
		_economy.lore = value
var exposure: int:          # 0–100 Heat model (TDD §3)
	get:
		return _economy.exposure
	set(value):
		_economy.exposure = value
# E1 #6: junk identities banked on extract, carried across runs until F2 sells them.
# Read AND written (and mutated-in-place via .append) by callers/tests — the getter
# returns the backing Array by reference so .append() mutates it (Array is a ref type).
var banked_junk: Array[JunkItem]:
	get:
		return _economy.banked_junk
	set(value):
		_economy.banked_junk = value
# M1.6 (M0): owned shop purchases — a META inventory of catalog ids.
var owned_items: Array[StringName]:
	get:
		return _economy.owned_items
	set(value):
		_economy.owned_items = value
# E3: cached pockets-drop tuning (a test overrides this directly to exercise policies).
var run_rules: RunRules:
	get:
		return _economy.run_rules
	set(value):
		_economy.run_rules = value

# --- META-STATE forwarded to _quota ------------------------------------------
# K2 (M1.4): the headline-stakes quota meta. Both persist across runs, escalate when
# a quota is met, and reset on a roguelite wipe.
var run_number: int:           # 1-based; the run currently being played. Resets to 1 on wipe.
	get:
		return _quota.run_number
	set(value):
		_quota.run_number = value
var quota_target: int:         # the Money bar THIS run must clear. 0 = "not yet initialised".
	get:
		return _quota.quota_target
	set(value):
		_quota.quota_target = value

# --- META-STATE that stays on core (no economy/quota home) -------------------
var knowledge_level: int = 0   # gates acts/bands (GDD §12)
var unlocked_recipes: Array[StringName] = []

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
# reset to 0 in start_run, fed into run_ended.depth_reached at end_run.
var current_depth_index: int = 0    # depth_index of the piece the player is in NOW (entry == 0)
var max_depth_reached: int = 0      # the deepest depth_index reached this run (the gate metric)
var current_dist_to_gate: int = 0   # dist_to_gate of the piece the player is in NOW ("how far home")
var run_inventory: RunInventory      # D1: the carried-junk slot bag; fresh each run, never banked
# M1.1 R0: the active run's opposition/cost-axis configuration. Run-scoped (NOT
# meta — never persisted). Populated at start_run. Read-only to other systems: they
# read GameState.active_run_config, never mutate it. Reset to null on run end.
var active_run_config: RunConfig
# M1.1 R0: a config staged by MainGame/CFG BEFORE start_run; consumed (and cleared)
# at start_run. Lets the run-start API stay locked while still letting CFG feed the run.
var _staged_run_config: RunConfig
# M1.6 (M0): the DIVE-staged config slot — distinct from _staged_run_config above.
# M4's P-debug overlay writes this; M2's dive scene reads it. Neither run-state nor meta.
var _dive_config: RunConfig
# M1.9 (S0/S8): the staged dive ROUTING key. GameState self-subscribes to
# EventBus.dive_requested and stages the emitted band_id here so the choice survives
# the router's hub→dive scene swap. Run-staging, NOT meta; consumed-on-read.
var _pending_dive_band: StringName = &""
# E3 #122: single "run is ending" idempotency guard. extract_and_end_run() and
# fail_run() are the two outcomes of one event; the first to resolve sets this and
# any later caller early-returns. start_run() resets it.
var _run_ended: bool = false

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	# E3: clock timeout is a FAILED run — route it through the shared fail path.
	EventBus.dive_clock_timeout.connect(_on_dive_clock_timeout)
	# M1.9 (S0/S8): stage the dive routing key on every dive request.
	EventBus.dive_requested.connect(_on_dive_requested)
	# (V4: the RunRules load moved into Economy._init — Economy owns pockets tuning.)

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
	# otherwise fall back to the all-off default so an unconfigured run reproduces the
	# M1.0 baseline EXACTLY. Consume the staging slot so it can't leak into a later run.
	active_run_config = _staged_run_config if _staged_run_config != null else _default_run_config()
	_staged_run_config = null
	# K2 (M1.4): begin the quota run — QuotaLadder captures the config (OQ1: one held
	# ref, not four scalar snapshots), resets its per-run eval state, and lazy-seeds the
	# bar from quota_base on the first quota-enabled run of a ladder. It returns true
	# only in that lazy-init case, so GameState persists the seeded bar; a quota-OFF run
	# writes NOTHING here (preserving the all-off control's byte-identical guarantee).
	if _quota.begin_run(active_run_config):
		SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.
	RNG.seed_from(seed)
	EventBus.run_started.emit(band_id, seed)

## M1.1 R0: the CFG/MainGame seam. Stage the config the NEXT start_run() will adopt.
func stage_run_config(config: RunConfig) -> void:
	_staged_run_config = config

## M1.1 R0: load the all-off default config (M1.0 control). Falls back to a fresh
## all-off RunConfig.new() if the .tres is missing.
func _default_run_config() -> RunConfig:
	var cfg: RunConfig = load(DEFAULT_RUN_CONFIG_PATH) as RunConfig
	if cfg == null:
		push_warning("RunConfig missing at %s; using all-off RunConfig.new()." % DEFAULT_RUN_CONFIG_PATH)
		cfg = RunConfig.new()
	return cfg

# --- M1.6 (M0): dive-staged config seam (M4 writes, M2's dive reads) ----------
## M1.6 (M0): M4's P-debug overlay stages the Director's chosen RunConfig here.
func stage_dive_config(config: RunConfig) -> void:
	_dive_config = config

## M1.6 (M0): the dive self-start seam. M2's dive _ready() reads this to resolve its
## RunConfig: the M4-staged config if set, else make_default_play_preset(). Never null.
func dive_config_or_default() -> RunConfig:
	if _dive_config != null:
		return _dive_config
	return RunConfig.make_default_play_preset()

# --- M1.9 (S0/S8): dive band routing staging seam ------------------------------
## Handler for EventBus.dive_requested — stage the routing key for the upcoming dive.
func _on_dive_requested(band_id: StringName) -> void:
	_pending_dive_band = band_id

## M1.9 (S0 pre-declare; S3 consumes): return the staged dive routing key and CLEAR
## it (consume-on-read) so a later run can never inherit a stale choice.
func consume_pending_dive_band() -> StringName:
	var key := _pending_dive_band
	_pending_dive_band = &""
	return key

## D1: construct a fresh run-state bag, reading max_slots once from the authored
## InventoryConfig. The live bag stays run-state (rebuilt every start_run).
func _make_run_inventory() -> RunInventory:
	var inv := RunInventory.new()
	var cfg: InventoryConfig = load(INVENTORY_CONFIG_PATH) as InventoryConfig
	if cfg != null:
		inv.max_slots = cfg.base_max_slots
	else:
		push_warning("InventoryConfig missing at %s; using RunInventory default." % INVENTORY_CONFIG_PATH)
	return inv

# E3: debug-only death trigger. With no enemies in M1, the `debug_kill` action (key
# K) is the stand-in that emits player_died(&"death"). Only fires during an active run.
func _unhandled_input(event: InputEvent) -> void:
	if run_active and event.is_action_pressed(&"debug_kill"):
		EventBus.player_died.emit(&"death")

func enter_band(band_id: StringName) -> void:
	current_band = band_id
	current_depth += 1
	EventBus.band_entered.emit(band_id, current_depth)

## Shared read helper: sum of base_sell_value across the current run bag. Pure read,
## run-state only — no mutation, no signals.
func run_haul_value() -> int:
	var total: int = 0
	if run_inventory != null:
		for item in run_inventory.items:
			if item != null:
				total += item.base_sell_value
	return total

## Bank the unbanked haul at a gate → commits to meta money. (Uncalled today; kept
## on core as a thin coordinator since it primarily manipulates run-state.)
func bank_haul() -> void:
	add_currency(&"money", unbanked_value, &"extraction")
	EventBus.haul_banked.emit(unbanked_value)
	unbanked_value = 0

## E1: the canonical run-state → meta-state transfer at the extract gate.
## Banks the carried junk *identities* into meta (decision #6 — NOT converted to
## Money here; F2 owns the sell), persists meta, then ends the run through the
## existing lifecycle so A3's clock + Telemetry react to one `run_ended`.
## Allows a zero-haul extract (decision #7).
func extract_and_end_run() -> void:
	# E3 #122: idempotency — first run-end wins.
	if _run_ended:
		return
	_run_ended = true

	var duration_s: float = _elapsed_s()   # BUG1: real elapsed run time
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

	# Persist the updated meta synchronously (atomic write + .bak).
	SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.

	EventBus.haul_banked.emit(banked_value)

	# end_run() flips run_active off, clears the bag, and emits run_ended(&"extract"…).
	end_run(&"extract", duration_s)

	# Belt-and-suspenders run-state reset (end_run already cleared the bag).
	unbanked_value = 0
	current_depth = 0

## BUG1 (M1.1): real elapsed seconds since start_run, via the monotonic engine clock.
func _elapsed_s() -> float:
	return float(Time.get_ticks_msec() - _run_start_ms) / 1000.0

## BUG2 (M1.1): the single mutator for live within-band depth. Edge-triggered on
## depth_index: only emits depth_changed when the depth actually changes.
func set_current_depth(idx: int, dist_home: int) -> void:
	current_dist_to_gate = dist_home   # always refresh "how far home"
	if idx == current_depth_index:
		return                         # no-op on same-depth ticks → no signal spam
	current_depth_index = idx
	max_depth_reached = maxi(max_depth_reached, current_depth_index)
	EventBus.depth_changed.emit(current_depth_index, max_depth_reached)

func end_run(reason: StringName, duration_s: float) -> void:
	run_active = false
	# K2 (M1.4): remember the run's end reason BEFORE active_run_config is cleared, so
	# the quota eval (run later from the SellScreen) can honor on_extract timing.
	_quota.set_end_reason(reason)
	if run_inventory != null:        # D1: wipe the bag so it never survives into the next run
		run_inventory.clear_run()
	# M1.1 R0: the active config is run-state — clear it on run end.
	active_run_config = null
	# BUG2: report the MAX within-band depth, not the stuck band-entry counter.
	EventBus.run_ended.emit(reason, duration_s, max_depth_reached)

# --- Ledger (forwarded to _economy) ------------------------------------------
func add_currency(kind: StringName, delta: int, source: StringName) -> void:
	_economy.add_currency(kind, delta, source)

func add_exposure(delta: int) -> void:
	_economy.add_exposure(delta)

# --- M1.6 (M0): buy economy (forwarded to _economy) ---------------------------
func purchase(item_id: StringName, price: int) -> bool:
	return _economy.purchase(item_id, price)

## M1.6 (M0): does the player own this purchase? Pure read (M3's effects gate on it).
func owns(item_id: StringName) -> bool:
	return _economy.owns(item_id)

## M1.12 V4b: public read accessor for the value of the haul banked but not yet
## sold (the live banked_junk pile). Forwards Economy.held_haul_value() — used by
## evaluate_quota_on_return() internally, and by white-box test callers driving
## quota_ladder().evaluate(...) directly with the same basis GameState itself uses.
func held_haul_value() -> int:
	return _economy.held_haul_value()

## F1: convert the whole banked junk pile → Money (Economy.sell), then evaluate the
## quota AFTER the credit + save — `money` is only final for the run here (Q2 lock),
## and held_haul is 0 because Economy.sell already emptied the pile. Returns F2's
## per-item breakdown.
func sell_banked_junk(source: StringName = &"sell") -> Array[Dictionary]:
	var sold: Dictionary = _economy.sell(source)
	# K2 (M1.4): evaluate after the credit + save. `total` is the sum just sold (the
	# this_run_banked basis); cumulative_money reads the post-credit `money`.
	_quota.evaluate(_economy.money, sold["total"], _economy.held_haul_value())
	var breakdown: Array[Dictionary] = sold["breakdown"]
	return breakdown

## M1.6 (M0): evaluate the quota on the GUARANTEED Hub-return beat, DECOUPLED from
## sell_banked_junk. For this_run_banked (0) the basis is the HELD banked_junk value
## (what the dive brought home); for cumulative_money (1) it reads money + held. The
## idempotency guard makes a later sell_banked_junk() a safe NO-OP re-eval.
func evaluate_quota_on_return() -> Dictionary:
	var held: int = _economy.held_haul_value()
	return _quota.evaluate(_economy.money, held, held)

## K2 (M1.4): the cached result of this run's quota evaluation, for the SellScreen.
func last_quota_result() -> Dictionary:
	return _quota.last_result()

## M1.12 V4b: public read accessor for the owned QuotaLadder sub-object. Lets
## white-box callers (test_quota_system) drive QuotaLadder.evaluate(...) directly
## against the real owned instance — the same object start_run()/end_run() already
## coordinate (begin_run/set_end_reason) — instead of through a private GameState
## delegate. GameState itself keeps using the coordinator methods above
## (sell_banked_junk / evaluate_quota_on_return) for real callers; this accessor
## exists for tests that need the lower-level evaluate() call directly.
func quota_ladder() -> QuotaLadder:
	return _quota

## K2 (M1.4): the full roguelite wipe (Director FINAL). Fans out to the sub-objects
## (_economy.wipe / _quota.wipe) and resets core's own progression counters, then
## re-persists through SaveManager's atomic write + .bak and signals observers. A
## SEPARATE meta op called by MainGame on the GameOver→Continue path. Touches ONLY
## meta (it runs between runs, after end_run cleared run-state).
func wipe_meta() -> void:
	var prev_run_number := run_number
	_economy.wipe()
	_quota.wipe()
	knowledge_level = 0
	var empty_recipes: Array[StringName] = []
	unlocked_recipes = empty_recipes
	# Persist the wiped state through the SAME atomic path (slot 0) as every meta op.
	SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.
	# Fire AFTER the persist so observers (HUD/Telemetry/GameOver) read settled state.
	EventBus.meta_wiped.emit(prev_run_number)
	# Nudge any money-projection HUD to repaint to 0.
	EventBus.currency_changed.emit(&"money", 0, &"wipe")

# E3: death stand-in for M1 (no enemies yet). Both this and the clock timeout below
# converge on the one shared fail path so there is a SINGLE drop code path.
func _on_player_died(_cause: StringName) -> void:
	fail_run(&"death")

# E3: clock timeout (A3) is a failed run — the shipped player-facing failure in M1.
func _on_dive_clock_timeout() -> void:
	fail_run(&"timeout")

## E3: the FAILURE counterpart to extract_and_end_run(). On death/timeout the run
## ends unsuccessfully: the player keeps only a "pockets" subset of the carried
## haul (Economy.resolve_pockets) and loses the rest. Mirrors extract's run-state →
## meta-state transfer, just on a subset. Idempotent via the shared _run_ended guard.
func fail_run(cause: StringName) -> void:
	if _run_ended:
		return
	_run_ended = true

	var duration_s: float = _elapsed_s()   # BUG1: real elapsed run time
	var pre_value: int = run_haul_value()
	# Pockets math lives in Economy; run context (the carried bag + the run seed) is
	# passed IN so Economy never reaches for run-state. Carries V6's RNG.substream seam.
	var run_items: Array[JunkItem] = run_inventory.items if run_inventory != null else ([] as Array[JunkItem])
	var kept: Array[JunkItem] = _economy.resolve_pockets(run_items, run_seed)
	var kept_value: int = _economy.sum_values(kept)
	var lost_value: int = pre_value - kept_value

	# Same run-state → meta-state transfer as extract, but only the kept subset.
	for item in kept:
		if item != null:
			banked_junk.append(item)

	# Persist the kept pockets synchronously via the SAME atomic write + .bak path.
	SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.

	# Parity with extract: report the kept amount through haul_banked. run_ended is
	# fixed-arity (reason, duration_s, depth) so value_lost is surfaced here + printed
	# below for the telemetry seam (G1).
	EventBus.haul_banked.emit(kept_value)
	print("E3 fail_run cause=%s pre_value=%d kept_value=%d lost_value=%d items_kept=%d depth=%d"
		% [cause, pre_value, kept_value, lost_value, kept.size(), current_depth])

	# end_run() flips run_active off, clears the bag (discarding the lost remainder),
	# and emits run_ended(cause, duration_s, depth) — the one run-end signal.
	end_run(cause, duration_s)

	unbanked_value = 0

# --- Save bridge (SaveManager reads/writes these) ----------------------------
## Assembles the meta dict as an ordered LITERAL in the EXACT current key order,
## sourcing each value from its new owner (NOT Dictionary.merge). store_var serializes
## a Dictionary in insertion order, so this keeps the meta blob byte-identical at v4.
func to_meta_dict() -> Dictionary:
	return {
		"money": _economy.money, "salvage": _economy.salvage, "lore": _economy.lore,
		"exposure": _economy.exposure, "knowledge_level": knowledge_level,
		"unlocked_recipes": unlocked_recipes,
		"banked_junk": _economy.banked_junk_ids(),
		# K2 (M1.4): quota meta — persists/escalates/resets-on-wipe.
		"run_number": _quota.run_number,
		"quota_target": _quota.quota_target,
		# M1.6 (M3): owned shop purchases — added at META v3->v4.
		"owned_items": _economy.owned_item_ids(),
	}

func from_meta_dict(d: Dictionary) -> void:
	_economy.money = d.get("money", 0)
	_economy.salvage = d.get("salvage", 0)
	_economy.lore = d.get("lore", 0)
	_economy.exposure = d.get("exposure", 0)
	knowledge_level = d.get("knowledge_level", 0)
	var recipes: Array[StringName] = []
	for r in d.get("unlocked_recipes", []):
		recipes.append(StringName(r))
	unlocked_recipes = recipes
	# E1: rehydrate banked_junk from persisted ids via the catalog (Economy owns it now).
	_economy.rehydrate_banked_junk_from_ids(d.get("banked_junk", []))
	# K2 (M1.4): quota meta. Pre-K2 saves migrate to run_number=1/quota_target=0.
	_quota.run_number = d.get("run_number", 1)
	_quota.quota_target = d.get("quota_target", 0)
	# M1.6 (M3): owned shop purchases. Pre-shop (v3) saves migrate to [].
	var owned: Array[StringName] = []
	for o in d.get("owned_items", []):
		owned.append(StringName(o))
	_economy.owned_items = owned
