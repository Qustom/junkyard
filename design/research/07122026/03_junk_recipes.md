# Recipes for Junk — Crafting, Repair & Combination in THE FAR YARD

*Research report. Scope: how salvaged junk becomes useful or valuable through recipes — repair, combine, break down, and process — and how recipes are discovered/unlocked. Grounds the GDD §8 "Repair / fixing (recipe-based)" promise and the already-present `unlocked_recipes` meta-state in a concrete, data-as-Resources spec with prior-art backing and an economy that respects `design/research/06152026/12_economy_balance_model.md`.*

**Status:** research + proposal. Judgment calls (fun, tone, scope) are flagged for the human Director, not decided here.

---

## 0. What the repo already promises (grounding)

Before proposing anything, here is what THE FAR YARD has *already committed to* — the design and the code both point the same direction, which is a strong signal the recipe system should slot in rather than invent:

- **GDD §8, "Repair / fixing (recipe-based)"** (a Resolved Decision, §14): *"Turning junk into sellable goods is a recipe system, not a tactile minigame. You acquire recipes (bought, found below, or unlocked via Lore), and fixing consumes the broken item plus required components/Salvage to produce the fixed, higher-value good. Keeps the loop fast and the depth in* what *you can make, not in execution. New recipes are a meaningful reward tier from deep dives and Knowledge."* This already fixes four things: no minigame, three unlock sources (buy / find / Lore), consume-inputs→produce-output, and recipes-as-reward-tier.
- **Three currencies / four tracks (GDD §8).** Money (sell fixed junk), **Salvage** (rare components, *not sold* — "the hard crafting ingredient for advanced gear and key yard restorations"), Lore/Knowledge (unlocks). Recipes are the transform node that GDD §8's "cross-feeding" hangs on — a tool "might be bought, or built from a rare part, or only realized once you understand a deep principle."
- **Meta-state already has the hooks.** `Game/systems/game_state.gd` / `economy.gd`: `unlocked_recipes: Array[StringName]` is a persisted meta field (serialized in `to_meta_dict`, migrated in `from_meta_dict`, cleared on `wipe_meta`), and `knowledge_level: int` gates acts/bands. `salvage: int` and `lore: int` currencies exist and flow through `add_currency`. So a recipe system needs **no schema migration to store recipe ownership** — it needs the recipe *data*, the crafting *action*, and the *unlock triggers*.
- **JunkItem is the canonical content Resource** (`Game/data/junk/junk_item.gd`): `id`, `display_name`, `description`, `origin_band` (surface/near/temporal/lateral/far), `tier` (1–5), `slot_size`, `base_sell_value`, greybox color/shape. Recipes consume and produce `JunkItem`s by `id`.
- **The catalog idiom is established.** `JunkCatalog` (`items: Array[JunkItem]` + `spawn_weights_by_id: Dictionary[StringName,float]`) and `ShopCatalog`/`ShopItem` show the exact pattern a `RecipeBook`/`Recipe` pair should follow: one `.tres` per entry, an authored `Array` catalog, keyed dictionaries, objects-OFF-friendly serialization by `id`.
- **The 8 shipped junk items and their values** (the economy recipes must respect):

  | id | band | tier | sell |
  |---|---|---|---|
  | `junk_scrap_bolt` | surface | 1 | 3 |
  | `junk_cable_coil` | surface | 1 | 8 |
  | `junk_copper_pipe` | near | 2 | 15 |
  | `junk_hubcap` | near | 2 | 20 |
  | `junk_circuit_board` | temporal | 3 | 45 |
  | `junk_car_battery` | temporal | 3 | 55 |
  | `junk_radiator` | lateral | 4 | 80 |
  | `junk_engine_block` | far | 5 | 120 |

---

## 1. Broad survey / prior art

Recipe systems cluster into a few patterns. Each is summarized with the strength/weakness that matters for THE FAR YARD.

### 1.1 Junk → components → craft (Fallout 4 / Fallout 76)
Junk is scrapped at a workbench into **components** ("scrap"), which are the real crafting currency; plans/mods then consume components. Fallout 76 added "scrap all junk" and a Scrapbox because raw junk was too heavy. ([Fallout wiki](https://fallout.fandom.com/wiki/Fallout_76_junk_items), [Steam: turning junk into components](https://steamcommunity.com/app/377160/discussions/0/1742227264205556902/))
- **Strength:** a clean two-stage value chain — raw junk is *legible loot*, components are *fungible fuel*. This is exactly Lost Garden's "raw resource → intermediate good → sink" chain, and it maps 1:1 onto our Money-junk vs. Salvage split.
- **Weakness:** at scale it becomes inventory bookkeeping (dozens of component types, "which junk gives adhesive?"). The lesson: keep the **component vocabulary tiny**. THE FAR YARD already has this discipline — Salvage is a *single* abstract currency, not 30 named components. Don't regress into a Fallout component matrix.

### 1.2 Combine two items → a new item (Dead Rising combo weapons)
Two specific items + a **blueprint** → a combo weapon; 100+ combos. Dead Rising 3/4's key innovation: **category unlocks** — once you unlock "Blades," *any* blade-category item substitutes for the specific one in a blueprint. ([Dead Rising wiki: combo weapons](https://deadrising.fandom.com/wiki/Combo_Weapons_(Dead_Rising_4)), [The Squid Chamber history](https://squiddude.wordpress.com/2018/02/16/dead-risings-combo-weapon-problem-a-history/))
- **Strength:** combining is *legible and toy-like* — "pipe + battery = stun baton" reads instantly. The category abstraction fights combinatorial explosion and rewards system-mastery.
- **Weakness:** 100+ recipes is a content treadmill; most players use ~5. Ship **few, strong** combines, not a catalog to complete.

### 1.3 Blueprint-gated unlocks in a roguelite (Dead Cells)
Blueprints drop from enemies/secret areas at **very low rates (~0.4%)**, are **dropped on death** unless returned to the Collector NPC, then unlock the item *for purchase with Cells*. ([Dead Cells wiki](https://deadcells.fandom.com/wiki/Blueprints), [drop-rate discussion](https://steamcommunity.com/app/588650/discussions/0/2217311444338096980/?l=english&ctp=3))
- **Strength:** two-step unlock (find blueprint → *then* invest currency) makes each unlock a deliberate, savored beat; the "return it or lose it" extraction-risk on blueprints is *directly* our extraction fiction — a recipe fragment is unbanked haul until you carry it home.
- **Weakness:** the community's loudest complaint is **pure-RNG gating in a skill game feels bad**. Very-low blind drop rates breed frustration. Lesson: gate recipes on *reaching depth / spending Knowledge*, not on a 0.4% coin flip. Determinism-friendly (found in a fixed deep cache, or bought once known) beats a slot machine.

### 1.4 Experimentation / emergent discovery (BOTW cooking, Noita alchemy)
No recipe list; players toss ingredients in a pot and learn by result. Praised for *genuine discovery* and emergent play. ([First Person Scholar](https://www.firstpersonscholar.com/stirring-the-pot/), [Kulik on BOTW feedback](https://medium.com/@chronospherics/how-breath-of-the-wild-leverages-intuition-familiarity-and-feedback-to-avoid-explicit-f9b5a3206117))
- **Strength:** discovery is a real emotion; experimentation gives player agency and "I found this myself" ownership. Fits Pillar 5 ("Understanding is power / Curiosity is a stat").
- **Weakness (well-documented):** BOTW cooking is **slow, cumbersome UX**, and despite a huge option space has "surprisingly little room for experimentation" because effects cancel — depth *appeared* without *being* there. And the academic tension (DHQ, *Crafting in Games*): experimentation that **consumes rare resources on a wrong guess punishes the player and discourages exploration**. Lesson: experimentation is a *flavor top-note*, viable only if failures are cheap; the backbone must be legible recipes.

### 1.5 Repair-to-sell / restoration flipping (Car Mechanic Simulator, Potion Craft)
Buy a cheap wreck → restore → resell for much more; **parts in worse condition yield bigger profit margins**; the **welder tool** is the unlock that makes almost any wreck instantly profitable. Potion Craft's Alchemy Machine starts broken and costs 2,000 gold to repair before it produces. ([CMS 2021 resale thread](https://steamcommunity.com/app/1190000/discussions/0/3413181204140156841/), [CMS profit guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2590379392), [Potion Craft machine](https://potion-craft.fandom.com/wiki/Alchemy_Machine))
- **Strength:** "broken thing → fixed thing → profit" is the *entire emotional promise* of THE FAR YARD's surface loop, and it's proven satisfying. The **tool-gates-margin** idea (welder) is our Gear/Yard track's payoff: a workshop upgrade unlocks a repair class.
- **Weakness:** CMS can become a spreadsheet grind of maxing "part restoration" skill; the fix is to keep the *decision* (which wreck, which recipe, is it worth the components?) alive rather than making repair a rote button. THE FAR YARD's slot inventory + push/cash-out already supplies that decision surface.

### 1.6 The universal failure mode: crafting fatigue
Across critiques ([bit-tech](https://bit-tech.net/features/gaming/developers-heres-how-to-fix-your-stupid-crafting-system/1/), [NeoGAF threads](https://www.neogaf.com/threads/what-games-have-the-best-worst-crafting-systems-what-makes-a-good-crafting-system.1388727/)): the worst systems are **endless menus of recipes**, scrolling "dozens or hundreds," artificial game-lengthening, no way to sort by *what you can make right now*. Best systems "produce something the designer didn't anticipate" and keep the menu small and the decision meaningful.
- **The synthesis for us:** recipe *count* is a sweet spot, not a maximum. Aim for a **curated few dozen across the whole game** (not per act), each with a clear reason to exist. Always offer a "craftable now" filter. Depth lives in *unlock progression* and *ingredient scarcity*, not in list length.

### 1.7 Cross-cutting takeaways
1. **Two-stage value chain** (raw junk → Salvage → crafted good) is the backbone — Fallout's structure without Fallout's component sprawl.
2. **Recipes are legible; discovery is the top-note.** Backbone = known recipes (bought/found/Lore-unlocked); a light experimentation layer adds "aha" without punishing wrong guesses.
3. **Gate on depth/Knowledge, not blind RNG.** Dead Cells' 0.4% is the anti-pattern; its *return-or-lose extraction risk* on the fragment is the pattern.
4. **Few, strong recipes.** Dead Rising's category-substitution beats a 100-recipe checklist; ship the abstraction, not the checklist.
5. **Tool/workshop gates a whole recipe class** (the welder lesson) — this is how the Yard/Gear tracks feel like they pay off.
6. **Keep the decision alive; kill the menu grind.** Slot pressure + "worth the components?" is the fun; scrolling is the enemy.

---

## 2. What fits THE FAR YARD

### 2.1 The four recipe kinds

All four are *recipe-based* (no minigame, per §14). Each is one `RecipeKind` enum value on a single `Recipe` resource — the *kind* changes how inputs/outputs are interpreted and which currency it touches, keeping one data shape.

| Kind | Reads as | Consumes | Produces | Currency role |
|---|---|---|---|---|
| **REPAIR** | fix a broken appliance to sell higher | 1 broken `JunkItem` + component(s)/Salvage + small Money cost | 1 fixed `JunkItem` (higher `base_sell_value`) | **Money** faucet (value-add) |
| **COMBINE** | parts → a tool / weapon / upgrade | 2–4 `JunkItem`s (+ Salvage) | a Gear/Yard item (owned) *or* a high-value sellable | Salvage → **Gear** sink; or Money faucet |
| **BREAKDOWN** | strip an item into components | 1 `JunkItem` | **Salvage** (+ sometimes a lower junk) | **Salvage** faucet (the only junk→Salvage path) |
| **PROCESS** | workshop cooking/refining | 1 `JunkItem` (often ×N of the same) | a refined/bundled `JunkItem`, Salvage, *or* Lore | bundling / refine / Lore faucet |

Why these four map cleanly onto the economy model (`06152026/12`):
- **REPAIR** is the classic *transform* node — it's where raw junk gains Money value, the faucet that "pulls" the whole surface loop. Its margin must be **positive but bounded** (see §2.4) so it doesn't trivialize raw selling.
- **BREAKDOWN** is the **only faucet that turns Money-junk into Salvage**. This is deliberate: Salvage should feel like a *choice cost* — you give up Money-sale value to get crafting fuel. That tension ("sell it, or strip it for parts?") is a second push/cash-out decision at the workbench.
- **COMBINE** is Salvage's primary **sink** (Lost Garden: match the grind source to a repeatable/exponential sink) — it consumes Salvage + parts to build Gear/Yard upgrades.
- **PROCESS** covers the odd jobs: *bundling* (5 bolts → 1 ingot, pure convenience + a slot-efficiency reward), *refining* (dead battery → charged), and the special **decode/study** recipes that are the **Lore faucet** (an anomalous core → Lore, Knowledge-gated). Process is where "workshop cooking" lives.

### 2.2 Starter recipe list (~22 concrete recipes)

Values below use the 8 shipped junk items plus plausible new `JunkItem`s (broken/fixed appliances, refined goods, tool components). New items are cheap to author (one `.tres` each). "In value" = summed `base_sell_value` of consumed junk; "Out value" = produced item's `base_sell_value` (or Salvage/Lore units). Margins are *illustrative starting points* for the economy workbook to tune, not balanced numbers.

**REPAIR (broken appliance → sellable) — the surface money engine**

| id | inputs | + cost | output | in→out value |
|---|---|---|---|---|
| `rcp_fix_toaster` | `junk_broken_toaster`(6) + `junk_cable_coil`(8) | 2 Money | `junk_working_toaster`(28) | 14 → 28 |
| `rcp_fix_lamp` | `junk_broken_lamp`(5) + `junk_cable_coil`(8) | 2 Money | `junk_working_lamp`(24) | 13 → 24 |
| `rcp_fix_radio` | `junk_broken_radio`(10) + `junk_cable_coil`(8) + 1 Salvage | 3 Money | `junk_working_radio`(38) | 18 → 38 |
| `rcp_fix_microwave` | `junk_broken_microwave`(14) + `junk_circuit_board`(45) | 5 Money | `junk_working_microwave`(90) | 59 → 90 |
| `rcp_refurb_radiator` | `junk_rusty_radiator`(30) + `junk_copper_pipe`(15) | 4 Money | `junk_radiator`(80) | 45 → 80 |
| `rcp_recharge_battery` | `junk_dead_battery`(15) + 1 Salvage | 3 Money | `junk_car_battery`(55) | 15 → 55* |

*(`rcp_recharge_battery` straddles REPAIR/PROCESS — a single-input refine; classify as PROCESS if the "charge over time at a station" flavor is wanted.)*

**COMBINE (parts → tool / weapon / upgrade) — Gear/Yard track, Salvage sink**

| id | inputs | + cost | output (owned, not sold) | note |
|---|---|---|---|---|
| `rcp_build_stun_baton` | `junk_copper_pipe`(15) + `junk_car_battery`(55) + `junk_cable_coil`(8) | 4 Salvage | `tool_stun_baton` (Gear) | improvised weapon (Pillar 2) |
| `rcp_build_magnet_core` | `junk_circuit_board`(45) + `junk_scrap_bolt`(3)×2 + 2 Salvage | 40 Money | `tool_magnet_grapple` (Gear) | GDD §7 grapple |
| `rcp_build_breather_filter` | `junk_radiator`(80) + `junk_copper_pipe`(15) | 6 Salvage | `tool_breather_rig` (Gear) | toxic-zone traversal |
| `rcp_build_sorting_bin` | `junk_hubcap`(20)×3 + `junk_copper_pipe`(15) | 30 Money | `yard_sorting_bin` (Yard: +slots) | Yard/inventory upgrade |
| `rcp_build_ward_totem` | `junk_engine_block`(120) + 8 Salvage | 3 Lore | `yard_ward_totem` (Yard defense) | Act 2 incursion defense |

**BREAKDOWN (item → components) — the Salvage faucet**

| id | input | output | Money value given up → Salvage gained |
|---|---|---|---|
| `rcp_strip_hubcap` | `junk_hubcap`(20) | 1 Salvage + `junk_scrap_bolt`(3) | 20 → 1 Salvage (+3) |
| `rcp_strip_circuit_board` | `junk_circuit_board`(45) | 3 Salvage | 45 → 3 Salvage |
| `rcp_strip_car_battery` | `junk_car_battery`(55) | 2 Salvage + `junk_dead_battery`(15) | 55 → 2 Salvage (+15) |
| `rcp_strip_radiator` | `junk_radiator`(80) | 4 Salvage + `junk_copper_pipe`(15) | 80 → 4 Salvage (+15) |
| `rcp_strip_engine_block` | `junk_engine_block`(120) | 7 Salvage | 120 → 7 Salvage |

**PROCESS (workshop cooking / refine / decode)**

| id | input | output | role |
|---|---|---|---|
| `rcp_bundle_bolts` | `junk_scrap_bolt`(3)×5 | `junk_scrap_ingot`(20) | bundling: 5 slots → 1 slot, +5 value |
| `rcp_spool_wire` | `junk_cable_coil`(8)×3 | `junk_copper_spool`(32) | bundling + small value-add |
| `rcp_smelt_copper` | `junk_copper_pipe`(15)×2 | `junk_copper_ingot`(38) + 1 Salvage | refine, dual output |
| `rcp_decode_core` | `junk_anomalous_core`(0 sell) | 3 Lore | **Lore faucet** (Knowledge-gated) |
| `rcp_distill_residue` | `junk_paradox_residue`(0 sell) + 2 Salvage | 1 Lore + `junk_stable_shard`(60) | deep-band study recipe |
| `rcp_study_tape` | `junk_cyrus_tape`(0 sell) | 2 Lore + story flag | narrative hook (Cyrus recordings) |

This is **22 recipes across the whole game** — comfortably under the fatigue threshold, spanning all four kinds, seeding all three currencies, and reaching into all four tracks. New `JunkItem`s introduced: broken/working toaster, lamp, radio, microwave; rusty_radiator; dead_battery; scrap_ingot, copper_spool, copper_ingot; anomalous_core, paradox_residue, stable_shard, cyrus_tape (≈15 new `.tres`, trivially authored).

### 2.3 Discovery / unlock mechanics tied to Knowledge

The GDD fixes three unlock sources (bought / found below / Lore). Proposal — a **single `unlock_source` marker per recipe** plus a `required_knowledge` gate, resolved through the *existing* `unlocked_recipes` meta list:

- **BOUGHT** — the surface path. A recipe appears in the Hub shop (or a confidant's inventory) once `knowledge_level >= required_knowledge`. Buying it appends its id to `unlocked_recipes`. This is the **reliable, deterministic** backbone (anti-Dead-Cells-RNG). Mechanic/diner confidants sell repair recipes cheaply; the "expert" grad-student sells process/decode recipes for Lore.
- **FOUND** — the extraction path (the good one from Dead Cells). A **recipe fragment** (`junk_recipe_fragment` carrying a `recipe_id`) spawns as junk in a deep band; it is **unbanked haul until you extract it** — carry it home and it unlocks; die and lose it. This makes finding a recipe a *push/cash-out bet*, reusing our extraction fiction perfectly. Deeper bands seed deeper recipes.
- **LORE** — the Knowledge path. Some recipes have **no buy/find route** and unlock purely by spending Lore / hitting a `knowledge_level` threshold (GDD §8: "only realized once you understand a deep principle"). These are the ward/decode/deep recipes gating acts.
- **EXPERIMENT (optional top-note)** — a *light* discovery layer that does **not** punish (per §1.4/§1.6): the workshop shows recipes whose *shape* the player has seen (e.g., "you've broken down a circuit board 3×") as a greyed **hint** ("Circuit boards seem to hold something more…"), nudging toward the Lore/buy unlock. **Never** consume rare inputs on a blind guess. Recommendation: ship this as UI hinting, not true free-form combination, in the first pass.

Knowledge as the master gate stays intact: `required_knowledge` on the recipe is the single lever that ties recipe access to the act structure (GDD §12), and `unlocked_recipes` (already persisted) is the source of truth for "can I make this."

### 2.4 Economy math — value-add that doesn't break selling

Anchored to `06152026/12` (faucet/drain, taut chains, match sink power to source power):

- **REPAIR margin rule.** Output value should be **1.5×–2.2×** the summed input junk value, *minus* a Money processing cost, so repairing is clearly better than selling raw — but not so much that raw selling becomes pointless (that would make un-repaired junk a dead resource). Example: `rcp_fix_microwave` 59 → 90 = ×1.53 gross; net after 5 Money and the opportunity cost of the consumed circuit board (which could itself sell for 45) the *marginal* gain over "just sell the parts" is modest — which is correct: repair should be a **meaningful but not dominant** money multiplier. The workbook's `Sinks`/`Run_EV` tabs own the final numbers.
- **The opportunity-cost framing is the real balance.** Every consumed component *had* a sell value. The honest margin is `output_value − Σ(input_sell_values) − money_cost`. Keep this **small and positive** for common repairs (a few extra Money) and larger for recipes gated behind Knowledge/deep finds (the reward tier). This makes recipe *progression*, not recipe *spam*, the money grower — matching GDD §10's "success ramps with player power."
- **BREAKDOWN is intentionally lossy in Money terms.** `rcp_strip_engine_block`: give up 120 Money to gain 7 Salvage. Salvage's *worth* is set by what COMBINE recipes need it for; the workbook derives an implied Money↔Salvage exchange (≈ 15–20 Money/Salvage here) and checks that COMBINE sinks make that trade feel worthwhile. Salvage is a **grind source** (`06152026/12` §4) → its sinks (COMBINE tiers) must be **repeatable/exponential**, i.e. later Gear/Yard tiers cost geometrically more Salvage so a heavy stripper never floods.
- **Guard against the investment-loop trap.** A recipe that *increases junk yield* (e.g. a "salvage magnet" tool built by COMBINE) is an exponential source — **cap it** (one tier, or a flat +X) per `06152026/12` §4, or it explodes for optimizers.
- **Lore stays capped.** PROCESS decode recipes are the Lore faucet, but the *inputs* (anomalous cores) are capped per band (limited deep spawns), so Lore can't be ground infinitely — it gates progression, not power.

### 2.5 Where crafting happens — surface workshop vs. in-dive field crafting

| | **Surface workshop** (recommended primary) | **In-dive field crafting** (recommended: minimal) |
|---|---|---|
| **Fits** | GDD §8/§11 loop: sell & sort → upgrade happen at the yard between runs; the workshop is a Yard-track upgrade (Animal-Crossing "sense of place") | Pillar 2 ("jury-rigged gear," fix/triage on the fly, GDD §6) |
| **Recipes** | All four kinds; REPAIR + COMBINE + PROCESS live here; workshop *tier* (Yard upgrade) gates recipe classes (the welder lesson §1.5) | Only **BREAKDOWN** (free up slots by stripping a bulky item for compact Salvage mid-dive) and emergency **REPAIR of a carried tool** |
| **Pacing** | Deliberate, no time pressure — keeps the dive fast (GDD run-length goals) and the menu-work off the clock | Costs dive time/light (a real push/cash-out cost) — so it stays a *rare, tactical* choice, not routine |
| **Risk** | none (meta space) | crafting on the clock = the tension; but too much field crafting turns the dive into inventory-management (the fatigue trap §1.6) |
| **Trade-off** | Could feel disconnected from the "engineer in the field" fantasy | Could bloat the dive and slow the core loop |

**Recommendation:** anchor crafting at the **surface workshop** (matches the shipped loop, keeps dives lean, gives the Yard track a visible payoff via workshop tiers). Allow a **single, deliberate in-dive action — BREAKDOWN-for-slots** — as the field-crafting representative: it directly serves the slot-inventory push/cash-out decision ("strip this radiator into Salvage to free 1 slot for a better find?") without importing a whole workbench underground. Broader field crafting is a **Director judgment call** (§4) — it's a fantasy-vs-pacing trade, not a technical one.

---

## 3. Integration sketch (data-as-Resources, against as-built APIs)

### 3.1 The `Recipe` resource

Mirrors `JunkItem`/`ShopItem`: one `.tres` per recipe, authored in the inspector, listed in a `RecipeBook` catalog. Objects-OFF-friendly (everything keyed by `StringName`).

```gdscript
class_name Recipe
extends Resource
## Recipe — one craft: repair, combine, breakdown, or process (GDD §8). A pure
## data container; the crafting ACTION lives in a WorkshopService. Authored as a
## .tres, listed in a RecipeBook, keyed by id everywhere (save/events/telemetry).

enum RecipeKind { REPAIR, COMBINE, BREAKDOWN, PROCESS }
enum UnlockSource { BOUGHT, FOUND, LORE }   # EXPERIMENT is a UI hint layer, not a source

# --- Identity ---
@export var id: StringName = &""
@export var display_name: String = "Recipe"
@export_multiline var description: String = ""
@export var kind: RecipeKind = RecipeKind.REPAIR

# --- Inputs (consumed) ---
## Junk consumed, keyed by JunkItem.id -> count. By-id (not index) like
## JunkCatalog.spawn_weights_by_id, so reordering never misaligns.
@export var input_junk: Dictionary[StringName, int] = {}
@export var input_salvage: int = 0
@export var money_cost: int = 0          # workshop processing fee

# --- Outputs (produced) ---
## Produced junk, keyed by JunkItem.id -> count (REPAIR/PROCESS usually 1 entry).
@export var output_junk: Dictionary[StringName, int] = {}
## COMBINE tools/upgrades: an owned_items id (GameState.owns), not a JunkItem.
@export var output_owned_id: StringName = &""
@export var output_salvage: int = 0      # BREAKDOWN / PROCESS
@export var output_lore: int = 0         # PROCESS decode recipes (Lore faucet)

# --- Gating / discovery ---
@export_range(0, 20) var required_knowledge: int = 0
@export var unlock_source: UnlockSource = UnlockSource.BOUGHT
@export var unlock_price_money: int = 0  # BOUGHT: shop/confidant price (Money)
@export var unlock_price_lore: int = 0   # LORE/BOUGHT-via-Lore price
@export_range(0, 5) var workshop_tier_required: int = 0  # Yard upgrade gate
@export_enum("surface","near","temporal","lateral","far") var origin_band: String = "surface"


## Legibility helper for the "craftable now?" UI filter (anti-fatigue, §1.6).
func is_craftable(inv: Array, salvage_have: int, money_have: int, ktier: int) -> bool:
	if ktier < required_knowledge:
		return false
	if salvage_have < input_salvage or money_have < money_cost:
		return false
	for jid in input_junk:
		if _count_in(inv, jid) < input_junk[jid]:
			return false
	return true
```

```gdscript
class_name RecipeBook
extends Resource
## Authored catalog of all Recipes (mirrors JunkCatalog / ShopCatalog).
@export var recipes: Array[Recipe] = []
```

### 3.2 The crafting action — `WorkshopService`

No new autoload (autoload count is disciplined at six). A plain `RefCounted`/node service the Hub workshop scene owns, calling *existing* `GameState`/`Economy` methods. It touches **meta-state only** (crafting happens on the surface, between runs — respects the run/meta boundary):

```gdscript
# Pseudocode — WorkshopService.craft(recipe) against as-built APIs.
func craft(recipe: Recipe) -> bool:
	# 1. Gate: unlocked + Knowledge + workshop tier.
	if not GameState.unlocked_recipes.has(recipe.id):
		EventBus.craft_failed.emit(recipe.id, &"locked"); return false
	if GameState.knowledge_level < recipe.required_knowledge:
		EventBus.craft_failed.emit(recipe.id, &"knowledge"); return false

	# 2. Affordability (banked_junk is the meta junk pile — Economy owns it).
	if not _have_inputs(recipe):
		EventBus.craft_failed.emit(recipe.id, &"missing_inputs"); return false

	# 3. Consume: remove input junk from banked_junk, debit Salvage/Money.
	_consume_junk(recipe.input_junk)                       # pull from GameState.banked_junk
	if recipe.input_salvage > 0:
		GameState.add_currency(&"salvage", -recipe.input_salvage, &"craft")
	if recipe.money_cost > 0:
		GameState.add_currency(&"money", -recipe.money_cost, &"craft")

	# 4. Produce.
	for out_id in recipe.output_junk:                      # append fixed/refined JunkItem(s)
		for _i in recipe.output_junk[out_id]:
			GameState.banked_junk.append(_catalog_item(out_id))
	if recipe.output_salvage > 0:
		GameState.add_currency(&"salvage", recipe.output_salvage, &"craft")
	if recipe.output_lore > 0:
		GameState.add_currency(&"lore", recipe.output_lore, &"craft")
	if recipe.output_owned_id != &"":
		GameState.owned_items.append(recipe.output_owned_id)   # COMBINE tools/upgrades

	SaveManager.save_meta(0)                                # atomic write + .bak (every meta op)
	EventBus.item_crafted.emit(recipe.id, recipe.kind, GameState.money, GameState.salvage)
	return true
```

Unlock triggers reuse existing paths:
- **BOUGHT** → the Hub shop `purchase()` path, or a confidant sale, appends `recipe.id` to `unlocked_recipes` (a one-line extension of the shop flow).
- **FOUND** → a `junk_recipe_fragment` carried out via the *existing* extract → `banked_junk` transfer; a Hub-return hook reads its `recipe_id` and appends to `unlocked_recipes` (and removes the fragment).
- **LORE** → spend `lore` via `add_currency(&"lore", -price, …)`, then append to `unlocked_recipes`.

### 3.3 EventBus signals (new — pre-declared per the M1 convention)

Following the repo's "declare signals centrally, emitters only emit" rule, and *primitives-only* for telemetry rows:

```gdscript
# --- Crafting / recipes (WorkshopService emits; UI/Telemetry consume) ---
signal recipe_unlocked(recipe_id: StringName, source: StringName)   # source = bought/found/lore
signal item_crafted(recipe_id: StringName, kind: int, money: int, salvage: int)
signal craft_failed(recipe_id: StringName, reason: StringName)      # locked/knowledge/missing_inputs
signal recipe_hint_available(recipe_id: StringName)                 # optional EXPERIMENT top-note
```

These stay outside the dive telemetry family (no `run_t_ms`/`depth`) since crafting is a Hub/meta action, exactly like the M1.6 shop signals (`item_sold`, `item_purchased`).

### 3.4 Data/lint checklist (definition of done)
A recipe linter (Python, per the data workflow) must verify:
1. every `input_junk`/`output_junk` key resolves to a real `JunkItem.id` in `JunkCatalog`;
2. `output_owned_id` (if set) resolves to a `ShopItem`/tool id;
3. no recipe has empty inputs *and* empty outputs;
4. `required_knowledge`, `tier`, prices are in range;
5. every recipe id is unique and referenced by at least one unlock route (a fragment, a shop entry, or a Lore gate) — no orphan recipes;
6. **economy sanity:** for REPAIR, `Σ output_value ≥ Σ input_sell_value` (repairing shouldn't lose Money); for BREAKDOWN, flag if `output_salvage × impliedRate > input_sell_value` (breakdown must be lossy in Money);
7. `recipe.id` naming convention `rcp_*`, new junk `junk_*`.

---

## 4. Open Questions

**Flagged for the human Director (vision / fun / tone / scope):**

- **OQ-1 (scope/fun) — recipe count for the first playable.** §1.6 says "few, strong." The 22 here span the whole game. How many should the *first vertical slice* ship — a tight 6–8 (2 repair, 2 breakdown, 2 combine, 1–2 process) to prove the loop, or the full 22 to test breadth? *Rec: 6–8 for the M-slice; breadth is a content task, not a system-proof task.*
- **OQ-2 (fun/tone) — how much in-dive field crafting?** §2.5 recommends *only* BREAKDOWN-for-slots underground. But Pillar 2's "jury-rigged engineer in the field" fantasy could want more (field-repair a tool, combine a panic weapon). More field crafting deepens the fantasy but risks turning dives into inventory management (§1.6) and slowing the loop. *Rec: ship BREAKDOWN-for-slots only; revisit at the fun gate.* **Director's call — it's a fantasy-vs-pacing trade.**
- **OQ-3 (fun) — experimentation layer: hint-only, or real free-form?** §2.3 recommends a non-punishing *hint* layer, not BOTW-style blind combination. True experimentation is a strong "discovery" emotion (Pillar 5) but is (a) a big UI/feel investment and (b) risks the "wrong guess wastes rare junk" anti-pattern. *Rec: hint-only in v1; evaluate real experimentation as a later delighter.*
- **OQ-4 (economy/fun) — repair margin steepness.** GDD §15 explicitly lists this open: "how steep the value jump from broken → fixed should be." §2.4 proposes ×1.5–2.2 gross with a small *net* margin after opportunity cost. Steeper = repair feels rewarding but can dwarf raw selling (dead-junk risk); shallower = repair feels pointless. **This is the workbook's headline knob and a fun-gate dial** — needs a playtest number, not an a-priori one.
- **OQ-5 (tone/scope) — do broken appliances spawn as junk, or is *all* junk repairable?** Two models: (a) distinct "broken toaster" items spawn and have a fixed counterpart (clean, legible, more `.tres`), or (b) any appliance-class junk carries a `condition` and *any* of them can be repaired (fewer items, but adds a stat to JunkItem and muddies the readable-junk goal). *Rec: model (a) — distinct broken/fixed items — for M-slice legibility; model (b) is a possible later depth.* **Schema-affecting; Director should ratify before the data task.**

**Resolvable on design merit (recommendations, not Director-gated):**

- **OQ-6 — inputs as `Dictionary[StringName,int]` vs. an `Ingredient` sub-resource?** *Rec: Dictionary* — matches the shipped `spawn_weights_by_id` idiom, objects-OFF-safe, simplest to lint. Switch to a sub-resource only if per-ingredient metadata (e.g. "consumes durability, not the whole item") is needed later.
- **OQ-7 — Salvage: single abstract currency (as shipped) vs. named components?** *Rec: keep single abstract Salvage.* §1.1's Fallout lesson is that named components breed bookkeeping; the shipped design already chose one abstract `salvage: int`. Named components are the classic over-engineering trap — resist unless a specific recipe *needs* distinctness.
- **OQ-8 — recipe-fragment loss on death: total loss, or pockets-eligible?** *Rec: pockets-eligible* — a found recipe fragment is `banked_junk`-class haul, so it should flow through the existing `resolve_pockets` "keep whole items up to 20%" path like any find, preserving one drop code path. (Consistency win; matches the E3 pockets model.)
- **OQ-9 — where does workshop-tier gating live?** *Rec:* a Yard-track `owned_items` id (e.g. `yard_workshop_t2`) that `WorkshopService` reads via `GameState.owns()`, so recipe-class gating reuses the M1.6 ownership system with no new state.

---

## Sources

- [Daniel Cook (Lost Garden), "Value chains"](https://lostgarden.com/2021/12/12/value-chains/) — faucet/drain, source/sink taxonomy, transforms, taut chains (the economy backbone recipes plug into).
- [Fallout wiki, "Fallout 76 junk items"](https://fallout.fandom.com/wiki/Fallout_76_junk_items) and [Steam, "Turning Junk into Components"](https://steamcommunity.com/app/377160/discussions/0/1742227264205556902/) — junk→components→craft two-stage chain; scrap-all; Scrapbox.
- [Dead Rising 4 combo weapons wiki](https://deadrising.fandom.com/wiki/Combo_Weapons_(Dead_Rising_4)) and [The Squid Chamber, "Dead Rising's Combo Weapon Problem"](https://squiddude.wordpress.com/2018/02/16/dead-risings-combo-weapon-problem-a-history/) — combine-two-items + blueprints + category substitution.
- [Dead Cells wiki, "Blueprints"](https://deadcells.fandom.com/wiki/Blueprints) and [drop-rate discussion](https://steamcommunity.com/app/588650/discussions/0/2217311444338096980/?l=english&ctp=3) — blueprint find→Collector→buy; ~0.4% RNG-gating critique; return-or-lose-on-death.
- [First Person Scholar, "Stirring the Pot"](https://www.firstpersonscholar.com/stirring-the-pot/) and [Kulik, "How BOTW Leverages Familiarity and Feedback"](https://medium.com/@chronospherics/how-breath-of-the-wild-leverages-intuition-familiarity-and-feedback-to-avoid-explicit-f9b5a3206117) — experimentation/emergent discovery; cumbersome-UX and shallow-depth critique.
- [DHQ, "Crafting in Games"](https://www.digitalhumanities.org/dhq/vol/11/4/000339/000339.html) and [Envato Tuts+, "5 Approaches to Crafting Systems"](https://code.tutsplus.com/5-approaches-to-crafting-systems-in-games-and-where-to-use-them--cms-22628a) — experimentation-vs-blueprint agency/control tradeoff; punishing wrong guesses discourages exploration.
- [bit-tech, "Fix your stupid crafting system"](https://bit-tech.net/features/gaming/developers-heres-how-to-fix-your-stupid-crafting-system/1/) and [NeoGAF crafting threads](https://www.neogaf.com/threads/what-games-have-the-best-worst-crafting-systems-what-makes-a-good-crafting-system.1388727/) — crafting fatigue, endless-menu anti-pattern, sort-by-craftable-now.
- [Car Mechanic Simulator 2021 resale thread](https://steamcommunity.com/app/1190000/discussions/0/3413181204140156841/), [CMS profit guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2590379392), [Potion Craft Alchemy Machine wiki](https://potion-craft.fandom.com/wiki/Alchemy_Machine) — restoration-to-sell loop; tool-gates-margin (welder); repair-the-station-to-produce.
- Internal: `design/Junkyard_GDD.md` §8/§14/§15; `design/research/06152026/12_economy_balance_model.md`; `Game/data/junk/junk_item.gd`, `junk_catalog.gd`; `Game/systems/game_state.gd`, `economy.gd`, `event_bus.gd`; `Game/data/shop/shop_item.gd`.
