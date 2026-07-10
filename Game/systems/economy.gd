class_name Economy
extends RefCounted
## Economy — the meta currencies, the junk economy (bank/sell), the buy path, and
## the death-drop "pockets" math, split out of GameState (M1.12 V4). Owned by
## GameState as a plain RefCounted sub-object (NOT an autoload — autoload count
## stays six). Holds ONLY meta-state; run context (the carried inventory, the run
## seed) is passed IN by GameState, so Economy keeps no run-state and no GameState
## back-reference (TDD §2/§3 run/meta boundary, now enforced by the type seam).
##
## Signals still flow through the EventBus autoload (globally reachable) so the
## observable signal set is byte-identical to the pre-split monolith.

const RUN_RULES_PATH := "res://data/economy/run_rules.tres"  # E3: pockets-drop tuning (data-driven)
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"  # E1: rehydrate banked_junk ids on load
# E3 pockets RNG salt: combined with run_seed to seed a LOCAL RandomNumberGenerator
# (via RNG.substream) for the `random` pockets policy (B3 sub-stream pattern). Never
# reseed the global RNG autoload mid-run — that would perturb layout/placement
# determinism. Co-located here with resolve_pockets, its sole consumer (V4: zero
# external readers, so it moves off GameState with the pockets code that uses it).
const POCKETS_RNG_SALT := 0x50434B54  # "PCKT"

# --- META-STATE (persists; serialized by GameState.to_meta_dict) -------------
var money: int = 0
var salvage: int = 0
var lore: int = 0
var exposure: int = 0          # 0–100 Heat model (TDD §3)
# E1 #6: junk identities banked on extract, carried across runs until F2 sells
# them. Holds the actual JunkItem resources in memory (so F2 can itemize the
# payoff); persisted/rehydrated by id through the JunkCatalog (objects-off save).
var banked_junk: Array[JunkItem] = []
# M1.6 (M0): owned shop purchases — a META inventory of catalog ids (a flat
# StringName list, objects-OFF-friendly). Persists across runs; reset on wipe().
var owned_items: Array[StringName] = []
# E3: cached pockets-drop tuning, loaded once. Authored at RUN_RULES_PATH; falls
# back to a code-default RunRules if the .tres is missing so the fail path is safe.
var run_rules: RunRules

func _init() -> void:
	# OQ3 (V4): Economy owns the pockets tuning, so it owns the RUN_RULES_PATH load
	# + the RunRules.new() safe-default. _init runs during GameState field-init (at
	# autoload construction); load() needs no scene tree and the RunRules class_name
	# is registered before any autoload constructs, so this is valid here.
	run_rules = load(RUN_RULES_PATH) as RunRules
	if run_rules == null:
		push_warning("RunRules missing at %s; using code defaults (0.20 / highest_value)." % RUN_RULES_PATH)
		run_rules = RunRules.new()

# --- Ledger ------------------------------------------------------------------
func add_currency(kind: StringName, delta: int, source: StringName) -> void:
	match kind:
		&"money": money += delta
		&"salvage": salvage += delta
		&"lore": lore += delta
		_: push_error("Unknown currency: %s" % kind)
	EventBus.currency_changed.emit(kind, delta, source)

func add_exposure(delta: int) -> void:
	var before := exposure
	exposure = clampi(exposure + delta, 0, 100)
	EventBus.exposure_changed.emit(exposure)
	for t in [25, 50, 75, 100]:
		if before < t and exposure >= t:
			EventBus.exposure_threshold_crossed.emit(t)

# --- M1.6 (M0): buy economy (neutral until M3's Shop calls it) ----------------
## M1.6 (M0): the buy-economy entry point. Debits `price` Money through the canonical
## ledger (add_currency, so Telemetry sees ONE currency_changed(&"money", -price, &"shop")),
## records the owned id, persists meta (atomic + .bak), and signals. Returns true iff the
## purchase went through. Reject paths (negative price, already-owned, can't-afford) emit
## purchase_failed and return false WITHOUT mutating money/owned_items. The run/meta
## boundary holds: purchases are pure meta (no run-state).
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
	add_currency(&"money", -price, &"shop")   # ONE ledger event; mirrors sell()'s credit
	owned_items.append(item_id)
	SaveManager.save_meta(0)                   # atomic write + .bak, slot 0 (every meta op's path) — TODO(multi-slot UI, M1.12 V9): see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.
	EventBus.item_purchased.emit(item_id, price, money)   # money = post-debit balance
	return true

## M1.6 (M0): does the player own this purchase? Pure read (M3's effects gate on it).
func owns(item_id: StringName) -> bool:
	return owned_items.has(item_id)

## F1: convert the whole banked junk pile → Money at each item's base_sell_value.
## Returns {"breakdown": Array[Dictionary], "total": int}. GameState sequences the
## quota eval afterwards (it needs `total` + the post-credit `money`). Steps:
##   1. build a per-item breakdown {id, name, value} so F2 can itemize the payoff,
##      summing the total,
##   2. clear banked_junk (the items are consumed by the sale),
##   3. credit the total through the canonical ledger mutation add_currency (ONE
##      currency_changed event for the lot),
##   4. persist meta synchronously (atomic write + .bak).
## Selling an empty bank is a safe no-op: total 0, add_currency(0) is benign, breakdown [].
func sell(source: StringName = &"sell") -> Dictionary:
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
	SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's SAVE_SLOT const / OQ4; V4's GameState split is a natural seam for GameState.active_slot.

	return {"breakdown": breakdown, "total": total}

## M1.6 fix: the value of the haul brought home but NOT yet sold — sums base_sell_value
## over the live banked_junk pile. On the Hub-return beat the haul is HELD (unsold), so
## `money` alone excludes it; the cumulative_money quota basis must add this so a winning
## run isn't read as a MISS just because the player hasn't visited the Shop yet. On the
## sell path banked_junk is already emptied before eval, so this returns 0.
func held_haul_value() -> int:
	var held_value: int = 0
	for item in banked_junk:
		if item != null:
			held_value += item.base_sell_value
	return held_value

## E3: choose the whole items the player keeps — fill a value budget, keeping items
## intact so F2 can itemize exactly what survived. Budget = floor(pre_value *
## pockets_fraction). Policy orders the candidates; HIGHEST_VALUE saves the best
## find first. Edge case: budget > 0 but the cheapest item exceeds it → empty
## pockets (a legible, fair outcome). Run context passed IN — Economy never reaches
## for run-state. `run_seed` seeds the LOCAL sub-stream for the RANDOM policy.
func resolve_pockets(run_items: Array[JunkItem], run_seed: int) -> Array[JunkItem]:
	var kept: Array[JunkItem] = []
	if run_items.is_empty() or run_rules == null:
		return kept

	var pre_value: int = sum_values(run_items)
	var budget: int = int(floor(float(pre_value) * run_rules.pockets_fraction))
	if budget <= 0:
		return kept

	var ordered: Array[JunkItem] = run_items.duplicate()
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
			var rng := RNG.substream(run_seed, POCKETS_RNG_SALT)
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

## E3: sum base_sell_value over an item subset (kept pockets, or a run bag).
func sum_values(subset: Array[JunkItem]) -> int:
	var total: int = 0
	for item in subset:
		if item != null:
			total += item.base_sell_value
	return total

# --- Serialization value providers (GameState assembles the ordered dict) -----
## E1: persist banked junk by id (String), not Resource refs — the save model is
## objects-OFF (FileAccess.store_var(..., false)).
func banked_junk_ids() -> Array[String]:
	var banked_ids: Array[String] = []
	for item in banked_junk:
		if item != null:
			banked_ids.append(String(item.id))
	return banked_ids

## M1.6 (M3): persist owned shop purchases by id as Strings (objects-OFF).
func owned_item_ids() -> Array[String]:
	var owned_strings: Array[String] = []
	for oid in owned_items:
		owned_strings.append(String(oid))
	return owned_strings

## E1: rehydrate banked_junk from persisted ids via the catalog. Unknown ids
## (e.g. a retired .tres) are skipped with a warning rather than crashing load.
func rehydrate_banked_junk_from_ids(ids: Array) -> void:
	banked_junk = _rehydrate_banked_junk(ids)

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

## K2 (M1.4): reset every economy meta field to its construction default (the
## roguelite wipe fans out here from GameState.wipe_meta). Freshly-TYPED empty
## arrays (an untyped [] would not match the typed field).
func wipe() -> void:
	money = 0
	salvage = 0
	lore = 0
	exposure = 0
	var empty_junk: Array[JunkItem] = []
	banked_junk = empty_junk
	var empty_owned: Array[StringName] = []
	owned_items = empty_owned
