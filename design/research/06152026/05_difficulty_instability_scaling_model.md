# Difficulty / Instability Scaling Model

*Research companion to the Technical Design Doc §9. How extraction and roguelite games scale risk-vs-reward across depth and time, and a concrete proposed scaling model for THE FAR YARD's bands and in-dive clock.*

---

## 1. Why this matters for THE FAR YARD

The game's stated core loop is a live risk-reward bet — "one more zone for better junk, or extract now and bank what you've got" (GDD §2, §6). For that bet to feel meaningful, three quantities must climb in lockstep as the player goes deeper or lingers longer: **reward density, threat, and the cost of failure**. If reward outruns danger, the optimal play is always "push," and the decision evaporates. If danger outruns reward, players bail early and never see the deep content. The job of a difficulty/instability model is to keep the marginal value of "one more zone" hovering near break-even, so the choice stays genuinely tense.

This report surveys how shipped extraction and roguelite games solve that problem, extracts the transferable design principles, and proposes formulas for the four bands (Near → Temporal → Lateral → Far) plus the in-dive instability clock.

---

## 2. Two axes of scaling: depth and time

Almost every game in this space scales along two independent axes:

- **Depth (spatial progression):** going deeper/further is a *deliberate* choice the player makes, and it steps reward and danger up in discrete jumps. This is the "greed" lever.
- **Time (run duration):** the longer a run lasts, threat rises *whether the player wants it or not*. This is the "you can't camp forever" pressure, and it's usually continuous rather than stepped.

The most satisfying systems use **both**, because they create a pincer: depth pushes you to go further for reward, while the time axis punishes the dithering and over-farming that depth invites. THE FAR YARD already designs for both — bands are the depth axis, and "instability pressure" is the time axis (GDD §6).

---

## 3. How specific games handle it

### Risk of Rain 2 — continuous time scaling + exponential depth jumps

RoR2 is the cleanest worked example of a combined model. A global **difficulty coefficient** (`coeff`) rises *linearly with time* and *jumps by 15% of its current value every time a new stage is entered*. Because the stage jump is multiplicative, repeated descents (loops) make the curve **exponential**, quickly outpacing the linear time term. Enemy level is derived from `coeff`, and enemies gain roughly **+30% HP and +20% damage per level**. Crucially, enemy *rewards (gold)* are also multiplied by `coeff`, so going deeper pays more — reward and threat are tied to the same number. Initial difficulty (Drizzle/Rainstorm/Monsoon) is just a multiplier on the time rate: Drizzle scales time at 50%, Monsoon at 150%. ([Risk of Rain 2 Wiki — Difficulty](https://riskofrain2.wiki.gg/wiki/Difficulty))

**Takeaway:** one scalar drives everything (enemy stats, spawn budget, *and* loot value), time is linear, depth is a multiplicative kick. This is the template the proposed model below borrows most heavily from.

### Hades — Heat (Pact of Punishment): opt-in difficulty for opt-in reward

Hades decouples difficulty from any in-run clock and makes it a **player-chosen stack of modifiers**. Each "Condition" (e.g., Hard Labor: +20% enemy damage per rank) adds **Heat** to a gauge; raising Heat unlocks fresh **Bounties** (rewards) for clearing regions. The design subtlety: you only earn each Bounty *once per Heat level*, so jumping straight to Heat 5 forfeits the rewards of Heats 1–4 — incentivizing incremental escalation. ([Hades Wiki — Pact of Punishment](https://hades.fandom.com/wiki/Pact_of_Punishment); [TheGamer — Heat and the Pact](https://www.thegamer.com/hades-heat-pact-punishment-trivia/))

**Takeaway:** the "more danger ⇒ more reward, but reward is gated so you can't skip the curve" principle. Useful for THE FAR YARD's run-modifier "weather" days (GDD §6) and for band-entry choices.

### Escape from Tarkov — the reward IS the risk (sunk-cost scaling)

Tarkov has comparatively flat *enemy* scaling; the escalation is **economic and psychological**. You bring gear *into* a raid, and death means losing everything you carried — so the more loot you accumulate, the higher the stakes of every subsequent second. The push-your-luck tension is self-generated: a successful loot run makes you *more* cautious, not less, because you now have more to lose. ([GamingArena — Risk and Reward in EFT](https://gamingareena.wordpress.com/2023/04/24/the-role-of-risk-and-reward-in-escape-from-tarkov-how-to-balance-risk-taking-with-survival/); [GamesRadar — EFT review](https://www.gamesradar.com/games/fps/escape-from-tarkov-review/))

**Takeaway:** the unbanked-haul mechanic is itself a difficulty scaler. Carrying more should *feel* heavier. THE FAR YARD's "small pockets fraction survives death" rule (GDD §4) is the right shape — it caps despair while preserving the sunk-cost dread.

### Spelunky — the ghost: a hard time cap that converts time into a resource

Spelunky's ghost spawns at a fixed timer (2:30 in Spelunky 1, 3:00 in Spelunky 2), after a warning, and is effectively unkillable — it forces you off the level. Designer Derek Yu's stated intent: collecting everything is "joyless"; time pressure turns looting into "an exciting dilemma" and rewards skillful, fast decision-making. Expert players even *weaponize* the ghost (leading it over gems to create diamonds), turning the threat into a high-skill reward. ([Spelunky Wiki — Ghost](https://spelunky.fandom.com/wiki/Ghost_(Classic)); [Spelunky 2 — Ghost](https://spelunky.fandom.com/wiki/Ghost_(2)))

**Takeaway:** a *telegraphed, escalating, eventually-lethal* timer is the single most proven device for the "stop farming" problem. The warning beat before the threat is essential. THE FAR YARD's instability meter should have a clear Spelunky-style "the clock is almost up" tell.

### Dredge — the panic meter: a continuous, fear-flavored instability gauge

Dredge's Panic rises while you're in darkness at night and falls in light or by sleeping. It's a continuous meter visualized by an **eye icon** that opens wider and flashes redder as it climbs; manifestations escalate in tiers — phantom obstacles, then ghost ships, then monster rays — so the *consequences* ramp with the meter rather than a single threshold flip. ([DREDGE Wiki — Panic](https://dredge.wiki.gg/wiki/Panic); [Casual Game Guides — Night, Panic, Aberrations](https://casualgameguides.com/walkthroughs/dredge/night-panic-aberrations-explained))

**Takeaway:** this is the closest tonal match to THE FAR YARD's "light dims, entities multiply, terrain shifts" instability (GDD §6). The lessons: (a) a single readable gauge, (b) a *visual identity* that intensifies with the value, and (c) **tiered manifestations** rather than one binary spawn.

### Deep Rock Galactic — Hazard Level: stepped difficulty bound to stepped reward

DRG sells difficulty as a pre-mission **Hazard Level (1–5)** that raises enemy count, enemy HP and damage, and reduces post-revive health, while *also* feeding a **Hazard Bonus** that scales end-of-mission rewards. Player count is a second multiplier on top. The contract is explicit and chosen up front. ([Deep Rock Galactic Wiki — Difficulty Scaling](https://deeprockgalactic.wiki.gg/wiki/Difficulty_Scaling))

**Takeaway:** discrete, player-selected difficulty tiers with a transparent reward multiplier — a clean model for THE FAR YARD's *band choice* and "weather" portals.

### Roguelike depth scaling (NetHack et al.) — the keeping-up problem

Traditional roguelikes scale by depth via three knobs: enemy *quantity* per floor, enemy *type weighting* (nastier monsters weighted higher as you descend), and direct *stat scaling* by depth. NetHack famously derives monster difficulty by averaging player level with dungeon depth. The classic failure mode is well documented: if **player power grows additively while enemy power grows multiplicatively (percentages)**, players fall irrecoverably behind at depth. ([Roguelike Tutorials — Increasing Difficulty](http://rogueliketutorials.com/tutorials/tcod/v2/part-12/); [TV Tropes — Level Scaling](https://tvtropes.org/pmwiki/pmwiki.php/Main/LevelScaling))

**Takeaway:** keep player-power growth and enemy-power growth in the *same mathematical family*, or deliberately let enemies pull ahead only as far as the extraction safety valve allows.

---

## 4. Design principles distilled

1. **One driving scalar.** Like RoR2's `coeff`, route enemy stats, spawn budget, AND loot quality through a single value so reward and danger are mathematically inseparable. You can't accidentally make farming "safe and lucrative."
2. **Time linear, depth multiplicative.** Continuous time pressure is a gentle linear ramp; crossing into a deeper band is a sharp multiplicative step. The combination yields the satisfying near-exponential late-run curve.
3. **Telegraph everything.** Telegraphing makes players "form expectations" ([Wikipedia — Telegraphing](https://en.wikipedia.org/wiki/Telegraphing_(entertainment))). Every escalation needs a *tell before the bite*: Dredge's widening eye, Spelunky's pre-ghost warning. A surprise difficulty spike reads as unfair; a *foreseen* one reads as a decision the player owned.
4. **Tier the consequences, don't flip a switch.** Dredge ramps panic effects in stages. Avoid single binary "now it's lethal" thresholds where possible; let danger bleed in so the player can feel the temperature rising and bail in time.
5. **Make the haul its own difficulty.** Tarkov's lesson — the more you carry, the higher the personal stakes — costs nothing to implement and generates tension for free.
6. **Gate reward to the curve.** Hades stops you from skipping difficulty tiers for free reward. Reward multipliers should require *actually being* at depth/instability, not just visiting.
7. **Be wary of rubber-banding.** Dynamic difficulty adjustment (silently easing/hardening based on player performance) risks players feeling their wins were "given" and that effort is pointless ([Wikipedia — Dynamic game difficulty balancing](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing); [Wikipedia — Rubber banding](https://en.wikipedia.org/wiki/Rubber_banding)). For a push-your-luck extraction game, **legible, deterministic** scaling is almost always preferable — the player must trust that their read of the risk is accurate. Reserve elastic adjustment, if used at all, for invisible soft-catches (e.g., a slightly more generous pity-loot timer after several deaths), never for the threat curve itself.

---

## 5. Proposed scaling model for THE FAR YARD

### 5.1 The single driver: Instability `I`

Let every dive track one scalar, **Instability `I`**, exposed to the player as the in-dive clock/meter (the "light dims, entities multiply" gauge of GDD §6). `I` rises from two sources — time in a zone and band depth — and drives enemy strength, spawn rate, *and* loot quality.

**Per-second time growth (linear within a zone):**

```
I += r_band  per second
```

where `r_band` is a per-band time-pressure rate. Deeper bands destabilize faster, consistent with "deeper bands drain light/stamina faster" (GDD §8):

| Band | `r_band` (Instability/sec) | Time to fill one zone's "comfort window" |
|------|----------------------------|------------------------------------------|
| Surface (tutorial) | ~0.00 | effectively unlimited |
| 1 — Near | 0.20 | ~75 s calm, ~150 s before pressure |
| 2 — Temporal | 0.30 | faster |
| 3 — Lateral | 0.45 | reality starts slipping sooner |
| 4 — Far | 0.65 | very little grace |

(Rates are starting points to tune against the ~15-min-per-band target, GDD §7.)

**Band-entry multiplicative step (the depth kick):** crossing a gate into a deeper band applies a one-time jump, RoR2-style:

```
I = I * (1 + 0.15)   per band crossed (plus a flat floor for the new band)
I = max(I, I_floor[band])
```

A flat `I_floor` per band guarantees a deep band is never trivially calm even if entered instantly, and the +15% multiplier means a long, greedy descent compounds into a genuinely hostile late game — the desired near-exponential curve without ever hard-coding "exponential" anywhere.

### 5.2 What `I` drives

**Enemy strength** (kept in the same family as player power growth to avoid the roguelike keeping-up trap):

```
enemyHP_mult  = 1 + 0.25 * I
enemyDmg_mult = 1 + 0.15 * I
```

**Spawn budget** (director-style, à la RoR2): a credit pool that accumulates proportional to `I`, spent on increasingly expensive/alien entities. Low `I` = lone weak things; high `I` = packs and "deep things."

```
spawnCredits_per_sec = base * (1 + 0.5 * I)
```

**Loot quality** — tied to the *same* `I` so reward and risk are inseparable:

```
lootTier_roll_bonus = floor(0.5 * I)      # nudges the rarity table upward
lootValue_mult      = 1 + 0.10 * I        # raw value scaling
```

This is the mathematical heart of the push/cash-out bet: every second of rising `I` makes the *next* item better **and** the next fight worse, by construction.

### 5.3 Telegraphing `I` (Spelunky + Dredge fusion)

Map `I` to readable, *tiered* states with a tell before each bite:

| `I` range | State | Player-facing telegraph |
|-----------|-------|--------------------------|
| 0–3 | **Calm** | Full light, ambient sound, sparse foes. |
| 3–6 | **Stirring** | Light dims one notch; a distant sound cue; loot icons get a faint glow (reward is climbing too). |
| 6–9 | **Unstable** | Vignette creeps in; terrain begins to shift; an on-screen meter pulses amber. Spawn rate visibly up. |
| 9–12 | **Critical** | Screen-edge red flash (the "ghost is coming" beat); a heartbeat/drone audio bed; the deep things begin appearing. |
| 12+ | **Collapse** | Hard escalation — a relentless, near-unkillable pursuer or accelerating extraction-gate decay forces you out, Spelunky-ghost style. |

The Collapse tier is the safety valve that guarantees no one farms a zone forever; the amber/red tiers are the *foreseen* warnings that make leaving feel like the player's own call.

### 5.4 The sunk-cost layer (Tarkov)

Add a soft carry penalty so the haul scales its own tension:

```
extractTime_mult = 1 + 0.02 * (unbankedValue / valueUnit)   # heavier haul = slower, riskier exit
```

Combined with the existing "die ⇒ lose unbanked haul minus a pockets fraction" rule (GDD §4), this means a rich run *feels* heavy and makes the decision to push one more zone progressively scarier — exactly the EFT effect, but with THE FAR YARD's mercy floor intact.

### 5.5 Difficulty selection (Hades + DRG)

Expose two opt-in escalators rather than silent rubber-banding:

- **"Weather" portals (per-dive, à la Hades Bounties / DRG Hazard):** a hostile-weather portal applies a flat `I` offset (e.g., +3 starting Instability) and in exchange multiplies `lootValue_mult` and rare-spawn odds. Reward gated to actually surviving the harder version.
- **Act-driven baseline ramp (the debt clock, GDD §10):** rather than real-time difficulty creep, let the *consequence* curve steepen with player power/wealth — "the clock grows teeth the better you do." Keep Act 1 `I` rates gentle; multiply `r_band` and the band-entry kick modestly per act so mastery, not the wall-clock, drives escalation.

### 5.6 Curve summary

- **Within a zone:** `I` is **linear** in time (per-band slope `r_band`) — predictable, readable, fair.
- **Across bands:** the +15% multiplicative entry kick makes a full Near→Far descent **near-exponential** — the deep end is genuinely punishing, rewarding the brave and capable.
- **Everything** (enemy HP/damage, spawn budget, loot tier, loot value) is a function of the single scalar `I`, so the risk-vs-reward equation can never silently break in the player's favor.

---

## Sources

- [Risk of Rain 2 Wiki — Difficulty (coeff formula, time vs. stage scaling)](https://riskofrain2.wiki.gg/wiki/Difficulty)
- [Hades Wiki — Pact of Punishment (Heat / Conditions / Bounties)](https://hades.fandom.com/wiki/Pact_of_Punishment)
- [TheGamer — Hades: 10 Things To Know About Heat And The Pact Of Punishment](https://www.thegamer.com/hades-heat-pact-punishment-trivia/)
- [GamingArena — The Role of Risk and Reward in Escape From Tarkov](https://gamingareena.wordpress.com/2023/04/24/the-role-of-risk-and-reward-in-escape-from-tarkov-how-to-balance-risk-taking-with-survival/)
- [GamesRadar — Escape from Tarkov review](https://www.gamesradar.com/games/fps/escape-from-tarkov-review/)
- [Spelunky Wiki — Ghost (Classic)](https://spelunky.fandom.com/wiki/Ghost_(Classic))
- [Spelunky Wiki — Ghost (2)](https://spelunky.fandom.com/wiki/Ghost_(2))
- [DREDGE Wiki — Panic](https://dredge.wiki.gg/wiki/Panic)
- [Casual Game Guides — How Do Night, Panic, and Aberrations Work? (DREDGE)](https://casualgameguides.com/walkthroughs/dredge/night-panic-aberrations-explained)
- [Deep Rock Galactic Wiki — Difficulty Scaling (Hazard Level / Hazard Bonus)](https://deeprockgalactic.wiki.gg/wiki/Difficulty_Scaling)
- [Roguelike Tutorials — Part 12: Increasing Difficulty](http://rogueliketutorials.com/tutorials/tcod/v2/part-12/)
- [TV Tropes — Level Scaling](https://tvtropes.org/pmwiki/pmwiki.php/Main/LevelScaling)
- [Wikipedia — Telegraphing (entertainment)](https://en.wikipedia.org/wiki/Telegraphing_(entertainment))
- [Wikipedia — Dynamic game difficulty balancing](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing)
- [Wikipedia — Rubber banding](https://en.wikipedia.org/wiki/Rubber_banding)
