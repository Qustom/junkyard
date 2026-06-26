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

_(pending — fresh-eyes pass + Director dispositions to be folded in here, mirroring the M1.5 "Resolved Decisions (ratified)" blocks. The standout **`[needs Director review]`** item is **OQ-1** (consumable vs persistent buy catalog → whether M1.6 takes the META v3→v4 save bump); the standout cross-task contracts are **OQ-3/OQ-7** (Hub-return owns the quota readout + wipe routing) and **OQ-4** (held haul) with M2, and **OQ-6** (telemetry export) with M4.)_
