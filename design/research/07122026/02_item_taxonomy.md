# Item Taxonomy for THE FAR YARD

*Research on **what kinds of items should exist** — a broad, band-spanning taxonomy of salvage,
valuables, materials, consumables, tools, lore/quest items, and exotic/cursed anomalies — mapped
onto the game's three currencies, four tracks, five bands, and the as-built `JunkItem` data shape.*

**Companion to:** `design/research/06152026/03_readable_junk_study.md` (how items *read*),
`design/research/06152026/12_economy_balance_model.md` (value/slot & faucet-drain economy),
`design/explorations/exploration-20260625/economy-extraction/p3-item-familiarity.md` (earned legibility).
**Grounded against:** `Game/data/junk/junk_item.gd`, the 8 shipped `Game/data/junk/items/*.tres`,
`Game/data/shop/shop_item.gd`, `Game/data/economy/run_rules.tres`, and `Junkyard_GDD.md §4/§6/§8`.

---

## 0. What already exists (the constraint we build on)

The as-built junk model is a **single canonical Resource**, `JunkItem` (`data/junk/junk_item.gd`), whose
fields are the vocabulary every proposal below must speak in:

| Field | Type / range | Role |
|---|---|---|
| `id` | `StringName` | stable key (events, telemetry, save, catalog) |
| `display_name` | `String` | shop/inventory label |
| `description` | multiline `String` | flavor / inspector text |
| `origin_band` | enum `surface / near / temporal / lateral / far` | GDD §4 depth gradient |
| `tier` | `int` 1–5 | depth/rarity; B3 gates high tiers behind depth |
| `slot_size` | `int` 1–9 | count-model carry cost |
| `grid_footprint` | `Vector2i` | spatial-model cells (advisory in M1) |
| `containment_flags` | flags `Placeable / Is Container / No Nest` | inventory rules; `IS_CONTAINER` is post-M1 |
| `base_sell_value` | `int` | Money on cash-out |
| `greybox_color` / `greybox_shape` | `Color` / `{RECT,CIRCLE,TRIANGLE,DIAMOND}` | placeholder read |
| `value_per_slot()` | `float` | the "worth the space?" surface |

The 8 shipped items are a **clean value/band/slot ladder** and the anchor for every number below:

| id | band | tier | slot | `base_sell_value` | $/slot |
|---|---|---|---|---|---|
| `junk_scrap_bolt` | surface | 1 | 1 | 3 | 3.0 |
| `junk_cable_coil` | surface | 1 | 1 | 8 | 8.0 |
| `junk_copper_pipe` | near | 2 | 2 | 15 | 7.5 |
| `junk_hubcap` | near | 2 | 2 | 20 | 10.0 |
| `junk_circuit_board` | temporal | 3 | 1 | 45 | 45.0 |
| `junk_car_battery` | temporal | 3 | 3 | 55 | 18.3 |
| `junk_radiator` | lateral | 4 | 4 | 80 | 20.0 |
| `junk_engine_block` | far | 5 | 6 | 120 | 20.0 |

Two other item-shaped Resources already exist and must **not** be re-absorbed into junk: **`ShopItem`**
(`data/shop/shop_item.gd`) is the *buyable meta-upgrade* (Gear/Yard tracks, `owned_items`, `effect_kind`
stub), and the retired generic **`Item`** (`data/item.gd`) — the as-built note is explicit that "a future
non-junk item type is its **own purpose-built Resource**," not a resurrection of `Item`. That is the seam
this taxonomy plugs into.

Three currencies and four tracks (GDD §8) give every item a **destination**: **Money** (sell junk),
**Salvage** (rare components/items kept, *not* sold, the hard crafting ingredient), **Lore/Knowledge**
(fragments decoded from anomalous finds) — feeding **Gear · Yard · Relationships · Knowledge**. Any
taxonomy that only produces "sell for Money" leaves two currencies and two tracks starved of faucets.
The whole point of a *broad* item roster is to give Salvage and Lore their own item-shaped sources.

---

## 1. Broad survey / prior art

### 1.1 Extraction shooters — the "value-per-slot triage" school

**Escape from Tarkov** is the reference for *category breadth under a grid*. Its loot splits into
`barter items, currency, keycards, keys, maps, quest items, special equipment, stackable items` and
info items, and its **barter-items** subcategory alone fans into nine buckets — *Building materials,
Electronics, Energy elements, Flammable materials, Household goods, Medical supplies, Tools, Valuables,
Other* — each with a distinct grid footprint ([EFT Wiki – Loot](https://escapefromtarkov.fandom.com/wiki/Loot),
[Category:Barter items](https://escapefromtarkov.fandom.com/wiki/Category:Barter_items)). The load-bearing
lesson: **breadth lives in the *fiction/material* axis, but the *decision* is always value-per-slot** — a
1×1 graphics card or a key beats a 4×2 low-value item every time, so Tarkov deliberately seeds small,
high-density "valuables" to make the bag a constant triage puzzle ([EFT Loot Guide – BoostRoom](https://boostroom.com/blog/escape-from-tarkov-loot-guide-most-valuable-items-to-pick-up)).
That maps *exactly* onto our shipped `value_per_slot()` and the engine-block-vs-circuit-board tension.
**Zero Sievert** (single-player, top-down, the closest structural cousin to us) proves the same roster
works small: ~100+ items, each either *sold to traders, used in a crafting recipe, or a quest turn-in* —
loot has "a use" or it is noise ([Zero Sievert Wiki – Items](https://zero-sievert.fandom.com/wiki/Items),
[Crafting Guide – TechRaptor](https://techraptor.net/gaming/guides/zero-sievert-crafting)).

### 1.2 Salvage games — material buckets and *hazard* as a category

**Hardspace: Shipbreaker** sorts everything into a *tiny* set of destinations — Barge (whole mechanical
items), Processor (sheet materials: Nanocarbon, Titanium), Furnace (base metals/scrap) — and, crucially,
makes **hazard a first-class item property**: coolant, fuel, and charged electronics can injure you or
destroy nearby salvage ([Hardspace Wiki – Salvage](https://hardspaceshipbreaker.fandom.com/wiki/Salvage)).
The takeaway for us: a small number of **sorting destinations** (Money / Salvage / Lore / Story / Trash)
keeps a broad roster legible, and **"this item can hurt you or your haul"** is a real category, not a
one-off — it directly seeds our cursed/anomalous band-4 items and the `containment_flags` we already have.
**Dredge** shows the *identity-item* pattern: beyond its 8 fish types it carries **Trinkets** (sell-only,
non-respawning), **Research Parts** (rare, tech-gated), **Relics** (fixed, quest-bound), and **Aberrations**
(mutated, higher-value, higher-risk variants of ordinary fish) ([Dredge Wiki – Dredge mechanic](https://dredge.fandom.com/wiki/Dredge_(game_mechanic)),
[Aberrations](https://dredge.fandom.com/wiki/Aberrations)). The Aberration idea — *a corrupted, worth-more,
scarier version of a familiar item* — is a near-free way to give each deeper band an "exotic" tier without
authoring a whole new object. **Dave the Diver** adds the *dual-use* lesson: a caught fish is both sale
inventory *and* a cooking ingredient, and some creatures are **story-only** (Bioluminescent Jellyfish) or
**drop-bearing** (Giant Squid → ink + story component) — one object, several loop roles ([Dave the Diver DB – NiaMeowDB](https://meowdb.com/db/dave-the-diver)).

### 1.3 Survival-crafting — junk as a *component reservoir*

**Fallout 4** is the definitive "junk → components" model: every junk item is a bag of **31 base
components** (steel, wood, copper, circuitry, nuclear material…); scrapping decomposes it, crafting
consumes the components ([Fallout Wiki – FO4 junk items](https://fallout.fandom.com/wiki/Fallout_4_junk_items),
[How To Scrap Junk – TheGamer](https://www.thegamer.com/fallout-4-tips-scrapping-junk/)). This is the
alternative to "one junk = one sell value": the *same pickup* can be **sold for Money OR broken for
Salvage components**, and that choice *is* the sell-vs-keep tension our GDD §8 recipe system implies.
**Subnautica** separates **raw materials** (mined), **processed/advanced components** (multi-step craft),
**organic** items, and **fragments/blueprints** (scanned → *unlock a recipe*, not consumed) — 203 resources
vs 175 blueprints ([Subnautica Wiki – Raw Materials](https://subnautica.fandom.com/wiki/Raw_Materials_(Subnautica))).
The **fragment-as-blueprint-unlock** is exactly our GDD "recipes found below" faucet for `unlocked_recipes`.
**Stardew Valley** contributes the **collection/museum** axis: **Artifacts** and **Minerals** aren't just
sell fodder — donating them is a parallel progression, and **Geodes** are *containers* whose contents are
unknown until cracked (a mystery-box faucet) ([Stardew Wiki – Artifacts](https://stardewvalleywiki.com/Artifacts)).
That "some items are for *knowing/collecting*, not *selling*" is our Lore/Knowledge track in miniature, and
Geodes are prior art for our `IS_CONTAINER` flag.

### 1.4 Roguelites — the boon/relic vs consumable split

**Hades** cleanly separates **Boons** (build-defining, meta-narrative, chosen not carried) from
**consumables/currencies** (Darkness, Gems, Nectar, Keys) — the design lesson is that *build items* and
*economy items* are different object classes with different UIs. For us that ratifies keeping **tools/gear**
(the Gear track, `ShopItem`) as a *different Resource* from ground junk, rather than cramming a weapon into
the junk pool. **Dead Cells / Dredge** both reinforce that a small, sharply-differentiated roster reads
better than a sprawling one — our own readable-junk study reached the identical conclusion (keep the rarity
ladder to ~5–6 steps).

### 1.5 What makes a roster readable *and* interesting — synthesis

1. **Breadth on the fiction axis, narrowness on the decision axis.** Twenty material flavors are fine if
   they all resolve to a handful of destinations (Money / Salvage / Lore / Story / Trash) and one core
   question (value-per-slot). Breadth *is* flavor; the loop stays a triage.
2. **Every item has a destination.** Zero Sievert's rule — *sell, craft, or quest* — is the anti-dead-weight
   check. A category with no sink is noise (economy model §5, "dead currency").
3. **Value density is the interest.** Small-precious (valuables, cores) vs bulky-lucrative (engine block)
   is the whole push/cash-out tension in one object property — and we already ship it (`value_per_slot()`).
4. **Dual-use creates the best decisions.** Fallout's sell-or-scrap and Dave's sell-or-cook mean the
   *same pickup* is a choice, not a lookup. Our three currencies make this natural: one object can be
   Money-now or a Salvage-component-later.
5. **Hazard and mystery are categories, not exceptions.** Hardspace hazards, Stardew geodes, and Dredge
   aberrations show that "this can hurt you," "you don't know its value yet," and "corrupted-but-richer"
   are *reusable* roster tools that scale with depth — a perfect fit for our band gradient and the
   Instability scalar `I` (deeper `I` → more exotic/cursed tiers).
6. **Band identity items sell the world.** Dredge's biome-locked fish and Tarkov's location-gated keys make
   *where you were* legible from *what you carry*. Each of our five bands should have signature objects that
   could come from nowhere else.

---

## 2. Proposed taxonomy for THE FAR YARD

### 2.1 The two orthogonal axes

Everything the player can pick up is classified on **two independent axes** already latent in the data:

- **Band / tier (depth)** — `origin_band` × `tier`, the existing 5×5 grid. This is the *readability & value*
  axis (readable-junk study: tier → rarity color, band → off-ladder glow). Value tracks it: surface≈$2–10,
  near≈$12–30, temporal≈$40–70, lateral≈$75–120, far≈$110–250+ (valuables/cores break density upward).
- **Category / role** — *the missing axis*. What the object **is** and **which currency/loop it feeds**.
  This is the new classification this document proposes. It answers "sell, keep, decode, use, or story?"

The category axis proposed below has **ten families**, grouped by their loop destination.

### 2.2 The ten categories

| # | Category | Feeds | Core question | Data shape |
|---|---|---|---|---|
| A | **Common Salvage (materials)** | Money (or scrap→Salvage) | value/slot | `JunkItem` |
| B | **Valuables / Precious** | Money (high density) | grab over bulk? | `JunkItem` |
| C | **Components / Craft-stock** | **Salvage** (keep, don't sell) | sell now or build later? | `JunkItem` + yield fields |
| D | **Consumables / Field supplies** | used in-dive | spend it or save it? | new `ConsumableItem` (or `ShopItem` consumable) |
| E | **Tools / Gear (found)** | Gear track | equip / upgrade | `ShopItem`-family (not junk) |
| F | **Recipes / Blueprints** | `unlocked_recipes` | one-time knowledge | new `BlueprintItem` |
| G | **Lore / Knowledge items** | **Lore** → Knowledge | decode for the master key | new `LoreItem` |
| H | **Quest / Story items** | story flags | non-sellable, plot-bound | `LoreItem`/flagged `JunkItem` |
| I | **Band-Exotic (identity)** | Money + Salvage + Lore | signature deep loot | `JunkItem` + exotic flags |
| J | **Cursed / Anomalous / Hazardous** | high reward + downside | push-your-luck object | `JunkItem` + hazard block + containment |

Categories **A, B, C, I, J are ground-spawnable salvage** → they extend `JunkItem`. **D, E, F, G, H** are
either meta objects (E is the Gear track / `ShopItem`) or narrative/knowledge objects with a genuinely
different data shape → they are **sibling Resources** (see §3). This preserves "one Resource per purpose"
and keeps the junk catalog clean.

### 2.3 Example roster (~55 items) mapped to bands, tiers, slots, and loop role

Values follow the shipped ladder; `[shipped]` marks the 8 existing items shown for anchoring.
"Role" abbreviations: **$**=sell for Money, **SV**=Salvage component (keep), **LO**=Lore/decode,
**USE**=consumable, **QST**=quest, **HAZ**=hazard/curse downside.

#### A — Common Salvage (materials) · the bread-and-butter faucet

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Scrap Bolt `[shipped]` | surface | 1 | 1 | 3 | $ | filler; near-zero density |
| Cable Coil `[shipped]` | surface | 1 | 1 | 8 | $/SV | wire → "pristine wiring loom" scrap |
| Rebar Length | surface | 1 | 2 | 6 | $ | bulky cheap; drop-first |
| Sheet Steel | surface | 1 | 2 | 10 | $/SV | steel component source |
| Copper Pipe `[shipped]` | near | 2 | 2 | 15 | $/SV | copper; classic scrapper metal |
| Aluminum Siding | near | 2 | 2 | 14 | $ | light, low value |
| Ball-Bearing Tin | near | 2 | 1 | 18 | $/SV | mechanical components |
| Retro Alloy Ingot | temporal | 3 | 2 | 48 | $/SV | "future-alloy," GDD §4 temporal |
| E-Waste Brick | temporal | 3 | 2 | 40 | $ | compacted future e-waste |
| Impossible Metal Bar | lateral | 4 | 2 | 90 | $/SV | weighs wrong; craft-grade |
| Star-Slag Chunk | far | 5 | 3 | 130 | $/SV | molten husk residue |

#### B — Valuables / Precious · small-but-lucrative (the density decision)

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Loose Coins | surface | 1 | 1 | 12 | $ | tiny, tops surface density |
| Silver Cutlery Set | near | 2 | 1 | 35 | $ | precious metal, 1 slot |
| Pocket Watch | near | 2 | 1 | 45 | $ | antique; era-flavored |
| Circuit Board `[shipped]` | temporal | 3 | 1 | 45 | $/SV | gold contacts; density king |
| Gold Tooth-Filling Jar | temporal | 3 | 1 | 60 | $ | grim, dense, sellable |
| Jeweled Trinket | lateral | 4 | 1 | 100 | $ | alt-reality bijou |
| Compressed Prism | far | 5 | 1 | 180 | $ | thumb-sized fortune; Tarkov-key analog |

#### C — Components / Craft-stock · the "keep, don't sell" Salvage faucet

| Item | Band | Tier | Slot | ~Value(if sold) | Role | Note |
|---|---|---|---|---|---|---|
| Spark Plugs | surface | 1 | 1 | 5 | SV | engine repair recipe stock |
| Pristine Wiring Loom | near | 2 | 1 | 16 | SV | high-yield wire component |
| Intact Electric Motor | near | 2 | 2 | 28 | SV | tool-craft core |
| Ceramic Magnet | temporal | 3 | 1 | 30 | SV | magnet-grapple upgrades |
| Coolant Cell | temporal | 3 | 2 | 35 | SV/HAZ | breather rig; leaks if damaged |
| Capacitor Bank | lateral | 4 | 2 | 70 | SV | ward/stabilizer tech |
| Paradox Gear | lateral | 4 | 1 | 95 | SV | anomaly-tech recipes only |
| Lore Core (blank) | far | 5 | 1 | — | SV | can't sell; keystone Salvage |

#### D — Consumables / Field supplies · spend-in-dive

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Fuel Canister | surface | 1 | 1 | — | USE | tool fuel; also findable |
| Spare Battery | surface | 1 | 1 | — | USE | extends the dive clock/light |
| Patch Kit | near | 2 | 1 | — | USE | tool durability / self-repair |
| Ration Bar | near | 2 | 1 | — | USE | stamina restore |
| Signal Flare | temporal | 3 | 1 | — | USE | distraction / reveal |
| Breather Filter | temporal | 3 | 1 | — | USE | toxic-pocket survival |
| Ward Charge | lateral | 4 | 1 | — | USE | repel a deep thing once |
| Stabilizer Vial | far | 5 | 1 | — | USE | shave local instability `I` |

#### E — Tools / Gear (found variants) · the Gear track (mostly `ShopItem`, occasionally dropped)

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Worn Magnet Head | near | 2 | 1 | — | Gear | found grapple part; feeds Gear track |
| Reinforced Saw Blade | temporal | 3 | 1 | — | Gear | tool tier bump |
| Cyrus's Nail-Gun | lateral | 4 | 2 | — | Gear/QST | named tool; story-linked |
| Containment Clamp | far | 5 | 1 | — | Gear | unlocks anomaly-containment slots |

#### F — Recipes / Blueprints · one-time `unlocked_recipes` faucet

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Grease-Stained Recipe Card | surface | 1 | 1 | — | recipe | teaches a basic repair |
| Appliance Schematic | near | 2 | 1 | — | recipe | fix white-goods for higher $ |
| Retro-Tech Manual | temporal | 3 | 1 | — | recipe | temporal-band craft branch |
| Impossible Blueprint | lateral | 4 | 1 | — | recipe | needs Lore to even read |
| Cyrus's Fabrication Codex | far | 5 | 1 | — | recipe/QST | endgame craft tier |

#### G — Lore / Knowledge items · the Lore → Knowledge faucet (gates the acts)

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Cyrus's Cassette Tape | surface | 1 | 1 | — | LO/QST | GDD: Cyrus only via recordings |
| Yellowed Logbook Page | near | 2 | 1 | — | LO | fragment; decodes to Lore |
| Corrupted Data Core | temporal | 3 | 1 | — | LO | needs a reader; Knowledge unlock |
| Alien Glyph-Plate | lateral | 4 | 1 | — | LO/HAZ | decoding raises Exposure/`I` |
| Memory Crystal | far | 5 | 1 | — | LO | high Lore; band-4 gate key |

#### H — Quest / Story items · plot-bound, non-sellable

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Inheritance Deed Fragment | surface | 1 | 1 | — | QST | Act-1 lawyer/creditor thread |
| Confidant's Keepsake | near | 2 | 1 | — | QST | Relationships track unlock |
| Rival Diver's Marker | lateral | 4 | 1 | — | QST | Act-3 antagonist breadcrumb |
| Cyrus's Signet | far | 5 | 1 | — | QST | hidden Cyrus's-path ending |

#### I — Band-Exotic (identity) · signature deep loot (Money + Salvage + Lore in one object)

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Hubcap `[shipped]` | near | 2 | 2 | 20 | $ | near-band identity object |
| Car Battery `[shipped]` | temporal | 3 | 3 | 55 | $/HAZ | temporal identity; leaks acid |
| Radiator `[shipped]` | lateral | 4 | 4 | 80 | $ | lateral identity object |
| War-Surplus Helm | temporal | 3 | 2 | 65 | $/LO | past-scrapyard flavor + lore |
| Frozen Moment | lateral | 4 | 1 | 110 | $/LO/HAZ | a second, trapped; needs containment |
| Engine Block `[shipped]` | far | 5 | 6 | 120 | $ | far identity; the bulky payday |
| Discarded God's Tooth | far | 5 | 3 | 250 | $/LO/HAZ | GDD §4 "discarded gods"; containment |
| Molted Star-Husk | far | 5 | 4 | 200 | $/SV | reality-warping treasure |

#### J — Cursed / Anomalous / Hazardous · push-your-luck objects (reward + downside)

| Item | Band | Tier | Slot | ~Value | Role | Note |
|---|---|---|---|---|---|---|
| Leaking Battery Cell | temporal | 3 | 1 | 30 | $/HAZ | damages adjacent slots over time |
| Screaming Kettle | temporal | 3 | 1 | 40 | $/HAZ | draws enemies while carried |
| Hungry Toolbox | lateral | 4 | 2 | 90 | $/HAZ | `IS_CONTAINER` that eats an item/dive |
| Exposure Idol | lateral | 4 | 1 | 130 | $/HAZ | sells huge; spikes Exposure meter |
| Weeping Portrait | far | 5 | 2 | 160 | $/LO/HAZ | Lore-rich; raises local `I` each tick |
| Living Rust | far | 5 | 1 | 100 | SV/HAZ | spreads to neighbors unless contained |

**Roster totals:** ~55 example items — A:11, B:7, C:8, D:8, E:4, F:5, G:5, H:4, I:8, J:6 — spanning all five
bands and tiers 1–5, with the 8 shipped items slotted in as anchors. This is a *starting* list sized for
M2–M3 greybox, not a final content bible.

### 2.4 How each category interacts with the core loop

- **Sell (Money, categories A/B/I):** the extraction faucet. B (valuables) and dense A items reward *good
  triage*; bulky A/I items (engine block) reward *nerve* (carry-cost vs payday). This is the shipped loop.
- **Keep/Craft (Salvage, category C + dual-use A):** GDD §8's recipe system. The **sell-or-scrap** fork
  (Fallout model) turns a pickup into a decision — cash today or a Gear/Yard upgrade tomorrow. C items are
  the *only* Salvage faucet; without them the Salvage currency has no source and dies (economy model §5).
- **Decode (Lore → Knowledge, category G + H):** the act-gate faucet. Lore items are low-flow, capped-ish
  (you can only find so many per band), and gate *progression* not *power* — matching the economy model's
  Lore role. Some (glyph-plates) carry a HAZ cost, tying Knowledge-gain to risk.
- **Use (category D):** in-dive consumables convert Money/Salvage (bought/crafted) into dive-time, safety,
  or reach — the *drain* that makes deep dives sustainable and gives the push decision a resource cost.
- **Unlock (category F):** blueprints are the "new recipes as a reward tier from deep dives" faucet — a
  one-time knowledge gain that widens what A/C items can become.
- **Story (categories H, and QST-flagged E/G/I):** non-economic; drives confidants, creditors, the rival,
  and the Cyrus mystery. Deliberately *non-sellable* so the player never trades away plot.
- **Risk (category J + HAZ flags across C/I/G):** the push-your-luck layer. A cursed item is worth a lot
  *and* carries a cost (damages neighbors, draws enemies, spikes Exposure or `I`, or needs a containment
  slot). This is where the Instability scalar `I` and the exposure system get item-level hooks, and where
  the anomaly-containment inventory tetris (GDD §6) earns its keep.

### 2.5 Band-as-identity (the world sells itself through loot)

Each band should be recognizable from a fistful of its junk (Dredge's biome-fish lesson):

- **Surface** — bolts, cable, rebar, loose coins, a grease-stained recipe, Cyrus's first tape. *Mundane, safe.*
- **Near** — copper, hubcaps, silver cutlery, a pocket watch, an intact motor. *Another junkyard, now.*
- **Temporal** — retro alloy, war-surplus, e-waste bricks, corrupted data cores, leaking cells. *Another time.*
- **Lateral** — impossible metal, paradox gears, a jeweled trinket, a frozen moment, the Exposure Idol. *Another reality.*
- **Far** — star-slag, a discarded god's tooth, memory crystals, living rust, Cyrus's signet. *Alien/magical.*

The **Aberration trick** (Dredge) is a cheap breadth multiplier: author a "warped" variant of a common item
that appears in high-`I` / storm-weather runs — same silhouette, off-ladder band glow, ~2× value, plus a
HAZ flag. One flag on an existing `.tres` yields a whole exotic sub-tier per band.

---

## 3. Integration sketch (against the real files)

### 3.1 Guiding principle

**Extend `JunkItem` for everything ground-spawnable and economic (A, B, C, I, J); add small sibling
Resources only where the data shape genuinely diverges (D, F, G/H).** This honors the as-built rule ("one
Resource per purpose") without exploding the class count. Tools/gear (E) already have their home in
`ShopItem` — found-gear is a `ShopItem`-family drop, not junk.

### 3.2 Extend `JunkItem` (categories A/B/C/I/J)

Add to `data/junk/junk_item.gd`:

```gdscript
enum Category { MATERIAL, VALUABLE, COMPONENT, EXOTIC, CURSED }  # A B C I J
@export var category: Category = Category.MATERIAL

# --- Multi-currency yield (today only base_sell_value exists) ---
# Keeps Money as the default; lets one pickup ALSO be a Salvage/Lore source (dual-use).
@export var salvage_yield: int = 0   # units of Salvage currency if scrapped/kept (C, some A/I)
@export var lore_yield: int = 0      # units of Lore if decoded (G-adjacent I items)
# base_sell_value stays the Money value; a UI/recipe decides sell-vs-scrap (Fallout fork).

# --- Hazard / curse block (category J, HAZ-flagged I/C/G) ---
@export var hazard_kind: StringName = &""   # &"" = inert; e.g. &"leak", &"noise", &"exposure", &"instability", &"spread"
@export var hazard_magnitude: float = 0.0   # designer-tuned; 0 = none
```

Add a **`REQUIRES_CONTAINMENT`** member to the existing `ContainmentFlag` enum (bit `1 << 3`) so exotic/cursed
items can demand a special slot — the GDD §6 anomaly-containment mechanic, using the machinery that already
exists (`containment_flags`, `IS_CONTAINER`, `NO_NEST`). No new inventory system; one new flag.

**Why not subclass `JunkItem` per category?** The catalog is a typed `Array[JunkItem]` and the spawner/
inventory are pure `JunkItem` consumers (as-built B3↔C2 seam). A `category` enum + optional fields keeps
all ground salvage in one catalog and one code path; subclasses would fragment the catalog for no runtime
gain. Reserve real subclassing for the non-junk siblings below, whose *fields* actually differ.

### 3.3 Sibling Resources (categories D, F, G/H)

Purpose-built, each with its own small catalog under `data/`, mirroring the `ShopItem`/`ShopCatalog` idiom:

- **`ConsumableItem`** (`data/consumables/`) — `id, display_name, description, effect_kind, magnitude,
  charges, greybox_color`. Reuses `ShopItem`'s `effect_kind`-stub pattern (already proven, effect wired
  later without a schema change). Findable in-dive **and** buyable, so it may also just be a `ShopItem` with
  `persistent = false` — recommend deciding this in Open Questions §4.
- **`BlueprintItem`** (`data/blueprints/`) — `id, display_name, unlocks_recipe: StringName, lore_gated: bool`.
  On pickup/decode it appends to the existing `GameState.unlocked_recipes` — a faucet for a field that
  already exists and already persists.
- **`LoreItem`** (`data/lore/`) — `id, display_name, description, lore_yield: int, fragment_id: StringName
  (dialogue/story hook), is_quest: bool`. Covers both G (decode → Lore currency) and H (quest, `lore_yield=0`,
  `is_quest=true`). The narrative payload (`fragment_id`) is why this can't just be a `JunkItem` — it points
  into the Dialogue Manager / story bible, not the economy.

### 3.4 Catalog & save/telemetry organization

- **`.tres` layout:** `data/junk/items/` already holds the A/B/C/I/J files; add subfolders or an `id` prefix
  convention (`junk_`, `val_`, `comp_`, `exotic_`, `cursed_`) so lint can check category↔prefix agreement.
  Siblings get `data/consumables/`, `data/blueprints/`, `data/lore/`, each with a typed catalog resource.
- **Spawn weighting:** `JunkCatalog.spawn_weights_by_id` (the shipped Dictionary) already supports per-item
  weights; band/`I`-gated categories (I, J) just get 0 weight in shallow bands. No new spawn system — B3's
  depth curve + this dictionary cover it.
- **Save:** `banked_junk` already persists as `id` strings rehydrated from the catalog (meta schema v2).
  New categories flowing into the bank cost **no** schema bump if they're `JunkItem`. Lore/quest items that
  should persist in *meta* (not run-state) would ride existing meta collections (`unlocked_recipes`, or a new
  `collected_lore: Array[StringName]`) — that *is* a schema bump, following the E1 template (migration step +
  fixture). Keep the run/meta boundary: consumables and unbanked junk are run-state; recipes, lore, owned
  gear are meta.
- **Telemetry:** the shipped `junk_picked_up` / `junk_spawned` rows already carry `item_id`; adding a
  `category` field to the pickup payload (additive, not a schema bump — same pattern as the `build` field)
  lets G1-style analysis measure *which categories* players grab, drop, and sell — the causal check the
  familiarity exploration also wants.

### 3.5 Readability hooks (tie to study 03)

The taxonomy slots straight into the locked readable-junk channels: **tier → rarity ladder color**, **band →
off-ladder glow**, and now **category → silhouette/shape**. The shipped `greybox_shape` enum has only 4
shapes (`RECT/CIRCLE/TRIANGLE/DIAMOND`) — with ~10 categories this enum should grow (or category should
*drive* a shape/icon family) so a cluttered floor parses by category-silhouette before color, per study 03 §6.
Value density (B vs I) already reads through `value_per_slot()`.

---

## 4. Open Questions

1. **Sell-vs-scrap: one pickup, two outputs — or two items? [fun/scope — Director]** The strongest decision
   (Fallout) is letting the *same* A/C item be sold for Money **or** broken for Salvage. That means `JunkItem`
   carries both `base_sell_value` and `salvage_yield`, and a UI fork at the counter/workbench. Cheaper
   alternative: components (C) are simply non-sellable Salvage objects, no fork. Trade-off: the fork is
   richer but adds a sell-screen mode and doubles the balancing (Money *and* Salvage EV per item);
   the split is simpler but loses the "cash now vs upgrade later" tension the GDD §8 recipe system implies.
   **Recommend the fork for a small subset (dual-use A/C only), inert for the rest** — but it's a fun-gate call.

2. **How many currencies does one object yield? [scope]** Category I "band-exotic" items are pitched as
   Money+Salvage+Lore in one object (Dave the Diver's Giant Squid). Elegant, but a triple-yield item is
   three balance knobs and a confusing sell screen. **Recommend: at most two roles per object** (a primary
   + one secondary), reserving triple-yield for 1–2 hero items per band.

3. **Consumables: new Resource or a `ShopItem` variant? [technical, resolvable]** `ShopItem` already has
   `persistent = false` (re-buyable) and an `effect_kind` stub. A findable-and-buyable consumable could reuse
   it rather than adding `ConsumableItem`. Trade-off: reuse = fewer classes but overloads `ShopItem`'s meaning
   (it's currently "Hub buy catalog"); a dedicated Resource is cleaner but is +1 class. **Lean reuse** unless
   in-dive consumables need fields the shop doesn't (charges, stack). *Fresh-eyes resolvable, not a Director call.*

4. **Does the catalog stay one typed `Array[JunkItem]`, or split per category? [technical, resolvable]**
   §3.2 recommends one catalog + a `category` enum. If a category needs radically different spawn logic
   (e.g. lore items placed at *fixed* set-piece anchors, not weighted-random), it may want its own placement
   pass. **Recommend: shared catalog for A/B/C/I/J; G/H lore placed by the set-piece injector** (`data/bands/
   flavors/set_piece_inject_config.gd` already exists) rather than the random junk placer.

5. **Curse/hazard depth: flavor flag or real system? [fun/scope — Director]** Category J can be a light
   `hazard_kind` string that a later milestone wires, or a full sub-system (spreading corruption, containment
   tetris, Exposure/`I` coupling). The GDD promises the containment-tetris and Exposure hooks, but that's
   real scope. **Recommend: author the `hazard_kind`/`REQUIRES_CONTAINMENT` data now (greybox-inert, à la
   `effect_kind = &"none"`), wire effects in the milestone that also builds Exposure/`I`** — so the data is
   forward-compatible but nothing is half-built. Whether cursed items are *fun* or just annoying is a fun-gate call.

6. **Item familiarity interaction [fun — Director, cross-refs p3 exploration].** If the familiarity mechanic
   ships, a *broad* roster multiplies the "first-contact fog" — dozens of item types to learn. Does breadth
   make familiarity a satisfying mastery arc or a grindy checklist? The two designs are coupled: more
   categories → more to appraise. **Recommend deciding roster breadth and familiarity together at the same
   fun gate**, with the mis-sell telemetry from the exploration as the shared evidence.

7. **Trash floor — do valueless items exist at all? [design, resolvable]** Tarkov/Zero Sievert keep pure
   noise (rags, empty cans) to make triage real; our economy model warns against dead weight. Trade-off:
   a little worthless clutter makes *finding* the good stuff satisfying, but too much is busywork and hurts
   the readable-floor goal (study 03). **Recommend: keep the *bottom* of category A cheap-but-nonzero (the
   $3 bolt), and use density/`value_per_slot()` — not true-zero items — as the "skip this" signal.**

8. **Roster size for M2/M3 [scope — Director].** ~55 here is a *starting* list. The readable-junk study and
   the roguelite survey both argue *fewer, sharper* items read better. What's the target count for the first
   playable content pass — the ~8 shipped, ~20 (2–4 per category), or the full ~55? **Recommend ~20 for the
   first content milestone** (proves every category + every currency faucet with minimum authoring), scaling
   toward ~55 as bands come online. Director's call on content budget.

---

## Sources

- [Escape from Tarkov Wiki – Loot](https://escapefromtarkov.fandom.com/wiki/Loot) · [Category:Barter items](https://escapefromtarkov.fandom.com/wiki/Category:Barter_items) · [Category:Valuables](https://escapefromtarkov.fandom.com/wiki/Category:Valuables) · [Loot Guide – BoostRoom](https://boostroom.com/blog/escape-from-tarkov-loot-guide-most-valuable-items-to-pick-up)
- [Zero Sievert Wiki – Items](https://zero-sievert.fandom.com/wiki/Items) · [Loot](https://zero-sievert.fandom.com/wiki/Loot) · [Crafting Guide – TechRaptor](https://techraptor.net/gaming/guides/zero-sievert-crafting)
- [Hardspace: Shipbreaker Wiki – Salvage](https://hardspaceshipbreaker.fandom.com/wiki/Salvage) · [Salvage Bay](https://hardspaceshipbreaker.fandom.com/wiki/Salvage_Bay)
- [Dredge Wiki – Dredge (game mechanic)](https://dredge.fandom.com/wiki/Dredge_(game_mechanic)) · [Aberrations](https://dredge.fandom.com/wiki/Aberrations) · [Fish](https://dredge.fandom.com/wiki/Fish)
- [Dave the Diver DB – NiaMeowDB](https://meowdb.com/db/dave-the-diver) · [Fish Guide – Switchblade](https://www.switchbladegaming.com/cozy-games/dave-the-diver-fish-guide/)
- [Fallout 4 Wiki – Junk items](https://fallout.fandom.com/wiki/Fallout_4_junk_items) · [How To Scrap Junk – TheGamer](https://www.thegamer.com/fallout-4-tips-scrapping-junk/)
- [Subnautica Wiki – Raw Materials](https://subnautica.fandom.com/wiki/Raw_Materials_(Subnautica)) · [Blueprints](https://subnautica.fandom.com/wiki/Blueprints_(Subnautica))
- [Stardew Valley Wiki – Artifacts](https://stardewvalleywiki.com/Artifacts) · [Museum list – TheGamer](https://www.thegamer.com/stardew-valley-museum-complete-list-artifacts-minerals/)
- Internal: `Junkyard_GDD.md §4/§6/§8`, `Game/data/junk/junk_item.gd`, `Game/data/shop/shop_item.gd`, `design/research/06152026/03_readable_junk_study.md`, `design/research/06152026/12_economy_balance_model.md`, `design/explorations/exploration-20260625/economy-extraction/p3-item-familiarity.md`
