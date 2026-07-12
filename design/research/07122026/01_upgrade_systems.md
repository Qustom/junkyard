# Upgrade Systems for THE FAR YARD — Research Report

*Research spike, 2026-07-12. Scope: the full upgrade/meta-progression design space for THE FAR YARD — character, carry/inventory, survivability, tools, home-base/workshop, movement, exposure resistance, extraction aids, and knowledge/recipe unlocks — surveyed against comparable games, then mapped concretely onto the as-built M1 systems (`GameState`, `EventBus`, `.tres` Resources, `RunConfig`, the debt/quota loop, exposure). Companion to TDD §3 (three currencies / four tracks), GDD §8, and the closed spikes `12_economy_balance_model.md`, `13_exposure_pacing.md`, `05_difficulty_instability_scaling_model.md`.*

This is a **design research doc**, not a build spec. Its open questions are surfaced for the human Director; its recommendations are recommendations.

---

## 0. Why this matters now, and the one hard constraint

The M1 loop already earns and banks **Money** (junk → `banked_junk` → `sell_banked_junk` → `money`) and has a **stub shop** (`ShopItem`/`ShopCatalog`, `GameState.owned_items`) that debits Money and records ownership but applies **no gameplay effect** (`effect_kind = &"none"`). Meta-state already carries three currency fields — `money`, `salvage`, `lore` — plus `knowledge_level`, `unlocked_recipes`, `exposure`, `run_number`, `quota_target` (`systems/game_state.gd` / `systems/economy.gd`). **Two of the three currencies (Salvage, Lore) have no faucet and no sink today.** The whole upgrade layer is what turns those dormant fields into a functioning economy, and it is the payload of the **"Upgrade" step** that already sits in the M2 vertical-slice loop (TDD §7: *morning prep → dive → extract → sell → upgrade → evening → sleep*) and the **four tracks** that M3 must fully wire.

The single load-bearing constraint the whole design must honor comes from `05_difficulty_instability_scaling_model.md`: enemy stats **and loot tier/value rise together** off one **Instability scalar `I`** (linear-in-time, **+15% multiplicative per band**). Upgrades are the player's counter-pressure against `I`. If upgrade power outruns `I`'s band steps, deep bands trivialize and the push/cash-out tension (Pillar 1) dies; if it lags, the player is walled out of content they've paid for. **Every stat-style upgrade must be sized in `I`-units, not absolute numbers** — this is the thesis of §2 and the reason the survey below leans so hard toward *horizontal* (capability-unlocking) over *vertical* (raw-stat) progression.

---

## 1. Broad survey / prior art

Grouped by the archetype each game teaches, with what it does well/poorly and the transferable lesson.

### 1.1 Extraction-genre meta-progression (the closest cousins)

- **Escape from Tarkov — the Hideout + Stash.** The persistent **stash** is the meta-vault; you spend Roubles/resources to physically **expand stash grid size** and build **Hideout modules** (medstation, workbench, intelligence center) that unlock crafting, passive resource generation, and healing. Strength: the base *is* the progression fantasy — visible, spatial, always-there between raids, and it gates capability (you literally can't craft X until the module exists). Weakness: brutally grindy, opaque prerequisite webs, and stash-management-as-tax that many players resent. **Lesson for us:** a spatial, visible base whose modules *unlock capability* (not just add numbers) is exactly the "Animal-Crossing-ish sense of place and pride" the GDD §8 Yard track wants — but keep prerequisite chains legible and few.
- **Dark and Darker — gear-as-progression, thin meta.** Almost all power lives in the *gear you carry into and lose from* a raid; the persistent layer is mostly a stash + cosmetic/class unlocks. Strength: every raid's stakes stay high because power is at risk. Weakness: little between-run *building*, so the "life" layer is thin. **Lesson:** THE FAR YARD deliberately wants the opposite balance — a **soft-roguelite** where the *life persists* and only the *run* resets (GDD §6). Our meta layer should be rich where Dark and Darker's is thin, precisely because the surface warmth (Pillar 3) is half the game.
- **Zero Sievert — hideout stash + trader tiers + skill points.** Single-player twin-stick extraction (our nearest structural twin): persistent stash, workbench upgrades, trader reputation that unlocks better stock, and a light **skill tree** (carry weight, health, stealth). Strength: the trader-reputation gate ties *social standing* to *what you can buy* — directly analogous to our **Relationships track** (confidants unlock cheaper upgrades / weird-goods fences). **Lesson:** reputation-gated shops are a clean, low-tech way to make Relationships mechanically matter without a bespoke system.

### 1.2 Roguelite meta-progression (calibration and power-creep)

- **Hades — spendable meta-currency (Darkness/Keys) + the Heat counter-lever.** You permanently buy stat/ability upgrades in the Mirror of Night, which *does* make runs easier over time — but acquiring the currency **requires risk**, and the **Heat/Pact system lets the player voluntarily re-add difficulty** to offset the power gained. Strength: the difficulty valve. **Lesson (critical):** we already own this valve — the **Instability scalar `I`** and the **quota ladder** (`quota_target` escalates each cleared run). Rising meta-power is *supposed* to be met by rising `I`/quota. Design the two curves as a matched pair, not independently.
- **Dead Cells — meta-currency + Metroidvania capability unlocks.** Two layers: permanent stat/blueprint spends *and* permanent **traversal abilities** (runes) that open previously-unreachable areas. Strength: the traversal unlocks are the memorable ones — they change *where you can go*, not just how hard you hit. **Lesson:** this is the exact template for our **tools-as-traversal** (grapple → vertical zones, breather → toxic zones, ward → deep things; GDD §7). Gate *bands/zones* behind *capabilities*, not behind stat thresholds.
- **Rogue Legacy — the manor (stat tree) + the trade-off knobs.** A big spendable stat tree (permanent HP/damage/mana), but gold is soft-wiped each run (you spend or lose it), and equipping upgrades raises the **"weight"** that reduces a gold bonus — a built-in anti-snowball tax. Weakness: pure vertical stat trees are the archetype most accused of *trivializing* the early game. **Lesson:** if we include a stat tree at all, borrow the *cost* mechanic (spend-or-lose pressure, a downside on stacking) rather than the flat-power shape.
- **Vampire Survivors / Enter the Gungeon — the two poles of the debate.** VS bakes permanent stat buys (PowerUps) that *do* creep power; Gungeon deliberately **never raises player power** and only widens the *item pool* future runs can draw from. The recurring community verdict (ResetEra threads; GameRant) is that **stat-based meta-progression is the one most likely to "ruin" a roguelite** by removing agency from difficulty, while **unlock-based (horizontal) progression ages better** because "every unlock should change player *behavior*, not just numbers." **Lesson — the load-bearing one for our whole design:** bias hard toward **horizontal** unlocks (new tools, recipes, zones, capabilities) and treat raw-stat buys as a small, tightly-`I`-budgeted minority.

### 1.3 Life-sim / salvage tool-tier progression (the surface half)

- **Stardew Valley — material-gated tool tiers.** Each tool climbs copper → steel → gold → iridium; **no tier-skipping**, each tier costs a fixed ore count + escalating gold, and some tiers **gate access** (the better watering can/axe/pickaxe let you reach or clear things you couldn't). Strength: dead-simple, legible, and the gating gives tiers *meaning* beyond efficiency. **Lesson:** a **linear, material-gated tool ladder** is a perfect fit for our **Gear/Tech track** where the "material" is **Salvage** — this is how Salvage finally gets its sink (see §2/§3). The "no skipping" rule also naturally paces spend across acts.
- **Dave the Diver — depth/air/knife tiers, story- and material-gated.** Air Tank (dive longer) and Diving Suit (survive deeper) are the *required-to-progress* upgrades; the **UV light is a hard gate** past specific terrain; knife upgrades unlock only after a **story beat**. Strength: cleanly separates *"more of a resource I already use"* (air, capacity) from *"a key that opens a door"* (UV light, depth suit). Weakness: some upgrades are so mandatory they're not really choices. **Lesson:** classify every proposed upgrade as **capacity** (more of an existing budget — light, slots, health) vs **key** (unlocks a place/interaction). Keys should be *earned via Knowledge/story*, capacity via *Money/Salvage*. This maps directly onto our currency roles.
- **Dredge — the spatial-grid boat.** Upgrades are **inventory-grid modules** (bigger nets, more hold, engine speed, better lights) placed into a **spatial rig** that is itself an inventory-tetris puzzle; light/darkness and "panic" pressure mirror our instability/exposure. Strength: the *carry rig is the upgrade surface* — buying capacity and arranging it is one system. **Lesson:** our **slot inventory** (`InventoryConfig.base_max_slots`, currently 12) and the GDD's "anomaly-containment slots for deep items" want to be a Dredge-style **upgradeable rig**, not just a number that ticks up.
- **Hardspace: Shipbreaker — certification-gated tool/suit tree.** Upgrades bought with **LYNX Tokens** (earned by meeting salvage goals), each **gated behind a Certification Rank**, spanning tool nodes (cutter range, tether count/lifetime) and **suit nodes (oxygen, fuel, thruster braking)** — a steady tier-locked climb from safe ships to volatile reactors. Strength: rank-gating paces the whole tree to content difficulty automatically. **Lesson:** a **rank/act gate on upgrade availability** (tie tiers to `knowledge_level` / act) is a cheap, robust way to keep upgrade power in lockstep with `I` and the band the player can actually reach.
- **Moonlighter — dual life: dungeon dive + shop/town rebuild.** Structurally our closest sibling (dive to loot, return to sell, spend to upgrade weapons *and* rebuild the town's shops which unlock services/enchants). **Lesson:** the town-rebuild-unlocks-services pattern is exactly our **Yard track** (workshop → recipes, sorting line → better sell, stabilizer → safer dives, shopfront → laundering/exposure relief).

### 1.4 Cross-cutting synthesis (what the survey agrees on)

1. **Horizontal beats vertical for longevity and challenge-preservation.** Prefer unlocks that change *what the player can do* over unlocks that change *a number*.
2. **Gate content with capabilities, not stat walls.** The memorable upgrades (Dead Cells runes, Dave's UV light, our grapple/breather/ward) open *places and interactions*.
3. **A visible, spatial base is a progression fantasy in itself** (Tarkov hideout, Moonlighter town, Dredge rig) — and it's the natural home for our Yard track and Act-2 defenses.
4. **Match the meta-power curve to a difficulty valve you control** (Hades Heat = our `I` + quota ladder). Never let them float independently.
5. **Distinguish "capacity" upgrades (buy with soft currency) from "key" upgrades (earn via progression/story).** This is how three currencies stay non-interchangeable.
6. **Give each currency a real sink** or it's a dead currency (`12_economy_balance_model.md` §5). Salvage and Lore currently have none — the upgrade layer is where they get one.

---

## 2. What fits THE FAR YARD

Mapping the survey onto the four GDD tracks and the as-built systems. The organizing rule, from §1.4 and the instability spike: **the Gear and Yard tracks are where players spend the soft/hard currencies (Salvage/Money) on capacity and capability; the Knowledge track is the *key* dispenser (Lore) that gates bands and unlocks recipe/tool *conception*; Relationships is a cross-cutting discount/access multiplier.** Cross-feeding (GDD §8 — an upgrade buyable *or* built from Salvage *or* unlocked via Lore) is honored by letting a single upgrade Resource declare costs in more than one currency and a prerequisite in Knowledge.

### 2.1 The upgrade categories, mapped

Below, each category names its **track**, its **currency role** (per `12_economy_balance_model.md`: Money=hard/pressure, Salvage=soft/volume, Lore=capped/gating), whether it's **capacity vs key**, where it **persists** (always meta-state — never run-state), and the **as-built hook** it modifies.

| # | Category | Track | Currency (primary) | Cap/Key | As-built hook it modifies |
|---|---|---|---|---|---|
| 1 | **Carry / inventory** — bigger bag, sorting satchel, **containment slots** for anomalous deep items | Gear + Yard | Salvage (+Money) | Capacity | `InventoryConfig.base_max_slots` (currently 12); containment via `JunkItem.containment_flags` |
| 2 | **Survivability** — max health, armor/plating, hazard (toxic/reality) resistance | Gear | Money→Salvage by tier | Capacity | Player Health component (M2); band hazard checks |
| 3 | **Tools-as-capability** — grapple (vertical zones), breather (toxic + stealth), saw (blocked paths), ward (perceive/repel deep things), nail-gun (fight/repair) | Gear/Tech | Salvage + a **Lore insight to conceive** | **Key** | Traversal/interaction gates per band; `RunConfig`-style per-run loadout |
| 4 | **Dive clock / light** — larger light budget, slower drain, refuel caches | Gear + Yard | Money (early) | Capacity | `DiveClockConfig` (`max_light=60`, `drain_per_second=1.0`) |
| 5 | **Movement** — move speed, stamina, dash/roll, quieter footfalls (stealth) | Gear | Salvage | Capacity | Player `CharacterBody2D` movement params (M2) |
| 6 | **Extraction aids** — bigger **pockets** on death, deployable emergency gate, faster extract, "insurance" on a lost haul | Gear + Yard | Money + Lore (gate device) | Mixed | `RunRules.pockets_fraction` (0.20); gate placement (`GATE_SPAWN_OFFSET`) |
| 7 | **Home-base / workshop** — workshop (unlock recipes), sorting line (better sell / faster), shopfront (**laundering → exposure relief**), **stabilizer** (lower `I` growth / safer dives), **defenses** (Act-2 incursions, Act-3 rival raid) | Yard | Money→Salvage; stabilizer needs Lore | Mixed (mostly Key) | New Yard meta; feeds `I`, exposure, sell rate, recipe unlocks |
| 8 | **Exposure resistance** — discreet fences, laundering capacity, "lie-low" facilities, confidant-trust that keeps them quiet | Yard + Relationships | Money + Relationships | Capacity (of the Heat buffer / decay) | `exposure` (Heat model) — passive decay & mitigation sinks (`13_exposure_pacing.md`) |
| 9 | **Knowledge / recipe unlocks** — decoded recipes, new craft branches, **band access**, ability to perceive deep things | Knowledge | **Lore** | **Key** | `knowledge_level`, `unlocked_recipes`; gates acts/bands (GDD §12) |
| 10 | **Relationships** — confidants that grant: cheaper upgrades, a getaway driver, a weird-goods fence, lore expertise, +capacity (a friend doubles your bag) | Relationships | **Not bought with Money** — trust/inclusion | Multiplier | New confidant meta; cross-cuts costs, sell, exposure, capacity |

**Currency-role check (against `12_economy_balance_model.md`):**
- **Salvage** finally gets its **grind→exponential sink**: the Gear tool-tier ladder (#1, #2, #5) and Yard modules (#7) priced with a geometric `cost = base × mult^tier`. This is the report's prescribed soak for grindable soft currency.
- **Money** stays the **pressure currency** feeding the **debt/quota** sink (`quota_target`) — upgrades compete with debt payments for Money, which is the intended tension. Early tiers (#2, #4, #6) are Money-priced so Money always has an alternative sink to debt.
- **Lore** stays **capped/gating**: it buys **keys** (#3 tool conception, #9 band access, #7 stabilizer), never raw power. Because Lore is capped per act, it can't be grinded to skip gates.

### 2.2 How upgrades are authored as data (`.tres` against a `class_name`)

The **`ShopItem` pattern already in the repo is the template** (`data/shop/shop_item.gd`): a pure `Resource` with `id`, `display_name`, `description`, `cost`, `persistent`, `greybox_color`, and — critically — the **`effect_kind: StringName` seam** whose docstring already anticipates *"a future task branches GameState/_apply on this without a schema change … a next-run RunConfig modifier or a passive meta stat."* That seam is exactly the extension point this whole system needs. Recommended evolution:

Introduce an **`UpgradeDef`** Resource (generalizing `ShopItem`) that adds:
- **Multi-currency cost** — `cost_money`, `cost_salvage`, `cost_lore` (any combination; honors GDD §8 cross-feeding). `ShopItem.cost` (Money-only) is the degenerate case.
- **Track + tier** — `track: {GEAR, YARD, RELATIONSHIP, KNOWLEDGE}`, `tier: int` (drives the exponential cost formula and the "no-skip" ordering).
- **Prerequisites** — `requires_knowledge: int` (act/band gate, Hardspace-style), `requires_upgrades: Array[StringName]` (tier chain / Tarkov module web — keep short), `requires_confidant: StringName` (Relationships gate).
- **Effect binding** — keep `effect_kind` as the discriminator, add a typed `effect_params: Dictionary` (e.g. `{"stat":"max_slots","delta":4}` or `{"config_override":"grapple_enabled"}`). The two effect *shapes* the survey demands:
  - **Passive meta stat** (capacity upgrades #1,#2,#4,#5,#6,#8) — a permanent modifier read at run-start when building run-state (e.g. inventory bag sizing, clock budget).
  - **Next-run capability** (tools/keys #3,#7,#9) — an unlock that flips a flag consumed when assembling the dive, naturally expressed as a **`RunConfig` override** (the existing `RunConfig` is the proven "run-scoped modifier" object; `_dive_config` staging already exists in `GameState`).

**Persistence (the hard boundary, TDD §2/§3):** every upgrade's *ownership* lives in **meta-state** exactly like `owned_items` does today (`store_var` as id-strings, rehydrated from a catalog — the same pattern as `banked_junk`). The *effect* is applied to **run-state at run assembly** and never stored there. A **schema bump** (meta v4 → v5) adds an `owned_upgrades`/effect-ledger field with a stepwise migration + a QA fixture — the exact template already documented in `M1_As_Built.md` §Save schema. Nothing about upgrades should ever be written into `run_inventory`, `active_run_config` (as persisted), or any run field.

### 2.3 Where the survey's cautions bite our specific design

- **Anti-trivialization (the `I` coupling).** Because loot value *and* enemy power both scale with `I` (+15%/band), a flat "+X% sell value" or "+Y max HP" upgrade is *relatively* weaker the deeper you go — a natural, desirable damping if we express upgrade effects as **additive-to-base** rather than **multiplicative-on-`I`**. Recommend: capacity upgrades give **absolute** budgets (e.g. +4 slots, +15s light), so their *relative* help shrinks as `I` grows, preserving deep-band tension. Reserve any *multiplicative* effect for the **stabilizer** (which is *supposed* to bend the `I` curve — that's its fantasy) and price it in Lore behind a Knowledge gate so it's rare and deliberate.
- **Cap the investment loop.** `12_economy_balance_model.md` §4 warns against runaway "investment" sources (upgrades that increase yield that buy more upgrades). If a "+sell value" or "+loot density" upgrade exists, it must be **hard-tier-capped** (Stardew "no-skip", Hardspace rank-gate) so it converts a would-be exponential into a trickle.
- **Soften the base as a gate, not a wall.** Tarkov's opaque prereq webs are the failure mode; keep `requires_upgrades` chains **short and legible** (Stardew's linear ladder), and telegraph the next unlock.

---

## 3. Integration sketch (against the real as-built APIs)

Data shapes and pseudocode written against the *actual* current surface (`ShopItem`, `GameState`, `Economy`, `RunConfig`, `InventoryConfig`, `DiveClockConfig`, `RunRules`, `EventBus`). Illustrative, not final.

### 3.1 The `UpgradeDef` Resource (generalizes `ShopItem`)

```gdscript
class_name UpgradeDef
extends Resource
## One purchasable/unlockable upgrade. Meta-state ownership; effect applied to
## run-state at assembly. Generalizes ShopItem (data/shop/shop_item.gd): keeps its
## `effect_kind` seam, adds multi-currency cost + track/tier + prereqs + typed params.

enum Track { GEAR, YARD, RELATIONSHIP, KNOWLEDGE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var track: Track = Track.GEAR
@export_range(1, 9) var tier: int = 1

# --- Cross-fed cost (GDD §8): any combination; 0 = "not priced in this currency" ---
@export var cost_money: int = 0
@export var cost_salvage: int = 0
@export var cost_lore: int = 0

# --- Prerequisites (legible, short chains — Stardew/Hardspace, NOT Tarkov webs) ---
@export var requires_knowledge: int = 0                 # act/band gate → GameState.knowledge_level
@export var requires_upgrades: Array[StringName] = []   # tier chain
@export var requires_confidant: StringName = &""        # Relationships gate (empty = none)

# --- Effect binding (reuses ShopItem's discriminator idea) ---
## &"none"            → stub spend (M1.6 behaviour, proves the loop)
## &"meta_stat"       → permanent capacity modifier, read at run assembly
## &"run_capability"  → flips a RunConfig flag for the next dive (tool/key unlock)
## &"recipe"          → adds to GameState.unlocked_recipes
## &"knowledge"       → raises GameState.knowledge_level (band gate)
@export var effect_kind: StringName = &"none"
@export var effect_params: Dictionary = {}   # e.g. {"stat":"max_slots","delta":4}
@export var greybox_color: Color = Color.LIGHT_GREEN
```

`UpgradeCatalog` mirrors `ShopCatalog` (`@export var items: Array[UpgradeDef]`) — data-authored, no directory globbing (the repo's stated reason).

### 3.2 Meta-state + the purchase/apply seam (extends `Economy`/`GameState`)

`GameState.purchase(item_id, price)` and `owns(item_id)` already exist (forwarding to `Economy`). Generalize purchase to multi-currency and add the apply step. Ownership persists exactly like `owned_items` (id-strings via `store_var`, rehydrated from catalog):

```gdscript
# Economy (systems/economy.gd) — new meta field, same pattern as owned_items.
var owned_upgrades: Array[StringName] = []   # persisted as ids; META schema v4→v5 + fixture

func can_afford(u: UpgradeDef) -> bool:
    return money >= u.cost_money and salvage >= u.cost_salvage and lore >= u.cost_lore

func purchase_upgrade(u: UpgradeDef) -> bool:
    if owned_upgrades.has(u.id) or not can_afford(u):
        return false
    # Debit via the SAME ledger so currency_changed(source) telemetry stays honest.
    add_currency(&"money",   -u.cost_money,   &"upgrade")
    add_currency(&"salvage", -u.cost_salvage, &"upgrade")
    add_currency(&"lore",    -u.cost_lore,    &"upgrade")
    owned_upgrades.append(u.id)
    return true
```

```gdscript
# GameState — gate + purchase + persist, then let the effect apply at run assembly.
func try_buy_upgrade(u: UpgradeDef) -> bool:
    if u.requires_knowledge > knowledge_level: return false
    for req in u.requires_upgrades:
        if not _economy.owned_upgrades.has(req): return false
    if u.requires_confidant != &"" and not has_confidant(u.requires_confidant): return false
    if not _economy.purchase_upgrade(u): return false
    if u.effect_kind == &"recipe":
        unlocked_recipes.append(StringName(u.effect_params.get("recipe_id","")))
    elif u.effect_kind == &"knowledge":
        knowledge_level = maxi(knowledge_level, int(u.effect_params.get("level", knowledge_level)))
    SaveManager.save_meta(0)                 # same atomic write + .bak path
    EventBus.upgrade_purchased.emit(u.id)    # HUD/Yard/Telemetry observers
    return true
```

**Capacity upgrades read at run assembly** — the boundary-clean application point. `start_run()` already builds `run_inventory` from `InventoryConfig.base_max_slots`; interpose the owned-upgrade modifier so the *meta* upgrade sizes the *run-state* bag without ever persisting into run-state:

```gdscript
# GameState._make_run_inventory() — apply owned meta-stat upgrades to the fresh bag.
func _make_run_inventory() -> RunInventory:
    var inv := RunInventory.new()
    var cfg: InventoryConfig = load(INVENTORY_CONFIG_PATH) as InventoryConfig
    inv.max_slots = cfg.base_max_slots if cfg else inv.max_slots
    inv.max_slots += _owned_stat_sum(&"max_slots")   # sums effect_params.delta over owned_upgrades
    return inv
```

Same shape for the dive clock (`DiveClockConfig.max_light += _owned_stat_sum(&"light")`) and pockets (`RunRules.pockets_fraction`) at their read points.

**Capability/key upgrades feed `RunConfig`** — the proven run-scoped modifier object. The dive-config staging seam (`stage_dive_config` / `dive_config_or_default`) already exists; owned tool unlocks translate into `RunConfig` flags the dive scene reads, so a purchased grapple/breather/ward simply toggles a traversal capability for that dive.

### 3.3 Economy hooks (faucet/drain wiring — closes the dead-currency gap)

Per `12_economy_balance_model.md`, wire distinct sinks so no currency floods or starves:
- **Salvage faucet** (currently absent): add a Salvage drop/refine source in the dive (e.g. a `salvage_awarded` on certain junk, or a refine step converting junk → Salvage). **Salvage sink:** the Gear/Yard tier ladders priced `cost_salvage = base × mult^tier` (the report's prescribed exponential soak for grind currency). Cap any yield-boosting upgrade's tier to avoid a runaway investment loop.
- **Money:** upgrades are a *competing* sink alongside the **debt/quota** (`quota_target`). This is intended tension — each run's Money must choose "pay the quota vs. buy the tool." Keep the debt curve tracking the *upgraded* income curve, not raw faucet (report §7).
- **Lore faucet** (currently absent): decoded from anomalous finds / Cyrus recordings / dreams (GDD §8), **capped per act**. **Lore sink:** Knowledge track keys (band access, tool conception, stabilizer) — gating, never raw power.
- **Exposure interplay:** buying/holding upgrades and visible wealth should feed the **Heat model** (`13_exposure_pacing.md`) — e.g. laundering/shopfront upgrades *raise the passive-decay rate or the inert buffer* (a mitigation sink), while conspicuous spends nudge exposure up. This makes the Yard exposure-resistance category (#8) a real management lever, not flavor.

### 3.4 Milestone sizing (what's M2 vs M3 vs later)

- **M2 (vertical slice — one full day).** The loop already contains an **"upgrade" step**; M2 needs the *minimum* version: **generalize `ShopItem`→`UpgradeDef`** (multi-currency + `effect_kind` wired for real), ship **1–3 real effects** end-to-end — the cleanest are **carry-capacity (#1)** and **one tool with traversal use (#3)** (TDD §7 M2 explicitly calls for "one tool with traversal use"). Prove the meta-spend → run-state-effect boundary and the save-schema bump. Keep it "configurable-not-balanced" (M1.6 idiom).
- **M3 (systems breadth — Acts 1–2).** The **four tracks fully wired** (TDD §7 M3): the full **Gear ladder**, the **Yard base** (workshop/sorting/shopfront/stabilizer + Act-2 **defenses**), **Knowledge gating** (Lore → band access), **exposure-resistance** upgrades, and **Relationships/confidant** unlocks as discount/access multipliers. **Salvage and Lore faucets/sinks go live here** so all three currencies function. **Build the `economy_model.xlsx` workbook first** (`12_economy_balance_model.md` §8) and tune the tier costs/curves against it before M3 balancing.
- **Later (M4+).** Act-3 repurposing of Yard defenses against the **rival diver**; anomaly-containment inventory tetris for far-band items; deeper stabilizer/`I`-bending tech; ending-branch-relevant Knowledge unlocks.

---

## 4. Open Questions

Stated as questions with trade-offs. Items tagged **[DIRECTOR]** are vision/fun/scope calls that should not be self-resolved.

1. **[DIRECTOR] How much *vertical* (raw-stat) progression at all?** The survey's strongest signal is that stat trees trivialize roguelites; our `I`-coupling damps but doesn't eliminate the risk. *Trade-off:* an all-horizontal design (tools/keys/recipes only, à la Gungeon) best preserves the push/cash-out tension but may feel less *rewarding* to a life-sim audience that likes visible number-growth (Stardew/Dave). *Recommendation:* bias ~80% horizontal, allow a small, tier-capped, absolute-value (non-`I`-multiplicative) stat minority (health, slots, light). Needs a fun-gate read.

2. **[DIRECTOR] Is the Yard a real spatial/placement base (Tarkov/Dredge/Moonlighter) or a menu of module unlocks?** *Trade-off:* spatial placement is a huge chunk of the "sense of place and pride" fantasy and sets up Act-3 tower-defense, but it's a large build (grid, placement UI, defense sim) — the GDD §15 already flags "yard-defense depth: light flavor vs. real TD mode" as open. *Recommendation:* menu-of-modules for M3, spatial/placeable in M4 when defenses become gameplay. Scope call.

3. **Should tool/key upgrades be *loadout-selected per run* or *always-on once owned*?** GDD §5 says "pick gear loadout" at morning prep (implying selection/limited slots — a push/cash-out lever: bring the ward *or* the grapple), but always-on is simpler and matches Dead Cells runes. *Trade-off:* loadout slots add a meaningful pre-dive decision and let us cap simultaneous power (anti-trivialization) but add UI and a slot-economy to balance. *Recommendation:* always-on for capacity; **loadout-limited for active tools** (honors GDD §5) — but confirm the slot count at playtest.

4. **How is Relationships mechanically modeled** — a discount multiplier on `UpgradeDef` costs, a gate (`requires_confidant`), a capacity boost (a friend "doubles your bag"), or all three? *Trade-off:* "all three" is richest but couples Relationships into many systems (harder to balance/tune); a single mechanism (e.g. cost discount) is clean but thin. Zero Sievert's reputation-gated shop is the cheapest robust option. *Recommendation:* start with gate + discount; add capacity-share (the friend-doubles-bag fiction) only if it reads as fun.

5. **Does the *stabilizer* bend `I` globally, per-band, or only add a flat safety buffer?** This is the one upgrade allowed a multiplicative effect, so it's balance-critical against `05_difficulty_instability_scaling_model.md`. *Trade-off:* a global `I`-slope reduction is powerful and satisfying but risks trivializing deep bands; a flat per-dive buffer (grace time before `I` bites) is safer. *Recommendation:* flat/early-grace first, model in the workbook before allowing any slope change.

6. **Do we need a *respec/refund* path** for owned upgrades? Roguelites split on this (Rogue Legacy allows equip/unequip; Tarkov never). *Trade-off:* respec lowers the stakes of a bad buy (good for experimentation) but weakens the weight of the spend decision and complicates the save schema. *Recommendation:* no respec in M2/M3 (spends are permanent, matching the debt-weight theme); revisit only if playtest shows buyer's-remorse friction.

7. **Where does Salvage's faucet live, and how does refining work?** Salvage has no source today. Options: (a) certain junk *is* Salvage, (b) a refine step converts banked junk → Salvage at the Yard, (c) rare drops only. *Trade-off:* (b) gives the Yard/workshop a job and keeps Salvage "hard/deliberate" per its role, but adds a refine UI; (a) is simplest but blurs Salvage vs. Money. *Recommendation:* (b) refine-at-workshop, so the Yard upgrade *unlocks* Salvage production — capability-gated currency, elegant.

8. **Should any upgrade be *consumable/per-run* rather than permanent?** `ShopItem.persistent` already models this (currently always true). Consumables (fuel, ammo, a one-shot emergency gate) fit the "costs that bite" pillar (GDD §7) and give Money a repeatable sink. *Trade-off:* consumables add inventory/loadout bookkeeping and a re-buy loop; permanents are cleaner meta. *Recommendation:* ship extraction/combat *consumables* (emergency gate, ammo, breather filters) as a deliberate repeatable Money sink in M3 — the report wants repeatable sinks for a grind economy's longevity.

9. **Save-schema cadence:** one bump for the whole `owned_upgrades` ledger now, or incremental bumps as tracks land? *Trade-off:* one wide field up front (with `effect_params` as an open dict) avoids repeated migrations but bakes in a shape early; incremental is safer but costs a fixture per bump. *Recommendation:* one `owned_upgrades: Array[StringName]` field (ids only; effects resolved from catalog at load, like `banked_junk`), so adding upgrades never bumps the schema again — only adding *new effect_kinds* touches code, not the save.

---

## Sources

- [Daniel Cook (Lost Garden), "Value chains"](https://lostgarden.com/2021/12/12/value-chains/) — faucet/drain, source/sink power-matching, dead currencies, capping investment loops (via `12_economy_balance_model.md`).
- [GameRant, "Roguelite Games With The Best Progression Systems"](https://gamerant.com/roguelite-games-with-best-progression-systems/) — Hades meta-currency + Heat valve, Dead Cells meta + Metroidvania unlocks, unlock-vs-stat framing.
- [GameBrief, "What is Meta-Progression?"](https://www.gamebrief.net/glossary/meta-progression) — calibration problem (too weak = meaningless, too strong = trivializes challenge).
- [ResetEra — "stat-based meta-progression is ruining roguelites"](https://www.resetera.com/threads/im-starting-to-feel-that-stat-based-meta-progression-is-starting-to-ruin-roguelites-generally-speaking.1509337/) and [ResetEra — "Do you like meta progression?"](https://www.resetera.com/threads/do-you-like-meta-progression-in-your-roguelikes-roguelites.1341955/) — community verdict favoring horizontal unlocks.
- [Entalto Studios, "5 Essential Tips to Make Your Roguelite Work"](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/) — horizontal vs vertical, "does this unlock change player behavior?"
- [GameRant, "How To Increase Stash Space In Escape From Tarkov"](https://gamerant.com/escape-from-tarkov-how-upgrade-stash-space/) and [TV Tropes, "Extraction Shooter"](https://tvtropes.org/pmwiki/pmwiki.php/Main/ExtractionShooter) — Tarkov hideout/stash, Zero Sievert & Dark and Darker positioning.
- [Theria Games, "Stardew Valley Tools and Upgrades"](https://theriagames.com/guide/stardew-valley-a-guide-to-tools-and-upgrades/) — material-gated linear tool ladder, no-skip, gating access.
- [TheGamer, "Best Upgrades in Dave the Diver"](https://www.thegamer.com/dave-the-diver-best-upgrades-ranked/) and [Dave the Diver Wiki — Equipment](https://dave-the-diver.fandom.com/wiki/Equipment) — air/depth capacity vs. UV-light key gates; story-gated tiers.
- [Hardspace: Shipbreaker Wiki — Upgrades](https://hardspaceshipbreaker.fandom.com/wiki/Upgrades) — LYNX-token, certification-rank-gated tool/suit tree.
- Internal: `design/Junkyard_GDD.md` §§5–12, `design/Junkyard_Technical_Design.md` §§3,7, `design/research/06152026/{05_difficulty_instability_scaling_model,12_economy_balance_model,13_exposure_pacing}.md`, `design/M1_Tasks/{M1_As_Built,M1_Design_Decisions}.md`, `Game/data/shop/shop_item.gd`, `Game/data/junk/junk_item.gd`, `Game/data/run_config/run_config.gd`, `Game/systems/game_state.gd`.
