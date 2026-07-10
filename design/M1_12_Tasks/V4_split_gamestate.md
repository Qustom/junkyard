# V4 / R5 — Split GameState into owned sub-objects (Phase-2 design)

> **Milestone:** M1.12 · Wave 3 (solo) · effort-L architectural refactor · **Assignee:** general-purpose
> **BlockedBy:** V6 (Wave 2 migrates `game_state.gd` pockets/exits salts onto `RNG.substream` — V4 must
> see the already-migrated seams, not the hand-rolled ones).
> **Master contract:** behavior-preserving. GameState's public API is unchanged; the ~38 dependent files
> compile + pass with **zero edits** (or the exact minimal edits are itemised); all four control layout
> fingerprints byte-identical; meta save bytes byte-identical for a fixed state; meta stays schema **v4**;
> v1/v2/v3→v4 migration fixtures pass unchanged. Autoload count stays **six** — sub-objects are plain
> `RefCounted` objects **owned by** GameState, not new singletons (DR-4).

---

## (a) Research on the premise

### A.1 Why this task

`Game/systems/game_state.gd` is a **752-line god-object** (`extends Node`, no `class_name` — it is only ever
reached as the `GameState` autoload). It owns four unrelated responsibilities that have accreted across
M1.0→M1.6:

1. **Run lifecycle** — `start_run` / `enter_band` / `extract_and_end_run` / `fail_run` / `end_run` /
   `set_current_depth`, plus the dive-staging seams (`stage_run_config`, `stage_dive_config`,
   `dive_config_or_default`, `_on_dive_requested`, `consume_pending_dive_band`, `_make_run_inventory`).
2. **Economy** — currencies (`add_currency`, `add_exposure`), the buy path (`purchase` / `owns`), the
   sell/cash-out (`sell_banked_junk`, `bank_haul`, `run_haul_value`), and the death-drop **pockets** math
   (`_resolve_pockets` / `_sum_values` / `_held_haul_value`, `run_rules`).
3. **The K2 quota ladder** — `_evaluate_quota` / `last_quota_result` / `evaluate_quota_on_return`, plus
   **seven** run-state quota fields and two meta fields, including the **four snapshot fields** that exist
   only to survive `end_run`'s clearing order.
4. **Serialization** — `to_meta_dict` / `from_meta_dict` and the banked-junk rehydration helpers
   (`_rehydrate_banked_junk` / `_build_catalog_index`) that SaveManager round-trips.

~38 files reference `GameState` (verified 2026-07-09); heaviest callers `main_game.gd` (27),
`decision_hud.gd` (16), `shop_ui.gd` (14). Splitting the file along these seams shrinks the monolith,
gives M2 (crafting / upgrades / instability) clean seams to bolt onto, and — critically — is achievable
**without touching a single caller** because GDScript's property getter/setter syntax lets GameState remain
a facade over the sub-objects.

### A.2 The facade problem (the load-bearing fact the whole split turns on)

The 38 callers do **not** just call methods — they read and write GameState **properties directly**. A
`grep -hoE "GameState\.[a-zA-Z_]+"` over the tree (deduped, with counts) shows the surface the facade must
preserve exactly:

| member | refs | kind | new owner |
|---|---|---|---|
| `run_inventory` | 70 | run-state field | **core** (stays a real field) |
| `active_run_config` | 39 | run-state field | **core** |
| `banked_junk` | 36 | meta field (read **and** written by tests) | **Economy** → forwarded |
| `start_run` | 33 | method | core |
| `current_depth_index` | 27 | run-state field | core |
| `money` | 23 | meta field (read **and** written by tests) | **Economy** → forwarded |
| `fail_run` | 23 | method | core (orchestrates Economy) |
| `stage_dive_config` / `dive_config_or_default` | 22 / 20 | method | core |
| `extract_and_end_run` | 20 | method | core (orchestrates Economy) |
| `run_active` / `run_seed` | 19 / 6 | run-state field | core |
| `GATE_SPAWN_OFFSET` / `EXITS_RNG_SALT` | 12 / 1 | **const** | core (stay as consts) |
| `set_current_depth` / `max_depth_reached` / `current_dist_to_gate` | 9 / 4 / 5 | run-state | core |
| `run_haul_value` | 9 | run-state read | core |
| `consume_pending_dive_band` | 8 | method | core |
| `wipe_meta` | 7 | method | core (fans out to sub-objects) |
| `sell_banked_junk` | 6 | method | core (orchestrates Economy+Quota) |
| `_run_ended` | 6 | run-state field (tests read it) | core |
| `purchase` / `owns` / `owned_items` | 5 / 2 / 2 | method/field | **Economy** → forwarded |
| `run_number` / `quota_target` | 4 / 3 | meta field | **QuotaLadder** → forwarded |
| `run_rules` | 3 | field | **Economy** → forwarded |
| `enter_band` | 4 | method | core |
| `from_meta_dict` / `to_meta_dict` | 3 / 1 | method | core (serialization dispatch) |
| `last_quota_result` / `evaluate_quota_on_return` | 2 / 2 | method | **QuotaLadder** → forwarded |
| `add_exposure` / `exposure` | 1 / 1 | method/field | **Economy** → forwarded |

**The mechanism** for the members that move (Economy + QuotaLadder) is Godot 4's property
getter/setter: a facade property forwards to the sub-object with reference semantics preserved.

```gdscript
var money: int:
	get: return _economy.money
	set(value): _economy.money = value
```

This matters because tests write these fields directly — `test_loop_drive.gd:51` `GameState.money = 0`,
`test_banking_math.gd:54` `GameState.money = _money_before`, and five tests do
`GameState.banked_junk = empty.duplicate()`. A getter alone would break those; **getter + setter** keeps
both read and write working. And `test_save_migration.gd:130` does `gs.banked_junk.append(null)` — the
getter returns the sub-object's Array **by reference**, so `.append()` mutates the real backing array
(Array/Dictionary are reference types in GDScript). All three access shapes (read / assign / mutate-in-place)
survive with getter+setter forwarding. **No caller edits required.**

The consts (`GATE_SPAWN_OFFSET`, `EXITS_RNG_SALT`, `POCKETS_RNG_SALT`, path consts) **cannot** be forwarded
(no getter on a const) — but they need not move. They stay declared on GameState. V6 owns the salt seams
(below); V4 leaves them exactly where V6 left them.

### A.3 Member inventory, bucketed by seam (with line ranges)

**Constants (stay on GameState core):** `INVENTORY_CONFIG_PATH`(11), `RUN_RULES_PATH`(12),
`POCKETS_RNG_SALT`(16), `EXITS_RNG_SALT`(22), `JUNK_CATALOG_PATH`(23), `DEFAULT_RUN_CONFIG_PATH`(26),
`GATE_SPAWN_OFFSET`(30). *(V6 may relocate the two RNG salts — see A.6; V4 does not.)*

**→ Economy (meta + junk economy + pockets)**
- fields: `money`(33), `salvage`(34), `lore`(35), `exposure`(36), `banked_junk`(42), `owned_items`(56),
  `run_rules`(125)
- methods: `add_currency`(358), `add_exposure`(562), `purchase`(375), `owns`(392),
  `sell_banked_junk`(411)*, `bank_haul`(270)*, `_resolve_pockets`(628), `_sum_values`(669),
  `_held_haul_value`(518)
  - *`sell_banked_junk` and `bank_haul` are **coordination points** — they touch Economy but also call
    `_evaluate_quota` (Quota) and `add_currency`. See A.4 on where the seam is drawn.*

**→ QuotaLadder (K2)**
- meta fields: `run_number`(47), `quota_target`(48)
- run-state fields: `_quota_active_this_run`(115), `_quota_step_snapshot`(116),
  `_quota_check_timing_snapshot`(117), `_quota_basis_snapshot`(118), `_quota_end_reason`(119),
  `_quota_evaluated_this_run`(120), `_quota_result`(121)
- methods: `_evaluate_quota`(450), `last_quota_result`(488), `evaluate_quota_on_return`(508)

**→ Lifecycle core (the slim GameState remainder)**
- run-state fields: `run_active`(59), `run_seed`(60), `current_band`(61), `current_depth`(62),
  `unbanked_value`(63), `_run_start_ms`(66), `current_depth_index`(70), `max_depth_reached`(71),
  `current_dist_to_gate`(72), `run_inventory`(73), `active_run_config`(79), `_staged_run_config`(83),
  `_dive_config`(91), `_pending_dive_band`(100), `_run_ended`(107)
- meta fields with no economy/quota home: `knowledge_level`(37), `unlocked_recipes`(38) — plain
  progression counters, touched only by serialization + `wipe_meta`; keep on core (0 external refs each)
- methods: `_ready`(127), `start_run`(141), `stage_run_config`(188), `_default_run_config`(194),
  `stage_dive_config`(205), `dive_config_or_default`(212), `_on_dive_requested`(219),
  `consume_pending_dive_band`(226), `_make_run_inventory`(234), `_unhandled_input`(248), `enter_band`(252),
  `run_haul_value`(261), `extract_and_end_run`(284), `_elapsed_s`(324), `set_current_depth`(332),
  `end_run`(342), `_on_player_died`(573), `_on_dive_clock_timeout`(577), `fail_run`(589), `wipe_meta`(534)
- **serialization dispatch:** `to_meta_dict`(677), `from_meta_dict`(703), `_rehydrate_banked_junk`(728),
  `_build_catalog_index`(743) — stay on core as the dispatcher; delegate field values to/from sub-objects
  (A.5). *(The two rehydration helpers may move into Economy with `banked_junk`; see Open Q4.)*

### A.4 Cross-object coupling — why GameState stays the coordinator

The seams are not cleanly separable because three flows straddle them. Rather than give sub-objects
back-references to each other (which would re-introduce coupling — the opposite of the debt goal), the
**facade orchestrates**: GameState's public methods sequence the sub-objects and pass run-state across as
parameters. Sub-objects stay dumb state+local-logic holders with **no cross-refs and no GameState
back-ref**, which is the real coupling win.

1. **`start_run`** (core) sets run-state, resolves `active_run_config`, then hands the config to
   `_quota.begin_run(qc)` and — for the lazy-init save — leaves the `SaveManager.save_meta(0)` on core.
2. **`sell_banked_junk`** (facade) → `_economy.sell(source)` returns the breakdown + `total`, credits via
   `_economy.add_currency` (already inside sell), persists, then core calls
   `_quota.evaluate(money, sold_total, end_reason)`. Quota needs `money` and `sold_total` — **passed in**,
   not reached-for.
3. **`fail_run`** (core) computes `pre_value = run_haul_value()` (run-state read on core), calls
   `_economy.resolve_pockets(run_inventory.items, run_seed)` → kept items, appends to `_economy.banked_junk`,
   persists, `end_run`. Pockets logic lives in Economy but receives run-state as arguments.
4. **`wipe_meta`** (core) fans out: `_economy.wipe()`, `_quota.wipe()`, and resets core's own
   `knowledge_level`/`unlocked_recipes`, then one `SaveManager.save_meta(0)` + the two EventBus signals.

This keeps the run/meta boundary crisp: Economy/Quota own only meta + their own eval run-state; **live
run-state (run_inventory, run_seed, run_active…) stays on core** and is *passed into* the meta objects, never
stored by them. That is exactly the TDD §2/§3 boundary the file's own header cites.

### A.5 Serialization round-trip — the byte-identity constraint

`SaveManager.save_meta` (save_manager.gd:22-25) calls `GameState.to_meta_dict()`, stamps
`schema_version = 4`, and `store_var(data, false)`. `load_meta` (27-33) reads, runs `_migrate_meta`
(v0→v1→v2→v3→v4, save_manager.gd:75-108), and calls `GameState.from_meta_dict(data)`.

**Godot `store_var` serializes a Dictionary in insertion order**, so byte-identity requires the composed
dict to keep the **exact current key order**: `money, salvage, lore, exposure, knowledge_level,
unlocked_recipes, banked_junk, run_number, quota_target, owned_items` (game_state.gd:690-701). The safe
implementation is: **GameState.to_meta_dict assembles the final literal dict in that fixed order**, sourcing
each value from the right sub-object — NOT `Dictionary.merge` of sub-dicts (merge appends keys in the other
dict's order and would reorder the blob). Concretely:

```gdscript
func to_meta_dict() -> Dictionary:
	return {
		"money": _economy.money, "salvage": _economy.salvage, "lore": _economy.lore,
		"exposure": _economy.exposure, "knowledge_level": knowledge_level,
		"unlocked_recipes": unlocked_recipes,
		"banked_junk": _economy.banked_junk_ids(),   # same String-id list builder as today
		"run_number": _quota.run_number, "quota_target": _quota.quota_target,
		"owned_items": _economy.owned_item_ids(),
	}
```

Same keys, same order, same value types → **byte-identical blob for a fixed state**. `from_meta_dict`
mirrors: reads each key with the same defaults and pushes into the sub-objects
(`_economy.money = d.get("money", 0)`, `_quota.run_number = d.get("run_number", 1)`, etc.), and
`banked_junk` still rehydrates via the catalog. No schema change → meta stays **v4**; the v1/v2/v3→v4
migration fixtures (`test_save_migration.gd`) are untouched because the migration lives entirely in
SaveManager, which V4 does not modify. The round-trip test (`to_meta_dict` → store → load → `from_meta_dict`
→ `to_meta_dict` equals the original bytes) is the definition-of-done proof.

### A.6 The V6 seam (do not undo)

V6 (Wave 2) promotes the two hand-rolled salted sub-streams into `RNG.substream(salt)`. In `game_state.gd`
these live at `_resolve_pockets` (line 651, `rng.seed = run_seed ^ POCKETS_RNG_SALT`) and the exits seam is
in `main_game.gd:1179` (`GameState.run_seed ^ GameState.EXITS_RNG_SALT`). **V6 runs first**, so when V4
opens `game_state.gd`, `_resolve_pockets` will already call `RNG.substream(POCKETS_RNG_SALT)` (or whatever
form V6 lands). V4's job: move `_resolve_pockets` into Economy **carrying whatever V6 left verbatim** — do
not revert to the local `RandomNumberGenerator`. `GameState.EXITS_RNG_SALT` is read by `main_game.gd` and
three exit tests; V4 keeps the const on GameState regardless of V6's disposition so those external reads
stay valid (or, if V6 relocated it to RNG, V4 leaves that relocation alone and does not re-add it). Any
fingerprint move here is a bug, not a deviation.

### A.7 The four quota snapshot fields — do they dissolve?

The four fields `_quota_active_this_run` / `_quota_step_snapshot` / `_quota_check_timing_snapshot` /
`_quota_basis_snapshot` (game_state.gd:115-118) exist for one documented reason (comments at 109-114 and
160-171): **`end_run` sets `active_run_config = null` (line 352) BEFORE the SellScreen sells**, and quota
evaluation (`_evaluate_quota`, called from `sell_banked_junk` at line 437 or `evaluate_quota_on_return` at
509) happens *after* that. So at eval time the config is gone; `start_run` snapshots the four scalars it
needs so the eval can still read them.

**Does the split dissolve them? Honest answer: the *ordering dependency is essential* — eval genuinely runs
after the config is cleared — so the snapshot cannot be eliminated. But it can be _relocated and
collapsed_.** Two improvements the split enables:

- **Relocate:** the four scalars stop being GameState's concern and become QuotaLadder's private run-state,
  captured in `_quota.begin_run(qc)`. GameState no longer carries any `_quota_*` field. This is pure
  encapsulation — the god-object shrinks by seven fields even if the *count* of quota-internal fields is
  unchanged.
- **Collapse (recommended):** `active_run_config = null` on line 352 only nulls **GameState's reference**;
  the `RunConfig` object itself is a `RefCounted` that survives as long as anything holds it. If
  `QuotaLadder.begin_run` keeps **its own reference** to the config (`_qc: RunConfig`), it can read
  `_qc.quota_step` / `_qc.quota_check_timing` / `_qc.quota_basis` / `_qc.quota_enabled` at eval time — the
  object is still alive. That collapses **four scalar snapshots → one held reference**. It is
  behavior-identical **iff** nothing mutates the config between `start_run` and eval, which is already a
  documented invariant ("Read-only to other systems: they read `GameState.active_run_config`, never mutate
  it," game_state.gd:77-78). The conservative alternative — keep snapshotting the four scalars inside
  QuotaLadder — is byte-identical with zero reliance on that invariant. **Recommendation: collapse to one
  held reference; fall back to scalar snapshots if the fresh-eyes reviewer wants zero reliance on the
  read-only invariant.** Either way `_quota_end_reason`, `_quota_evaluated_this_run`, `_quota_result` remain
  (they are eval state, not config snapshots). See Open Q1.

---

## (b) Pseudocode

Three files. Sub-objects are `RefCounted` in **separate `.gd` files** with `class_name` (Open Q2 weighs
inner-class vs separate-file; separate files are the recommendation — testable in isolation, clean seam for
M2). GameState composes them in `_ready` and forwards.

### `systems/economy.gd`

```gdscript
class_name Economy
extends RefCounted
## Owns meta currencies, the junk economy (bank/sell), the buy path, and the
## death-drop pockets math. Holds NO run-state — run context (inventory, seed) is
## passed in by GameState, preserving the run/meta boundary (TDD §2/§3).

const RUN_RULES_PATH := "res://data/economy/run_rules.tres"
const JUNK_CATALOG_PATH := "res://data/junk/junk_catalog.tres"

# meta
var money: int = 0
var salvage: int = 0
var lore: int = 0
var exposure: int = 0
var knowledge_level_UNUSED := 0   # NOTE: knowledge_level stays on GameState core (not economy)
var owned_items: Array[StringName] = []
var banked_junk: Array[JunkItem] = []
var run_rules: RunRules

func _init() -> void:
	run_rules = load(RUN_RULES_PATH) as RunRules
	if run_rules == null:
		run_rules = RunRules.new()   # safe code-default (0.20 / highest_value)

func add_currency(kind: StringName, delta: int, source: StringName) -> void:
	match kind:
		&"money": money += delta
		&"salvage": salvage += delta
		&"lore": lore += delta
		_: push_error("Unknown currency: %s" % kind)
	EventBus.currency_changed.emit(kind, delta, source)   # signals stay identical

func add_exposure(delta: int) -> void:
	var before := exposure
	exposure = clampi(exposure + delta, 0, 100)
	EventBus.exposure_changed.emit(exposure)
	for t in [25, 50, 75, 100]:
		if before < t and exposure >= t:
			EventBus.exposure_threshold_crossed.emit(t)

func purchase(item_id: StringName, price: int) -> bool:
	# byte-for-byte the current body (reject paths emit purchase_failed; the
	# SaveManager.save_meta(0) call stays here — it is a pure meta op).
	...

func owns(item_id: StringName) -> bool: return owned_items.has(item_id)

## Sell the whole banked pile → returns {breakdown, total}. GameState sequences the
## quota eval afterwards (it needs `total` + post-credit `money`).
func sell(source: StringName) -> Dictionary:
	var breakdown: Array[Dictionary] = []
	var total := 0
	for item in banked_junk:
		if item == null: continue
		breakdown.append({"id": item.id, "name": item.display_name, "value": item.base_sell_value})
		total += item.base_sell_value
	banked_junk = ([] as Array[JunkItem])
	add_currency(&"money", total, source)
	SaveManager.save_meta(0)
	return {"breakdown": breakdown, "total": total}

## Death-drop pockets. Run context passed IN — Economy never reaches for run-state.
## Uses whatever V6 left for the RANDOM policy (RNG.substream(POCKETS_RNG_SALT)).
func resolve_pockets(run_items: Array[JunkItem], run_seed: int) -> Array[JunkItem]:
	...   # verbatim _resolve_pockets body, run_inventory.items → run_items param

func held_haul_value() -> int:  # verbatim _held_haul_value
	...

# serialization value providers (GameState assembles the ordered dict)
func banked_junk_ids() -> Array[String]: ...
func owned_item_ids() -> Array[String]: ...

func wipe() -> void:
	money = 0; salvage = 0; lore = 0; exposure = 0
	banked_junk = ([] as Array[JunkItem])
	owned_items = ([] as Array[StringName])
```

### `systems/quota_ladder.gd`

```gdscript
class_name QuotaLadder
extends RefCounted
## Owns the K2 quota: meta ladder (run_number/quota_target) + the per-run eval
## state. Captures the run's quota config at begin_run so eval survives end_run
## clearing active_run_config (see A.7).

# meta
var run_number: int = 1
var quota_target: int = 0

# per-run eval state (was 7 fields on GameState)
var _qc: RunConfig                 # RECOMMENDED: hold the config ref (collapses 4 snapshots → 1)
var _end_reason: StringName = &""
var _evaluated_this_run: bool = false
var _result: Dictionary = {"checked": false}

## Called by GameState.start_run. Returns whether a lazy meta-init is needed so
## GameState (which owns the save call) can persist the seeded bar.
func begin_run(qc: RunConfig) -> Dictionary:
	_qc = qc
	_end_reason = &""
	_evaluated_this_run = false
	_result = {"checked": false}
	var active := qc != null and qc.quota_enabled
	if active and quota_target <= 0:
		quota_target = qc.quota_base
		run_number = 1
		return {"needs_save": true}     # GameState calls SaveManager.save_meta(0)
	return {"needs_save": false}

func set_end_reason(reason: StringName) -> void: _end_reason = reason   # called from end_run

## money + sold_total passed in (Economy values); held_haul from Economy for the
## cumulative basis on the Hub-return beat. Verbatim _evaluate_quota logic.
func evaluate(money: int, sold_total: int, held_haul: int) -> Dictionary:
	if _evaluated_this_run: return _result
	var active := _qc != null and _qc.quota_enabled
	if not active: _result = {"checked": false}; return _result
	var timing := _qc.quota_check_timing    # 0=on_extract, 1=every_run_end
	if timing == 0 and _end_reason != &"extract": _result = {"checked": false}; return _result
	_evaluated_this_run = true
	var basis := _qc.quota_basis             # 0=this_run_banked, 1=cumulative_money
	var achieved := (money + held_haul) if basis == 1 else sold_total
	var met := achieved >= quota_target
	EventBus.quota_evaluated.emit(run_number, quota_target, achieved, met)
	if met:
		run_number += 1
		quota_target += _qc.quota_step
		SaveManager.save_meta(0)
		EventBus.quota_advanced.emit(run_number, quota_target)
		_result = {"checked": true, "met": true, "achieved": achieved, "target": quota_target}
	else:
		_result = {"checked": true, "met": false, "achieved": achieved, "target": quota_target}
	return _result

func last_result() -> Dictionary: return _result

func wipe() -> void:
	run_number = 1
	quota_target = 0
```

### `systems/game_state.gd` (slim core = facade + coordinator + run lifecycle)

```gdscript
extends Node
# consts unchanged (GATE_SPAWN_OFFSET, salts left as V6 left them, path consts)

var _economy := Economy.new()
var _quota := QuotaLadder.new()

# --- forwarded meta (getter+setter keeps read/assign/mutate-in-place working) ---
var money: int:
	get: return _economy.money
	set(v): _economy.money = v
var salvage: int: get: return _economy.salvage; set(v): _economy.salvage = v
var lore: int: get: return _economy.lore; set(v): _economy.lore = v
var exposure: int: get: return _economy.exposure; set(v): _economy.exposure = v
var banked_junk: Array[JunkItem]:
	get: return _economy.banked_junk
	set(v): _economy.banked_junk = v
var owned_items: Array[StringName]:
	get: return _economy.owned_items
	set(v): _economy.owned_items = v
var run_rules: RunRules: get: return _economy.run_rules; set(v): _economy.run_rules = v
var run_number: int: get: return _quota.run_number; set(v): _quota.run_number = v
var quota_target: int: get: return _quota.quota_target; set(v): _quota.quota_target = v

# --- meta that stays on core (no economy/quota home) ---
var knowledge_level: int = 0
var unlocked_recipes: Array[StringName] = []

# --- run-state (unchanged, real fields on core) ---
var run_active := false
var run_seed := 0
var run_inventory: RunInventory
var active_run_config: RunConfig
# ... all other run-state fields verbatim ...

# --- forwarded methods (one-line delegates) ---
func add_currency(kind, delta, source) -> void: _economy.add_currency(kind, delta, source)
func add_exposure(delta) -> void: _economy.add_exposure(delta)
func purchase(id, price) -> bool: return _economy.purchase(id, price)
func owns(id) -> bool: return _economy.owns(id)
func last_quota_result() -> Dictionary: return _quota.last_result()

# --- coordinated flows (facade sequences the sub-objects) ---
func start_run(band_id, seed) -> void:
	# ... verbatim run-state setup + active_run_config resolution ...
	var q := _quota.begin_run(active_run_config)
	if q.needs_save: SaveManager.save_meta(0)
	RNG.seed_from(seed)
	EventBus.run_started.emit(band_id, seed)

func sell_banked_junk(source := &"sell") -> Array[Dictionary]:
	var sold: Dictionary = _economy.sell(source)
	_quota.evaluate(_economy.money, sold.total, _economy.held_haul_value())  # held=0 post-sell
	return sold.breakdown

func evaluate_quota_on_return() -> Dictionary:
	return _quota.evaluate(_economy.money, _economy.held_haul_value(), _economy.held_haul_value())

func fail_run(cause) -> void:
	if _run_ended: return
	_run_ended = true
	var duration_s := _elapsed_s()
	var kept := _economy.resolve_pockets(run_inventory.items if run_inventory else [], run_seed)
	for item in kept: if item != null: _economy.banked_junk.append(item)
	SaveManager.save_meta(0)
	EventBus.haul_banked.emit(_economy._sum_values(kept))
	end_run(cause, duration_s)
	unbanked_value = 0

func end_run(reason, duration_s) -> void:
	run_active = false
	_quota.set_end_reason(reason)     # was _quota_end_reason = reason
	if run_inventory != null: run_inventory.clear_run()
	active_run_config = null
	EventBus.run_ended.emit(reason, duration_s, max_depth_reached)

func wipe_meta() -> void:
	var prev := _quota.run_number
	_economy.wipe()
	_quota.wipe()
	knowledge_level = 0
	unlocked_recipes = ([] as Array[StringName])
	SaveManager.save_meta(0)
	EventBus.meta_wiped.emit(prev)
	EventBus.currency_changed.emit(&"money", 0, &"wipe")

# --- serialization dispatch (ordered dict; byte-identical) — see A.5 ---
func to_meta_dict() -> Dictionary: ...   # ordered literal sourcing from sub-objects
func from_meta_dict(d) -> void: ...      # pushes into sub-objects, rehydrates banked_junk
```

`_ready` keeps the EventBus connections (`player_died`, `dive_clock_timeout`, `dive_requested`) and moves
the `run_rules` load into `Economy._init` (or keeps it on core and injects — Open Q3).

---

## Open Questions

1. **Do the four quota snapshot fields truly dissolve, or is the ordering dependency essential?**
   The ordering dependency (eval runs after `end_run` nulls `active_run_config`) **is essential** — it
   cannot be removed. But the four *scalar* snapshots can **collapse to one held `RunConfig` reference**
   inside QuotaLadder (A.7), since nulling GameState's ref does not free the RefCounted config, and the
   config is a documented read-only invariant. *Recommendation: collapse to one held ref (4→1); fall back
   to scalar snapshots inside QuotaLadder if a reviewer wants zero reliance on the read-only invariant.
   Either way the seven `_quota_*` fields leave GameState entirely.* Needs fresh-eyes sign-off (Phase 3).

2. **Sub-object form: inner class vs separate `.gd` vs RefCounted?** *Recommendation: separate `.gd`
   files (`systems/economy.gd`, `systems/quota_ladder.gd`) with `class_name`, extending `RefCounted`.*
   Separate files are unit-testable in isolation (a QA win for the round-trip/quota tests), give M2 a clean
   type to extend, and avoid bloating game_state.gd (the point of the split). RefCounted (not Node) because
   they are owned data, not scene-tree citizens — no `_process`, no signals of their own (they emit through
   the EventBus autoload, which is globally reachable). **Constraint:** they must NOT be autoloads (DR-4,
   autoload count stays six). Trade-off: `class_name` adds two global type names — acceptable, and lets
   tests type their locals.

3. **Where does `run_rules` load — `Economy._init` or injected by core?** The current load is in
   `GameState._ready` (line 135) with a `push_warning` fallback. Moving it into `Economy._init` is cleanest
   (Economy owns pockets tuning) but `_init` runs before the scene tree is ready — `load()` is fine there
   (no tree needed). *Recommendation: load in `Economy._init`.* Minor; resolve on merit.

4. **Do the banked-junk rehydration helpers move to Economy?** `_rehydrate_banked_junk`(728) +
   `_build_catalog_index`(743) serve `banked_junk` (Economy's field) but are called from `from_meta_dict`
   (core's dispatcher). *Recommendation: move both into Economy as `rehydrate_banked_junk_from_ids(ids)`;
   `from_meta_dict` calls `_economy.rehydrate_banked_junk_from_ids(d.get("banked_junk", []))`.* Keeps
   catalog knowledge with the field it rehydrates. Resolve on merit.

5. **Does any caller reach a field the facade can't cleanly delegate?** Audit result: **no.** Every moved
   member is a var (getter+setter forwards read/assign/mutate-in-place) or a method (one-line delegate).
   The only non-forwardable members are `const`s (`GATE_SPAWN_OFFSET`, `EXITS_RNG_SALT`) — and they stay on
   core, so their 13 external reads are untouched. `test_save_migration.gd:130`'s
   `gs.banked_junk.append(null)` works via reference semantics (A.2). **Predicted caller edits: zero.** If
   the round-trip or a determinism test surfaces one, it is itemised as a deviation per the DoD.

6. **The 5+ hardcoded slot-0 sites — touch now or defer?** `SaveManager.save_meta(0)` is called at 5+
   sites (start_run lazy-init, extract, purchase, sell, quota-advance, wipe, fail). After the split these
   sites are spread across GameState (start/extract/fail/wipe), Economy (purchase/sell), and QuotaLadder
   (advance). *Recommendation: **defer** — V9 already owns the slot-0 tracking note (a code comment, no
   behavioral change), and DR-4 scopes V4 to a behavior-preserving split. Threading a `slot` parameter
   through is multi-slot-UI work for a future milestone, out of V4's scope. V4 just preserves the literal
   `0` at every site (now in three files instead of one) and adds the same V9-style comment.* Confirm the
   split does not make the future slot-threading harder (it does not — the sites are still few and each is a
   single `SaveManager.save_meta(0)` call).

---

## Expected debt ledger

**Structure (line counts, approximate):**

| unit | before | after |
|---|---|---|
| `game_state.gd` (monolith) | **752** | ~**430** slim core (lifecycle + facade forwards + serialization dispatch) |
| `systems/economy.gd` (new) | — | ~**180** (currencies, buy/sell, pockets, wipe) |
| `systems/quota_ladder.gd` (new) | — | ~**110** (ladder meta + eval + begin_run) |
| **total** | 752 | ~720 across 3 files |

Net LOC is roughly **flat** (a facade-preserving split adds ~30–40 lines of getter/setter/delegate
boilerplate — the cost of touching **zero** of the 38 callers). **This task's debt win is not net-LOC; it
is coupling and cohesion**, which is the version's stated measure for structural tasks:

- **God-object retired:** one 752-line file owning four responsibilities → three files, each with one
  responsibility (lifecycle / economy / quota). Max file size drops from 752 to ~430.
- **7 quota run-state fields + 2 quota meta fields leave GameState** (relocated to QuotaLadder; the four
  snapshot scalars collapse to **1** held config ref — a genuine field-count reduction, Open Q1).
- **Coupling reduced:** sub-objects have **zero** back-references and zero cross-references — run-state is
  *passed in*, never reached-for, so the run/meta boundary is now enforced by the type seam, not just
  convention. The three straddling flows (start/sell/fail/wipe) are the only coupling points and they are
  explicit coordinator methods on the facade.
- **M2 seam:** crafting/upgrades extend `Economy`; instability escalation extends `QuotaLadder` — clean
  types to bolt onto instead of editing a 752-line monolith.

**Behavior preserved (the DoD proofs):** 38 callers compile + pass with zero edits (or itemised);
`to_meta_dict`→store→load→`from_meta_dict` round-trip is byte-identical for a fixed state; v1/v2/v3→v4
migration fixtures green (SaveManager untouched, meta stays v4); economy/quota/shop/loop tests green; all
four control **layout** fingerprints byte-identical (the split touches no RNG/layout path; V6's migrated
salt seams are carried verbatim). Autoload count stays **six**; EventBus signal set unchanged.

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolver, 2026-07-10.** I did **not** author this design. I re-read
> `game_state.gd` in full, `save_manager.gd`, the heaviest callers (`main_game.gd`,
> `decision_hud.gd`, `shop_ui.gd`), and every test that reads/writes GameState fields directly,
> and I **empirically verified in headless Godot 4.6.3** the load-bearing facade mechanism the
> whole split turns on. All six Open Questions resolve on technical merit. **No new
> Director-level (vision/fun/tone/scope/date) call surfaces** — DR-4 (facade-preserving) is the
> only Director item, already recommended by the breakdown, and my verification shows it is
> low-risk to ratify. The four control-layout fps and meta byte-identity are preserved by
> construction; the only refinements below are (i) the `POCKETS_RNG_SALT` const co-locates with
> its sole consumer in `Economy`, and (ii) the V9-comment + V6-seam carry-forward obligations,
> both byte-safe.

### Verification performed (primary sources, not the design's prose)

- **The facade mechanism is empirically confirmed in Godot 4.6.3.** I ran a standalone headless
  probe (`Facade extends Node` with `var money`/`var pile` getter+setter forwarding to an inner
  `RefCounted`) exercising **every access shape the real callers/tests use**: (1) direct assign
  `f.money = 7` → setter writes backing ✔; (2) compound assign `f.money += 5` → getter-then-setter
  ✔; (3) **read-then-mutate `f.pile.append(99)` mutated the backing array** (Array is returned
  by reference) ✔ — this is exactly `test_save_migration.gd:130` `gs.banked_junk.append(null)` and
  `extract_and_end_run`'s `banked_junk.append(item)`; (4) typed-array assign `f.pile = fresh` ✔;
  (5) `f.pile = empty.duplicate()` ✔ — the exact shape at `test_loop_drive.gd:50`,
  `test_banking_math.gd`, `test_death_drop_pockets.gd`, `test_main_game_loop.gd`; (6)
  `append` + `pop_back` in place ✔ (`test_save_migration.gd:130-131`). **Result: `FACADE_PROBE:
  ALL PASS`.** A getter alone would have broken shapes (1)(2)(4)(5); getter **and** setter passes
  all six. The predicted **zero caller edits** rests on a verified mechanism, not an assumption.
- **The full write-surface audit backs "zero caller edits."** A tree-wide grep for writes to the
  forwarded fields (`money`/`salvage`/`lore`/`exposure`/`banked_junk`/`owned_items`/`run_rules`/
  `run_number`/`quota_target`) outside `game_state.gd` returns **only test files**, and every one
  is an assign, a `.duplicate()` assign, or an `.append()`/`pop_back()` mutate — all six confirmed
  above. Non-test callers (`main_game.gd`, `decision_hud.gd`, `shop_ui.gd`, `extract_gate.gd`,
  `gate_test.gd`) only **read** fields, **call methods**, or read the **consts**
  (`GameState.GATE_SPAWN_OFFSET`, `GameState.EXITS_RNG_SALT`) — all preserved by the facade. **No
  production caller writes a forwarded field.**
- **The quota-config read-only invariant is real (collapse is safe).** A grep for any
  field-wise write to `active_run_config.<field>` at runtime returns **nothing**; the only
  `.quota_*=` assignments in the tree are inside `run_config.gd`'s `make_default_play_preset()`
  factory (building a fresh `c` *before* it is ever bound as `active_run_config`) and test
  authoring. So once a config is bound at `start_run`, nothing mutates it before eval. And
  `RunConfig extends Resource` → `RefCounted`, so `end_run`'s `active_run_config = null`
  (`game_state.gd:352`) drops only *GameState's* reference; a `QuotaLadder._qc` reference keeps
  the object alive. The ordering dependency is genuine (eval at `sell_banked_junk:437` /
  `evaluate_quota_on_return:509` runs **after** `end_run:352`), which is exactly why the collapse
  is legitimate rather than eliminable.
- **Meta key order confirmed for byte-identity.** Current `to_meta_dict` insertion order
  (`game_state.gd:690-701`) is `money, salvage, lore, exposure, knowledge_level,
  unlocked_recipes, banked_junk, run_number, quota_target, owned_items`. The design's ordered
  **literal** (A.5, lines 171-178) reproduces this order character-for-character while sourcing
  each value from its new owner. `store_var` serializes a Dictionary in insertion order, so the
  ordered literal (NOT `Dictionary.merge`) keeps the blob byte-identical at v4; SaveManager is
  untouched, so the v1/v2/v3→v4 migration fixtures pass unchanged.

### OQ1 — do the four quota snapshot fields dissolve? → **RESOLVED: COLLAPSE to one held `_qc: RunConfig` reference in `QuotaLadder`.**
Confirmed on merit and by the verification above. The ordering dependency (`end_run` nulls
`active_run_config` before eval) is **essential and cannot be removed** — but the **four scalar
snapshots** (`_quota_active_this_run` / `_quota_step_snapshot` / `_quota_check_timing_snapshot` /
`_quota_basis_snapshot`) **collapse to one held `RefCounted` reference** captured in
`QuotaLadder.begin_run(qc)`. This is byte-identical: (a) the config is never field-mutated at
runtime (grep-clean), so reading `_qc.quota_step`/`quota_check_timing`/`quota_basis`/`quota_enabled`
at eval time yields the same values `start_run` would have snapshotted; (b) `RunConfig` is
`RefCounted`, so `QuotaLadder._qc` outlives `GameState`'s null-out at `:352`; (c) `_qc` is the same
object `begin_run` received, and nothing reassigns `active_run_config` to a different object between
`start_run` and eval (only the null). **All seven `_quota_*` fields leave GameState** either way;
the collapse additionally cuts four snapshot scalars to one held ref — a genuine field-count
reduction. The scalar-snapshot fallback (capture the four scalars *inside* `QuotaLadder` at
`begin_run`) remains available and is *also* byte-identical, but it is **not needed**: the read-only
invariant is empirically clean, and the fallback buys nothing but a marginal decoupling from an
invariant the codebase already documents and enforces (`game_state.gd:77-78`). **Ship the collapse.**
`_end_reason`, `_evaluated_this_run`, `_result` remain as eval state (not config snapshots). **No
Director review.**

### OQ2 — sub-object form → **RESOLVED: separate `.gd` files, `class_name`, `extends RefCounted`.**
As the design recommends. `systems/economy.gd` (`class_name Economy`) and
`systems/quota_ladder.gd` (`class_name QuotaLadder`), both `extends RefCounted` (owned data, not
scene-tree citizens — no `_process`, no own signals; they emit through the `EventBus` autoload,
globally reachable from any `RefCounted`). Verified **no existing `class_name Economy` /
`QuotaLadder` collision** in the tree. Separate files are unit-testable in isolation (a QA win for
the round-trip + quota tests) and give M2 clean types to extend. **Hard constraint (DR-4): they are
`GameState.new()`-owned fields, NOT autoloads — autoload count stays six.** The two added global
type names are acceptable. **No Director review.**

### OQ3 — `run_rules` load site → **RESOLVED: load in `Economy._init()`.**
Economy owns the pockets tuning, so it owns the `RUN_RULES_PATH` load + the `RunRules.new()`
safe-default fallback (moved off `GameState._ready:135-138`). `_init()` runs during
`GameState`'s field-initialization (`var _economy := Economy.new()`), i.e. at autoload
construction — earlier than the current `_ready`, but `load()` needs no scene tree and global
`class_name` types (`RunRules`) are registered before any autoload constructs, so both the `load`
and the `RunRules.new()` fallback are valid there. `Economy._init` touches no other autoload
(`EventBus`/`RNG` are only reached at method-call time, well after `_ready`), so there is **no
autoload-order hazard**. A trivially-safe alternative (keep the load in `GameState._ready` and
inject `_economy.run_rules = load(...)`) exists if integration ever surfaces an ordering surprise,
but none is expected. **No Director review.**

### OQ4 — rehydration helpers home → **RESOLVED: move both into `Economy`.**
`_rehydrate_banked_junk` + `_build_catalog_index` (and the `JUNK_CATALOG_PATH` const they use)
move into `Economy` as `rehydrate_banked_junk_from_ids(ids)`; `GameState.from_meta_dict` calls
`_economy.rehydrate_banked_junk_from_ids(d.get("banked_junk", []))`. Catalog knowledge co-locates
with the `banked_junk` field it rehydrates — the same cohesion argument that moves `banked_junk`
itself. The unknown-id skip-with-warning behavior is carried verbatim (unchanged load safety).
**No Director review.**

### OQ5 — any undelegatable field? → **RESOLVED: NONE. Predicted caller edits: ZERO — verified.**
The audit holds under primary-source verification. Every moved member is a `var` (getter+setter
forwards read / assign / compound-assign / mutate-in-place — all six shapes empirically confirmed)
or a method (one-line delegate). The **only** non-forwardable members are `const`s, and they are
handled explicitly (see the V6-seam decision below): `GATE_SPAWN_OFFSET` and `EXITS_RNG_SALT` stay
on `GameState` (external readers use `GameState.<CONST>`); `POCKETS_RNG_SALT` co-locates into
`Economy` with its sole consumer (zero external readers). `test_save_migration.gd:130`'s
`.append(null)` works via array-by-reference (confirmed). **No production caller writes a forwarded
field.** If the round-trip or a determinism test surfaces a single edit, it is itemised as a
deviation per the DoD — but none is expected. **No Director review.**

### OQ6 — the hardcoded slot-0 sites → **RESOLVED: DEFER to V9's marker; V4 carries the comments verbatim across the split. Coordination confirmed collision-free.**
Confirmed against `V9_housekeeping.md`. **V9 (Wave 1) runs and fully merges before V4 (Wave 3)**,
and V9 part (c) adds a single-line tracking comment at the **7** `SaveManager.save_meta(0)` sites
in `game_state.gd` (`:181, :307, :387, :432, :474, :556, :608`) — no behavioral change, no `slot`
threading (multi-slot UI is a future milestone). V4 then splits `game_state.gd`, relocating some
of those sites: **4 stay on core** (`:181` start_run lazy-init → core after `_quota.begin_run`
returns `needs_save`; `:307` extract; `:556` wipe_meta; `:608` fail_run), **2 move into `Economy`**
(`:387` purchase, `:432` sell), **1 moves into `QuotaLadder`** (`:474` quota advance). **V4's
obligation: preserve the literal `SaveManager.save_meta(0)` AND V9's tracking comment verbatim at
each relocated site** (now spread across three files). This does not make future slot-threading
harder — the sites are still few and each is a single `save_meta(0)` call; if anything the split
clarifies which sites are economy-owned vs quota-owned vs lifecycle-owned. **No collision** (V9 and
V4 are in different waves and V4 only carries V9's already-placed comments forward). **No Director
review.**

### V6 → V4 seam (Wave 2 → Wave 3) — carry-forward obligations, **refined**

V6's `Resolved Decisions (Phase 3)` leave the pockets/exits seams in this exact form; V4 must honor
them verbatim:

- **Pockets (`game_state.gd:650-651` → `Economy.resolve_pockets`).** V6 replaces the 3-line inline
  block with **`var rng := RNG.substream(run_seed, POCKETS_RNG_SALT)`**. When V4 moves
  `_resolve_pockets` into `Economy`, it **carries that `RNG.substream(...)` call verbatim** (never
  reverts to a local `RandomNumberGenerator`), with `run_seed` arriving as a **parameter**
  (`resolve_pockets(run_items, run_seed)`) — Economy never reaches for run-state. **Refinement to
  A.2/A.6:** the design says "all consts stay on GameState," but `POCKETS_RNG_SALT` has **zero
  external references** (verified: its only reader is the pockets code that is moving to Economy).
  Therefore **`POCKETS_RNG_SALT` moves into `Economy`** alongside `resolve_pockets` — co-located
  with its sole consumer, which is cleaner than leaving it on `GameState` and qualifying it as
  `GameState.POCKETS_RNG_SALT`. This is byte-safe (the literal `0x50434B54` does not change; only
  its declaring file does) and preserves the "Economy has no GameState back-ref" goal.
- **Exits (`main_game.gd:1178-1179`).** V6 migrates this site (which lives in `main_game.gd`, NOT
  `game_state.gd`), so **V4 does not touch the exits call at all**. V4's only exits obligation:
  **keep `EXITS_RNG_SALT` declared on `GameState`** (`const` on the facade), because it is read
  cross-file as `GameState.EXITS_RNG_SALT` by `main_game.gd:1179` and the exit tests
  (`test_exit_placement.gd`, `test_exit_placement_count.gd`) and referenced in `run_config.gd`'s
  comments. Likewise `GATE_SPAWN_OFFSET` stays on `GameState` (heavily read as
  `GameState.GATE_SPAWN_OFFSET` by `main_game.gd`, gate entities, and four tests). **Any fingerprint
  move at these seams is a bug, not a deviation.**

### DR-4 — split depth (facade-preserving vs deeper split) → **RATIFIED-READY: facade-preserving is low-risk. No new Director call.**
The breakdown recommends facade-preserving; my verification confirms it **truly yields zero caller
edits + zero save change**: (1) the getter+setter facade passes all six real access shapes
(empirically), and no production caller writes a forwarded field (audited); (2) the ordered-literal
`to_meta_dict` keeps the meta blob byte-identical at v4 with SaveManager untouched, so the
v1/v2/v3→v4 fixtures pass unchanged. The deeper-split alternative (update call sites / expose new
seams to M2) buys nothing M1.12 needs — M2 can extend `Economy`/`QuotaLadder` as clean types
without V4 pre-touching 38 files, and touching callers would violate the version's
behavior-preserving + regression-floor contract. **Facade-preserving is the correct, low-risk
disposition; the Director's recommended DR-4 stands with no new judgment required.**

### Minor note (not an OQ) — `bank_haul` placement
`bank_haul` (`game_state.gd:270`) has **zero callers** in the tree (only its definition). It reads
run-state `unbanked_value` and calls `add_currency` (Economy). Because it is currently uncalled, its
placement is behaviorally inert. **Recommendation: keep it on the core facade** as a thin coordinator
(reads `unbanked_value`, calls `_economy.add_currency`, emits `haul_banked`, zeroes `unbanked_value`)
rather than pushing it into Economy, since it primarily manipulates run-state that lives on core.
Byte-safe either way; core placement keeps the run-state read local.

### Binding summary for the builder

Split `game_state.gd` into **`systems/economy.gd`** (`class_name Economy extends RefCounted`) +
**`systems/quota_ladder.gd`** (`class_name QuotaLadder extends RefCounted`) + a slim `GameState`
core facade. **Forward** every moved `var` with a Godot-4 **getter+setter** property (both required
— getter-only breaks the writes) and every moved method with a one-line delegate. **Collapse** the
four quota snapshot scalars to one held `QuotaLadder._qc: RunConfig` (all seven `_quota_*` fields
leave GameState). **Assemble `to_meta_dict` as an ordered literal** in the exact current key order,
sourcing each value from its new owner (NOT `Dictionary.merge`) → byte-identical v4 blob; SaveManager
untouched. **Move** `_rehydrate_banked_junk` + `_build_catalog_index` + `JUNK_CATALOG_PATH` into
Economy; **load `run_rules` in `Economy._init`**. **Move `POCKETS_RNG_SALT` into Economy** with
`resolve_pockets` (carrying V6's `RNG.substream(run_seed, POCKETS_RNG_SALT)` verbatim, `run_seed`
passed in); **keep `EXITS_RNG_SALT` + `GATE_SPAWN_OFFSET` on GameState** (external readers).
**Carry V9's slot-0 tracking comments verbatim** to each relocated `save_meta(0)` site. **DoD proof:**
`FACADE_PROBE`-style access all-shapes green, 38 callers compile+pass with **zero edits**, meta
round-trip byte-identical, v1/v2/v3→v4 fixtures green, all four control layout fps byte-identical,
autoload count six. **No item requires Director review** (DR-4 facade-preserving stands as
recommended).
