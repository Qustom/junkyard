# M3 — Hub Shop (sell + buy) · Per-task Design (Phase 2)

**Milestone / iteration:** M1.6 (Surface & Staging), Wave 3.
**Stable id:** M3. **Role(s):** `general-purpose` (programmer — Shop UI wiring + `GameState.purchase()` body + any save bump) + `game-director-designer` (the greybox buy-catalog `.tres` data + economy intent) + `ui-ux-designer` (the Shop `Control` layout).
**BlockedBy:** **M0** (pre-declares `GameState.purchase(...)` / owned-items surface + the new EventBus signals `shop_opened` / `item_sold` / `item_purchased` + any META save-schema scaffold) and **M2** (the Hub scene mounts the shop-interactable anchor + owns the dive→hub return routing that *replaces* the auto-`SellScreen`). Sequenced **after** M2 (rebases onto the Wave-2 Hub), not parallel with it (Breakdown §4).
**Authored:** 2026-06-26 (Phase 2). Status: **draft — Open Questions unresolved** (Phase 3 fresh-eyes + Director dispositions pending).

> **The one thing M3 must prove:** the Hub has a *purpose beyond departure* — you walk to a shop, **SELL** your banked haul into Money (the loop M1.0–M1.4 closed, now re-homed from the auto-`SellScreen` into a place), and **SPEND** that Money on a minimal greybox catalog — the first time THE FAR YARD lets you *do something* with money between runs. This is the riskiest seam in M1.6: it **retires `SellScreen`**, so every responsibility that screen owns must land somewhere, and it introduces a **new economy** (buying) that may demand the milestone's only save-schema bump.

---

## (a) Research on the premise

### Why sell+buy now (the playtest / structural finding)

M1.0–M1.5 built and closed a real dive loop, but the *between-runs* beat is a debug artifact. Selling is an **auto-presented modal** (`SellScreen`, a `CanvasLayer` that pauses the tree on `run_ended` — `ui/sell/sell_screen.gd:85,129`), and there is **no spend side at all**: `GameState.money` only ever goes *up* (`sell_banked_junk` → `add_currency(&"money", …)`, `game_state.gd:342`) or resets to 0 on a roguelite wipe (`wipe_meta`, `game_state.gd:412`). Money is a **score, not a currency** — nothing reads it as a spendable resource. The GDD's whole surface premise (a life + a debt + upgrades bought across three currencies / four tracks) hangs on Money being *spendable*; M1.6's Hub is where that starts. M3 is the iteration's reason to walk anywhere in the Hub: the portal departs, the **shop is where the meta-loop lives**.

The Director ratified scope = **sell + buy** (Breakdown §2: *"The Shop sell path REPLACES the auto-`SellScreen`. … Buying is new — a minimal greybox catalog, spending `Money`."*). M3 is deliberately a **new economy this iteration** — the first meta-spend in the project.

### What M3 builds on in-repo (cited)

**The sell logic is already a clean, reusable, UI-free method — REUSE it verbatim.** `GameState.sell_banked_junk(source := &"sell") -> Array[Dictionary]` (`game_state.gd:324-352`) does the entire conversion: it walks `banked_junk`, builds a `{id, name, value}` breakdown, empties the pile, credits Money through the canonical ledger (`add_currency(&"money", total, source)` → one `currency_changed` event, `:342`), **persists synchronously** (`SaveManager.save_meta(0)`, `:345`), then runs the quota eval (`_evaluate_quota(total)`, `:350`) and returns the breakdown. `SellScreen` is **pure presentation over this** — its own header says so (`sell_screen.gd:4`: *"PURE PRESENTATION over F1's logic: it owns no Money, touches no save"*). **The Shop's SELL tab calls the exact same method** — no sell logic moves or duplicates; only the *presentation* re-homes from a `CanvasLayer` modal into the Shop `Control`.

**Money + quota meta + banked haul are all META-STATE, persisted by `to_meta_dict()` / `from_meta_dict()`** (`game_state.gd:547-581`): `money`, `salvage`, `lore`, `exposure`, `knowledge_level`, `unlocked_recipes` (`Array[StringName]`), `banked_junk` (persisted by id → rehydrated via the `JunkCatalog`, `:551-559, 584-608`), and the K2 quota pair `run_number` / `quota_target`. **Owned purchases, if persistent, are a *new* meta field** and belong in this dict — see §(b) and the save-bump skeleton. The run/meta boundary (`game_state.gd:2-9`, TDD §2/§3) is explicit: the in-dive haul is run-state banked at a gate; **Money and any owned purchases are meta** — the Hub reads meta only (Breakdown §6).

**Data-as-Resources is the catalog idiom.** Junk is authored as `.tres` against a `class_name` script (`JunkItem`, `data/junk/junk_item.gd:1`) and curated in a catalog Resource (`JunkCatalog`, `data/junk/junk_catalog.gd` — `@export var items: Array[JunkItem]` + a parallel `spawn_weights` PackedFloat32Array). The buy catalog mirrors this exactly: a `ShopItem` `class_name` Resource + a `ShopCatalog` holding `Array[ShopItem]`, authored as `.tres` (the data; `game-director-designer` owns it), loaded by the Shop UI. **The catalog is DATA, not code** (`CLAUDE.md`: "Content is data, not code"). The `.tres` ext_resource/script_class idiom is exactly `data/junk/junk_catalog.tres`.

**The save architecture supports a clean v3→v4 bump.** `SaveManager` (`save_manager.gd`) is `META_SCHEMA_VERSION = 3` (`:15`) with a stepwise `_migrate_meta` chain (`:75-98`, cases `0,1,2`), atomic write + `.bak` (`:39-54`), and a documented fixture pattern. The migration template is *in the code* (`save_manager.gd:74` comment + `test_save_migration.gd:25-28`): "add a stepwise case … commit a binary `meta_v<N>.sav` fixture … add a case here that loads it, asserts the new field's default + survival of old fields, round-trips once." The existing v2→v3 step (`save_manager.gd:88-95`) and its fixture (`tests/fixtures/gen_meta_v2_fixture.gd` + `meta_v2.sav`, asserted by `test_save_migration.gd:_run_v2()`) are the **exact pattern a v3→v4 owned-purchases bump copies**.

### FULL inventory of `SellScreen` responsibilities — and where each re-homes

This is the load-bearing risk of M3 (Breakdown §7: *"the riskiest seam in M1.6"*). `SellScreen` is auto-presented today: mounted as a sibling in `scenes/game/main_game.tscn:40`, wired in `main_game.gd:158-165` (its `continue_pressed` → `_on_continue_pressed` → wipe-if-pending + `start_new_run`; its `back_to_config_pressed` → `_on_back_to_config`; it self-presents on `EventBus.run_ended`). Retiring it means re-homing **every** one of the following. Nothing here may be silently dropped.

| # | `SellScreen` responsibility | Where it is today | Re-homes to (M3 proposal) |
|---|---|---|---|
| R1 | **Cash-out conversion** (call `sell_banked_junk` ONCE, capture money_before/after) | `sell_screen.gd:135-137` | **Shop SELL tab** — calls the identical `GameState.sell_banked_junk(&"sell")`. No logic change; presentation only. |
| R2 | **Per-item sell tally render** (one row per `{name, value}`, empty-row fallback) | `_render_rows`, `sell_screen.gd:191-208` | **Shop SELL tab** — same row render in the Shop `Control` (ui-ux owns the layout). |
| R3 | **Subtotal + live persistent Money total** (count-up flourish; label always reads live `GameState.money`) | `_animate_tally` / `_set_money_label`, `sell_screen.gd:216-260` | **Shop SELL tab** — count-up is *optional* flourish (OQ-4: keep or drop in greybox). The live Money readout becomes the Shop's persistent header (also gates the BUY tab). |
| R4 | **Quota-outcome readout (K2)** — "Quota cleared — next $X" / "QUOTA MISSED — $achieved / needed $target" from `GameState.last_quota_result()` | `_render_quota`, `sell_screen.gd:168-183` | **Shop / Hub-return beat** (Breakdown §3 M3 row: "Quota outcome readout (K2) re-homed into the Shop/Hub-return beat"). The cached result is read the same way; **where it shows** (a Hub-return banner vs a Shop line) is OQ-3. |
| R5 | **`pending_wipe` flag + roguelite-wipe ROUTING** — a MISS sets `_pending_wipe`; `main_game._on_continue_pressed` reads `pending_wipe()` and calls `GameState.wipe_meta()` *before* the next run | `sell_screen.gd:72,169-188` + `main_game.gd:196-199` | **Hub return controller (M2) or Shop.** This is the **most dangerous drop** — the wipe must still fire on a missed quota, BEFORE the next dive. The natural new owner is whoever processes `run_ended` on the Hub-return path. Recommended: the **Hub** reads `GameState.last_quota_result()` on return, shows the QUOTA-MISSED beat, and calls `wipe_meta()` before re-arming the departure portal (OQ-3 + OQ-7). |
| R6 | **Web "Export telemetry" button** (web-only; downloads `user://telemetry/run_log.jsonl`; hidden on desktop) | `_setup_export_control` / `_on_export_telemetry_pressed`, `sell_screen.gd:94-115` | **New home needed.** Candidates: the Shop UI, a Hub terminal, or the M4 debug menu. Recommended: the **M4 P-key debug menu** (it is the "operator" surface and is available in Menu/Hub/Dive, so the export is reachable anywhere) — OQ-6. *Must not be dropped: it is the only telemetry-retrieval path on web.* |
| R7 | **Continue / restart intent** (`continue_pressed` → loop to next dive) | `sell_screen.gd:284-287` + `main_game.gd:158,196` | **The Hub itself is the "continue".** In M1.6 you don't loop straight into a dive — you *return to the Hub* and walk to the portal. The "Continue" verb dissolves into the Hub-departure-portal (M2). |
| R8 | **"Back to Config" intent** (`back_to_config_pressed` → re-show ConfigMenu) | `sell_screen.gd:294-297` + `main_game.gd:161` | **Obsolete** — the config rail is gone in M1.6 (M4 moves it to a P-key overlay available everywhere). "Back to Config" has no analogue; the Director can open the P-overlay in the Hub instead. *Drop intentionally* (OQ-8). |
| R9 | **Pause-the-tree presentation** (pauses the dive behind it; `PROCESS_MODE_ALWAYS` to tick while paused) | `sell_screen.gd:79,129` | **Not needed** — the Shop opens in the *Hub* (a non-dive scene; the dive clock is dive-only, Breakdown §2), so there is no live dive to pause. The Shop is just a `Control` over the Hub. |
| R10 | **All player-facing strings via `tr()` against a CSV** | `ui/sell/sell_strings.csv` | **Shop strings CSV** (`ui/shop/shop_strings.csv` or similar) — carry the F2 string keys forward (`SELL_ROW`, `SELL_SUBTOTAL`, `SELL_MONEY_TOTAL`, `SELL_QUOTA_MET/MISS`, `SELL_EXPORT_*`) into the Shop's CSV so localization isn't lost. |

**Disposition of the `SellScreen` files:** once R1–R10 re-home, `ui/sell/sell_screen.gd` + `.tscn` are removed from the *flow* — the M2 dive-only refactor strips the `SellScreen` instance from `main_game.tscn:40` and its wiring (`main_game.gd:158-165, 196-199`). Whether the `.gd`/`.tscn`/`.csv` files are deleted outright or kept as dead reference is OQ-9 (recommend: delete the scene from the flow, salvage the `.csv` keys + the `_render_rows`/`_animate_tally` render code into the Shop, then delete the old files so there is no second sell path).

### Determinism / baseline safety

M3 adds **no run-lever knobs** and touches **no band generation** → the all-off `RunConfig` fingerprint `e943ac9c8bc1` and the **89-knob count are untouched** (Breakdown §6). Buying is a **meta** operation entirely outside the run config / fingerprint surface. The save bump (if purchases persist) is **additive** (a new `owned_items` field defaulting to `[]`), exactly like E1's `banked_junk` (v1→v2) and K2's quota pair (v2→v3) — old saves migrate to an empty owned set, never crashing load.

---

## (b) Pseudocode (illustrative, against the real as-built APIs)

> All snippets are illustrative. The `purchase(...)` / owned-items **signatures** and the new EventBus signals are **pre-declared by M0**; M3 fills the *bodies*. Catalog `.tres` values are **configurable-not-balanced** greybox.

### 1. `GameState.purchase()` body — the Money debit + owned-items append + save

The mirror of `sell_banked_junk`'s "mutate meta → emit ledger event → save synchronously" discipline (`game_state.gd:324-352`), run in reverse (debit not credit):

```gdscript
# --- META-STATE (new field; persisted by to_meta_dict / rehydrated by from_meta_dict) ---
# Owned persistent purchases, by ShopItem id. Resets to [] on wipe_meta (a roguelite
# wipe clears bought upgrades too — see OQ-5). Empty for a consumable-only catalog.
var owned_items: Array[StringName] = []

## M3: spend Money on a catalog ShopItem. Pre-declared by M0; body here.
## Returns true on success, false if unaffordable / already owned (caller shows why).
## Mirrors sell_banked_junk's ledger+save discipline: ONE currency_changed event for
## the debit, then a synchronous atomic save so the spend survives a quit.
func purchase(item: ShopItem) -> bool:
    if item == null:
        return false
    if money < item.cost:
        return false                                   # unaffordable — no mutation
    # Persistent-upgrade guard: a non-stackable owned upgrade can't be re-bought.
    if item.persistent and owned_items.has(item.id):
        return false                                   # already owned
    # Debit through the canonical ledger so Telemetry's currency-out hook sees it.
    # add_currency takes a delta; a negative delta is the spend. source = &"shop".
    add_currency(&"money", -item.cost, &"shop")        # emits currency_changed(money, -cost, shop)
    if item.persistent:
        owned_items.append(item.id)
        _apply_purchase_effect(item)                   # OQ-2: stub vs real effect
    # Persist synchronously (atomic write + .bak), same slot-0 path as every meta op.
    SaveManager.save_meta(0)
    EventBus.item_purchased.emit(item.id, item.cost)   # M0-declared telemetry signal
    return true

## M3: where a persistent upgrade's effect lands (OQ-2). In greybox this may be a
## pure stub (spend registers, effect inert) OR stage a next-run modifier. Illustrative:
func _apply_purchase_effect(item: ShopItem) -> void:
    match item.effect_kind:
        &"none":  pass                                 # greybox stub — owning it is the proof
        # &"start_money_bonus", &"extra_slot", … → a future RunConfig/meta modifier
```

`add_currency` (`game_state.gd:300-306`) already accepts a signed `delta` and emits `currency_changed(kind, delta, source)` — a negative delta is a valid spend with **zero new ledger code**; Telemetry can segment currency-out by `source == &"shop"` exactly as it segments currency-in by `&"sell"`/`&"pockets"`.

### 2. The `ShopItem` / `ShopCatalog` Resources + a minimal greybox catalog (`.tres` shape)

Authored by `game-director-designer` against new `class_name` scripts, mirroring `JunkItem`/`JunkCatalog`:

```gdscript
# data/shop/shop_item.gd
class_name ShopItem
extends Resource
@export var id: StringName = &""                  # stable; events/telemetry/save (owned_items)
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var cost: int = 50                         # Money price (configurable-not-balanced)
@export var persistent: bool = true                # true = owned across runs (save bump); false = consumable
@export var effect_kind: StringName = &"none"      # greybox: &"none" = stub spend (OQ-2)
@export var greybox_color: Color = Color.LIGHT_GREEN   # reuse the JunkItem greybox idiom for the cell
```

```gdscript
# data/shop/shop_catalog.gd
class_name ShopCatalog
extends Resource
@export var items: Array[ShopItem] = []            # the buyable set the Shop BUY tab lists
```

Proposed minimal greybox catalog (`data/shop/shop_catalog.tres`, 3 entries — **illustrative values, configurable-not-balanced**):

```
[gd_resource type="Resource" script_class="ShopCatalog" ...]
[ext_resource ... shop_catalog.gd id="0"]
[ext_resource ... shop_item.gd id="1"]
[ext_resource ... res://data/shop/items/shop_scrap_magnet.tres id="2"]
[ext_resource ... res://data/shop/items/shop_lucky_charm.tres id="3"]
[ext_resource ... res://data/shop/items/shop_reinforced_bag.tres id="4"]
[resource]
script = ExtResource("0")
items = Array[ExtResource("1")]([ExtResource("2"), ExtResource("3"), ExtResource("4")])

# shop_scrap_magnet.tres   → id=&"scrap_magnet",   cost=100, persistent=true,  effect_kind=&"none"
# shop_lucky_charm.tres    → id=&"lucky_charm",    cost=150, persistent=true,  effect_kind=&"none"
# shop_reinforced_bag.tres → id=&"reinforced_bag", cost=250, persistent=true,  effect_kind=&"none"
```

Three **persistent** greybox upgrades whose `effect_kind=&"none"` makes them **stub spends** in M1.6 (owning them is the proof the meta-spend loop closes; real effects are a follow-up — OQ-2). Persistent → exercises the save bump (the loop's whole point). See OQ-1 for the consumable-vs-persistent recommendation + Director flag.

### 3. The Shop UI flow (open via hub interactable → SELL tab → BUY tab)

```
Player walks into the Shop Area2D (M2 mounts it) and presses [F] (interact):
  → InteractionDetector emits interaction_requested(&"shop", shop_node)   (existing pattern)
  → Shop opens its Control (a TabContainer: SELL | BUY), emits EventBus.shop_opened   (M0-declared)
  → persistent header always reads live GameState.money (R3); BUY tab gates on it.

SELL tab:
  - lists banked_junk rows (reuse SellScreen._render_rows shape: {name, value}, empty fallback)  [R2]
  - "Sell all" button → GameState.sell_banked_junk(&"sell")   [R1]  (credits + saves + quota eval)
    → on return: re-render (bank now empty), repaint Money header, fire EventBus.item_sold(total)  (M0-declared)
    → quota readout (R4) from GameState.last_quota_result(): MET line, or MISS → wipe routing (R5, OQ-3/OQ-7)

BUY tab:
  - one cell per ShopCatalog.items entry: name, cost, [Buy] (disabled if money < cost OR persistent&&owned)
  - [Buy] → GameState.purchase(item):
       true  → repaint Money header + grey out an owned persistent item
       false → flash "Not enough Money" / "Owned"
```

The interaction reuse is wholesale: the Hub's interactor is the dive's `InteractionDetector`/`interaction_requested` pattern filtered by `interactable_id` (`&"shop"`), exactly as `JunkPickup` (`&"junk"`) and `ExtractGate` (`&"gate"`) disambiguate today — M2 mounts the anchor, M3 fills the Shop behind it.

### 4. Save-schema v3→v4 migration step + fixture (IF purchases persist — see OQ-1)

This fires **only if** the Director ratifies a persistent catalog. Then, copying the v2→v3 pattern exactly:

```gdscript
# save_manager.gd: bump the constant
const META_SCHEMA_VERSION := 4         # was 3

# save_manager.gd _migrate_meta: add the v3->v4 case (after case 2)
        3:
            # v3 -> v4 (M3): owned_items added (persistent shop purchases). Old saves
            # predate the shop → default to an empty owned set so from_meta_dict
            # rehydrates owned_items to [].
            if not data.has("owned_items"):
                data["owned_items"] = []
```

```gdscript
# game_state.gd to_meta_dict(): add
    "owned_items": _owned_ids_as_strings(),     # Array[String] of StringName ids (objects-OFF)
# game_state.gd from_meta_dict(): add
    owned_items = _rehydrate_owned(d.get("owned_items", []))   # → typed Array[StringName]
# game_state.gd wipe_meta(): add (a roguelite wipe clears bought upgrades — OQ-5)
    var empty_owned: Array[StringName] = []
    owned_items = empty_owned
```

**Fixture need (TDD rule: "a QA fixture on every schema change"):**
- `tests/fixtures/gen_meta_v3_fixture.gd` — clones `gen_meta_v2_fixture.gd` (`tests/fixtures/gen_meta_v2_fixture.gd:21-50`) but writes a **v3** dict (schema_version=3, the v1 fields + `banked_junk` + `run_number`/`quota_target`, and **NO** `owned_items`). Commit the binary `tests/fixtures/meta_v3.sav`.
- `tests/test_save_migration.gd` — add a `_run_v3()` case (mirroring `_run_v2()`, `:197-301`): stage `meta_v3.sav`, assert it migrates to v4 with `owned_items == []` added + every v3 field intact + a clean round-trip + `.bak`. Wire it into `_ready()` (`:53-59`) after `_run_v2()`.

The migration is **additive + safe** — no field is removed or reshaped, so the `.bak` recovery and atomic-write guarantees are unchanged.

---

## (c) Open Questions

- **OQ-1 — WHAT IS BUYABLE: consumables (no save bump) vs persistent upgrades (save bump)? — `[needs Director review — fun/scope call]`.** A **consumable** catalog (one-shot effects, spent within/before a run) needs **no** new meta field and **no** save bump — Money debits, the effect applies, nothing is owned. A **persistent** catalog (upgrades owned across runs) requires the **META v3→v4 bump + migration + `meta_v3.sav` fixture** in §(b).4 and a `wipe_meta` clear. **Recommendation: a minimal *persistent* catalog (the 3 greybox upgrades in §(b).2), accepting the v3→v4 bump.** Rationale: the *entire point* of M1.6's Hub is to start the meta-progression loop — "spend Money, keep the thing across runs" is the loop the GDD's four tracks are built on; a consumable-only shop would spend Money but leave **no durable meta state**, proving far less of the surface premise and dodging the save-discipline work that every later upgrade system needs anyway. The bump is cheap (one additive field, the pattern is already in-repo twice). **Trade-off the Director owns:** the bump is irreversible schema debt for a greybox feature that may be re-cut; the consumable path is lower-risk but proves less. **This is a fun/scope call — surface to the Director with the recommendation (persistent).** *(Phase 3 must flag, not self-resolve.)*

- **OQ-2 — does buying actually DO anything in greybox, or is it a stub spend?** With `effect_kind=&"none"` (§(b).2), a purchase debits Money + records ownership but applies **no gameplay effect** — owning it is the only proof. **Recommendation:** **stub spend for M1.6** (`effect_kind=&"none"`, `_apply_purchase_effect` is a no-op). Rationale: M1.6 is structural/UI/meta — proving the *spend-and-persist loop* (Money goes down, the owned set grows, it survives a quit and a re-load) is the milestone goal; *what* the upgrade does is a balance/content question for a later milestone. The `effect_kind` field is authored now so a future task wires real effects (e.g. a next-run `RunConfig` modifier or a passive meta stat) without a schema change. **Trade-off:** a stub spend may read as "pointless" in playtest (RG2 should watch whether testers buy at all). *Recommend stub; note the RG2 watch-item. Light Director awareness, not a blocking call.*

- **OQ-3 — where does the QUOTA-OUTCOME readout (R4) + the MISS-wipe ROUTING (R5) land — a Hub-return banner, or a Shop line?** The cached `last_quota_result()` (`game_state.gd:398`) must still be shown, and a MISS must still drive `wipe_meta()` *before* the next dive (today `main_game.gd:196-199`). Two homes: **(a)** the **Hub** reads it on `run_ended`/return, shows a QUOTA-MISSED beat, and wipes before re-arming the portal — wipe happens whether or not the player visits the Shop; **(b)** the **Shop SELL tab** shows it, and wipe routes off the Shop's continue — but then a player who *never opens the Shop* never wipes, which **breaks the roguelite contract.** **Recommendation: (a) — the Hub-return controller (M2) owns the quota readout + wipe routing**, because the wipe must be unconditional and the Shop is *optional* in the Hub. The Shop SELL tab may *also* echo the MET/next-quota line for context, but the **authoritative wipe lives on the Hub-return path, not behind a Shop visit.** **This is a hard cross-task contract with M2** — coordinate during Wave 3. *Recommend (a); confirm the M2/M3 seam.*

- **OQ-4 — is the haul held-banked-until-Shop, or auto-sold on hub entry?** (Breakdown §7.) **Held** = `banked_junk` survives the dive→hub return (it already persists as meta), the player sees the haul, and selling converts it at the Shop. **Auto-sold** = the Hub-return path calls `sell_banked_junk` immediately, and the Shop only shows the resulting Money. **Recommendation: HELD — sold at the Shop.** Rationale: it gives the Shop a *reason to exist* and matches the Director's "walk to shop = sell" intent (Breakdown §7); the haul already persists as meta so holding is free. **But note the quota interaction:** the K2 quota is evaluated *inside* `sell_banked_junk` (`game_state.gd:350`), so if selling is deferred to the Shop, **the quota isn't evaluated until the player sells** — and a player who never visits the Shop never triggers the quota check or its wipe. This couples OQ-4 to OQ-3: either (i) the Hub-return path force-evaluates the quota on return independent of selling, or (ii) selling is *required* before the next dive. **Recommendation: held haul, but the quota eval + wipe routing fire on Hub-return (OQ-3 option a) decoupled from the Shop sell** — so the roguelite contract holds even if the player ignores the Shop. *Confirm with the Director + M2.*

- **OQ-5 — does a roguelite `wipe_meta()` clear `owned_items` too?** `wipe_meta` (`game_state.gd:410-431`) resets *every* meta field to construction defaults (money, banked_junk, quota). **Recommendation: YES — clear `owned_items` on wipe** (a missed-quota wipe is a full restart; bought upgrades are part of the meta progression that resets). This matches the existing wipe semantics (it already nukes `banked_junk` and Money). **Trade-off:** if a future design wants *some* meta to survive a wipe (a "permanent unlock" track), `owned_items` would need splitting into wiped vs permanent sets — out of M1.6 scope. *Recommend clear-on-wipe; flag the future-permanent-track question as a note, not an M1.6 decision.*

- **OQ-6 — where does the web "Export telemetry" button (R6) re-home?** It is **web-only** and is the **only telemetry-retrieval path on web** (`sell_screen.gd:94-115`) — it must not be dropped. Candidates: (a) the Shop UI, (b) a dedicated Hub terminal interactable, (c) the **M4 P-key debug menu**. **Recommendation: (c) the M4 debug menu** — it is the "operator/debug" surface, is available in Menu **and** Hub **and** Dive (so export is reachable from anywhere, not gated behind a Shop visit), and groups naturally with the other debug/telemetry controls. **Cross-task coordination with M4** (which owns the debug-menu rework). Fallback if M4 can't absorb it in time: a small "Export telemetry" button on the Shop SELL tab (carries the F2 strings R10). *Recommend M4; coordinate, with the Shop as fallback.*

- **OQ-7 — exactly who calls `wipe_meta()` and when, now that `main_game._on_continue_pressed` is gone?** M2 makes `main_game` dive-only and removes the `SellScreen` continue wiring (`main_game.gd:158,196-199`). The wipe call must move to the **Hub-return controller** (per OQ-3a). **Recommendation:** the Hub, on receiving `run_ended`/return, reads `last_quota_result()`; if it's a checked MISS, it shows the QUOTA-MISSED beat then calls `GameState.wipe_meta()` before re-enabling the departure portal — so the *next* dive starts from a wiped ladder exactly as today. **This is a contract M2 must implement and M3 depends on** — name it explicitly in both task specs. *Technical; resolve in the M2/M3 seam.*

- **OQ-8 — drop "Back to Config" (R8) entirely?** The config rail is gone in M1.6 (M4 → P-key overlay). **Recommendation: drop it** — there is no "config screen" to go back to; the Director opens the P-overlay in the Hub instead. *Low-risk; recommend drop.*

- **OQ-9 — delete the `SellScreen` files, or keep them as dead reference?** Once R1–R10 re-home, `sell_screen.gd`/`.tscn` are out of the flow. **Recommendation: salvage the reusable render code (`_render_rows`, the count-up if kept) + the `sell_strings.csv` keys into the Shop, then DELETE `ui/sell/*` so there is no orphan second sell path** (a stray auto-presenting `SellScreen` listening on `run_ended` would double-sell). Confirm the M2 dive-only refactor removes the `main_game.tscn:40` instance + wiring in the same wave. *Recommend delete-after-salvage; M2/M3 coordination.*

- **OQ-10 — does the Shop BUY tab need a "can't afford / owned" affordance beyond disabling the button?** Greybox minimal: disable `[Buy]` when `money < cost` or owned. **Recommendation:** disable + a transient label flash on a failed `purchase()` (which already returns `false`) — no modal, no confirm dialog in greybox. *Low-risk; ui-ux call.*

---

## Resolved Decisions (Phase 3)

_Fresh-eyes pass, 2026-06-26. Reviewer is **NOT** the M3 author. Resolved against the verified as-built code (`game_state.gd` `sell_banked_junk`/`add_currency`/`wipe_meta`/`to_meta_dict`/`from_meta_dict`/`_evaluate_quota`/`last_quota_result`; `sell_screen.gd` the full SellScreen surface; `save_manager.gd` `META_SCHEMA_VERSION=3` + the `_migrate_meta` chain + `_atomic_store`; `tests/fixtures/gen_meta_v2_fixture.gd` + `tests/test_save_migration.gd` `_run_v2()`/`_ready()`; `data/junk/junk_catalog.gd`/`junk_item.gd`) and against the **M0 and M2 Phase-2 designs** (cross-task convergence). The two sibling designs are authoritative for the shared seams: **M0 owns the `purchase()`/`owns()`/`owned_items` surface + the EventBus signal set + the migration scaffold; M2 owns the dive-only refactor + the Hub-return controller that decouples quota/wipe from selling.** M3 fills the Shop UI + catalog data + the persist wiring. Where M3's Phase-2 pseudocode and M0's pre-declared API disagree, **M0's locked API wins** (M0 is the single writer of `game_state.gd`/`event_bus.gd`) — the divergences are resolved below (RD-2, RD-7)._

> **One standout `[needs Director review]` item carries forward unresolved by design: OQ-1** (consumable vs persistent buy catalog → whether M1.6 takes the META v3→v4 save bump). It is a fun/scope call; fresh-eyes attach a firm recommendation but do **not** self-resolve it. Everything else is resolved on technical/design merit or deferred to an already-Director-flagged cross-task item (M2's `DR-M2-1`/`DR-M2-2`, M0's `OQ-3`).

### RD-1 — OQ-1 (consumable vs persistent catalog → save bump): RECOMMEND PERSISTENT + v3→v4 bump — **`[needs Director review — fun/scope]`** (NOT self-resolved)

**Carried to the Director with a firm recommendation: ship a minimal *persistent* catalog (3 greybox upgrades) and take the META v3→v4 bump.** Fresh-eyes endorse the author's recommendation on the merits below, but this stays a Director call (it is the one irreversible schema decision in M1.6, on a greybox feature that may be re-cut):

1. **It is the loop M1.6 exists to start.** The Breakdown's "one thing M1.6 must prove" (§1) is a *surface with a meta-loop* — "sell → bank Money → spend on durable upgrades that survive the run." A consumable-only shop debits Money but leaves **no durable meta state**, proving far less of the surface premise and skipping the save-discipline work every later upgrade system needs anyway. Both M0 (`OQ-3`) and M2 independently land on persistent as the recommendation; this design agrees.
2. **The bump is mechanical and low-risk.** `_migrate_meta` already has **three** precedents to copy (v0→v1 `knowledge_level`, v1→v2 `banked_junk`, v2→v3 `run_number`/`quota_target`, `save_manager.gd:78-95`). The v3→v4 step is **purely additive** (`owned_items` defaults `[]`), so old saves never crash, the `.bak`/atomic-write guarantees are untouched, and the fixture/test pattern is already in-repo (RD-6).
3. **Determinism-safe.** `owned_items` is meta, entirely outside `fingerprint()` / the RunConfig surface — the all-off baseline `e943ac9c8bc1` and the 89-knob count are unmoved (confirmed against the Breakdown §6 contract and M0's carried contracts).

**Director question to surface (verbatim):** *"Should the M1.6 greybox shop sell durable upgrades you keep across runs (→ a deliberate save v3→v4 bump + migration + `meta_v3.sav` fixture, plus a `wipe_meta` clear), or only consumables spent within a run (no save change)? Fresh-eyes + M0 + M2 all recommend PERSISTENT — it's the meta loop the Hub is built for, and the bump is routine."* **All RD entries below assume the PERSISTENT verdict; if the Director picks consumable-only, the deltas are spelled out in RD-9.**

### RD-2 — `purchase()` signature: M0's `purchase(item_id: StringName, price: int)` is the locked API; the Shop passes primitives, NOT a `ShopItem` — RESOLVED (cross-task, M0 wins)

**The M3 §(b).1 pseudocode (`func purchase(item: ShopItem) -> bool`) is superseded by M0's pre-declared signature `purchase(item_id: StringName, price: int) -> bool` + `owns(item_id: StringName) -> bool` (M0 §B.2).** M0 is the single writer of `game_state.gd`, so its shape is authoritative. Consequences M3's builder follows:

- **`GameState` stays catalog-agnostic.** It never imports/loads `ShopItem`/`ShopCatalog` — it only knows ids + prices. The Shop UI reads the `ShopCatalog` `.tres`, and for a buy calls `GameState.purchase(item.id, item.cost)`. This is cleaner than M3's draft (which would have coupled `game_state.gd` to the new `ShopItem` class).
- **The affordability/owned guards split across the seam:** `purchase()` checks `money >= price` and emits `purchase_failed(item_id, price, money)` on a shortfall (M0 §B.2). The **already-owned guard for a non-stackable persistent upgrade lives in the Shop UI** (it disables/greys the Buy button when `GameState.owns(item.id)`, RD-8), so the UI never calls `purchase()` for an owned item. (M0's `purchase()` as drafted does *not* itself re-check `owns()` before appending — to avoid silent double-owns, **M3's builder adds a one-line `if owned_items.has(item_id): return false` guard inside `purchase()` and flags it to M0** as a body-fill, since M0 owns the file. This is a body detail, not a signature change.)
- **`_apply_purchase_effect` is dropped from `purchase()`'s body for greybox** — with `effect_kind=&"none"` (RD-3) there is no effect to apply, so the M0 `purchase()` body (debit → append `owned_items` → save → emit) stands as-is. The `effect_kind` field is authored on `ShopItem` now so a future milestone wires effects without a schema change; M1.6's `purchase()` does not branch on it.

### RD-3 — OQ-2 (does buying DO anything in greybox?): STUB SPEND, effect deferred — RESOLVED (design), RG2 watch-item flagged

**Locked: greybox purchases are stub spends — `effect_kind=&"none"`, no gameplay effect.** Buying debits Money, records the owned id, and persists; *owning the thing* is the proof the meta-spend loop closes (Money goes down, the owned set grows, it survives a quit + reload). What an upgrade *does* is a balance/content question for a later milestone — out of M1.6's structural/UI/meta scope (Breakdown §2). The `effect_kind: StringName` field is authored on `ShopItem` now (RD-7) so a future task wires real effects (a next-run `RunConfig` modifier or a passive meta stat) **without a schema change**. *Flag to RG2 (not a Director-blocking call): watch whether testers buy at all when the purchase has no visible effect — a "pointless spend" read is a known risk of greybox and is exactly the kind of signal RG2 exists to catch.* Light Director awareness, no verdict required.

### RD-4 — OQ-4 (held haul vs auto-sold) + OQ-3/OQ-7 (quota/wipe decoupling): HELD haul, quota/wipe fire on the GUARANTEED Hub-return beat — RESOLVED, converges with M2 `DR-M2-1`

This is the load-bearing cross-task contract; it is resolved **identically** to M2's design (M2 OQ-6 / `DR-M2-1`), so the M2↔M3 seam is consistent:

- **The haul is HELD, not auto-sold.** `banked_junk` already persists as meta (`game_state.gd:42`, `to_meta_dict:559`), so holding it across the dive→hub return is free and gives the Shop its reason to exist. The player sees the held haul; **only the Shop SELL tab calls `GameState.sell_banked_junk(&"sell")`** (R1). Matches the Director's "walk to shop = sell" intent (Breakdown §7).
- **The quota eval + MISS-wipe are DECOUPLED from selling and fire on the Hub-return beat that M2 owns.** This is the critical fix: today `_evaluate_quota` runs *inside* `sell_banked_junk` (`game_state.gd:350`), so if selling is deferred to an *optional* Shop visit, a player who re-dives without selling **never triggers the quota check or its wipe** — breaking the roguelite contract. **Resolution (locked, matching M2):** the **M2 Hub-return controller** reads `GameState.last_quota_result()` on `returned_to_hub`, shows the QUOTA-MISSED beat, and calls `GameState.wipe_meta()` **before re-arming the departure portal** — unconditionally, whether or not the player ever opens the Shop. The Shop SELL tab may *echo* the MET / next-quota line for context, but the **authoritative quota outcome + wipe live on the Hub-return path, never behind a Shop visit.**
- **Mechanism note (the decoupling's implementation):** because `_evaluate_quota` is currently only reachable through `sell_banked_junk`, the decoupling needs the eval to be callable on hub-return independent of a sell. The clean shape (verified against `game_state.gd:363-392`): `_evaluate_quota` is already idempotent (`_quota_evaluated_this_run`) and reads run-state snapshots, so the **Hub-return controller can call a thin `GameState` entry that runs the eval once on return** (basis `this_run_banked` would read `0` sold-this-call if nothing was sold yet, so for the held-haul model the eval must run **after** an eventual sell *or* the basis must read `cumulative_money`). **This is a `game_state.gd` body detail that belongs to M0/M2's single-writer pass, not M3** — M3 flags it: *the quota eval must be invokable on the guaranteed hub-return beat decoupled from `sell_banked_junk`, and the basis interaction with a not-yet-sold held haul must be resolved by M2/M0.* M3 depends on the decoupled eval existing; it does not write it. **Already Director-flagged as M2 `DR-M2-1` — no new Director item; M3 confirms its half (Shop sells, never owns the wipe).**

### RD-5 — OQ-5 (does `wipe_meta()` clear `owned_items`?): YES, clear-on-wipe — RESOLVED (design)

**Locked: a roguelite `wipe_meta()` clears `owned_items` to a fresh-typed empty array.** A missed-quota wipe is a full meta restart; bought upgrades are part of the meta progression that resets, exactly as the wipe already nukes `banked_junk` and Money (`game_state.gd:419-420`, the typed-empty-array idiom). M0 already specifies this addition in its `wipe_meta()` pass (M0 §B.2: `var empty_owned: Array[StringName] = []; owned_items = empty_owned`) — so it is **M0's edit, not M3's** (M0 is the single writer of `game_state.gd`). M3 only relies on it holding. *Future note (not an M1.6 decision):* if a later design wants a "permanent unlock" track that survives a wipe, `owned_items` would split into wiped-vs-permanent sets — explicitly out of M1.6 scope; recorded so the future task knows the seam.

### RD-6 — OQ (save migration plan): v3→v4 step + `meta_v3.sav` fixture + `_run_v3()` test — RESOLVED (mechanical, copies the v2→v3 precedent exactly)

Assuming the PERSISTENT verdict (RD-1), the migration is the well-trodden additive step. Verified against the existing v2→v3 work:

- **Constant + step (lands in M3, NOT M0 — M0 must not bump the version):** `META_SCHEMA_VERSION := 4` (`save_manager.gd:15`); add a `3:` case to `_migrate_meta` after the `2:` case (`save_manager.gd:88-95`):
  ```gdscript
  3:
      # v3 -> v4 (M1.6 M3): owned_items added (persistent shop purchases). Old saves
      # predate the shop → default to an empty id list so from_meta_dict reads "owns nothing".
      if not data.has("owned_items"):
          data["owned_items"] = []
  ```
- **Save-bridge:** `to_meta_dict()` adds `"owned_items": <Array[String] of the ids>` (objects-OFF, like `banked_junk`'s id list, `game_state.gd:551-559`); `from_meta_dict()` rehydrates to a typed `Array[StringName]` via `d.get("owned_items", [])`. **These are M0/M3 boundary edits to `game_state.gd`** — M0 declares the field + neutral default in its single-writer pass (M0 §B.2 shows the exact lines, gated on this verdict); M3 lands the persist wiring once the verdict is PERSISTENT. The clean split: **M0 ships the field declaration; M3 ships the version bump + migration step + the `to/from_meta_dict` persist lines + the fixture/test** (because M3 is where the persist decision is realized). M3's builder coordinates the `game_state.gd` edits with M0's pass (single-writer discipline).
- **Fixture (`tests/fixtures/gen_meta_v3_fixture.gd` + binary `meta_v3.sav`):** clone `gen_meta_v2_fixture.gd` exactly; write a **v3** dict — `schema_version=3`, all v1 fields + `banked_junk` (empty id list, as the v2 fixture does) + the K2 pair `run_number`/`quota_target`, and **NO `owned_items` key** (that absence is what the v3→v4 step adds). Use distinct known values (e.g. `money` differing from `EXPECT_V2_MONEY=2500`) so the test can tell fixtures apart, mirrored by new `EXPECT_V3_*` consts.
- **Test (`tests/test_save_migration.gd`):** add a `_run_v3()` case mirroring `_run_v2()` (`:197-301`): stage `meta_v3.sav`, `load_meta`, assert it migrates to v4 with `owned_items == []` added, every v3 field intact (money/salvage/lore/exposure/knowledge/recipes/banked_junk/run_number/quota_target), a clean round-trip (`save_meta` → reload → values survive), and the `.bak` written. Wire `_run_v3()` into `_ready()` (`:53-59`) after `_run_v2()`. **Run as a SCENE headless** (`--headless <tscn>`), not `--script`, per the orchestrator's godot-headless-invocation memory.

### RD-7 — `ShopItem` / `ShopCatalog` `.tres` shape: LOCKED, mirrors `JunkItem`/`JunkCatalog` — RESOLVED (design)

The catalog is data-as-Resources, authored by `game-director-designer` against new `class_name` scripts, mirroring the junk idiom (`data/junk/junk_item.gd` + `junk_catalog.gd`). Locked shape:

- **`data/shop/shop_item.gd`** (`class_name ShopItem extends Resource`): `id: StringName` (stable; the key in `owned_items` + events + save), `display_name: String`, `description: String` (`@export_multiline`), `cost: int` (Money price, **configurable-not-balanced** greybox), `persistent: bool = true` (true = owned across runs → save bump; the M1.6 catalog is all-persistent), `effect_kind: StringName = &"none"` (greybox stub, RD-3), `greybox_color: Color` (reuse the JunkItem greybox-cell idiom for the BUY cell).
- **`data/shop/shop_catalog.gd`** (`class_name ShopCatalog extends Resource`): `@export var items: Array[ShopItem] = []`. **Simpler than `JunkCatalog`** — it carries **no `spawn_weights`** (the Shop lists every item; there is no weighted random draw). The Shop BUY tab iterates `catalog.items` in author order.
- **The 3-entry greybox catalog** (`data/shop/shop_catalog.tres` + 3 item `.tres` under `data/shop/items/`, illustrative configurable-not-balanced values): `scrap_magnet` (cost 100), `lucky_charm` (cost 150), `reinforced_bag` (cost 250) — all `persistent=true`, `effect_kind=&"none"`. Three is enough to exercise the loop (afford one, save for another, see one greyed when owned) without balance work.

### RD-8 — OQ-10 (BUY affordance): disable + transient flash, no modal — RESOLVED (ui-ux, minor)

Greybox-minimal, matching M0's `purchase_failed` signal. Each BUY cell's `[Buy]` button is **disabled** when `GameState.money < item.cost` **OR** `GameState.owns(item.id)` (an owned persistent upgrade greys out). A failed `purchase()` (which returns `false` and emits `purchase_failed(item_id, price, money)`, M0 §B.2) drives a **transient label flash** ("Not enough Money" / "Owned") — no confirm dialog, no modal. The Money header repaints on `item_purchased` and on `currency_changed`. *ui-ux owns the layout; no Director call.*

### RD-9 — IF the Director picks CONSUMABLE-ONLY (the OQ-1 alternative): the deltas — RESOLVED (contingency)

Recorded so the build is unblocked under either verdict:
- **No save bump.** `META_SCHEMA_VERSION` stays 3; **no** v3→v4 migration step, **no** `meta_v3.sav` fixture, **no** `_run_v3()` test, **no** `owned_items` lines in `to/from_meta_dict`. RD-6 is dropped entirely.
- **`owned_items` becomes an in-memory meta scratch** (declared by M0, not persisted) — `purchase()` still debits Money + emits `item_purchased`, but ownership does not survive a reload. `wipe_meta` still clears it (RD-5 holds in-memory).
- **`ShopItem.persistent` is set `false`** on the catalog entries; the BUY cell's owned-greyout (RD-8) is dropped (a consumable can be re-bought) — only the affordability disable remains.
- **Everything else (RD-2/3/4/7/8, the Shop UI, the held-haul + decoupled quota/wipe) is unchanged.** Consumable-vs-persistent touches only the persistence layer, not the Shop flow.

### RD-10 — Full SellScreen re-home table: every R1–R10 lands somewhere; nothing dropped — RESOLVED (verified against `sell_screen.gd`)

The §(a) re-home table is verified complete against the live `sell_screen.gd` surface. Final dispositions, with cross-task ownership pinned:

| # | SellScreen responsibility | Final home (Phase-3 locked) | Owner |
|---|---|---|---|
| R1 | Cash-out (`sell_banked_junk(&"sell")`, once) | **Shop SELL tab** — identical call, presentation-only re-home | M3 |
| R2 | Per-item sell tally render | **Shop SELL tab** — same row shape, salvaged from `_render_rows` | M3 (ui-ux) |
| R3 | Subtotal + live Money header | **Shop persistent header** (gates BUY); count-up flourish OPTIONAL in greybox (drop is fine) | M3 (ui-ux) |
| R4 | Quota-outcome readout | **Hub-return beat (authoritative)** + optional Shop echo (RD-4) | **M2** owns; M3 may echo |
| R5 | `pending_wipe` + MISS-wipe routing | **Hub-return controller** — fires unconditionally before re-arming the portal (RD-4) | **M2** (`DR-M2-1`) |
| R6 | Web "Export telemetry" button | **M4 P-key debug menu** (reachable in Menu/Hub/Dive), Shop SELL tab as fallback if M4 slips (RD-11) | **M4** (M2 `DR-M2-2`); M3 carries fallback |
| R7 | Continue / restart intent | **Dissolves into the Hub departure portal** — "continue" = walk to the portal | M2 |
| R8 | "Back to Config" intent | **Dropped** — the config rail is gone (M4 → P-overlay); no analogue (OQ-8) | M2 (delete) |
| R9 | Pause-the-tree presentation | **Not needed** — the Shop opens in the Hub (no live dive to pause) | M3 (n/a) |
| R10 | Strings via `tr()` against a CSV | **Shop strings CSV** (`ui/shop/shop_strings.csv`) — carry the `SELL_*` keys forward (incl. `SELL_EXPORT_*` if R6's fallback lands on the Shop) | M3 (ui-ux) |

**Files:** once R1–R10 re-home, **delete `ui/sell/sell_screen.gd` + `.tscn` after salvaging** the `_render_rows` shape + the `sell_strings.csv` keys into the Shop (OQ-9). The deletion of the `main_game.tscn:40` SellScreen instance + its wiring is **M2's** dive-only refactor (M2 owns `main_game.*`); M3 must confirm with M2 that the same wave removes the auto-presenting instance so no orphan second sell path (a stray `SellScreen` still listening on `run_ended` would **double-sell**). **Coordinate at the M2→M3 sequential boundary (Wave 2→3).**

### RD-11 — OQ-6 (web telemetry export home): M4 P-debug menu, Shop SELL tab as the fallback — RESOLVED, converges with M2 `DR-M2-2`

The web "Export telemetry" button is the **only** telemetry-retrieval path on web (`sell_screen.gd:94-115`, `TelemetryExporter`) — it must not be dropped (RG2 needs web telemetry back). **Locked home: the M4 P-key debug menu** — it is the operator/debug surface, mounted on `App.DebugOverlay` (M0 §B.1) so it is reachable in Menu/Hub/Dive (not gated behind a Shop visit), and it groups with the other debug controls. **M4 owns the re-home; M3 carries a fallback** — if M4 can't absorb it in the same milestone, M3 adds a small "Export telemetry" button on the Shop SELL tab (web-guarded exactly as `_setup_export_control`, carrying the `SELL_EXPORT_*` strings R10). **This is the same item M2 flagged as `DR-M2-2`** — no new Director item; M3 confirms the path is preserved (not dropped) and provides the Shop fallback. *Cross-task coordination with M4; M3 = safety net.*

### Needs Director review (M3)

> Fresh-eyes do NOT self-resolve these — vision/fun/tone/scope calls per the orchestrator loop step 7. Both already have firm recommendations.

- **DR-M3-1 — Consumable vs PERSISTENT buy catalog → the META v3→v4 save bump (OQ-1 / RD-1).** Recommendation: **PERSISTENT** (3 greybox upgrades, accept the v3→v4 bump). It's the meta loop the Hub exists to start; the bump is mechanical (three in-repo precedents); determinism is unaffected. M0 and M2 independently recommend the same. *The one irreversible schema call in M1.6 — Director ratifies.*
- **DR-M3-2 (light, RG2 watch — not blocking) — Stub spend may read as "pointless" (OQ-2 / RD-3).** Recommendation: ship the stub spend (`effect_kind=&"none"`); RG2 watches whether testers buy at all when the purchase has no visible effect. *Director awareness only — no verdict needed unless RG2 surfaces a problem.*

> **Cross-task items NOT re-flagged here** (already owned + Director-flagged by the sibling designs, M3 only confirms its half): the **quota/wipe-on-Hub-return decoupling** (M2 `DR-M2-1`, RD-4) and the **web telemetry-export home** (M2 `DR-M2-2`, RD-11). M3 confirms: the Shop sells but never owns the wipe; the telemetry export is preserved (M4 primary, Shop fallback).
