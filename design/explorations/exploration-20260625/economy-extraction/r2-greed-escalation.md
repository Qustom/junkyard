# Greed Escalation
**Category:** Risk/reward dials

## The mechanic
A **per-room dwell ramp on the reward side**. The longer the player lingers in one room, the more that room is worth to keep working — fresh, higher-value junk appears (or the values of remaining/incoming junk tick up) the longer you stay — but the *same* dwell timer also raises aggro and reinforcement spawns. So every room becomes a tight "leave now with what I've grabbed, or push one more wave for the fatter payout" microdecision. It is the **room-scale mirror of the macro push/cash-out** (E2): instead of "extract this dive vs dive deeper," it's "milk this room vs move on," resolved every ~10–20 seconds, room after room. The *skill* is reading the crossover — the moment the marginal value of staying drops below the marginal threat of the next spawn — and walking before the room turns into a fight you didn't want.

## What exists today
Honest read: **the threat half of this loop already exists**, the reward half does not. The alarm-spawner (`hazards/5-alarm-spawner.md`) is a literal per-room `dwell_t` that, at each `alarm_threshold_s`, spawns a reinforcement and emits `alarm_triggered(room_id, wave_n, depth)` — exactly the "camping costs you" pressure. The Hunter and the e2 density gradient escalate dive-wide threat on dwell. Exposure (`exposure_meter.gd`) and `return_cost.gd` price *total* lingering; `dive_clock.gd` is the global ~300s budget.

On the reward side, value is currently **placed once, statically**: `junk_placer.gd` builds a deterministic plan at band-gen time, scaling each item's `base_sell_value` by `DepthCurve.value_mult(depth_norm)`. Value rises with **depth**, never with **dwell**. A room is worth a fixed amount the instant you enter it; staying only drains it. **What's missing is a dwell→value ramp** — a reason for greed to *grow* in place, so the alarm's rising threat has something to push against.

## How to fit it in
Reuse the alarm-spawner's room-dwell seam wholesale: the same `dwell_t` accumulating inside `room_bounds` (the L2 `Rect2.has_point` test) drives **both** the spawn threshold and a new value ramp. At each tick, spawn-as-today **and** roll a fresh higher-value pickup from `JunkPlacer`/`JunkCatalog` into a far cell (reusing the placer's `value_mult` path, multiplied by a dwell factor), or bump the value of unclaimed items in-room. The microdecision then reads off E2's existing surface — the live "Holding" number climbs as you greed, exactly the push-your-luck read E2 already frames at the gate, now at room scale. Interaction with the **e2 density gradient** (deep rooms start denser/hotter, so the ramp bites sooner) and the **dive clock** (greed eats the global budget, coupling the two scales). New `RunConfig` knobs: `greed_value_ramp_per_s`, `greed_spawn_ramp_per_s`, both **off by default → baseline parity**. Telemetry: per-room `dwell_t` vs value-extracted vs waves-survived, so the gate can see where players over- or under-stay.

## Research (cited)
This is the canonical "stay-for-more" press-your-luck loop. **Risk of Rain** ties time directly to *both* difficulty and loot opportunity — "you always need to balance your greed against the timer" — the purest statement of this dial, but at *run* scale. **Spelunky's ghost** is the inverse framing: a hard anti-loiter timer where "you can keep exploring; your reward will be higher, but the risk will be higher too" — explicitly a risk/reward-of-staying tradeoff. **Deep Rock Galactic** swarm pressure and **Vampire Survivors** time-as-difficulty are the same family. Our twist is making the ramp **room-local and value-positive** (greed *grows* a target), not just a threat clock — the reward side these games mostly leave implicit.

## Open questions
- **Does it just duplicate the global dive clock / depth curve?** It must feel *room-local and resettable* (leaving banks the gain, a fresh room starts cold) or it collapses into "the whole dive gets richer + harder," which the clock + depth curve already do. **Director: is the per-room reset enough differentiation, or does this overlap the alarm-spawner so much they should be one feature?**
- **Reward vs threat slope tuning.** If value out-climbs threat, the dominant strategy is "always camp to the last wave" (greed never punished); if threat out-climbs value, nobody ever stays (mechanic is inert). The crossover must sit in a *tense* band — a playtest/tuning call, knob-gated.
- **Readability of the ramp.** The alarm fill is already a HUD/diegetic tell; adding a *rising-value* tell risks meter clutter. Can the climbing "Holding" number alone carry the reward read, or does the room need its own "getting richer" cue? **UX/Director call.**

Sources:
- [Risk of Rain 2 review — greed vs the timer (Gideon's Gaming)](https://gideonsgaming.com/risk-of-rain-2-review-cloudy-with-a-chance-of-pain/)
- [Difficulty scales with time (Risk of Rain Wiki)](https://riskofrain.fandom.com/wiki/Difficulty)
- [Spelunky ghost as risk/reward anti-loiter timer (Steam Discussions)](https://steamcommunity.com/app/239350/discussions/0/864975632732132776/)
