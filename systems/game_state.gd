extends Node
## GameState — holds both run-state and meta-state, and enforces the boundary
## between them (TDD §2/§3: "strict separation of run-state vs. meta-state").
##
##   meta-state  → persists across runs (SaveManager writes meta.sav from it).
##   run-state   → disposable; wiped on extract or death/timeout.
##
## The push/cash-out loop lives here: unbanked haul is run-state and is lost
## (minus a "pockets" fraction) on death; banked value flows into meta money.

const POCKETS_FRACTION := 0.15  # GDD §6: fraction of unbanked haul kept on death
const INVENTORY_CONFIG_PATH := "res://data/inventory/inventory_config.tres"  # D1: bag size source
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

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)

# --- Run lifecycle -----------------------------------------------------------
func start_run(band_id: StringName, seed: int) -> void:
	run_active = true
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

func enter_band(band_id: StringName) -> void:
	current_band = band_id
	current_depth += 1
	EventBus.band_entered.emit(band_id, current_depth)

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

func add_exposure(delta: int) -> void:
	var before := exposure
	exposure = clampi(exposure + delta, 0, 100)
	EventBus.exposure_changed.emit(exposure)
	for t in [25, 50, 75, 100]:
		if before < t and exposure >= t:
			EventBus.exposure_threshold_crossed.emit(t)

func _on_player_died(_cause: StringName) -> void:
	# Soft-roguelite: drop unbanked haul minus the pockets fraction.
	var kept := int(round(float(unbanked_value) * POCKETS_FRACTION))
	add_currency(&"money", kept, &"pockets")
	unbanked_value = 0
	if run_inventory != null:        # D1: carried junk is lost on death, never banked
		run_inventory.clear_run()

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
