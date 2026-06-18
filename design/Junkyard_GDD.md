# THE FAR YARD — Game Design Document

*Working title. Alternates: Scrapline, Deep Salvage, Yard's End, Below the Pile.*

**Version 0.2 — living document**
**Genre:** Roguelite extraction / survival-adventure with life-sim overworld
**Tone:** Cosmic dread with warmth
**Camera/View:** Top-down

---

## 1. High Concept

You're a laid-off engineer drowning in student debt, scraping by as a rideshare driver, when an uncle you barely remember dies and leaves you his junkyard. You plan to sell it and clear the loans. But while clearing it out, you notice the space doesn't add up — the yard is bigger inside than out. Then you find the portals.

Each portal opens onto another **junkyard** — and the deeper you go, the looser the word "junkyard" becomes. The lot across town. A scrapyard from forty years ago. A breaker's yard from a future that won't happen. A reality where rust is currency. Somewhere down there, things that came through the portals are picking through the same piles you are.

So you dive. You salvage, you fix, you sell, you survive — and you try to pay off a debt that gets stranger and more dangerous the more money you make.

**Pitch line:** *Dredge meets an extraction roguelite, set in a junkyard that is secretly every junkyard.*

---

## 2. Design Pillars

1. **Push or cash out.** Every moment below is a live risk-reward bet: one more zone for better junk, or extract now and bank what you've got. This single tension drives the whole game.
2. **An engineer, not a soldier.** You solve the depths with tools, wits, and jury-rigged gear. Combat is real but improvised and costly. Cleverness beats firepower.
3. **The contrast is the point.** The yard unsettles; the town heals. Horror is *earned* by how human and warm the surface life is. Neither half works without the other.
4. **Money is a problem, not just a reward.** Success draws attention. The better you do, the more the world wants to know where it's coming from — and the harder it gets to keep the secret.
5. **Understanding is power.** Knowing what the junkyard *is* unlocks places, crafts, and choices you literally couldn't reach before. Curiosity is a stat.

---

## 3. Story & Premise

### Setup (Act 1)
The protagonist (player-named; default neutral) inherits **Bellweather Salvage** from a near-stranger uncle, Cyrus. The plan is simple: clean it up, sell the land, kill the debt. Early cleanup reveals impossibilities — a path that's longer walking back than walking in, a shed with no exterior, cold spots, a sound like distant surf where there's no water. Cyrus left cryptic notes. The first portal opens on its own one night.

### Escalation (Act 2)
The protagonist starts diving deliberately. Money comes in. But you can't move this kind of cash, or this kind of *merchandise*, without people noticing. The central social question becomes: **who do you bring in, and who do you keep out?** A trusted friend doubles your capacity but becomes a liability. A buyer who asks too few questions is suspicious; one who asks too many is dangerous. The student loan was just the first creditor.

### Reckoning (Act 3)
Once you're genuinely rich and the secret is straining, the world closes in: corporate buyers, a journalist, a **rival diver who surfaces as an active antagonist only now** (they clearly have their *own* portal), and whatever Cyrus was really doing down there before he died. **Whether Cyrus survived at all stays an open question until the very end** — his presence is felt only through recordings (tapes, voicemails, a logbook) scattered across the bands. Endings branch on exposure, relationships, and how deep you chose to go.

### Themes
Debt and the things we inherit; the cost of secrets; what "garbage" means and who decides; finding home in a place that frightens you; whether to escape a broken life or rebuild one.

---

## 4. The World: "Junkyard-ness" as a Depth Gradient

The organizing idea. **Every zone you can reach is, by some definition, a junkyard.** Descending broadens the definition until it barely resembles where you started. This single rule explains the loot curve, justifies endless procedural variety, and seeds the horror.

| Band | "Junkyard" defined as... | Flavor | Loot | Danger |
|---|---|---|---|---|
| **Surface** | Your inherited lot | Familiar, mundane, safe (mostly) | Common scrap, tools | None / tutorial |
| **Band 1 — Near** | A junkyard elsewhere *now* | The lot across town, the city dump, a port breaker's yard | Modern goods, electronics, parts | Low; first "things that came through" |
| **Band 2 — Temporal** | A junkyard from another *time* | Past scrapyards, war surplus, a future e-waste megafill | Antiques, retro tech, future-alloys | Medium; stranger entities |
| **Band 3 — Lateral** | A junkyard from another *reality* | Physics slightly off, alt-history detritus, things that were never made here | Anomalous items, paradox parts | High; reality instability |
| **Band 4 — Far** | A junkyard by an *alien or magical* definition | Discarded gods, molted star-husks, a place that eats categories | Reality-warping treasures, lore cores | Severe; the deep things |

**Implications baked in:**
- **The scrap-network.** If your yard is one node, there are others. Other divers, other yards, rivals — and the unsettling sense that *you're being salvaged too.*
- **Lore-gated depth.** You can't safely (or sometimes physically) reach a deeper band until your **Knowledge** is high enough to comprehend/stabilize it. Knowledge is the gate between acts.
- **Procedural but legible.** Each dive assembles a run from a band's zone-pieces, so layouts vary while flavor stays coherent.

---

## 5. Core Game Loop

**Daytime → Dive → Extract → Sell → Upgrade → Evening (life) → Sleep → repeat.**

1. **Morning prep** — pick gear loadout, set a goal, choose an entry portal/band.
2. **Dive** — explore procedural zones, collect junk, fix/triage on the fly, fight or avoid "things that came through," traverse hazardous terrain. **Time/light is a consumable resource** that drains faster the deeper you are.
3. **The decision** — every zone deeper improves loot quality but costs time, risks your unbanked haul, and raises instability. **Push or extract?**
4. **Extract** — return to a surface gate to *bank* your haul. Die or run out of time/light → lose the unbanked haul (a small "pockets" fraction survives) but **keep all meta-progression**.
5. **Sell & sort** — convert junk to Money; set aside Salvage components; log Lore fragments.
6. **Upgrade** — invest across Gear, Yard, Relationships, Knowledge.
7. **Evening** — limited social/life actions: see friends, eat at the diner, advance story, decide who to tell.
8. **Sleep** — advances the day, may trigger dreams (lore/foreshadowing), resets the cycle.

---

## 6. The Dive (Roguelite + Extraction)

- **Run = a descent.** Procedurally assembled from the chosen band's zone-pieces. You enter through a portal and aim to go as deep as your nerve and gear allow.
- **Extraction banks loot.** Loot is *unbanked* until you return to a gate. Gates appear at band thresholds and as found shortcuts. Reaching a new gate lets you bank-and-continue or bank-and-leave.
- **Death/timeout is soft-roguelite.** You lose the current unbanked haul (minus a "pockets" save — you keep a few *whole items* worth a small fraction of the haul's value, not an abstract percentage) and consumables spent, but keep tools, blueprints, yard upgrades, relationships, and Knowledge. No total resets — the *run* resets, the *life* persists. *(M1 greybox value: keep whole items up to 20% of haul value, highest-value first — tuned at the M1 fun gate; data-driven in `run_rules.tres`. Ratified decision #13.)*
- **Instability pressure.** The longer you linger in a zone (especially deep), the more it destabilizes — light dims, entities multiply, the terrain shifts. Internal time pressure even though the overworld day is generous.
- **Run modifiers / "weather."** Some days a portal opens onto an unusually rich or unusually hostile version of a band (storms of static, a "low tide" exposing rare wrecks, a migration of deep things). Encourages choosing which portal to take.

### Run length & pacing
- **Target average dive ≈ 30 minutes.** Each band is a relatively short, self-contained segment (~15 min of meaningful play), so:
  - **Short dive ≈ 15 min** — one band, grab-and-extract.
  - **Long dive ≈ 60 min** — a full multi-band descent to the deep end and back.
- Band-sized chunks keep the push/cash-out decision frequent (a real gate at every ~15 min) and make a session easy to fit to the player's available time.

### Inventory (slot-based, upgradeable)
- **Carry capacity = slots**, not weight. Clean, readable, and a direct push/cash-out lever: full bag means deciding what to drop to grab something better.
- Slots are a **Yard/Gear upgrade** (bigger pack, sorting satchel, anomaly-containment slots for deep items). Some deep/anomalous items occupy multiple slots or need special containment, adding inventory tetris to the deep bands.

---

## 7. Combat & Tools (Balanced, Improvised)

You fight like an engineer: scrap weapons that double as utility, durability and ammo that make every fight a *choice*.

- **Tools-as-weapons-as-traversal.** A **magnet-grapple** pulls loot, yanks enemies, and crosses gaps. A **nail-gun** fights and repairs/builds. A **circular-saw-on-a-pole** cuts foes and cuts through blocked paths. A **breather rig** lets you survive toxic pockets *and* muffles sound for stealth.
- **Avoidance is always viable.** Stealth, distraction (toss a noisy part), and routing around are first-class options. Many deep things can't be killed cleanly, only evaded or warded.
- **Costs that bite.** Ammo, fuel, tool durability, stamina. Fighting trades resources you could've spent going deeper — that's the point.
- **Threats = "things that came through."** Not the junk itself (mostly), but entities that crawled in from wherever the portals lead. Junk is their habitat, not their body. They get more alien, less physical, and more dread-inducing by band. Deep things may require Knowledge/specific gear to even perceive or repel.

---

## 8. Economy: Three Currencies, Four Tracks

### Currencies
- **Money** — from selling fixed-up junk. The debt-clock fuel and the everyday upgrade currency.
- **Salvage** — specific rare items/components (not sold). The "hard" crafting ingredient for advanced gear and key yard restorations.
- **Lore (Knowledge)** — fragments decoded from anomalous finds, dreams, Cyrus's notes, NPC insight. The master key: unlocks deeper bands, new craft branches, and story.

### Investment Tracks
1. **Gear / Tech tree** — mostly Money + Salvage; some tools need a Lore insight to even *conceive* of. New tools open new traversal (grapple → vertical zones, breather → toxic zones, ward → deep things).
2. **The Yard (base)** — Money rebuilds it; certain restorations need Salvage or a Lore breakthrough. Physical, visible growth: workshop, sorting line, shopfront, a stabilizer that makes diving safer, and **defenses**. Defenses are first motivated in Act 2 — sometimes things follow you *up* through a portal, so you fortify the yard against incursions (wards, traps, reinforced gates). In Act 3 that same fortification is repurposed to defend against the **rival diver** who starts raiding your operation. Animal-Crossing-ish sense of place and pride, with a tower-defense-adjacent payoff late.
3. **Relationships** — *not bought with money.* Advanced through trust and **inclusion**. Bringing a friend into the mystery is the unlock; each confidant grants capability (cheaper upgrades, a getaway driver, a fence for "weird" goods, lore expertise) — and raises **Exposure**.
4. **Knowledge** — accrued from Lore; the higher-level meta-gate. Unlocks new zones, crafting ideas, and safe routes. Gates the acts.

**Cross-feeding:** the elegant part — Gear, Yard, and Relationships can each be advanced by *money, specific items, OR lore*, depending on the upgrade. A tool might be bought, or built from a rare part, or only realized once you understand a deep principle.

### Repair / fixing (recipe-based)
Turning junk into sellable goods is a **recipe system**, not a tactile minigame. You acquire **recipes** (bought, found below, or unlocked via Lore), and fixing consumes the broken item plus required components/Salvage to produce the fixed, higher-value good. Keeps the loop fast and the depth in *what* you can make, not in execution. New recipes are a meaningful reward tier from deep dives and Knowledge.

---

## 9. NPCs, Secrecy & the Exposure System

The social meta-layer that ties the pillars together. **It persists between runs — it does not reset.**

- **Confidants.** A small cast (e.g., a mechanic friend, a diner owner who half-knew Cyrus, a broke grad-student "expert," a rideshare buddy). For each, you choose: bring them in, or keep them out.
  - *In* → real capability + warmth + story, but raises Exposure and creates a vulnerability (they can slip, be pressured, get hurt, or want a cut).
  - *Out* → safer secret, but you forgo their help and the relationship may sour as you grow distant and inexplicably rich.
- **Exposure meter.** A slow-filling track raised by: visible wealth, careless selling, confidants talking, rivals snooping. As it fills, **story crises** fire — break-ins, lowball buyout offers, a journalist's questions, men asking about Cyrus. High Exposure can lose you the yard.
- **Exposure management as gameplay.** Launder money through legit-looking sales, build trust so confidants stay quiet, choose discreet fences, sometimes *intentionally* lie low (skip a lucrative dive). Risk-reward at the life-sim layer mirroring the dive layer.

---

## 10. The Debt Clock (Escalating Stakes)

Debt starts soft and gets scary as you succeed.

- **Act 1 — Student loans.** Ordinary interest; pay when able. Establishes the money motive without punishing early experimentation.
- **Act 2 — New creditors.** As Exposure and wealth rise, fresh financial threats appear: a lawyer contesting the inheritance, a buyer who won't take no, a "partner" who wants in. Some carry soft deadlines.
- **Act 3 — Predators.** Blackmail, corporate pressure, a rival diver, possibly something that follows you up from below. Real deadlines with branching consequences.

The clock *grows teeth* the better you do — success is the threat. (Design note: keep Act 1 forgiving so players learn; ramp consequence with player power, not real-time.)

---

## 11. Day Cycle (Time as Resource)

- **Dives consume daylight/light and stamina;** deeper bands drain both faster. This forces the "one more zone vs. head home" call *inside* the day, not just inside the run.
- **Evening = limited actions.** A handful of social/life slots before sleep (visit someone, eat, work the shop, decode lore, rest). You can't do everything — choosing is the point.
- **Sleep advances the day** and may surface dreams (foreshadowing/lore) tied to how deep you've been.
- **Weekly/seasonal beats.** Debt payments, town events, rival moves, and Exposure crises land on the calendar to give the loop rhythm and dread-anticipation.

---

## 12. Progression Arc (Acts as Knowledge Gates)

- **Act 1 (Bands Surface–1):** Learn the loop. Discover the impossibility. First confidant choice. Goal: survive, sell, glimpse the truth.
- **Act 2 (Bands 2–3):** Industrialize the operation. Knowledge unlocks temporal/lateral bands and the ward/stabilizer tech. Things start following you up — you build **yard defenses** against incursions. Exposure becomes a real management game. Goal: get rich without losing the secret — or yourself.
- **Act 3 (Band 4):** The **rival diver** turns active antagonist and raids the yard — your incursion defenses now pull double duty against them. Confront what Cyrus found (and whether he's truly gone), and the network. Knowledge unlocks the far band. Endings resolve. Goal: decide what this is all *for*.

### Endings (branch on Exposure, Relationships, Knowledge, Depth)
- **Clean exit** — pay everything, seal the yard, walk away human. Bittersweet.
- **The Magnate** — embrace the operation; wealth and power, secret strained to breaking.
- **Caught** — Exposure maxed; the yard is taken, the truth out. Loss, or a defiant last dive.
- **Gone Deep** — Knowledge maxed; you understand too well and choose the network over the surface. Eerie.
- **(Hidden) Cyrus's path** — uncover and complete what your uncle started.

---

## 13. Art & Audio Direction (Initial)

- **Visual contrast** mirrors the tone pillar: the surface is warm, hand-painted, lived-in (golden-hour diner, cluttered cozy shop). The depths shift palette by band — familiar grime → desaturated nostalgia → impossible color → non-Euclidean dark.
- **Diegetic dread.** Horror through wrongness and sound design, not gore. Space that doesn't add up; a melody from a music box three bands down.
- **Audio.** Warm acoustic/lo-fi overworld; sparse, granular, increasingly synthetic-and-organic soundscapes below. Silence used as a weapon.
- **Readable junk.** Items legible at a glance (value/era/band cues) so sorting-and-deciding stays fast and satisfying.

---

## 14. Resolved Decisions

- **Camera:** Top-down. Favors exploration, stealth routing, and readable junk on the ground.
- **Run length:** ~30 min average. Bands are short (~15 min) self-contained segments; short dive ≈ 15 min (one band), long descent ≈ 60 min (full multi-band run and back).
- **Inventory:** Slot-based, upgradeable. Acts as a push/cash-out lever; deep/anomalous items can need extra or special containment slots.
- **Co-op:** Deferred to a future version. Design single-player-first, but keep the scrap-network/"bring someone in" fiction co-op-friendly for later.
- **Permadeath:** Optional hardcore mode (death = real reset). Cheap to add given the roguelite bones; explicitly **not a design focus**.
- **Cyrus:** Whether he survived stays unknown until the very end. Presence delivered only through **recordings** (tapes, voicemails, logbook entries) found across the bands.
- **Rival diver:** Stays off-screen until **Act 3**, then becomes an active antagonist who raids the yard. Confronting them reuses the incursion **defenses** built in Act 2.
- **Item fixing:** **Recipe-based** — acquire recipes, consume broken item + components to produce higher-value goods. No tactile minigame; depth lives in *what* you can make. New recipes are a reward tier from deep dives and Knowledge.

## 15. Still Open / Future

- Exact band count and how many bands are reachable per run at each act.
- Stamina vs. light vs. timer — which exactly governs the in-dive clock (or a blend).
- Repair economy tuning: how steep the value jump from broken → fixed should be.
- Yard-defense depth: light fortification flavor vs. a real tower-defense mode in Act 3.
- Rival mechanics: do they contest live zones below, or only raid the yard above?

---

*Next step: these decisions unblock a first systems prototype — top-down loop with a single band, slot inventory, the push/cash-out gate, recipe-fixing, and an exposure stub.*
