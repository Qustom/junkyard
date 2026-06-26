# Suppressor
**Category:** Ranged & projectile enemies

## The idea
A ranged entity that **does no damage at all** — it fires soft, easy-to-see shots that, on hit, briefly **slow** the player (and/or muffle a beat of input). It's a *setup* enemy: harmless alone, but it strips away the player's most important resource against everything else — **mobility** — so the real killers (pursuer, Lobber, Sentry, Spinner) can land. Its behavioral distinctness is that it's the only enemy whose threat is **entirely relational**: it has no win condition by itself, so it forces the player to **prioritize and triage targets under pressure** ("kill the harmless one first, or eat the slow and die to the chaser?"). No other enemy in the set asks "which threat do I deal with in what order?" — the Suppressor *creates* that question.

## How it fits THE FAR YARD
It taxes the **move** verb by debuffing it, and it makes the **throw** verb a genuine triage decision: spending a sale-value item to kill a *non-lethal* enemy feels wrong until you realize it's enabling everything else to kill you — that's the intended "is this worth it?" tension the GDD's economy is built on. It's the clearest fit for the design pillar that **avoidance and positioning are first-class** — the Suppressor attacks positioning itself. The slow can reuse a simple movement-speed multiplier on the player for `slow_ms` (a clean run-state debuff; no new physics). Pure run-state, knob-gated, distance/line-based shots. First appears in **Band 2–3** as a "tar-sprayer" / "stasis-emitter" — junk tech that gums you up. It's the natural pairing partner for every other entry in this category, so it ships *with* at least one other enemy, never solo.

## Graybox sketch
- A square (Suppressor, layer `hazard`) that periodically fires a clearly-colored slow-shot toward the player (current position; slow, dodgeable).
- On hit: apply `player.speed *= slow_factor` for `slow_ms`, draw a tint/ring on the player so the slowed state is legible. **No** `fail_run` path — it can never kill directly (so no `*_kills` toggle; that *is* its identity).
- States: `IDLE` (player out of range) → `FIRE` (telegraph + slow-shot) → `COOLDOWN` → repeat.
- Knobs: `suppressor_fire_period_ms`, `suppressor_slow_factor` (e.g. 0.5), `suppressor_slow_ms`, `suppressor_shot_speed`. The slow magnitude × duration is the whole tuning surface.

## Synergies & counters
- **Designed to combo:** Suppressor + pursuer (get slowed → can't outrun the chase), Suppressor + Spinner (slowed → can't thread the gap), Suppressor + Lobber (slowed → can't leave the marker). It is the multiplier that makes the others lethal.
- **Throw counter:** mouse-aimed throw kills it; the decision to "spend an item on the harmless one" is the intended high-skill read.
- **Counter (move):** dodge the slow shots (they're slow and telegraphed), or accept a slow and create distance during the un-slowed windows. Breaking line-of-sight on a wall also stops new shots.

## Open questions
- **Slow vs. stun:** a movement *slow* keeps the player in control (fairer, fits "no cheap deaths"); a brief input *stun*/root is scarier and reads as more menacing but risks feeling like a control-loss the player can't answer. Recommend slow-only for greybox. (Fun/tone — Director.)
- **Does a non-damaging enemy read as a threat at all,** or will players ignore it until it kills them via a combo they don't connect to it? It may need strong visual coupling (the slow tint + a clear shot trail) to teach the cause. (Vision/legibility — Director; this is the make-or-break call.)
- **Should the slow stack** from multiple Suppressors / rapid hits, or hard-cap? Stacking is dangerous (lock-out risk); recommend refresh-not-stack with a floor on `speed`. (Scope/safety — Director.)
- **No-kills-toggle exception:** every other hazard has a `*_kills` knob; the Suppressor deliberately has none. Confirm that's the intended permanent stance, not an omission. (Design consistency — Director.)
