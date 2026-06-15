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

# --- META-STATE (persists; serialized by SaveManager) ------------------------
var money: int = 0
var salvage: int = 0
var lore: int = 0
var exposure: int = 0          # 0–100 Heat model (TDD §3)
var knowledge_level: int = 0   # gates acts/bands (GDD §12)
var unlocked_recipes: Array[StringName] = []

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
	return {
		"money": money, "salvage": salvage, "lore": lore,
		"exposure": exposure, "knowledge_level": knowledge_level,
		"unlocked_recipes": unlocked_recipes,
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
