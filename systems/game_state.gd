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
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"  # E1: rehydrate banked_junk ids on load
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

# --- RUN-STATE (disposable) --------------------------------------------------
var run_active: bool = false
var run_seed: int = 0
var current_band: StringName = &""
var current_depth: int = 0
var unbanked_value: int = 0    # value carried but not yet banked at a gate
var run_inventory: RunInventory      # D1: the carried-junk slot bag; fresh each run, never banked
# E3 #122: single "run is ending" idempotency guard. extract_and_end_run() and
# fail_run() are the two outcomes of one event; the first to resolve sets this and
# any later caller early-returns, so a same-frame extract+timeout tie can't double-
# bank or fire run_ended twice. start_run() resets it. On a literal same-frame tie
# whichever runs first wins — wire extract ahead of timeout so reaching the gate
# is honored (the player-friendly resolution; E3 Open questions).
var _run_ended: bool = false

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
	run_seed = seed
	current_band = band_id
	current_depth = 0
	unbanked_value = 0
	run_inventory = _make_run_inventory()   # D1: fresh, empty bag sized from config
	RNG.seed_from(seed)
	EventBus.run_started.emit(band_id, seed)

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

	var duration_s: float = 0.0
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

func end_run(reason: StringName, duration_s: float) -> void:
	run_active = false
	if run_inventory != null:        # D1: wipe the bag so it never survives into the next run
		run_inventory.clear_run()
	EventBus.run_ended.emit(reason, duration_s, current_depth)

# --- Ledger ------------------------------------------------------------------
func add_currency(kind: StringName, delta: int, source: StringName) -> void:
	match kind:
		&"money": money += delta
		&"salvage": salvage += delta
		&"lore": lore += delta
		_: push_error("Unknown currency: %s" % kind)
	EventBus.currency_changed.emit(kind, delta, source)

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

	return breakdown

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

	var duration_s: float = 0.0
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
	return {
		"money": money, "salvage": salvage, "lore": lore,
		"exposure": exposure, "knowledge_level": knowledge_level,
		"unlocked_recipes": unlocked_recipes,
		"banked_junk": banked_ids,
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
