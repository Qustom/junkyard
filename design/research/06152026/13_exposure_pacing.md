# Exposure Pacing

*Research companion to the Technical Design Doc §9 (Exposure & Secrecy). How to pace a rising secrecy/heat meter and its crisis events so they create tension without feeling punishing or random.*

---

## 1. The Problem in One Sentence

A rising "heat" meter has to do two contradictory jobs at once: it must feel like an ever-present, mounting threat (so the player respects the secrecy fantasy), and it must feel *fair* — the player should always understand why it went up, believe they could have done otherwise, and have a route back down. Get the balance wrong in one direction and the meter is wallpaper the player ignores; wrong in the other direction and it feels like a random tax on play. This report surveys how shipped games solve that tension and ends with concrete pacing guidance for THE FAR YARD.

---

## 2. How Other Games Handle Escalating-Threat Meters

The shipped designs cluster into a few archetypes, and the differences between them are the design knobs we care about.

### Short-loop, fully resettable heat (GTA, Hitman)

GTA's **Wanted Level** is a five-star meter that spikes on *witnessed, visible* crimes and then enters an explicit **cooldown** phase. When police lose line of sight the radar stops flashing and the stars begin flashing; each pursuing unit shows a field-of-view cone (narrow for foot officers, wide for helicopters), and staying out of those cones drains the meter to zero. Re-entering a cone re-engages the chase. The soundtrack even has dedicated "cooldown" stems that play while you are hiding ([GTA Wiki](https://gta.fandom.com/wiki/Wanted_Level_in_GTA_V)). The key lesson is **legibility of cause and of escape**: the player can see exactly what is hunting them, exactly where its perception reaches, and exactly what action (break line of sight, wait) clears the state.

Hitman's **Suspicion Meter** (and the modern Alert Levels / Enforcer model) is even more local. Suspicion fills when a specific NPC observes specific "wrong" behaviour — running, a drawn weapon, a disguise an Enforcer can see through. The meter is *attached to an observer*, telegraphed by an on-screen fill, and resolved by breaking that observer's attention ([Hitman Wiki](https://hitman.fandom.com/wiki/Suspicion_Meter)). The lesson: tie rises to *identifiable witnesses and identifiable acts*, never to ambient nothing.

### Slow-loop resource you manage (Sunless Sea, Don't Starve, This War of Mine)

Don't Starve's **Sanity** drains passively from being in the dark, near monsters, or eating bad food, and is restored by a wide menu of *deliberate* actions — picking flowers (+5 each), sleeping (+50/night), wearing sanity gear, crafting prototypes. Crucially the *penalty is gated by threshold*: only below ~15% do shadow creatures spawn and the screen distort ([Don't Starve Sanity Guide](https://readygamesurvive.com/guides/dont-starve-sanity-guide/)). So most of the meter's range is "free" — the danger is concentrated at the bottom, which means the player has a large buffer to manage and the punishment is rare but vivid.

Sunless Sea's **Terror** (0–100, mutiny/game-over at 100) rises from sailing in unlit water and falls through specific, *planned* actions: keeping lights on, killing enemies (−10% instantly), and returning to London (auto-drops to 50, with a cost). Failbetter deliberately made Terror "less predictable... to encourage desperate tales of survival" rather than a routine top-up at a central port ([Sunless Sea Wiki](https://sunlesssea.fandom.com/wiki/Terror)). The lesson here is a deliberate one about *route planning*: the meter becomes a logistics puzzle layered over the moment-to-moment game.

This War of Mine's **morale/despair** is a 100-point scale split into 5 visible bands with progressive behavioural states (Content → neutral → Depressed → Broken). A Broken survivor stops self-preserving entirely. Enough negative events can *permanently* shift a survivor's archetype ([TWoM Wiki — Morale](https://this-war-of-mine.fandom.com/wiki/Morale)). The lesson: **banded, visible states with escalating behavioural consequences** read as a story to the player, not as a number.

### Per-character stress with random afflictions (Darkest Dungeon)

Darkest Dungeon's **Stress** rises with exploration and combat; at the 100 threshold a hero rolls an **Affliction** (usually a debuff) or, rarely, a **Virtue** (a buff). Stress is so central it is literally the game's logo (the Iron Crown) ([Darkest Dungeon — Wikipedia](https://en.wikipedia.org/wiki/Darkest_Dungeon)). This is the most "punishing/random" archetype on the list, and it is instructive *because* it courts that risk: the rare-virtue upside and the town-side stress-relief facilities (tavern, abbey) are what keep it from feeling purely cruel. The meter is paired with explicit, player-chosen *sinks*.

### Long-arc doom clocks (XCOM 2, Cultist Simulator, Blades in the Dark)

XCOM 2's **Avatar Project** is a 12-pip doom clock on the strategic layer; fill it and a fixed final countdown begins (24 days on Rookie down to ~15 on Commander). Players push it back with story missions, certain guerrilla ops, and Blacksites (which remove more than one pip). It is meant to keep tension across the whole campaign — though Firaxis acknowledged players learned to *exploit* it by repeatedly letting it run to <7 days and reacting, which "gave the strategic layer a leisurely pace that never matched the tone" ([XCOM Wiki — Avatar Project](https://xcom.fandom.com/wiki/Avatar_Project)). The lesson is a *warning*: a clock you can repeatedly reset at the last second trains players to ignore it until the buzzer.

Cultist Simulator models suspicion as **Notoriety / Mystique** cards that, if grabbed by a Hunter, generate Tentative → Damning Evidence and can end your run. Notoriety has a fixed **decay time (300s)** and several *mitigations*: wait it out, have a Heart follower destroy the card, hide it inside a painting, or relocate your headquarters ([Cultist Simulator Wiki — Notoriety](https://cultistsimulator.fandom.com/wiki/Notoriety)). The lesson: the threat is *materialised as a discrete object the player can act on*, and there are multiple, asymmetric ways to deal with it.

The single most directly relevant model is **Blades in the Dark's Heat → Wanted Level** system, because it is explicitly a secrecy/exposure meter for a crew of people doing things they must keep secret:

- After each job the crew takes **0 / 2 / 4 / 6 Heat** based on how "loud" the operation was, with modifiers (+1 high-profile target, +1 hostile turf, +1 at war, **+2 if killing was involved — "bodies draw attention"**).
- Heat accumulates on a track; **at 9 Heat the crew gains a permanent Wanted Level and the Heat clears** (excess rolls over).
- Higher Wanted Level means law enforcement responds with greater **quality and scale**, *and* raises the severity of post-job **Entanglements** (the crisis events).
- The *only* way to reduce Wanted Level is **incarceration** — someone takes the fall — which is a deliberate, costly sink ([Blades — Heat](https://bladesinthedark.com/heat)).

Blades pairs this with **Progress Clocks**: a "danger clock" fills 1–3 segments per complication depending on severity, and "when the clock is full, the danger comes to fruition." Blades explicitly frames a clock as *"a speedometer... it shows the speed, it doesn't determine it"* — i.e. the meter is a readout of the fiction, not an arbitrary timer ([Blades — Progress Clocks](https://bladesinthedark.com/progress-clocks)). This is the cleanest articulation of the fairness principle we need.

---

## 3. Thresholds vs Gradual Effects

The survey reveals a consistent and important pattern: **the meter's value should be mostly inert, with consequences concentrated at thresholds — but the *climb itself* should produce gradual, ambient signals.**

- Don't Starve, This War of Mine, and Sunless Sea all keep large stretches of the meter consequence-free, then trigger sharp effects at bands (Don't Starve's 15%, TWoM's five behavioural states, Sunless Sea's 50/100 break points). This gives the player a *manageable buffer* and makes the crossing feel like an event.
- Darkest Dungeon and Blades use a *single hard threshold* (100 stress → affliction; 9 heat → wanted level) where the consequence is large and discrete.
- GTA/Hitman blend them: the meter level continuously scales the *intensity* of the response (more stars = more police), but specific tiers unlock new response *types* (helicopters, NOOSE/SWAT).

The synthesis for a crisis-event system like ours: use **discrete thresholds to fire crisis events** (so they read as authored story beats, not noise), but use **gradual ambient feedback** (music stems, NPC behaviour, visual tells) to telegraph the approach so the threshold never surprises. Pure-gradual systems feel like a slow tax; pure-threshold systems feel arbitrary unless heavily telegraphed.

---

## 4. Player Agency: Sinks, Cooldowns, and Decay

Every system that is regarded as fair gives the player *more than one* way to push the meter down, and at least one of them is *active and skill-expressing* rather than passive waiting. The catalogue of mitigation types across the games:

- **Passive decay / cooldown** (GTA cooldown phase, Cultist Simulator's 300s decay, Sunless Sea's London reset). Cheap to use, low agency — good as a baseline floor so the meter never *only* goes up.
- **Active spend / sink** (Blades' incarceration, Sunless Sea lights-on costing fuel, Don't Starve crafting/flowers, Darkest Dungeon's town stress-relief which costs gold and a roster slot). The player trades a resource for relief. This is where most of the *interesting* decisions live.
- **Skill / risk action** (Hitman breaking line of sight, Sunless Sea killing an enemy for −10% terror, Cultist's Heart follower destroying a Notoriety card with a failure chance). Higher agency, higher tension.
- **Asymmetric / costly trade** (Blades' incarceration sends a *person* to prison; Cultist's HQ relocation burns a limited resource). These make reduction a meaningful sacrifice, not a chore.

Two design rules emerge. First, **decay should exist but be slow enough that it cannot, by itself, keep pace with active play** — otherwise the meter is meaningless (the XCOM last-second-reset trap). Second, **the best sinks are the ones that cost something the player also wants for the main game loop** (money, time, a teammate, a run's loot), so that managing exposure is a genuine opportunity cost, not a free button.

---

## 5. Telegraphing and Fairness

This is the single most important factor in whether the system feels punishing/random versus tense/fair. The recurring principles:

1. **Every rise must have a visible, attributable cause.** Hitman attaches suspicion to a specific watching NPC; GTA fills stars only on *witnessed* crimes; Blades assigns Heat per-job by named factors the player chose into ("you killed someone, +2"). The anti-pattern is ambient passive accrual the player can't trace — that reads as random. Even Sunless Sea, whose Terror is deliberately "unpredictable," ties rises to a concrete, controllable input (sailing dark).

2. **Telegraph the threshold before it fires.** GTA's flashing-stars cooldown, This War of Mine's named morale states, Blades' segmented clock you can literally count — all let the player *see the threshold coming* and act. The Blades "speedometer" framing is the goal: the meter is a readout that lets the player gauge their situation, never a hidden die roll.

3. **Telegraph the *consequence type* at each tier.** Blades' trigger-table variant of progress clocks gives "each step... repercussions or changes in the environment," so the player learns what each threshold band will bring ([thealexandrian.net on Progress Clocks](https://thealexandrian.net/wordpress/40424/roleplaying-games/blades-in-the-dark-progress-clocks)). Players forgive a harsh crisis they were warned about; they resent one they couldn't have predicted.

4. **Avoid the "no-win" perception.** Vampire: The Masquerade – Bloodlines is a cautionary tale: players complained of "masquerade violation for no reason," because violations sometimes fired from actions they didn't perceive as exposing, with a hard game-over after too few. Even though there *are* redemption quests to claw points back, the opacity of *why* a violation triggered is what generated the "punishing/random" reputation ([Bloodlines — masquerade violations discussion](https://gamefaqs.gamespot.com/boards/914819-vampire-the-masquerade-bloodlines/55774858)). The fix is purely about feedback clarity, not about making the system softer.

5. **Reduce randomness in *whether*, allow it in *flavour*.** Darkest Dungeon's stress threshold is deterministic (always at 100); the *which affliction* is random, which keeps variety without making the trigger feel unfair. Decouple "the crisis fires" (deterministic, telegraphed) from "which crisis fires" (can be randomised for replay value).

---

## 6. Pacing the Crisis Events Themselves

Beyond the meter, the *events* it spawns need their own rhythm. Lessons from the survey and from progress-clock theory:

- **Escalation, not repetition.** Each higher Wanted Level in Blades brings responses of greater "quality and scale" and worse Entanglements; each GTA star tier adds new enemy *types*. Crisis events should escalate in *kind* across tiers, not just frequency, so the player feels the situation genuinely deepening.
- **Recovery beats between spikes.** GTA's explicit cooldown phase, Darkest Dungeon's town visit, Sunless Sea's return to port — every well-paced system alternates pressure with a *breather* where the player can act on the meter. A crisis that immediately leads into another crisis with no agency window feels like punishment. Build a guaranteed "you can respond now" window after each crisis fires.
- **Frequency should track player choices, not the clock.** The strongest systems make crisis cadence emergent from how aggressively the player engages the risky activity (loud jobs in Blades, dark sailing in Sunless Sea). This makes pacing *self-adjusting*: cautious players get fewer crises, reckless players get more — and both feel they earned their pace.
- **Beware the resettable doom clock.** XCOM 2's experience shows that a clock the player can reliably reset at the last moment trains them to ignore it. If a long-arc exposure clock exists, either make the last-minute reset *costly enough* to discourage brinkmanship or make some of its progress *permanent* (Blades' Wanted Level never decays from play, only from incarceration).
- **Make the first crisis a teaching crisis.** Fire an early, low-stakes crisis specifically to teach the player the system's cause→effect→mitigation loop while the cost of learning is small.

---

## 7. Tuning via Telemetry

Pacing this kind of system is almost impossible to get right on paper; it is a tuning problem solved with data and playtests. Dynamic-difficulty literature stresses adjusting parameters to keep players in the engagement band between boredom and frustration, ideally without the player noticing the hand on the dial ([Dynamic game difficulty balancing — Wikipedia](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing); [Game balance — Wikipedia](https://en.wikipedia.org/wiki/Game_balance)). Concretely, instrument and watch:

- **Exposure-over-time curves per run**, segmented by player skill/archetype. Look for the *shape*: a healthy curve sawtooths (climb → mitigate → climb), a broken one either flatlines low (meter ignored) or ramps monotonically to a crisis the player never engaged with.
- **Time/percentage of runs spent in each threshold band.** If players almost never enter the high bands, the upper crises are dead content; if they live there, decay/sinks are too weak.
- **Mitigation usage rates.** Which sinks do players actually use? An unused sink is a balance or legibility failure. Track the ratio of passive decay vs active mitigation.
- **Crisis-event outcomes:** how often does a fired crisis lead to a run loss, a successful recovery, or being ignored? A crisis that is *always* fatal or *never* matters both need re-tuning.
- **Self-reported feel.** Pair the numbers with playtest survey questions: "Did exposure rising ever feel unfair/random?" and "Did you understand why it went up?" — the Bloodlines lesson is that the *perception* of fairness can diverge from the math.
- **Brinkmanship detection.** Watch for the XCOM exploit signature: players repeatedly approaching the threshold and resetting. If you see it, the threshold or reset cost needs changing.

---

## 8. Concrete Pacing Guidance for THE FAR YARD

Synthesising the above into recommendations for the exposure & secrecy system (TDD §9):

**Overall aggression.** Aim for *moderate-but-relentless*. Model the meter on Blades' Heat (loud activity → exposure, with permanent escalation at the top) rather than GTA (fully resettable) or Darkest Dungeon (per-entity, high randomness). Exposure should be a long-arc pressure the player feels across runs, not a per-second panic — this matches a life-sim/extraction structure where runs are punctuated by overworld downtime.

**Threshold structure.** Use a banded meter (suggest 0–100) with **3–4 named crisis thresholds** plus a large inert buffer at the bottom, à la Don't Starve. For example:
- 0–40: *Quiet.* No effects beyond ambient telegraphs (townsfolk gossip flavour). The "free" working range.
- 40–65: *Whispers.* First crisis tier — minor, recoverable overworld events; teaching crises.
- 65–85: *Scrutiny.* Mid crises — a meaningful overworld threat that costs resources to defuse.
- 85–100: *Crisis.* Severe, escalated story events; crossing 100 fires a major beat and (Blades-style) leaves a *permanent* mark that doesn't fully wash out.

Fire crises on **deterministic threshold crossings** (telegraphed), but **randomise which event** within a tier for replay variety (Darkest Dungeon split).

**Decay and mitigation.** Provide a layered kit, mirroring the fair systems:
- A *slow passive decay* during overworld downtime — enough to reward lying low for a cycle, but deliberately *too slow to outrun active risky play* (avoid the XCOM reset trap).
- At least two *active sinks* that cost things the player also wants: e.g. spend money/time on a cover activity, sacrifice run loot to "clean up evidence," or send an NPC to take heat off you (a Blades-incarceration-style asymmetric trade). Make the deepest reduction the most costly.
- One *skill/risk* mitigation so reduction can be active and tense, not just a wait.
- Make the **top-band escalation partly permanent** so brinkmanship is discouraged and high exposure has lasting narrative weight.

**Telegraphing (non-negotiable).** Every exposure gain must surface an attributable cause in the moment ("the scavenger saw the lights," "+2: a body was found"). Layer ambient tells as the meter climbs — music stems, NPC dialogue, visual changes in the overworld — so each threshold is visible on approach. After every crisis, guarantee a *recovery window* in which the player can act on exposure before the next can fire. Treat the meter as Blades' speedometer: a readout of choices, never a hidden roll.

**What to measure in playtests.**
1. Exposure-over-time curve shape per run (want a sawtooth, not a flatline or a monotonic ramp).
2. Fraction of runs reaching each band, and dwell time per band.
3. Mitigation-sink usage rates (each sink should see real use; passive-vs-active ratio).
4. Per-crisis outcome distribution (recovered / ignored / run-ending) — no crisis should be always-fatal or always-ignored.
5. Survey: "Did exposure ever feel unfair or random?" and "Could you tell why it rose?" — track perceived fairness separately from the math.
6. Brinkmanship signature (repeated approach-and-reset near a threshold).

The north star: a cautious player should be able to keep exposure in the quiet band most of a run through deliberate play, a reckless player should reliably trigger escalating crises they understand they provoked, and *no* player should ever feel exposure rose for a reason they couldn't see.

---

## Sources

- [Wanted Level in GTA V — GTA Wiki](https://gta.fandom.com/wiki/Wanted_Level_in_GTA_V)
- [Suspicion Meter — Hitman Wiki](https://hitman.fandom.com/wiki/Suspicion_Meter)
- [Alert Levels — Hitman Wiki](https://hitman.fandom.com/wiki/Alert_Levels)
- [Darkest Dungeon — Wikipedia](https://en.wikipedia.org/wiki/Darkest_Dungeon)
- [Don't Starve Sanity Guide for Beginners — Ready Games Survive](https://readygamesurvive.com/guides/dont-starve-sanity-guide/)
- [Terror — Sunless Sea Wiki](https://sunlesssea.fandom.com/wiki/Terror)
- [Morale — This War of Mine Wiki](https://this-war-of-mine.fandom.com/wiki/Morale)
- [Notoriety — Cultist Simulator Wiki](https://cultistsimulator.fandom.com/wiki/Notoriety)
- [Avatar Project — XCOM Wiki](https://xcom.fandom.com/wiki/Avatar_Project)
- [Masquerade violations discussion — GameFAQs (Bloodlines)](https://gamefaqs.gamespot.com/boards/914819-vampire-the-masquerade-bloodlines/55774858)
- [Heat — Blades in the Dark SRD](https://bladesinthedark.com/heat)
- [Progress Clocks — Blades in the Dark SRD](https://bladesinthedark.com/progress-clocks)
- [Blades in the Dark: Progress Clocks — The Alexandrian](https://thealexandrian.net/wordpress/40424/roleplaying-games/blades-in-the-dark-progress-clocks)
- [Dynamic game difficulty balancing — Wikipedia](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing)
- [Game balance — Wikipedia](https://en.wikipedia.org/wiki/Game_balance)
- [Telegraphing (entertainment) — Wikipedia](https://en.wikipedia.org/wiki/Telegraphing_(entertainment))
