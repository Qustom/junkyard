# M0 — Foundation: app-flow router + economy + signals + P action · Phase-2 Design

**Task:** M0 (M1.6 Wave 1, lands first and ALONE). **Role:** general-purpose (programmer).
**Blocks:** M1 (routes Menu→Hub via the router; reads New/Continue/Quit meta entry points), M2 (router transitions + `dive_requested`/return signals + dive-only `main_game` seam), M3 (the `GameState.purchase()`/owned-items surface + the save-schema scaffold), M4 (reads the `debug_menu_toggle`=P action).
**BlockedBy:** none.
**Authored:** 2026-06-26, Phase 2 of the four-phase process (`CLAUDE.md`), from `design/M1_6_Tasks/M1.6_Breakdown.md` §3 (M0 row), §6 (carried contracts), §7 (open risks). Mirrors the proven M1.5 **L0** foundation prior art (`design/M1_5_Tasks/L0_foundation_knobs_signals.md`) — the single-writer pass over the shared files for the whole milestone.

> **What this doc IS:** the **flow + economy + signal + input contract** every other M1.6 build design keys off. M0 is the *single-writer pass* over the shared structural files (`project.godot`, `systems/event_bus.gd`, `systems/game_state.gd`, and the **new router file**) so no two Wave-2/Wave-3 tasks ever edit them in parallel (the M1.1 pre-declare rule, Breakdown §6, §10). It defines (1) the scene/flow **router mechanism** for Main Menu ↔ Hub ↔ Dive; (2) the **app-entry swap** (`run/main_scene` → `main_menu.tscn`); (3) the **buy-economy** surface on `GameState` (`purchase(...)` + owned-items, off/neutral default) and the META save-schema scaffold; (4) **every new `EventBus` signal** M1.6 needs, pre-declared up front; (5) the **`debug_menu_toggle`=P** input action. M0 owns ALL `project.godot` `[input]`/`[application]` edits for the milestone.
>
> **What this doc is NOT:** any scene content or UI. M0 builds **no** Main Menu (M1), **no** Hub room (M2), **no** Shop UI / catalog (M3), **no** tab regroup (M4). It lands the *seams* those tasks plug into: a router with a stable transition API, a `GameState` economy surface at neutral defaults, the signal declarations (inert until emitted), the P action, and the entry-scene swap. It adds **no `RunConfig` lever knobs** — M1.6 is structural/meta/UI, so the all-off determinism baseline (`e943ac9c8bc1`) and the **89-knob count** stay byte-identical (Breakdown §2, §6).

---

## (a) Research on the premise — why M0 is a single-writer foundation

### A.1 The structural problem M1.6 introduces (and why M0 must land first, alone)

M1.0–M1.5 built the whole dive loop *inside one scene*: `scenes/game/main_game.tscn` is the app entry (`project.godot:15` `run/main_scene="res://scenes/game/main_game.tscn"`), and **it owns the menu, the config rail, the Start button, and the between-runs SellScreen all as children** (`main_game.tscn:42-101` is the `MainMenu` CanvasLayer with `Backdrop`/`ConfigMenu`/`Center/VBox/{Title,Hint,StartButton}`/`VersionLabel`; `SellScreen` is a sibling at `:40`). The flow is hand-wired in `main_game.gd`: `_show_menu()`/`_hide_menu()` toggle `_menu.visible` (`main_game.gd:1314-1320`), `_on_start_pressed()` → `start_new_run()` (`:1276-1280`), and `SellScreen.continue_pressed` loops straight back into `start_new_run()` (`:158`, `:196-199`). There is **no scene transition anywhere in the codebase** — confirmed: `grep change_scene_to_file|change_scene_to_packed` over the repo returns nothing. The whole game is one `Node2D` that shows/hides overlays.

M1.6 breaks this into **three top-level states** — Main Menu (M1), Hub (M2), Dive (the refactored `main_game`, M2) — that the player moves *between*. The moment more than one task needs to add a flow transition, declare a new cross-state signal, edit the entry scene, or touch the economy, three parallel worktrees collide on `project.godot` + `event_bus.gd` + `game_state.gd` + the router. M0 is the M1.6 application of the M1.1/M1.4/M1.5 **pre-declare rule** (Breakdown §6, §10): **one task writes the shared structural files up front, off/neutral, for the whole milestone**, so M1/M2/M3/M4 only *read the router API*, *emit pre-declared signals*, *call the economy surface*, and *read the P action* — they never touch the four foundation files again. This is exactly the role L0 played for M1.5 and K0 for M1.4 (`design/M1_5_Tasks/L0_foundation_knobs_signals.md` §A.1).

The dependency map (Breakdown §4) makes M0 **Wave 1, solo**: `BlockedBy: none`, everything else `BlockedBy: M0`. M0 lands + is verified on `main` before Wave 2 opens.

### A.2 The run/meta boundary the economy surface must honor (`systems/game_state.gd`)

`GameState` is the autoload that **holds both run-state and meta-state and enforces the boundary** (`game_state.gd:1-9`; TDD §2/§3 "strict separation"). M0's economy additions are **pure meta**, so they sit with the existing meta block (`:32-49`):

- **Meta-state (persists; serialized by `SaveManager`):** `money:int` (`:33`), `salvage:int` (`:34`), `lore:int`, `exposure:int`, `knowledge_level:int`, `unlocked_recipes:Array[StringName]` (`:38`), `banked_junk:Array[JunkItem]` (`:42`), and the K2 quota meta `run_number:int`/`quota_target:int` (`:47-49`). The **owned-purchases surface M0 declares (`owned_items`) joins this block** — it persists exactly like `unlocked_recipes` (a meta inventory of StringName ids).
- **The canonical ledger mutation** is `add_currency(kind, delta, source)` (`:300-306`), which mutates `money`/`salvage`/`lore` and emits `EventBus.currency_changed(kind, delta, source)`. **`purchase()` debits Money through `add_currency(&"money", -price, &"shop")`** — it never mutates `money` directly, so Telemetry's currency-out hook sees one event per purchase (mirroring how `sell_banked_junk` credits through the same single mutation, `:342`).
- **The save bridge** is `to_meta_dict()` (`:547-563`) / `from_meta_dict(d)` (`:565-581`). `to_meta_dict` persists `banked_junk` **by id (String)** because the save model is objects-OFF (`:551-559`); `from_meta_dict` rehydrates via the JunkCatalog (`:577`, `_rehydrate_banked_junk`). **`owned_items` follows the `unlocked_recipes` pattern exactly** — a flat `Array[String]`/`Array[StringName]` of catalog ids, no rehydration needed (an owned upgrade is just an id flag; M3's effects read the id set). This keeps the save objects-OFF and migration-friendly.
- **The wipe** `wipe_meta()` (`:410-431`) resets EVERY meta field to its construction default and re-persists (the roguelite reset). **`owned_items` must be reset here too** (a fresh-typed empty array, `:417-420` pattern) — owned purchases are meta and a wipe clears them. M1's "New Game on an existing save" routes through this (Breakdown §7).

The Director's call (Breakdown §2, §7) is that **buying may persist** (owned upgrades across runs). If it does, that is a **deliberate META v3→v4 bump** (A.4). M0 lands the *surface* at off/neutral so an unconfigured/unused economy is byte-identical to today; M3 fills the catalog + the buy bodies + (if persistent) the migration.

### A.3 The EventBus house style M0 must follow (`systems/event_bus.gd`)

`EventBus` is **pure wiring, no state** (`:1-6`). The pre-declare discipline is explicit and repeated per milestone: M1.4's K0 block (`:118-123`) and M1.5's L0 block (`:157-163`) are each headed *"sole event_bus.gd edit this milestone, owner = K0/L0 … Pre-declared up front so the consuming tasks only EMIT — they never edit this file."* **M0 adds one new M1.6 block and is the sole `event_bus.gd` editor this milestone.**

House-style rules M0's signals obey (verified across the file):
- **Telemetry-row signals carry PRIMITIVES ONLY** so `Telemetry` serializes straight to JSONL (`:53-60`, `:85-88`, `:164`). Gameplay-event signals that aren't telemetry rows may carry refs — e.g. `junk_dropped(item: JunkItem, world_pos: Vector2)` (`:66`). M1.6's flow signals are **all primitives** (StringName band/scene ids, ints) — none need to carry a Node ref, because the router resolves scenes by path, not reference.
- **`run_t_ms` / `depth` conventions:** in-dive telemetry rows stamp `run_t_ms:int` (monotonic ms) + `depth:int` — e.g. `item_thrown(item_id, depth, run_t_ms)` (`:167`), `new_hazard_killed(kind, depth, run_t_ms)` (`:149`). **M1.6's flow signals fire OUTSIDE a dive (in the Menu/Hub) where there is no run clock or depth**, so they do NOT carry `run_t_ms`/`depth`. `dive_requested(band_id)` fires from the Hub before any run exists; `returned_to_hub(reason)` fires after `run_ended` cleared run-state. The shop/economy signals carry the transaction primitives (item id, price/value, money-after).
- **`run_ended` arity is LOCKED** (`:10`, Breakdown §6) — no M1.6 signal touches it. The dive→hub return is a NEW signal that *observes* `run_ended` (the router listens to `run_ended` and then emits `returned_to_hub`), not a change to `run_ended`.
- **No test asserts a signal count** (confirmed: L0 §A.3 verified there is no count assertion on `event_bus.gd`). So declaring the full M1.6 signal set up front is free; an unused declared signal is inert.

### A.4 The save discipline a v3→v4 bump entails (`systems/save_manager.gd`)

`SaveManager` is the decided save architecture (`:1-12`; TDD §3, research §9): typed state → `FileAccess.store_var(value, false)` (objects OFF, `:47`), per-slot `meta.sav` carrying an integer `schema_version` (`:24`), **ordered stepwise migrations** v→v+1 (`_migrate_meta`, `:75-98`), **atomic write + `.bak`** (`_atomic_store`, `:39-54`). `META_SCHEMA_VERSION = 3` today (`:15`).

A v3→v4 bump (IF purchases persist) is a **mechanical, well-trodden step** — the migration chain already has three precedents to copy (`:78-95`): v0→v1 (`knowledge_level`), v1→v2 (E1 `banked_junk`), v2→v3 (K2 `run_number`/`quota_target`). The v3→v4 step is:

```gdscript
3:
    # v3 -> v4 (M1.6 M3): owned_items added. Old saves predate the shop → default
    # to an empty id list so from_meta_dict reads owned nothing.
    if not data.has("owned_items"):
        data["owned_items"] = []
```

…plus bump `META_SCHEMA_VERSION` to `4` (`:15`), add `"owned_items"` to `to_meta_dict()`/`from_meta_dict()` (defaulting `[]`), and add a **`meta_v3.sav` QA fixture** so the migration is regression-tested (the existing fixtures live under `tests/fixtures/`; the v2→v3 step was covered by a matching fixture — M3's QA task adds the v3 one). The atomic-write/`.bak` path is unchanged. **The bump is a real schema change surfaced to the Director (Breakdown §2, §7), not silent** — and it happens in **M3** (where the catalog decides whether purchases persist), NOT M0. M0's job is to **declare the surface so it slots cleanly into v4** and to **scaffold the migration shape** in this doc so M3's author lands it without re-deciding it. See OQ-3 for the persist-vs-consumable Director call.

> **Critical scoping note:** M0 must NOT bump `META_SCHEMA_VERSION` itself. If M0 added `owned_items` to `to_meta_dict()` *without* a version bump + migration, an old v3 save would round-trip a missing key (defaulted to `[]` by `from_meta_dict`'s `.get(...)`, harmless) — but the *clean* contract is one bump owned by the task that makes purchases persistent (M3). **Recommendation (OQ-3): M0 declares the `owned_items` field + the neutral default in `GameState`, and scaffolds the migration here, but the `META_SCHEMA_VERSION` bump + migration step + fixture land in M3** when the persist decision is ratified. If the Director picks consumable-only, NO bump ever happens and `owned_items` stays an in-memory run-or-meta scratch the shop reads (see OQ-3).

### A.5 How today's `main_game`-owned menu/scene wiring works — what the router replaces

The current "flow" is entirely intra-scene overlay toggling inside `main_game.gd`:

- **Boot → menu:** `_ready()` (`:143-169`) loads fixtures, wires the SellScreen/run_ended handlers, calls `_show_menu()` (`:166`), then `_maybe_show_consent_prompt()` (`:169`, the first-run G6 telemetry modal — `_consent_pending` blocks Start until answered, `:1296-1311`). `_show_menu()` sets `_menu.visible=true` + grabs Start focus (`:1314-1316`).
- **Start → dive:** `_on_start_pressed()` (`:1276-1280`) → `start_new_run()` (`:208-335`), which `_hide_menu()`s, clears+regenerates the band, places the player, and calls `GameState.start_run(BAND_ID, seed)` (`:306`). The config comes from the `ConfigMenu` rail (`%ConfigMenu`, `:75`, `apply_and_get_config()`, `:223`).
- **Dive end → reward → loop:** a run ends via `extract_and_end_run()` / `fail_run()` in `GameState`, which fires `run_ended`. `SellScreen._on_run_ended` (`sell_screen.gd:120-124`) auto-presents over the **paused** tree, sells the bank (`sell_banked_junk`, `:135`), shows the quota outcome (`_render_quota`, `:168-184`), and on **Continue** emits `continue_pressed` → `main_game._on_continue_pressed` (`:196-199`) which runs the wipe-if-missed then `start_new_run()` again. "Back to Config" re-shows the menu (`:1287-1289`).

**What the router replaces:** the implicit "show/hide overlays in one scene" flow becomes **explicit transitions between three scenes**. The Main Menu's Start becomes "route to Hub"; the Hub's departure portal becomes "route to Dive"; the dive's `run_ended` becomes "route back to Hub." `main_game` **stops owning the menu** (M2 strips the `MainMenu` CanvasLayer + Start button + ConfigMenu rail to dive-only) and **stops auto-presenting SellScreen as the between-runs screen** (M3 retires it; selling moves to the Hub Shop). M0 defines the router so M1/M2 have a stable transition API to build against. The riskiest seam (Breakdown §7) is **SellScreen retirement** — it currently owns the sell tally + quota readout + the web "Export telemetry" button (`sell_screen.gd:53-55`, `_setup_export_control`, `:94-101`) + the `pending_wipe`→`wipe_meta` routing (`:186-188`); all three must be re-homed (M3's inventory, but M0 pre-declares the signals — `item_sold`/`quota readout` re-home — so M3 wires them without editing EventBus).

### A.6 The entry-scene swap is CI-safe (verified — the §6 load-bearing contract)

Breakdown §6/§7 flags: repointing `run/main_scene` must not break the headless smoke test or the test scenes. **Verified directly:**

- **`tools/ci_smoke_test.gd`** `extends SceneTree` (`:1`) and **never instantiates `main_game.tscn`** — `_initialize()` (`:10-65`) only checks the six autoloads by name (`:14-21`), RNG determinism (`:23-29`), a save round-trip + migration (`:32-50`), and a single `JunkItem` load (`:53-56`). It is **entry-scene-agnostic** — it runs as a `--script`, bypassing `run/main_scene` entirely. **The swap is safe for CI.** ✅
- **`tests/test_main_game_loop.tscn`** (the integration drive) instantiates the dive scene **by its own constant** `const MAIN_GAME_PATH := "res://scenes/game/main_game.tscn"` (`test_main_game_loop.gd`) and calls `MainGame.start_new_run()` directly — it does **not** read `run/main_scene`. So the swap doesn't break it *per se*. BUT it depends on `MainGame` exposing a programmatic `start_new_run()` entry; **M2's dive-only refactor must keep that programmatic entry** (the test + the RG-verify tests, `test_rg1_m1*_verify.gd`, drive `start_new_run()` headless without the menu). That is M2's contract — M0 only notes it here so M2's design honors it. ✅ (no M0 test change needed for the swap itself).

**Net:** the only thing the `run/main_scene` swap itself breaks is "boot launches straight into the dive," which is precisely the change M1.6 wants. No test hard-assumes `main_game.tscn` is the *entry*; the one test that loads it does so by an explicit path constant. **M0 may repoint `run/main_scene` with no test edits** (any test edit belongs to M2's dive-only refactor or M1/M3 scene work).

### A.7 The `[input]` map M0 extends (`project.godot:52-148`)

The input actions are a hand-authored `[input]` block. Existing actions: `move_*` (WASD+arrows+stick), `interact` (F=70 + pad A), `extract` (pad B), `highlight_left/right` (Q/E + wheel + pad), `throw` (Space=32 + LMB + RT), `aim_*` (right stick), `pause` (Esc=4194305 + pad Select), `debug_kill` (K=75). **M0 adds ONE action: `debug_menu_toggle` = P** (physical keycode **80**), following the exact `debug_kill` shape (`:144-148`) — a single `InputEventKey` with `physical_keycode` set, `deadzone` 0.5. P is unused today (confirmed: no `physical_keycode":80` in the map). M4 reads this action to open/close the tabbed debug menu as an overlay available in Menu/Hub/Dive (Breakdown §3 M4). M0 owns **all** `[input]` edits this milestone (the single-writer rule), so M4 adds no input action — it only reads `debug_menu_toggle`.

---

## (b) Pseudocode — illustrative GDScript against the REAL as-built APIs

> Everything below is **off/neutral by default**: the router exists but its transitions are only driven by M1/M2 scenes; the economy surface debits nothing until M3's shop calls it; the signals are inert until emitted; the P action does nothing until M4 reads it. A run launched the old way (headless `start_new_run()`) is byte-identical — none of M0's additions feed `fingerprint()` (they are flow/meta/UI, never generation), so the all-off baseline stays `e943ac9c8bc1` and the **89-knob count is untouched** (M0 adds NO `RunConfig` knob).

### B.1 The router mechanism — RECOMMENDED: a persistent root **`App`** node that swaps child scenes (with the P-overlay mounted on it)

Three candidate mechanisms (weighed in OQ-1); the recommendation is **(B) a persistent root `App` node** because it gives the P-debug overlay (and any future persistent HUD) **one stable mount available in all three states**, which `change_scene_to_file` cannot (it tears down the whole tree including any overlay on every transition).

**New file `scenes/app/app.gd` + `scenes/app/app.tscn`** (the new `run/main_scene`). `App` is a thin `Node` that holds the current state scene as its child + a `CanvasLayer` for the debug overlay, and exposes the transition API the flow signals drive:

```gdscript
class_name App
extends Node
## App (M1.6 M0) — the persistent root scene router. THE app entry (run/main_scene).
## Holds exactly one "state scene" child at a time (Main Menu / Hub / Dive) and swaps
## it on the flow signals. A persistent CanvasLayer mount (the debug overlay) survives
## every swap, so M4's P-toggle menu is available in ALL THREE states from one instance.
## Owns NO game-state truth (the run/meta boundary stays GameState's) — it only swaps
## scenes and re-emits hub_entered/returned_to_hub so observers fire AFTER the swap.

const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"   # M1 authors this scene
const HUB_PATH := "res://scenes/hub/hub.tscn"                # M2 authors this scene
const DIVE_PATH := "res://scenes/game/main_game.tscn"        # M2 refactors to dive-only

@onready var _state_host: Node = $StateHost          # the swappable state scene lives here
@onready var _overlay: CanvasLayer = $DebugOverlay   # persistent P-menu mount (M4 fills it)

var _current_state: StringName = &""   # &"menu" / &"hub" / &"dive" — pure router bookkeeping

func _ready() -> void:
    # Router listens to the flow signals + run_ended so it owns the transitions; the
    # scenes only EMIT intent (decoupled exactly like SellScreen.continue_pressed today).
    EventBus.dive_requested.connect(_on_dive_requested)
    EventBus.return_to_hub_requested.connect(_on_return_to_hub_requested)
    EventBus.run_ended.connect(_on_run_ended)   # auto-return after a dive resolves (OQ-5)
    _goto(MAIN_MENU_PATH, &"menu")              # boot → Main Menu (the new entry beat)

## Swap the state scene: free the old, instance + add the new under _state_host.
## Greybox-simple; no transition animation (M1.6 is structural). Scenes are resolved
## by PATH (not ref) so the router holds no scene references across a swap.
func _goto(scene_path: String, state: StringName) -> void:
    for child in _state_host.get_children():
        child.queue_free()
    var packed := load(scene_path) as PackedScene
    if packed == null:
        push_error("App: missing state scene %s" % scene_path); return
    _state_host.add_child(packed.instantiate())
    _current_state = state

# --- Flow handlers (the router's whole job) ---------------------------------
func _on_dive_requested(_band_id: StringName) -> void:
    _goto(DIVE_PATH, &"dive")
    # NOTE: the dive scene starts the run itself in its own _ready/entry (M2 wiring),
    # exactly as start_new_run() does today — the router only puts it in the tree.

func _on_return_to_hub_requested(_reason: StringName) -> void:
    _goto(HUB_PATH, &"hub")
    EventBus.hub_entered.emit()   # fire AFTER the hub is in the tree (observers read settled state)

## Auto-return: a dive that ends (extract/death/timeout) routes back to the Hub. We
## defer one frame so SellScreen-style same-frame run_ended consumers settle first, then
## return. (OQ-5: auto-return vs. an explicit player "leave" — recommend auto for M1.6.)
func _on_run_ended(reason: StringName, _duration_s: float, _depth: int) -> void:
    if _current_state != &"dive":
        return   # ignore run_ended that didn't originate from the dive state
    call_deferred("_return_after_dive", reason)

func _return_after_dive(reason: StringName) -> void:
    EventBus.returned_to_hub.emit(reason)   # carries the dive outcome for the Hub/Shop readout
    _goto(HUB_PATH, &"hub")
    EventBus.hub_entered.emit()
```

`scenes/app/app.tscn` is trivial greybox: `App (Node)` → `StateHost (Node)` + `DebugOverlay (CanvasLayer)`. **M4 mounts its P-toggle tabbed menu under `DebugOverlay`** (one instance, all three states). **M1 fills `main_menu.tscn`**, **M2 fills `hub.tscn`** and refactors `main_game.tscn` to dive-only, **M3 adds the Shop inside the Hub**.

> Why not `get_tree().change_scene_to_file()` (candidate A)? It is one line per transition and needs no root node — but it **frees the ENTIRE tree including any debug overlay on every swap**, so the P-menu would have to be re-instanced per scene (3 copies, 3 wirings) or moved to an autoload `CanvasLayer`. It also can't hold a stable mount for a future persistent HUD/Cyrus presence (every later meta system hangs off the Hub, Breakdown §1). The `App`-node approach is marginally more scaffolding now for a much cleaner seam for M2+ — and it keeps the autoloads (which already survive any scene change) plus a stable overlay. **Recommend (B); OQ-1 lets Phase-3 confirm.**

### B.2 The economy surface on `GameState` — `purchase()` + `owned_items` (off/neutral)

```gdscript
# --- META-STATE additions (persist; serialized by SaveManager) ----------------
# (joins the meta block at game_state.gd:32-49, beside unlocked_recipes)
## M1.6 (M0): owned shop purchases — a META inventory of catalog ids (like
## unlocked_recipes). Persists across runs; reset on wipe_meta(). Default empty =
## "owns nothing" = today's behaviour (no shop existed). M3 fills the catalog + the
## buy bodies; whether this PERSISTS (save v3->v4) vs. is consumable-only is OQ-3.
var owned_items: Array[StringName] = []

## M1.6 (M0): the buy-economy entry point. Debits `price` Money through the canonical
## ledger (add_currency, so Telemetry sees ONE currency_changed(&"money", -price, &"shop")),
## records the owned id, persists meta, and signals. Returns true iff the purchase went
## through (enough money). NEUTRAL until M3 calls it from the Shop UI — declaring it
## changes nothing. The run/meta boundary holds: purchases are pure meta (no run-state).
func purchase(item_id: StringName, price: int) -> bool:
    if price < 0:
        return false
    if money < price:
        EventBus.purchase_failed.emit(item_id, price, money)   # "can't afford" (Shop UI reads it)
        return false
    add_currency(&"money", -price, &"shop")   # ONE ledger event; mirrors sell_banked_junk's credit
    owned_items.append(item_id)
    SaveManager.save_meta(0)                   # atomic write + .bak, slot 0 (same path as every meta op)
    EventBus.item_purchased.emit(item_id, price, money)   # money = post-debit balance
    return true

## M1.6 (M0): does the player own this purchase? Pure read (M3's effects gate on it).
func owns(item_id: StringName) -> bool:
    return owned_items.has(item_id)
```

**Save-bridge additions** (in `to_meta_dict`, `:547-563` / `from_meta_dict`, `:565-581`) — owned_items persisted as flat strings (objects-OFF), defaulting `[]`:

```gdscript
# to_meta_dict() — append beside "unlocked_recipes":
    var owned: Array[String] = []
    for id in owned_items:
        owned.append(String(id))
    # ... "owned_items": owned,   (only if OQ-3 = persistent → with the v3->v4 bump)

# from_meta_dict() — append:
    var owned_in: Array[StringName] = []
    for raw in d.get("owned_items", []):
        owned_in.append(StringName(raw))
    owned_items = owned_in
```

**`wipe_meta()` addition** (`:410-431`, beside the typed-empty resets):

```gdscript
    var empty_owned: Array[StringName] = []
    owned_items = empty_owned   # owned purchases are meta → a wipe clears them
```

> **Scope:** if OQ-3 resolves **consumable-only / non-persistent**, the `to_meta_dict`/`from_meta_dict`/migration lines are NOT added (no save bump) and `owned_items` is just an in-memory meta scratch the Shop reads/clears — `purchase()` still works, it just doesn't survive a reload. If **persistent**, M3 adds the save-bridge lines + the v3→v4 bump (A.4) + the fixture. **M0 declares the field + `purchase()`/`owns()` either way** (neutral); the persist wiring is M3's, gated on the Director call.

### B.3 The new `EventBus` signals (append one M1.6 block after the L2 block, `event_bus.gd:182`)

```gdscript
# === M1.6 signals (sole event_bus.gd edit this milestone, owner = M0) =========
# Pre-declared up front so M1/M2/M3/M4 only EMIT/CONNECT — they never edit this file
# (the M1.1 pre-declare rule, M1.6 Breakdown §6/§10). These are FLOW + ECONOMY events
# that fire OUTSIDE a dive (Menu/Hub), so — unlike the dive telemetry rows above — they
# carry NO run_t_ms/depth (there's no run clock in the Menu/Hub). Primitives only.
# run_ended (line 10) is UNCHANGED — the router OBSERVES it to auto-return to the Hub.

# --- App flow / scene router (M2 emits dive_requested; App emits the rest) -----
## The player chose to depart on a dive (Hub departure-portal interact). The App router
## swaps in the dive scene. band_id = which band to dive (M1.6 has the single &"near").
signal dive_requested(band_id: StringName)
## The player/flow asked to return to the Hub WITHOUT a dive resolving (e.g. a Main-Menu
## "back", or a future explicit hub-return). Router-driven; distinct from returned_to_hub.
signal return_to_hub_requested(reason: StringName)
## The Hub scene is now live in the tree (fired by the router AFTER the swap, so HUD/
## audio/Telemetry observers read a settled Hub). Fires on every hub entry (from menu OR
## after a dive). No payload — the Hub reads meta (money/banked_junk/owned_items) directly.
signal hub_entered()
## A dive resolved and the player was returned to the Hub. reason = the run_ended reason
## (&"extract"/&"death"/&"timeout") so the Hub/Shop can show the dive-outcome readout
## (the quota line + sell tally re-homed from the retired SellScreen). Fires AFTER
## run_ended settled (router defers one frame). Pairs with hub_entered on the dive path.
signal returned_to_hub(reason: StringName)

# --- Hub shop (M3 emits; the Shop UI + GameState economy drive these) ---------
## The Shop UI opened (Hub shop-interactable). Telemetry: shop-open rate (RG2). No payload.
signal shop_opened()
## The Shop UI closed (returns control to the Hub). Telemetry: shop dwell (RG2).
signal shop_closed()
## A banked-junk item was sold at the Shop → Money. value = its base_sell_value; money =
## the post-sale balance. The Shop sell path emits ONE per item sold (or M3 may emit a
## single roll-up — see OQ-4). Re-homes the SellScreen tally telemetry. Primitives only.
signal item_sold(item_id: StringName, value: int, money: int)
## A purchase succeeded: item_id bought for `price`; money = post-debit balance. Emitted
## by GameState.purchase() (B.2). RG2 reads buy rate / spend. Primitives only.
signal item_purchased(item_id: StringName, price: int, money: int)
## A purchase was attempted but the player couldn't afford it. money = current balance.
## Lets the Shop UI show "can't afford" without GameState knowing about the UI. Inert
## until M3's Shop calls purchase() on an unaffordable item.
signal purchase_failed(item_id: StringName, price: int, money: int)
```

> **Arity rationale (per house style, A.3):** flow signals carry **no** `run_t_ms`/`depth` (they fire with no active run). Economy signals carry the transaction primitives + the **post-transaction Money balance** (mirroring how `currency_changed` already carries the delta and consumers read `GameState.money`, and how SellScreen reads live `GameState.money`). `item_sold` reuses the existing `GameState.sell_banked_junk()` path (M3 absorbs SellScreen's `sell_banked_junk` call) — the signal is the *additive telemetry/UI* row; the money mutation still flows through `add_currency`/`currency_changed` as today. The provisional set is **9 signals**; OQ-4 may trim `item_sold` to a roll-up and OQ-5 may drop `return_to_hub_requested` if M1.6 only ever auto-returns. Final set frozen in Resolved Decisions after Phase 3.

### B.4 `project.godot` edits — the entry swap + the P action (M0 owns ALL `[application]`/`[input]` edits)

```ini
# [application] — repoint the app entry to the new persistent router root (B.1).
# main_game.tscn becomes the DIVE-ONLY scene the router loads (M2 refactors it).
# CI-safe: ci_smoke_test runs as --script (entry-agnostic); test_main_game_loop loads
# main_game.tscn by its own path constant, not run/main_scene (A.6). No test edit needed.
run/main_scene="res://scenes/app/app.tscn"

# [input] — ONE new action: debug_menu_toggle = P (physical keycode 80). Mirrors the
# debug_kill shape (project.godot:144-148). M4 reads it to toggle the tabbed debug
# overlay (mounted on App.DebugOverlay, available in Menu/Hub/Dive). M0 is the sole
# [input] editor this milestone — M4 only READS this action.
debug_menu_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":80,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

> **Determinism note:** neither edit touches generation. `run/main_scene` only changes what boots; the P action is an unread input until M4. The all-off `fingerprint()` is `e943ac9c8bc1` regardless (it's computed over the generated band, which is unchanged), and the 89-knob count is untouched (no `RunConfig` field added). M0 adds NO knob.

### B.5 The save-schema scaffold (v3→v4 migration skeleton — lands in M3 IF persistent)

Provided here so M3's author lands it without re-deriving it (A.4). **Not M0's edit** (M0 must not bump the version); the scaffold is the contract M3 fills if OQ-3 = persistent:

```gdscript
# save_manager.gd — IF OQ-3 = persistent purchases (M3's edit, NOT M0's):
const META_SCHEMA_VERSION := 4   # was 3

# in _migrate_meta()'s match (after the `2:` v2->v3 step, save_manager.gd:88-95):
    3:
        # v3 -> v4 (M1.6 M3): owned_items added (the shop). Old saves predate the shop
        # → default to an empty id list so from_meta_dict reads "owns nothing".
        if not data.has("owned_items"):
            data["owned_items"] = []
# + a tests/fixtures/meta_v3.sav fixture so the v3->v4 migration is regression-tested
#   (mirrors the existing v2 fixture for the v2->v3 step). M3's QA sub-task owns this.
```

---

## (c) Open Questions

**OQ-1 — Router mechanism: persistent `App` node (recommended) vs. `change_scene_to_file` vs. an autoload scene-state? (architecture; recommend, Phase-3 confirm).** Three shapes, weighed against *where the P-overlay must live so it's available in all three states* (the load-bearing constraint, Breakdown §7):
- **(A) `get_tree().change_scene_to_file()` between three top-level scenes.** Simplest (one line per transition, no root node). BUT every transition **frees the whole tree including any debug overlay** → the P-menu must be re-instanced per scene (3 copies/wirings) or pushed to an autoload `CanvasLayer`. The Hub holds no run-state so rebuilding it from meta on each return is fine (Breakdown §7 confirms this). No stable mount for a future persistent HUD/Cyrus.
- **(B) a persistent root `App` node that swaps child scenes (drawn in B.1).** One stable mount for the P-overlay (and future persistent HUD) available in all three states; the router owns the transitions, scenes only emit intent (decoupled like SellScreen today). Slightly more scaffolding (one `Node` + `CanvasLayer`). Autoloads survive either way.
- **(C) an autoload "SceneRouter" that holds the current scene + a `CanvasLayer`.** Like (B) but the router is a 7th autoload. CLAUDE.md says "keep autoloads few and disciplined" — adding one for routing is heavier than a root scene-node, and the overlay-mount benefit is identical to (B).

  **Recommendation: (B) the persistent `App` root node.** It gives the P-overlay one home, keeps the autoload count at 6, and gives M2+ a stable seam for every later meta surface that hangs off the Hub. Trade-off: a little more wiring than (A). **Phase-3 confirms; if (A) is chosen instead, the P-overlay moves to an autoload `CanvasLayer` and B.1's router collapses to `get_tree().change_scene_to_file()` calls in the scenes.**

**OQ-2 — Where exactly does the P-debug overlay MOUNT, and does it pause the dive while open? (recommend, Phase-3/M4 confirm).** With mechanism (B), the overlay mounts on `App.DebugOverlay` (a `CanvasLayer` sibling of the state host) — one instance, all three states. Two sub-questions: **(i)** does M4's menu set `process_mode = ALWAYS` + pause the tree while open (so the config rail can be read mid-dive without the world ticking)? Recommend **yes in-dive (pause), no-op in Menu/Hub** (nothing to pause there) — mirrors how SellScreen pauses (`sell_screen.gd:79,129`). **(ii)** Is the overlay even visible/active in the Main Menu, or only Hub+Dive? The Director may want the debug menu reachable from the very first screen (to set a config before the first dive). Recommend **available in all three** (the breakdown says "available in Menu/Hub/Dive," M4 row). **This is M4's detail; M0 only provides the mount + the P action — flagged so M4's design resolves the pause/visibility behaviour.**

**OQ-3 — Do purchases PERSIST (save v3→v4 bump) or are they consumable-only (no bump)? (Director fun/scope call — the one save-schema decision).** Breakdown §2/§7 surfaces this as a deliberate, Director-ratified call:
- **(a) persistent owned upgrades** (recommended minimal: 2–3 greybox upgrades owned across runs) — exercises the real meta-spend loop the Hub exists to grow into (every later meta system hangs off it, §1). **Cost: a META v3→v4 bump + migration step + `meta_v3.sav` fixture (A.4/B.5), landed in M3.**
- **(b) consumable-only** (one-shot items spent within a run, non-persistent) — no save bump; `owned_items` stays an in-memory scratch. Cheaper, but the Hub's spend loop teaches nothing durable and the meta layer the milestone is *for* (§1) is unexercised.

  **Recommendation: (a) persistent, accept the v3→v4 bump** — the whole point of M1.6's surface is the meta loop (sell → bank Money → spend on durable upgrades), and the bump is mechanical (three migration-step precedents already exist, A.4). **NEEDS DIRECTOR REVIEW (fun/scope):** *"Should the M1.6 greybox shop sell durable upgrades you keep across runs (→ a deliberate save v3→v4 bump + a 2–3-item greybox catalog), or only consumables spent within a run (no save change)? Recommend persistent — it's the meta loop the Hub is built for, and the bump is routine."* M0 declares `purchase()`/`owned_items` neutrally either way; the persist wiring + bump are M3's, gated on this verdict.

**OQ-4 — `item_sold` per-item vs. a single roll-up signal? (recommend, Phase-3/M3 confirm).** The retired SellScreen sells the WHOLE bank in one `sell_banked_junk()` call and itemizes from the returned breakdown (`sell_screen.gd:135,191-208`). The Shop (M3) absorbs that path. Two telemetry shapes: **(a)** emit `item_sold(item_id, value, money)` once per item (rich RG2 per-item analysis, but N events per sale); **(b)** a single `bank_sold(item_count, total_value, money)` roll-up (one event, matches the one `sell_banked_junk` call). **Recommendation: declare `item_sold` per-item (a)** — RG2 may want per-item value distributions, and the existing `haul_banked(total)` (`event_bus.gd:14`) already carries the roll-up total, so a per-item row is the additive complement. M3 emits it in the breakdown loop. **If M3's design prefers the roll-up, swap the arity here — M0 freezes the choice in Resolved Decisions.**

**OQ-5 — Dive→Hub return: auto on `run_ended`, or an explicit player "leave the results screen" beat? And is `return_to_hub_requested` needed at all? (recommend, Phase-3/M2+M3 confirm).** Today the loop auto-loops on SellScreen Continue. M1.6 routes the dive end back to the Hub. Two shapes: **(a)** the router auto-returns on `run_ended` (drawn in B.1, `_on_run_ended` → deferred return) — simplest, the dive-outcome readout then lives in the Hub/Shop (the re-homed quota line, via `returned_to_hub(reason)`); **(b)** a results overlay in the dive shows the tally first, and a Continue press emits `return_to_hub_requested` to route home. **Recommendation: (a) auto-return**, with the outcome readout re-homed to the Hub-return/Shop beat (matches "walk to shop = see your haul = sell," Breakdown §7). This makes `return_to_hub_requested` **possibly unused in M1.6** (only `returned_to_hub` fires on the dive path). I declared `return_to_hub_requested` anyway (free, and a Main-Menu "back to hub" or a future explicit-leave wants it) — **if Phase-3 confirms M1.6 only ever auto-returns, drop it and the signal set is 8 not 9.** Flag to M2 (who owns the dive-end seam) + M3 (who owns the outcome readout).

**OQ-6 — How does the Hub survive a dive teardown given it holds no run-state? (recommend, confirm — resolved on merit).** With mechanism (B) the Hub is **freed on dive entry and re-instanced on return** (`_goto` queue_frees the old state, instances the new). The Hub holds **no run-state** (Breakdown §2/§7: "the Hub reads meta only") — it reads `GameState.money`/`banked_junk`/`owned_items` (all meta, all persisted/in-memory across the dive) on its `_ready()`/`hub_entered`. So **rebuilding it from meta each return is correct and cheap** (greybox room + player spawn + portal + shop interactable — no persistent Hub state to preserve). The player node is re-spawned in the Hub fresh each entry (it's a dive/hub-local entity, not meta). **No open question of correctness — stated here because a fresh-eyes reviewer will ask "doesn't tearing down the Hub lose something?" Answer: no, the Hub is a pure view over meta-state.** (If mechanism (A) is chosen, identical answer — `change_scene_to_file` to the Hub rebuilds it from meta too.)

**OQ-7 — CI smoke-test + entry-scene assumptions: confirmed clean, but does M0 add a router smoke check? (recommend, confirm).** A.6 verified `ci_smoke_test.gd` is entry-agnostic and `test_main_game_loop.tscn` loads `main_game.tscn` by an explicit path constant — **the `run/main_scene` swap breaks neither, no M0 test edit is required for the swap.** Open: should M0 add a tiny **router boot test** (instance `app.tscn` headless, assert it boots to the Menu state without error)? Recommend **a minimal one** (mirrors `test_main_game_loop.tscn`'s pattern — load the scene, assert no error, assert `_current_state == &"menu"`) so the router has a green smoke gate before Wave 2 builds on it. **It's cheap and M0 owns the router file, so M0 owns its smoke test.** Phase-3 confirms whether it's worth the one file; recommend yes.

**OQ-8 — Does M0 itself edit `project.godot` for the entry swap, given M2 refactors `main_game.tscn` to dive-only in a LATER wave? (sequencing; recommend, confirm).** The swap repoints `run/main_scene` to `app.tscn`, and `app.tscn` loads `main_menu.tscn`/`hub.tscn` which **don't exist until M1/M2 land**. If M0 lands the swap in Wave 1, booting the project between M0 and M1/M2 would fail to find those scenes. Two options: **(a)** M0 lands the `project.godot` swap + `app.tscn` with **greybox placeholder** menu/hub scenes (tiny `Control`s that the M1/M2 scenes replace) so the project always boots; **(b)** M0 declares the swap in *this design* but the actual `run/main_scene` edit lands with M1 (the first real scene). **Recommendation: (a) M0 ships `app.tscn` + the swap + minimal greybox placeholder `main_menu.tscn`/`hub.tscn` stubs** (a `Label` + a button that emits `dive_requested`), so the project boots end-to-end after Wave 1 and M1/M2 *replace* the stubs rather than create-from-nothing. This keeps M0 a true single-writer of `project.godot` (M1/M2 never touch `[application]`) and gives Wave-2 a bootable baseline. Trade-off: M0 writes throwaway stub scenes M1/M2 overwrite — acceptable (the breakdown's greybox norm). **Flag to M1/M2: you REPLACE the stub `main_menu.tscn`/`hub.tscn` M0 lands, you don't create them.** Phase-3 confirms the stub-vs-defer split.

---

## Carried contracts (stated, not violated)

- **All-off `RunConfig` default = permanent baseline** (fingerprint `e943ac9c8bc1`): M0 adds **NO `RunConfig` lever knob** and touches **no generation** — the fingerprint stays byte-identical and the **89-knob count holds** (`has_full_coverage()` + `test_run_config`/`test_config_menu` counts stay 89; M4 regroups into tabs without adding/removing). None of M0's additions (router, economy, signals, P action, entry swap) feed `fingerprint()` — they are flow/meta/UI/input. (B.4 note)
- **Run-state vs meta-state boundary** (`game_state.gd`): `money`/`owned_items` are **meta** (persisted, wiped on `wipe_meta`); the in-dive haul stays run-state banked at a gate as today. `purchase()` is a pure meta op (debit Money via `add_currency`, append `owned_items`, save) — no run-state touched. The Hub reads meta only (OQ-6).
- **Save schema:** a v3→v4 bump happens **only if** OQ-3 = persistent purchases, and it lands in **M3**, not M0 (atomic-write/`.bak` unchanged, one stepwise migration step + a `meta_v3.sav` fixture — A.4/B.5). M0 must NOT bump `META_SCHEMA_VERSION`.
- **`run_ended` arity LOCKED**; telemetry/flow signals are **additive** (new signals only — M0 pre-declares all of them up front; the router OBSERVES `run_ended`, never changes it). Config-marked telemetry continues; RG2 compares M1.6 cohorts to the M1.0–M1.5 baselines.
- **Single-writer:** M0 is the **sole editor of `project.godot` (`[application]`/`[input]`), `event_bus.gd`, the economy block of `game_state.gd`, and the new `scenes/app/` router file** this milestone. M1/M2/M3/M4 only read the router API, emit pre-declared signals, call the economy surface, and read the P action. (Breakdown §4, §10)
- **`run/main_scene` swap is CI-safe** — `ci_smoke_test.gd` is entry-agnostic (runs as `--script`); `test_main_game_loop.tscn` loads the dive by an explicit path constant. No M0 test edit for the swap. (A.6)

---

## Resolved Decisions (Phase 3)

_Fresh-eyes pass, 2026-06-26. Resolver did NOT author this design. Every Open Question is resolved below on technical/design merit, cross-checked against the as-built `event_bus.gd`/`game_state.gd`/`save_manager.gd`/`ci_smoke_test.gd`/`project.godot` and against the four sibling M1.6 designs (`M1_main_menu.md`, `M2_hub_scene_flow.md`, `M3_hub_shop_economy.md`, `M4_debug_menu_rework.md`) so the M0 contract MATCHES what the consuming tasks build against. Items needing the Director's vision/fun/tone/scope judgment are tagged **[NEEDS DIRECTOR REVIEW]**; everything else is FROZEN. The router mechanism, the economy surface, the exact signal set + arities, the entry-swap + P-action edits, and the save-scaffold ownership are locked here._

### Verification of the design's premises (all CONFIRMED against the repo)

- **CI is entry-agnostic** — `tools/ci_smoke_test.gd` `extends SceneTree`, runs as `--script`, only checks the six autoloads + RNG determinism + a save round-trip + a `_migrate_meta` v0→v3 step + one `JunkItem` load (`:10-65`). It never reads `run/main_scene` or instantiates `main_game.tscn`. **The `run/main_scene` swap is CI-safe with zero M0 test edits.** ✅ (OQ-7)
- **P (physical keycode 80) is unused** — grep of the `[input]` block confirms no `physical_keycode":80`; `debug_kill`=75 (`project.godot:144-148`) is the exact shape to mirror. ✅
- **The economy surface fits the existing meta block** — `add_currency(&"money", delta, source)` (`:300-306`) is the single ledger mutation + `currency_changed` emit; `wipe_meta()` (`:410-431`) resets every typed meta field; `to_meta_dict`/`from_meta_dict` (`:547-581`) persist `unlocked_recipes` as a flat StringName array — `owned_items` clones that pattern exactly. ✅
- **Save chain is a clean 3-precedent stepwise migration** (`save_manager.gd:75-98`, `META_SCHEMA_VERSION=3`); a v3→v4 step is mechanical. ✅

---

### RD-1 — Router mechanism: **persistent root `App` node (option B). FROZEN.** (resolves OQ-1, OQ-6)

Lock **(B) the persistent root `App` node** (`scenes/app/app.tscn` + `app.gd`) as drawn in B.1. Reasoning held up under fresh eyes:
- The **load-bearing constraint is the P-debug overlay mount**: M4 (`M4_debug_menu_rework.md:42, 265`) mounts the tabbed config overlay once and toggles it in **all three** states with `PROCESS_MODE_ALWAYS`. A persistent `App.DebugOverlay` `CanvasLayer` gives it ONE home; `change_scene_to_file` (option A) frees the whole tree per swap → the overlay must be re-instanced/re-wired 3× or pushed to a 7th autoload-adjacent layer. (B) is strictly cleaner here.
- (C) a 7th "SceneRouter" autoload is rejected on CLAUDE.md's "keep autoloads few and disciplined" — a root scene-node gives the identical overlay benefit at autoload-count 6.
- **All four sibling designs were written mechanism-agnostically** — M1/M2 route every transition through the M0 router API / `EventBus` signals, never calling `get_tree().change_scene_*` themselves (`M2_hub_scene_flow.md:36, 91, 246`; `M1_main_menu.md:114-122`). So (B) is transparent to them; M0 ships the mechanism and they bind to the signals. No sibling-design rework is needed by this lock.
- **Tree shape FROZEN:** `App (Node)` → `StateHost (Node)` + `DebugOverlay (CanvasLayer)`. `_goto(path, state)` `queue_free()`s the current `StateHost` child and instances the new one (load by PATH, never holding a scene ref across a swap). Boots to `MAIN_MENU_PATH` in `_ready()`.
- **OQ-6 (Hub teardown) resolved on merit:** the Hub holds NO run-state (Breakdown §2/§7; `M2_hub_scene_flow.md:287` re-instances fresh every entry). Freeing it on dive-entry and rebuilding it from meta (`GameState.money`/`banked_junk`/`owned_items`) on `hub_entered` is correct and cheap. Confirmed consistent with M2's RD ("re-instance the hub fresh on every entry"). The player node is a hub/dive-local entity, re-spawned fresh per entry — never meta. **Nothing is lost by tearing down the Hub: it is a pure view over meta-state.**

### RD-2 — Final `EventBus` signal set: **8 signals, arities frozen.** (resolves OQ-4, OQ-5; reconciles M3)

The provisional 9-signal set is trimmed/reconciled to **8**, cross-checked against M3's actual emitters so M0's pre-declaration and M3's calls AGREE (M0 is the single writer; a mismatch would force M3 to edit `event_bus.gd`, which is forbidden). Final set, appended as the M1.6 block after `event_bus.gd:182`:

| # | signal | arity (FROZEN) | emitter | notes |
|---|---|---|---|---|
| 1 | `dive_requested` | `(band_id: StringName)` | M2 portal | router swaps in dive. M1.6 single band `&"near"`. |
| 2 | `returned_to_hub` | `(reason: StringName)` | App router | reason = `run_ended` reason; the Hub-return beat reads it for the quota/wipe readout (M2 RD-OQ9). |
| 3 | `hub_entered` | `()` | App router | fired AFTER the hub is in the tree (menu-entry OR dive-return); Hub reads meta directly, no payload. |
| 4 | `shop_opened` | `()` | M3 shop | RG2 shop-open rate. |
| 5 | `shop_closed` | `()` | M3 shop | RG2 shop dwell. |
| 6 | `item_sold` | `(item_count: int, total_value: int, money: int)` | M3 shop | **roll-up, NOT per-item** — see OQ-4 below. money = post-sale balance. |
| 7 | `item_purchased` | `(item_id: StringName, price: int, money: int)` | `GameState.purchase()` | money = post-debit balance. **3-arg** — see reconciliation note. |
| 8 | `purchase_failed` | `(item_id: StringName, price: int, money: int)` | `GameState.purchase()` | "can't afford" / "already owned"; money = current balance. |

- **OQ-5 (dive→hub return) RESOLVED: auto-return on `run_ended`; DROP `return_to_hub_requested`.** The set goes 9→8. The router auto-returns (B.1 `_on_run_ended` → deferred `_return_after_dive`), and the dive-outcome readout (quota line + sell tally) re-homes to the Hub-return beat via `returned_to_hub(reason)` — consistent with M2's RD-OQ9 ("the Hub-return beat owns the quota readout + the wipe", `M2_hub_scene_flow.md:290`) and the Director-locked "walk to shop = see your haul = sell". M1.6 has **no** code path that returns to the Hub WITHOUT a dive resolving (the Main Menu routes Menu→Hub via `hub_entered`, not a "back to hub"), so `return_to_hub_requested` would be a dead declaration. Per the L0 house rule, declare only what's emitted — dropped. (If a future "explicit leave the dive" beat appears, re-add it then; it's free to add later.)
- **OQ-4 (`item_sold` per-item vs roll-up) RESOLVED: roll-up `(item_count, total_value, money)`.** Decisive technical reason: **M3 is the emitter and M3's design emits a roll-up** (`M3_hub_shop_economy.md:157` "fire `EventBus.item_sold(total)`"), because the absorbed `GameState.sell_banked_junk()` sells the WHOLE bank in ONE call returning a breakdown (`game_state.gd:324-352`) and credits via ONE `add_currency`. A per-item signal would force M3 to loop and emit N times against a single-call API — friction with no payoff, since the existing `haul_banked(total_value)` (`event_bus.gd:15`) already carries the total and per-item value lives in the `sell_banked_junk` return breakdown M3 holds locally. **Lock the roll-up but widen M3's proposed 1-arg form to `(item_count, total_value, money)`** so RG2 gets count + post-sale balance for free (M3 updates its emit to the 3-arg form — a pure call-site change, no `event_bus.gd` edit). Per-item value distributions, if RG2 wants them, come from the desktop JSONL the breakdown already feeds, not this signal.
- **`item_purchased` arity reconciliation (M0 vs M3): lock M0's 3-arg `(item_id, price, money)`.** M3's draft emits 2-arg `item_purchased(item.id, item.cost)` (`M3_hub_shop_economy.md:89`). Since `GameState.purchase()` knows `money` post-debit for free and post-transaction balance is the house convention (mirrors how consumers read `GameState.money` after `currency_changed`), the 3-arg form is strictly richer. **M3 updates its emit to the 3-arg form** (call-site only).
- House-style compliance CONFIRMED: all 8 carry **primitives only** (no Node refs — the router resolves by path); flow signals (1-3) carry **no `run_t_ms`/`depth`** (they fire outside a dive with no run clock); `run_ended` arity is **untouched** — the router OBSERVES it.

### RD-3 — Economy surface on `GameState`: `purchase()` / `owns()` / `owned_items` at neutral defaults. (reconciles with M3's body)

- **`owned_items: Array[StringName] = []`** added to the meta block (`game_state.gd:32-49`, beside `unlocked_recipes`), reset to a freshly-typed empty array in `wipe_meta()` (`:410-431`). FROZEN.
- **`owns(item_id: StringName) -> bool`** — pure read. FROZEN.
- **`purchase(...)` signature reconciliation — RESOLVED: M0 declares the PRIMITIVE form `purchase(item_id: StringName, price: int) -> bool`.** M3's draft wrote `purchase(item: ShopItem)` (`M3_hub_shop_economy.md:73`), but **`ShopItem` is a class M3 authors — it does not exist when M0 lands, so M0 literally cannot declare a `ShopItem`-typed signature without a parse error** (and M0 is the single-writer of the economy surface, by contract). Therefore:
  - **M0 ships the primitive `purchase(item_id, price)` body** (B.2): affordability guard → `add_currency(&"money", -price, &"shop")` (one ledger event) → `owned_items.append(item_id)` → `SaveManager.save_meta(0)` → emit `item_purchased(item_id, price, money)`; on shortfall emit `purchase_failed(...)` + return false. Neutral until M3 calls it.
  - **M3 calls `GameState.purchase(item.id, item.cost)`** from its Shop, and does its `ShopItem`-specific guards (the `persistent` + already-owned check, `M3_hub_shop_economy.md:78-80`) **in the Shop UI before calling** — purchase()'s own already-owned guard is the belt-and-braces (recommend M0's `purchase()` also early-return `purchase_failed` if `owns(item_id)` is already true, so a double-buy is impossible regardless of the UI). This keeps `GameState` free of any `ShopItem`/UI dependency (the run/meta boundary + the data-as-Resources separation hold). **M3 updates its design's `purchase(item)` call to `purchase(item.id, item.cost)`** — flagged to M3 below.
- **Persistence of `owned_items` is gated on RD-4** (the save bump). `purchase()` works either way; only the `to_meta_dict`/`from_meta_dict` lines + the bump are conditional.

### RD-4 — Save schema: **owned_items persists → META v3→v4 bump, landed in M3 (NOT M0).** [NEEDS DIRECTOR REVIEW — fun/scope]

This is the one genuine Director call (vision/scope), surfaced not self-resolved.

**Recommendation (strong): persistent owned upgrades — accept the v3→v4 bump.** Both M0 (OQ-3) and M3 (OQ-1) independently recommend persistent; M3 already specifies the 3-greybox-upgrade catalog (`effect_kind=&"none"` stub spends), the v3→v4 migration step, the `gen_meta_v3_fixture.gd` + `meta_v3.sav` fixture, and the `test_save_migration.gd` `_run_v3()` case (`M3_hub_shop_economy.md:144, 178-198`). Rationale: M1.6's entire premise is to start the meta-spend loop the Hub exists to grow (sell → bank Money → spend on durable upgrades); a consumable-only shop spends Money but leaves no durable meta, proving far less and dodging the save-discipline work every later upgrade needs anyway. The bump is mechanical (3 in-repo precedents).

> **Director question:** *"Should the M1.6 greybox shop sell durable upgrades you keep across runs (→ a deliberate, irreversible META v3→v4 save bump + migration + a `meta_v3.sav` QA fixture, plus a 2–3-item greybox catalog), or only consumables spent within a run (no save change)? Both design passes recommend persistent — it's the meta loop the Hub is built for and the bump is routine; the only cost is irreversible schema debt for a greybox feature that could later be re-cut."*

**M0's scope is fixed regardless of the verdict:** M0 declares `owned_items` + `purchase()`/`owns()` at neutral defaults and **scaffolds** the v3→v4 migration shape in this doc (A.4/B.5). **M0 MUST NOT bump `META_SCHEMA_VERSION`** — the bump + migration step + fixture land in **M3** (where the persist decision is ratified), exactly as M3's design already lays out. If the Director picks consumable-only, no bump ever happens and `owned_items` stays in-memory meta scratch (no `to_meta_dict` lines). The two designs are already consistent on this split. FROZEN: bump-ownership = M3, not M0.

### RD-5 — `project.godot` edits (M0 owns ALL `[application]`/`[input]` edits this milestone). FROZEN.

- **`run/main_scene="res://scenes/app/app.tscn"`** (was `main_game.tscn`). CI-safe (verified). `main_game.tscn` becomes the dive-only scene M2 refactors.
- **One new input action `debug_menu_toggle` = P (physical keycode 80)**, mirroring `debug_kill`'s shape (`project.godot:144-148`): single `InputEventKey`, `physical_keycode:80`, `deadzone:0.5`. M4 only READS it (`M4_debug_menu_rework.md:268, 281-282` asserts presence with a soft `push_warning`). M0 is the sole `[input]` editor — confirmed no other M1.6 task adds an action.
- **Determinism preserved:** neither edit feeds `fingerprint()`; M0 adds **no `RunConfig` knob**. All-off fp stays `e943ac9c8bc1`; the **89-knob count holds** (M4 regroups into tabs, never adds/removes). FROZEN.

### RD-6 — P-debug overlay mount + pause behaviour. (resolves OQ-2; defers detail to M4)

- **Mount: `App.DebugOverlay` `CanvasLayer`** — one instance, all three states (RD-1). M0 ships the empty mount + the P action; M4 fills it. FROZEN at the M0 seam.
- **Pause + visibility are M4's detail, not M0's** — but M0's resolution records the consistent target: M4 sets the overlay `PROCESS_MODE_ALWAYS` and pauses the tree only **in-dive** while open (no-op in Menu/Hub — nothing to tick), and the overlay is reachable in **all three** states (Breakdown M4 row; `M4_debug_menu_rework.md:265`). Consistent across docs; **no Director call needed** (the earlier "available in Main Menu?" flag is resolved: yes, available everywhere, per the breakdown).

### RD-7 — Stub scenes: **YES — M0 ships greybox `main_menu.tscn` + `hub.tscn` stubs so the project stays bootable after Wave 1.** (resolves OQ-8) [minor scope — recommend, Director may veto]

**Resolved: ship the stubs.** `app.tscn`'s `_goto(MAIN_MENU_PATH, ...)` loads `res://scenes/menu/main_menu.tscn` at boot, and the dive path loads `res://scenes/hub/hub.tscn` — neither exists until M1/M2 land in Wave 2. If M0 repoints `run/main_scene` without stubs, the project fails to boot (and the RG verify scenes that instance the dive still work, but a plain launch is broken) between the M0 merge and the M1/M2 merges. Two-line throwaway greybox stubs (a `Label` + a button that emits `dive_requested` for the hub stub; a `Label` + a button that emits `hub_entered`/routes to hub for the menu stub) keep `main` bootable end-to-end after Wave 1, which is the milestone hygiene norm. **M1 REPLACES `main_menu.tscn`; M2 REPLACES `hub.tscn`** — they overwrite the stubs, not create-from-nothing. This is flagged to M1/M2 below. Trade-off: M0 writes ~2 throwaway scenes — acceptable and cheap. (If the Director prefers a clean "M0 lands the swap but the entry edit defers to M1", that's option (b); the stub path is recommended because it keeps `main` always-green-and-bootable, the M1.1+ norm.)

### RD-8 — Router smoke test: **YES, ship a minimal one.** (resolves OQ-7's second half)

M0 owns the new router file, so M0 owns its smoke gate. Add a tiny headless test (a `.tscn` driven scene per the memory rule "verify/knob tests run as SCENES, not `--script`") that instances `app.tscn`, asserts it boots without error, and asserts `_current_state == &"menu"`. Cheap, gives Wave 2 a green router baseline. The existing `ci_smoke_test.gd` stays untouched (it's the autoload/save/RNG gate, entry-agnostic). FROZEN.

---

### Cross-task flags folded back (for the orchestrator / Phase-4 lock)

- **→ M3:** update three call-sites to match M0's locked surface (no `event_bus.gd`/`game_state.gd` economy-surface edits — those are M0's): (1) call `GameState.purchase(item.id, item.cost)` (primitive args), not `purchase(item)`; (2) emit `item_purchased(item.id, item.cost, GameState.money)` (3-arg); (3) emit `item_sold(item_count, total_value, GameState.money)` (3-arg roll-up). M3 still owns the v3→v4 bump + fixture (RD-4) and the `ShopItem`/already-owned UI guards.
- **→ M1 / M2:** you REPLACE the stub `main_menu.tscn` (M1) / `hub.tscn` (M2) that M0 lands (RD-7); you do not create them from nothing. Route all transitions through the M0 signals (`dive_requested` / `returned_to_hub` / `hub_entered`), never `get_tree().change_scene_*`.
- **→ M2:** `return_to_hub_requested` is DROPPED (RD-2/OQ-5) — the dive→hub path is auto-return on `run_ended` (router-driven) + the Hub-return beat owns the quota/wipe readout via `returned_to_hub(reason)`, matching M2's RD-OQ9.
- **→ M4:** mount under `App.DebugOverlay`; you own the pause/visibility detail (RD-6). The web "Export telemetry" re-home (M2 OQ-7 / M3 R6) is NOT an M0 concern — M0 declares no signal for it; the orchestrator picks its final home (recommended: the M4 P-menu, available in all three states).

### Director review queue (do NOT proceed without a verdict)

1. **RD-4 — persistent purchases → META v3→v4 save bump (fun/scope).** Recommend **persistent**; both design passes concur. The bump lands in M3, not M0. *(This is the single un-self-resolvable item; everything else is locked on technical merit.)*

All other Open Questions (OQ-1, OQ-2, OQ-4, OQ-5, OQ-6, OQ-7, OQ-8) are **resolved on technical/design merit** above. Design is locked pending the RD-4 verdict.
