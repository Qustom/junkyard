# Environmental Extraction — Harvesting from Fixtures

*Research spike for THE FAR YARD. How the player rips salvage out of the environment
itself — car batteries out of wrecks, copper out of walls, motors out of machines,
fuel out of tanks, loot out of sealed containers — as a distinct verb from picking
up loose ground loot.*

**Author:** game-director-designer · **Date:** 2026-07-12 · **Status:** research (not
yet a task; a candidate M2 content system)

---

## 0. Framing: fixtures vs. ground loot

The M1 build has exactly one acquisition verb: **loose ground loot**. `JunkPlacer.plan()`
scatters depth-scaled `JunkItem` duplicates across a band's floor cells; `JunkSpawner`
instances one `JunkPickup` (Area2D) per entry; the player walks up and presses `interact`;
D1's `RunInventory.try_add()` accepts or rejects (`Game/entities/junk_pickup/junk_pickup.gd`,
`Game/systems/depth/junk_placer.gd`, `Game/systems/spawning/junk_spawner.gd`). Pickup is
**instant, free, silent, and always available** — a single button press with a fat-finger
lockout of `0.0` (no channel).

**Environmental extraction** proposes a *second* verb layered on the same interaction spine:
harvesting from **fixtures** — interactable environment objects (wrecked cars, wall runs of
copper pipe, dead machines, fuel drums, sealed crates). Fixtures differ from ground loot on
four axes that are, together, the whole design pitch:

| Axis | Ground loot (M1, shipped) | Fixture harvest (proposed) |
|---|---|---|
| **Time** | Instant press | **Channel** — hold/wait 1.5–5 s; interruptible |
| **Gate** | Always grabbable | Often **tool-gated** (cutter, pry-bar, magnet, breather) |
| **Cost** | Free | **Noise** (aggro/instability), tool durability, sometimes fuel/consumable |
| **Value** | Low, high-density scatter | **Value-dense**, deliberate, the "worth the risk?" objects |

This maps 1:1 onto the two lead GDD pillars: **Push or cash out** (a fixture is a live
risk-reward micro-bet inside the run) and **An engineer, not a soldier** (tools *unlock the
world's value*, not just win fights). It is a natural **M2** system — the vertical-slice
milestone already calls for "one tool with traversal use" and recipe-based repair (TDD §7,
M2), and a tool that *also* gates harvesting is a clean way to make that tool earn its keep.

---

## 1. Broad survey / prior art

### 1.1 Hardspace: Shipbreaker — the gold standard for "cut it out of the world"

Shipbreaker is the reference implementation of environmental extraction as the *entire* game.
The player has two core tools: a **Cutter** (a laser with a pinpoint "vaporise the point you
hold on target" mode and a wide-beam "carve a line across the hull" mode) and a **Grapple**
(pull yourself to heavy objects, pull light objects to you, later tether two objects). Value
lives in *components* embedded in the ship — you cut points to detach panels, then rip out the
reactor, thrusters, and named components, sorting each into the right processor. Progression is
**certification tiers** that unlock tools rated for higher **Cut Levels** and more hazardous
ships (Javelin/Gecko-class), all under a **debt** you are working off ([Modular Laser Cutter —
Fandom](https://hardspaceshipbreaker.fandom.com/wiki/Modular_Laser_Cutter), [Tools & Upgrades —
Shapes](https://shapes.inc/fandom/hardspace-shipbreaker/tools-and-upgrades), [how to cut salvage
— Gamepur](https://www.gamepur.com/guides/how-to-cut-salvage-in-hardspace-shipbreaker)).

**Strengths for us:** the exact fiction (dismantle a wreck into sellable parts to clear a debt),
tool-gating as the progression engine, and the "hold-on-target to sever a specific point"
channel verb. Hazards are baked into the object (a fuel line you cut carelessly ignites; a
pressurised cabin decompresses) — extraction is dangerous *because of what you're cutting*.

**Weaknesses / mismatch:** Shipbreaker is a first-person physics sandbox with free-aim beams and
zero-G object handling. Our top-down, grid-cell, greybox prototype cannot (and should not) carry
free-form cutting. We take the **structure** (tool-gated, channel-to-sever, value-in-components,
debt frame) and drop the **physics** (no free-aim laser, no soft-body hull). Our fixture is an
*atomic node with a channel and a yield table*, not a deformable mesh.

### 1.2 Tarkov / Zero Sievert — timed container search, loose-vs-contained loot

Escape from Tarkov and its 2D top-down cousin ZERO Sievert split acquisition into **loose loot**
(grab instantly off the ground/shelf) and **containers** (filing cabinets, toolboxes, bodies,
crates) that require a **timed search**: you open the container and items are *revealed one at a
time* over a few seconds, during which you are exposed and weapon-down. ZERO Sievert makes this
tension explicit — searching a body takes real time, and if someone gets the jump on you mid-search
you're at a disadvantage; players learned to cancel-and-reopen a search to bias which corner
reveals first so they could grab a specific item without waiting out the whole animation ([Search —
Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Search), [Looting — Tarkov
Wiki](https://escapefromtarkov.fandom.com/wiki/Looting), [ZERO Sievert looting
thread](https://steamcommunity.com/app/1782120/discussions/0/4753074843850056927/), [ZERO Sievert
review — In An Age](https://inanage.com/2024/11/27/review-zero-sievert/)).

**Strengths for us:** the **channel-as-vulnerability** model — the time you spend harvesting is
time you can't defend yourself or watch the clock. That is precisely the tension we want fixtures
to add over instant ground grabs. The loose-vs-contained split is a proven way to make *some*
loot free and *some* loot cost commitment.

**Weaknesses:** Tarkov's search is a pure UI-grid reveal with no *skill* and no *world*
consequence beyond time. It's tense in PvP (someone might shoot you) but flat in PvE. For a
single-player game we must supply the pressure ourselves — the dive clock draining, noise pulling
"things that came through," instability rising — or the channel is just a nag timer.

### 1.3 7 Days to Die / Rust — scrapping world objects, tool tiers, per-object depletion

7DTD is the closest to our literal fiction: **ruined vehicles** (sedans, trucks, buses),
appliances, and machinery are **salvageable** with a **Disassemble Tool** — the tier-1 **Wrench**
(then ratchet, then impact driver) harvests electrical/mechanical objects and yields scrap iron,
electrical parts, springs, etc. Tools are **tiered** (Tier 0 primitive → Tier 3 steel), and better
tools harvest faster and return more. Crucially, a wreck is a **finite node with stages**: it holds
salvage loot as a "container," and *if you scrap it too far the container is destroyed and never
respawns* — you can deliberately leave it partly intact to keep it as a renewable source; empty
containers otherwise respawn on a long day-timer ([Salvaging —
7DTD](https://7daystodie.fandom.com/wiki/Salvaging), [Scrapping —
7DTD](https://7daystodie.wiki.gg/wiki/Scrapping), [Wrench —
7DTD](https://7daystodie.fandom.com/wiki/Wrench), [car respawn
thread](https://steamcommunity.com/app/251570/discussions/0/1291817208493648601/)). Rust similarly
gates car/component scrapping and world-object farming behind tool tiers.

**Strengths for us:** the exact catalog (cars, appliances, machines → mechanical/electrical parts),
**tool-tier gating**, and **multi-stage depletion** (a car isn't one grab — it's several harvests,
and you decide when to stop). The "you can leave it partly harvested" idea is a fixture-scale
push/cash-out.

**Weaknesses:** 7DTD's persistent open world makes depletion/respawn a long meta-timer question.
Ours is a **roguelite** — fixtures should be **single-run, non-respawning within a dive**, freshly
re-rolled by proc-gen each descent. We inherit the *stages* and *tool tiers*, not the persistence.

### 1.4 Deep Rock Galactic — mineral veins, tool-appropriate extraction, "objective vs bonus" nodes

DRG's ore veins and minerals are harvest nodes embedded in destructible terrain, mined with the
pickaxe (or drilled/blown with C4 for chunks). Some minerals are **objective-critical** (Morkite),
some are **currency** (Nitra buys resupplies mid-mission), some are **bonus credits** (Gold). The
node telegraphs itself through a glowing seam in the rock; different extraction methods (pick,
drill, explosive) trade speed for control ([Resources —
DRG](https://deeprockgalactic.fandom.com/wiki/Resources), [ore mining methods
thread](https://steamcommunity.com/app/548430/discussions/1/3165461141509924809/)).

**Strengths for us:** the idea that **different fixtures serve different currencies** maps onto our
three-currency economy — a fuel tank feeds a *consumable*, a copper run feeds *Money*, an alien
star-husk feeds *Lore*. And Nitra-as-mid-mission-currency is a model for a fixture whose output you
*spend inside the same dive* (e.g. siphoned fuel refills your saw/torch).

**Weaknesses:** DRG mining is terrain deformation with a movement/traversal skill layer we don't
have top-down. We take the **taxonomy** (critical/currency/bonus nodes) not the mechanic.

### 1.5 Subnautica — hand-vs-tool harvest, one-shot vs. renewable nodes

Subnautica's harvesting nodes are mineral outcrops you break to reveal materials; **many can be
broken by hand, but tools have custom faster animations**, and some resources **do not respawn**
while a few sources (Reefback barnacles) do ([Harvesting Nodes —
Subnautica](https://wiki.subnautica.com/sn/Harvesting_Nodes), [Every Resource That Respawns —
TheGamer](https://www.thegamer.com/subnautica-every-respawning-resource/)).

**Strengths for us:** the **soft tool gate** — you *can* harvest bare-handed, but a tool is faster
and yields more. That's a gentler, less frustrating alternative to Shipbreaker/7DTD hard gates, and
worth considering as the default so a player who lacks the cutter isn't hard-walled out of content.

### 1.6 Dredge / Dave the Diver — timed harvesting *under an existing pressure clock*

Dredge and Dave the Diver both run resource-gathering as **timed minigames layered under a survival
clock** — Dredge's dredging is a small nav-a-dot-around-obstacles wheel you complete while your
sanity/night-danger rises; Dave's dredging DLC adds a wheel-shaped minigame during a fog event that
gates valuable finds ([DREDGE — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Dredge),
[Dave the Diver DREDGE pack —
Steam](https://store.steampowered.com/app/2677020/DAVE_THE_DIVER__DREDGE_Content_Pack/), [Catch and
Release review](https://www.chantasticvoyage.com/2023/07/catch-and-release-review-of-dredge-and.html)).
Dredge is also THE FAR YARD's stated pitch anchor ("*Dredge meets an extraction roguelite*", GDD §1).

**Strengths for us:** proof that a *timed harvest under a dread clock* is exactly the tone we want —
the harvest is quiet mechanically but the **context** (the light dimming, the thing in the fog)
supplies the tension. This validates keeping the fixture verb simple (a channel bar) and letting the
**dive clock + instability + noise** carry the fear, rather than building a twitchy cutting minigame.

**Weaknesses:** a literal QTE/wheel minigame risks fighting our "recipe-based, no tactile minigame"
decision for repair (GDD §8). We should be careful that fixture harvest is a **channel + risk**, not
a dexterity minigame — consistency with the repair philosophy matters.

### 1.7 Teardown — total material stripping (the anti-pattern boundary)

Teardown lets you demolish and strip *any* material with the right tool, physics-simulated.
It's the maximal expression of "the environment is the loot," and it's the boundary we should
*not* cross: it demands a voxel-destruction engine and turns levels into rubble. Our takeaway is
inverse — **fixtures are discrete authored props with a defined yield**, not a fully destructible
world. That keeps proc-gen legible (fixtures are placeable, seedable, countable) and keeps the
"readable junk" contract intact.

### 1.8 Cross-survey synthesis — the pattern menu

| Pattern | Best exemplar | What it buys | Cost / risk |
|---|---|---|---|
| **Channel-to-sever** (hold on point) | Shipbreaker | Deliberate, tense, tool-expressive | Needs interrupt rules or it's a nag timer |
| **Timed reveal search** | Tarkov / ZERO Sievert | Vulnerability-while-looting | Flat in PvE without external pressure |
| **Tool-tier gate** | 7DTD / Rust | Progression; "see it now, take it later" | Hard-walls content if too strict |
| **Soft tool gate** (hand OK, tool better) | Subnautica | Never fully blocks; rewards the tool | Weaker gate → weaker progression pull |
| **Multi-stage depletion** | 7DTD car | Fixture-scale push/cash-out | Bookkeeping; needs clear stage telegraph |
| **Node → distinct currency** | DRG (Morkite/Nitra/Gold) | Ties fixtures to the 3-currency economy | Must read at a glance which is which |
| **Harvest under a dread clock** | Dredge / Dave | Tension from context, simple verb | Only works if the clock is already scary |
| **Full material strip** | Teardown | Maximal fantasy | Engine-heavy; rejected for us |

**The recommended blend for THE FAR YARD:** a **channel-to-harvest** verb (Shipbreaker/Tarkov)
that is **soft-tool-gated by default with a few hard-gated marquee fixtures** (Subnautica default +
7DTD marquee), supports **multi-stage depletion** on big fixtures (7DTD car), routes different
fixtures to **different currencies** (DRG), and derives its tension from the **existing dive clock +
noise + instability** (Dredge) rather than a dexterity minigame (keeping faith with the no-minigame
repair decision).

---

## 2. What fits THE FAR YARD

### 2.1 Starter fixture catalog (per band)

Fixtures should follow the GDD "junkyard-ness gradient" (§4): the *definition of a fixture*
loosens as you descend, exactly like the loot does. Bands: `surface`, `near`, `temporal`,
`lateral`, `far`.

| Band | Fixture | Verb / gate | Primary yield → currency |
|---|---|---|---|
| **Surface / Near** | **Wrecked car** (multi-stage) | Pry hood (bar) → rip battery; cut catalytic converter (saw); pull alternator; strip wiring loom (cutter) | Battery/alternator/cat → **Money** (value-dense); wiring → Salvage (copper) |
| Surface / Near | **Wall pipe/wiring run** | Cut (cutter) — soft-gated: slower with bare hands | Copper pipe/wire → **Money**/Salvage |
| Surface / Near | **Dead appliance** (fridge/washer) | Rip panel → pull compressor motor / copper coil | Motor → Salvage; coil → Money |
| Surface / Near | **Fuel drum / tank** | **Siphon** (channel; breather muffles fumes) | Fuel → **in-dive consumable** (refuels saw/torch/generator) |
| Surface / Near | **Sealed crate / vending / locker** | **Pry open** (bar) → reveals loose ground loot inside | Random `JunkItem` scatter → mixed |
| **Temporal** | **Antique machine** (loom, engine block) | Unbolt/rip (magnet-grapple) → brass gears, flywheel | Gears → Salvage; antiques → **Money** (era premium) |
| Temporal | **War-surplus crate / ammo box** | Pry (bar) | Retro tech/ordnance parts → Money/Salvage |
| Temporal | **Future e-waste server rack** | Cut/unrack (cutter) | Rare-earth module, alloy → **Money** + occasional Lore |
| **Lateral** | **Paradox apparatus** | Channel (may need a ward-tool to touch safely) | Anomalous part (multi-slot / needs containment) → Salvage + **Lore** |
| **Far** | **Star-husk / discarded "god"** | Channel; **Knowledge-gated to even perceive/extract** (GDD lore-gate §4) | **Lore core** → Lore; reality-warp treasure |

Design notes on the catalog:
- **Currency routing is deliberate.** Cars/appliances/pipes are **Money** faucets (the everyday
  debt-clock fuel). Machines and anomalies bias to **Salvage** (the hard crafting ingredient). Deep
  fixtures bias to **Lore**. This gives fixtures a *reason to exist per band* beyond "more value."
- **Fuel drums are the sink-and-source hook.** A siphon that fills an in-dive fuel reserve for your
  torch/saw makes a fixture that *enables more fixtures* — a DRG-Nitra-style intra-run economy that
  is optional but rewarding. (Flag as scope — see Open Questions.)
- **Cars are the flagship multi-stage fixture** and the ideal M2 vertical-slice showpiece: one
  object, 3–4 harvests, each a different tool/verb, each a "do I have time/noise budget for one more
  part?" micro-decision.

### 2.2 Interaction design

**Channel time.** Harvest is a **hold-to-channel** (or press-to-start-then-wait) action, 1.5–5 s
scaling with fixture tier/difficulty. The channel is **interruptible**: moving off the fixture or
taking damage cancels it (refund-vs-waste is an Open Question). A progress bar renders at the fixture
(reuse the readable-junk grounding conventions — the bar is the telegraph that "this is being
worked"). Channel time is the core cost: **it eats the dive-light budget** (`dive_clock_changed`
keeps draining while you channel), so every fixture is time you're *not* spending going deeper or
extracting.

**Tool gates (soft by default, hard for marquee fixtures).** Each `FixtureDef` declares an optional
`required_tool` and a `bare_hands_allowed` flag:
- **Soft gate (default):** harvestable bare-handed but **slower and louder**; the tool (cutter,
  bar, magnet, breather) makes it fast and quiet. This never hard-walls a player out of content —
  the Subnautica model.
- **Hard gate (marquee):** a few fixtures are *impossible* without the tool (copper needs a real
  cutter; the star-husk needs a ward and Knowledge). These are the **"see it now, take it later"**
  progression hooks the GDD tool tree is built for (§8: "New tools open new traversal" — here, new
  *harvest*). Seeing a locked fixture you can't yet touch is a pull to invest in the Gear track.

**Noise → in-run danger (NOT the meta Exposure meter).** Harvesting is **loud** — the differentiator
that makes fixtures riskier than silent ground grabs. Completing (or channeling) a harvest emits a
**noise event** that raises **in-run** pressure: aggro nearby "things that came through"
(`opposition_event`) and/or nudge the **instability/dive escalation** already in the build (the
`exposure_*` run-scoped signals — `exposure_meter_changed`, `exposure_speed_mult_changed`, etc.).
**Critical distinction to hold:** this is the *in-dive instability* pressure, **not** the *social
Exposure* meter of GDD §9 (visible-wealth/confidants-talking, a between-runs meta system). Feeding
in-run noise into the *social* meter would be a category error. Recommendation: run-scoped
noise→aggro; leave meta Exposure alone. (Flagged for Director — Open Questions.)

**Multi-stage depletion.** Big fixtures (cars) hold an **ordered list of yield stages**; each
channel completes one stage and re-arms for the next until depleted, then the fixture disables
(`Interactable.enabled = false`) and reads as spent. The player can **stop at any stage** — a
fixture-scale push/cash-out ("I grabbed the battery; the cat converter isn't worth the extra 4 s of
noise"). Fixtures **do not respawn within a run**; a fresh descent re-rolls them via proc-gen.

**Consumables/durability cost.** Tool-gated harvest can consume **tool durability** and, for
torch/saw fixtures, **fuel** (which siphon fixtures replenish). This is the GDD "costs that bite"
pillar (§7) applied to harvesting: fighting isn't the only thing that drains your kit.

### 2.3 How it deepens the risk/reward loop vs. plain ground loot

Ground loot is a *legibility and pacing* system — fast triage, keep the floor readable, keep the
bag-management decision alive. Fixtures add a **second, slower decision axis** that ground loot
structurally can't:

1. **A time bet inside the run.** Every channel is seconds off the light clock — a concrete,
   felt version of "one more zone vs. head home," now at the granularity of a single object.
2. **A tool-progression pull.** Locked/slow fixtures make the Gear track *visible as denied value*
   on the ground, which is a stronger motivator than an abstract upgrade menu. Investing in the
   cutter literally *opens the world's copper to you* — the GDD's cross-fed upgrade fantasy made
   physical.
3. **A noise-for-value trade.** Fixtures are the game's loudest actions; they convert the quiet
   scavenger into a target. That is the "success draws attention" pillar (§2.4) enacted moment to
   moment inside the dive.
4. **Value density + bag tetris.** Fixtures yield the value-dense, sometimes multi-slot/containment
   items (an alternator, an anomalous paradox part) that make the slot-inventory decision bite —
   feeding the D1/D2 inventory tension the readable-junk study is built around.
5. **Currency steering.** Because fixtures route to specific currencies, a player low on Salvage can
   *choose* to prioritise machines over cars this run — giving the run a goal beyond raw Money, which
   the flat ground-scatter can't express.

Net: ground loot is the **floor** (ambient, free, fast); fixtures are the **objectives** (deliberate,
gated, risky, currency-steered). Both feed the same bag and the same push/cash-out gate, but fixtures
are where the run's *decisions* live.

---

## 3. Integration sketch (against as-built APIs)

The whole design deliberately **reuses the shipped interaction + placement + spawn spine** and adds
a channel/interrupt layer plus a new content Resource. Nothing here requires touching the run/meta
boundary or the save schema for a first slice.

### 3.1 New data: `FixtureDef` Resource (`data/fixtures/fixture_def.gd`)

Mirrors `JunkItem`'s "data as Resources" pattern. Authored `.tres`, catalog-indexed like
`JunkCatalog`.

```gdscript
class_name FixtureDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Wrecked Car"
@export_enum("surface","near","temporal","lateral","far") var origin_band: String = "surface"

# Verb / gate
@export var channel_time_s: float = 3.0
@export var required_tool: StringName = &""        # &"" = none
@export var bare_hands_allowed: bool = true         # soft gate; false = hard gate
@export var knowledge_gate: int = 0                 # min knowledge_level to perceive/extract (far band)

# Yield: ordered stages. Each stage names JunkItem ids from junk_catalog.tres + a count.
# Depth value-scaling is applied at plan time, same as JunkPlacer (reuse DepthCurve.value_mult).
@export var yield_stages: Array[Dictionary] = []    # [{ item_id: StringName, count: int, currency_hint: StringName }]

# Cost / risk
@export var noise_level: float = 1.0                # scales the emitted noise radius/magnitude
@export var tool_durability_cost: int = 0
@export var fuel_cost: int = 0                       # siphon fixtures have negative (they GRANT fuel)

# Greybox appearance (M1-style, no art dependency)
@export var greybox_color: Color = Color(0.4, 0.4, 0.45)
@export var greybox_size: Vector2 = Vector2(28, 18)  # fixtures are bigger than 10px junk
@export var blocks_movement: bool = true             # solid prop → doubles as cover/routing
```

A `FixtureCatalog` (`items: Array[FixtureDef]` + `spawn_weights_by_id`) parallels `JunkCatalog`
exactly, so the planner can weighted-pick per band.

### 3.2 New scene: `Fixture` (`entities/fixture/fixture.tscn` / `.gd`)

Composition follows the **exact ExtractGate/JunkPickup owner pattern** — a body with an
`Interactable` child on layer 3, listening to `EventBus.interaction_requested`. The one new thing is
a **`HarvestChannel`** component (a channel timer + interrupt + progress) replacing the instant
`_try_pickup()`.

- Root is a **StaticBody2D on the `world` layer (bit 2)** when `blocks_movement` (cars/racks are
  cover and routing obstacles — a nice interaction with the stealth pillar), or an Area2D when not
  (wall pipes). An `Interactable` child sits on the `interactable` layer (bit 3) with
  `interactable_id = &"fixture"` and `prompt_text` from the def (e.g. "Rip battery").
- `HarvestChannel` reuses the **`InteractionOwner` id-guard/parent-check** shape but adds the
  channel. Because the shipped `InteractionOwner` only supports an *instant* activation with an
  optional post-lockout (no progress channel — confirmed in
  `Game/components/interaction/interaction_owner.gd`), the channel is the genuinely new engine work.

```gdscript
class_name Fixture
extends StaticBody2D

@export var def: FixtureDef
var _io: InteractionOwner
var _stage: int = 0
var _channeling: bool = false
var _channel_t: float = 0.0
@onready var _interactable: Interactable = $Interactable

func _ready() -> void:
    _io = InteractionOwner.new(self, _interactable.interactable_id, 0.0)  # start on press
    add_child(_io)
    _io.activated.connect(_on_activated)

func _on_activated(_target: Node) -> void:
    if _channeling or def == null or _is_depleted():
        return
    if not _tool_ok() or not _knowledge_ok():
        _flash_locked()                      # telegraph the gate; no channel
        return
    _begin_channel()

func _begin_channel() -> void:
    _channeling = true
    _channel_t = def.channel_time_s * _tool_speed_mult()   # soft gate: bare hands slower
    set_process(true)
    EventBus.fixture_harvest_started.emit(def.id, _channel_t)   # HUD draws the bar; audio cues

func _process(delta: float) -> void:
    if not _channeling:
        set_process(false); return
    if _interrupted():                       # moved away / took damage (Open Question: refund vs waste)
        _channeling = false
        EventBus.fixture_harvest_interrupted.emit(def.id, &"moved")
        set_process(false); return
    _channel_t -= delta
    if _channel_t <= 0.0:
        _complete_stage()

func _complete_stage() -> void:
    _channeling = false
    set_process(false)
    var stage: Dictionary = def.yield_stages[_stage]
    # Noise → IN-RUN danger only (NOT meta Exposure). Aggro / instability nudge.
    EventBus.noise_emitted.emit(global_position, def.noise_level, def.id)
    # Yield: reuse the shipped spawn factory so harvested items are ordinary ground pickups
    # (keeps the bag-space decision honest — Open Question: spawn vs auto-add).
    _spawn_yield(stage)                      # -> JunkSpawner.spawn_one(item, pos, container)
    EventBus.fixture_harvest_completed.emit(def.id, _stage)
    _stage += 1
    if _is_depleted():
        _interactable.enabled = false        # reads as spent; detector skips it
        EventBus.fixture_depleted.emit(def.id)
```

`_spawn_yield()` builds a depth-scaled `JunkItem` duplicate exactly as `JunkPlacer` does
(`template.duplicate(true)`; scale `base_sell_value` by `DepthCurve.value_mult(depth_norm)`), then
hands it to the **already-shipped shared factory** `JunkSpawner.spawn_one(item, world_pos, container)`
— the same entry point drop-to-swap uses. So harvested parts *are* normal ground pickups the moment
they pop out; no new pickup/accept/reject code.

### 3.3 Proc-gen placement

Two placement models, recommend the first for M2:

- **(A) Authored anchors in zone-pieces (recommended M2).** A zone-piece scene carries `Marker2D`
  "fixture anchors" (tagged with an allowed-fixture-kind), exactly like the door **sockets** the
  band assembler already mates on (`Game/systems/depth/junk_placer.gd` and the B1↔B2 socket geometry
  in `M1_As_Built.md`). During band assembly a **`FixturePlacer`** — parallel to `JunkPlacer`, using
  the same **local RNG sub-stream** pattern (`RNG.substream_hashed(band.resolved_seed, _FIXTURE_SALT)`,
  *never* reseeding the global autoload) — fills each anchor from a band-appropriate `FixtureCatalog`
  by seeded weighted pick, or leaves it empty by a density roll. Hand-placed anchors keep fixtures
  **readable and deliberate** (a car sits where a car makes sense) while staying seed-deterministic.
- **(B) Fully planner-driven placement** (later). Fixtures planned onto floor cells like junk, with
  depth scaling on count/tier via `DepthCurve`. More variety, less authored legibility. Defer.

Either way, `FixturePlacer.plan(band, catalog, ...) -> Array[{world_pos, def, depth}]` and a
`FixtureSpawner.populate(plan, container)` mirror the `JunkPlacer`/`JunkSpawner` seam **verbatim** —
plan is pure/deterministic, spawner is a pure consumer. Fixtures parent to the band container (not to
scaled piece nodes) at raw world coords, honoring the I1 `cell_size_override` lesson so they don't
mis-place at size-mult ≠ 1.0.

### 3.4 New EventBus signals (pre-declare on `main` before any parallel wave)

Per the as-built convention (`M1_As_Built.md`: "pre-declare any new signals on `main` before a
*parallel* wave"):

```gdscript
signal fixture_harvest_started(fixture_id: StringName, channel_s: float)
signal fixture_harvest_completed(fixture_id: StringName, stage: int)
signal fixture_harvest_interrupted(fixture_id: StringName, reason: StringName)
signal fixture_depleted(fixture_id: StringName)
signal noise_emitted(world_pos: Vector2, magnitude: float, source: StringName)
```

`fixture_harvest_started/completed` drive the HUD progress bar + `AudioDirector` cues (a channel is a
great audio moment — grinding metal, then a *clunk* on completion) and Telemetry. `noise_emitted` is
consumed by whatever run-scoped danger system exists at build time (opposition aggro and/or the
`exposure_*` in-run instability), keeping fixtures decoupled from any specific enemy.

### 3.5 HUD / readability

Reuse the readable-junk conventions (`03_readable_junk_study.md`): a fixture telegraphs, **before**
you commit the channel, (a) its silhouette (a car reads as a car), (b) a **tool-required glyph** if
gated ("needs cutter"), and (c) a **depletion state** (intact → partially stripped → spent). The
channel itself shows a **progress bar** at the fixture. No text on the floor until focused — the
prompt (`ui/interaction_prompt.tscn`) already handles the focused verb hint ("[E] Rip battery").

### 3.6 Smallest M2-sized slice (the vertical-slice cut)

Everything above is the full system. The **minimum lovable slice** to validate the verb at M2:

1. **One fixture: the wrecked car**, single-stage for the slice (yields one `car_battery` `JunkItem`).
2. **One verb: hold-to-channel ~3 s, interruptible** (moving cancels). This is the only genuinely new
   engine code (the channel/interrupt on top of `InteractionOwner`).
3. **Yield spawns as a ground `JunkPickup`** via the shipped `JunkSpawner.spawn_one` — zero new
   acquisition code; the player still grabs it and the bag can be full.
4. **Single-use depletion** (`Interactable.enabled = false` after one harvest); fresh each descent.
5. **Placement via one authored anchor** in one existing zone-piece.
6. **Tool gate and noise ship behind flags, defaulting OFF** — so the all-off default reproduces "a
   3-second-channel version of a ground pickup," the permanent control (mirroring the M1.x
   configurable-knob convention: *all-off default reproduces the prior baseline*). Turn the tool gate
   and `noise_emitted→aggro` on as the A/B knobs the M2 gate measures.
7. **Telemetry:** log `fixture_harvest_started/completed/interrupted` so the gate can ask *"is the
   channel fun or a nag? how often do players interrupt? does the car out-earn its time?"*

That slice is one programmer task (channel component + `Fixture` scene) + one
`game-director-designer` task (`FixtureDef` schema, the car `.tres`, one anchor authored) — sized
like a single M2 wave item.

---

## 4. Open Questions

Design calls that need resolution before a build; the **fun/tone/scope** ones are explicitly flagged
for the human **Director** (per the orchestrator's judgment rule).

1. **[FUN — Director] Is a channel fun or a nag?** The entire premise rests on the hold-to-channel
   feeling tense-and-deliberate rather than tedious. Trade-off: too short (<1.5 s) and it's a reskinned
   instant grab; too long (>5 s) and it's a chore that players resent under the clock. *Recommendation:*
   ship the car at ~3 s behind a tuning knob and let the M2 fun-gate + telemetry (interrupt rate,
   time-per-harvest, "did they harvest at all?") settle it. **Needs Director review at the M2 gate.**

2. **[FUN — Director] Interrupt: refund or waste the time?** If moving/taking damage cancels a channel,
   is the elapsed time **refunded** (channel resets, forgiving) or **wasted** (you lost those seconds,
   punishing)? Trade-off: waste makes noise/positioning matter and raises stakes; refund avoids
   feel-bad losses to a stray enemy nudge. *Recommendation:* **refund on player-initiated move, waste
   on damage** (you chose to bail = free; you got hit = consequence). Fun call — **Director.**

3. **[Design] Yield destination — ground-spawn vs. auto-add to inventory.** Spawning the harvested part
   as a ground `JunkPickup` (recommended, reuses shipped code) keeps the bag-space decision honest but
   adds a second press. Auto-adding to `RunInventory` is smoother but hides the capacity tension and
   needs full-bag handling at the fixture. *Recommendation:* ground-spawn for the slice; revisit if the
   double-step feels bad in playtest.

4. **[Design — Director-adjacent] Noise → which system?** Confirm noise feeds **run-scoped instability /
   opposition aggro**, NOT the **meta social Exposure meter** (GDD §9). These are different systems that
   share the word "exposure" in the codebase (`exposure_*` run signals vs. the between-runs social
   meter). Conflating them is a category error. *Recommendation:* run-scoped noise→aggro only. **Flag
   to Director** to confirm the two "exposures" stay separate and to decide whether noise *also* nudges
   the in-run instability escalation or *only* aggros enemies.

5. **[Scope — Director] Tool-gate hardness.** How many fixtures are **hard-gated** (impossible without
   the tool, strong progression pull, risk of frustration) vs. **soft-gated** (slower/louder bare-handed,
   gentler)? Trade-off: hard gates make the Gear track feel essential (Shipbreaker/7DTD) but can wall a
   player out of a band's value; soft gates never block but weaken the pull (Subnautica). *Recommendation:*
   soft by default, **1–2 marquee hard gates per band** (copper needs a cutter; far-band star-husk needs
   ward+Knowledge). Scope/vision call — **Director.**

6. **[Scope] Multi-stage fixtures in M2 or defer?** The flagship car is best as a 3–4 stage strip (the
   fixture-scale push/cash-out), but multi-stage adds telegraphing + state complexity. *Recommendation:*
   ship **single-stage** in the M2 slice to validate the verb; add stages in the same milestone only if
   the single-stage verb tests fun.

7. **[Scope] Intra-run fuel economy (siphon fixtures).** Fuel drums that refill an in-dive fuel reserve
   for torch/saw fixtures (DRG-Nitra style) is an elegant "fixtures that enable fixtures" loop, but it
   introduces a new in-run resource and HUD. *Recommendation:* **defer past the M2 slice**; prototype
   only if the base fixture verb lands.

8. **[Design] Do fixtures block movement?** Solid fixtures (StaticBody on `world`) double as cover and
   routing obstacles (good synergy with the stealth pillar) but complicate proc-gen packing (they must
   not block the only path). *Recommendation:* cars/racks/machines are **solid** (place off the critical
   path via anchor authoring); wall pipes are **non-blocking** Areas. Validate path-non-blocking in the
   band's existing reachability check.

9. **[Design] Telegraphing the yield/gate before committing.** Should a fixture show *what* it yields
   and *what tool* it needs before you spend the channel time (readability) or preserve discovery? Per
   `03_readable_junk_study.md`, *recommend telegraph* — silhouette + tool glyph + depletion state — so
   the time bet is an informed decision, not a gamble.

10. **[Determinism] Yield rolls.** If a fixture's yield table has variance, those rolls must use the
    **local `RNG.substream_hashed(seed, salt)`** pattern (never the global autoload), same as
    `JunkPlacer`, so the plan stays seed-reproducible and the smoke test's determinism assertion holds.
    *Recommendation:* keep M2 yields **fixed (no variance)** to sidestep this entirely for the slice;
    add seeded variance later through the established sub-stream.

---

## Sources

- [Modular Laser Cutter — Hardspace: Shipbreaker Wiki](https://hardspaceshipbreaker.fandom.com/wiki/Modular_Laser_Cutter)
- [Tools & Upgrades — Hardspace: Shipbreaker (Shapes)](https://shapes.inc/fandom/hardspace-shipbreaker/tools-and-upgrades)
- [How to cut salvage in Hardspace: Shipbreaker — Gamepur](https://www.gamepur.com/guides/how-to-cut-salvage-in-hardspace-shipbreaker)
- [Equipment — Hardspace: Shipbreaker Wiki](https://hardspaceshipbreaker.fandom.com/wiki/Equipment)
- [Search — Escape from Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Search)
- [Looting — Escape from Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Looting)
- [ZERO Sievert looting change/bug thread — Steam](https://steamcommunity.com/app/1782120/discussions/0/4753074843850056927/)
- [Review: Zero Sievert — In An Age](https://inanage.com/2024/11/27/review-zero-sievert/)
- [Salvaging — 7 Days to Die Wiki](https://7daystodie.fandom.com/wiki/Salvaging)
- [Scrapping — 7 Days to Die Wiki (wiki.gg)](https://7daystodie.wiki.gg/wiki/Scrapping)
- [Wrench — 7 Days to Die Wiki](https://7daystodie.fandom.com/wiki/Wrench)
- [Car respawn thread — 7DTD Steam Discussions](https://steamcommunity.com/app/251570/discussions/0/1291817208493648601/)
- [Resources — Deep Rock Galactic Wiki](https://deeprockgalactic.fandom.com/wiki/Resources)
- [Ore mining methods thread — DRG Steam Discussions](https://steamcommunity.com/app/548430/discussions/1/3165461141509924809/)
- [Harvesting Nodes — Subnautica Wiki](https://wiki.subnautica.com/sn/Harvesting_Nodes)
- [Every Resource That Respawns — Subnautica (TheGamer)](https://www.thegamer.com/subnautica-every-respawning-resource/)
- [DREDGE — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Dredge)
- [Dave the Diver — DREDGE Content Pack (Steam)](https://store.steampowered.com/app/2677020/DAVE_THE_DIVER__DREDGE_Content_Pack/)
- [Catch and Release: a review of Dredge and Dave the Diver](https://www.chantasticvoyage.com/2023/07/catch-and-release-review-of-dredge-and.html)
- [A game sound designer's guide to button interactions — UX Collective](https://uxdesign.cc/a-game-sound-designers-guide-to-button-interactions-6837dd5cc977)
