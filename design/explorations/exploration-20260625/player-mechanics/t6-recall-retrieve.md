# Recall / Retrieve
**Category:** Deepening the throw

## The mechanic
Throwing loot at a threat shouldn't be a permanent *delete* of carried value — it should be a **loan you can repay by walking into the danger you just answered**. A missed throw lands on the floor; a kill consumes the item. "Recall / Retrieve" formalizes that landed-item as a *recoverable* asset and (optionally) adds an **active button** that yanks it back to hand — trading the walk-into-danger for a cooldown/skill check. This is the pressure valve on L1's core tension ("throwing spends my loot"): the cost is real, but bounded, and the way you pay it down is by re-entering the space the threat occupied.

## What exists today
**Basic retrieve already works** — read `entities/thrown_item/thrown_item.gd:99-106`. On a *miss* (wall hit, max-range, or the 5s lifetime fallback) the projectile calls `_miss()`, which emits `EventBus.junk_dropped(item, global_position)`. The existing `JunkSpawner._on_junk_dropped` path re-spawns an ordinary grabbable `JunkPickup` at the landing spot (`entities/junk_pickup/junk_pickup.gd`). So a missed throw is **already** a floor pickup you can walk back to — passive retrieve is *done*. (`throw_missed` telemetry also fires.)

What does **not** exist:
- A *kill* consumes the item outright (`_hit_hazard`, `:88-95` nulls `_item`) — you never get a successful-throw item back. That's intentional today (the cost of winning), not a bug to "fix."
- No **active recall** — no boomerang/return-to-hand verb. Retrieval is 100% "walk to it."
- No telemetry distinguishing *thrown-and-recovered* from *thrown-and-abandoned* (left on the floor at extract).

## How to fit it in
**Flavor (a) — passive (mostly done).** Keep the L1 miss→`junk_dropped` re-drop as the baseline retrieve. The only additions worth making: a `throw_recover_window` is irrelevant (the pickup persists with the band), but we *should* add telemetry for "item still on floor at extract" so we can measure loot genuinely lost to throwing.

**Flavor (b) — active recall (the new verb).** A button (`recall`, suggested **R** keyboard / controller face button) that, while a thrown item is mid-flight *or* a recently-landed pickup exists, reverses its `_dir` toward the player and lets it be re-collected on overlap (boomerang feel). Trade: instead of walking into the threat's space, you pay a **cooldown** + a **skill/positioning** demand (you must survive where you are while it flies back). To preserve the throw-economy cost, active recall should NOT apply to a *killing* throw — a hit still consumes the item (you spent it to win). Recall only rescues *misses*. This keeps the "kill = spend" rule intact while softening "miss = chase it down."

**Interactions:** with the ~300s dive clock (`systems/dive_clock.gd`), recall saves walk-time but spends a cooldown — a wash that rewards good aim over greedy retrieval. With danger zones: passive forces re-entry (pressure preserved); active lets a cornered player recover value without re-entering (pressure relieved — the balance risk).

**Control mapping:** new `recall` action (R + controller button), gated entirely by a knob.

**RunConfig knob + telemetry** (house style, `data/run_config/run_config.gd`, all-off default reproduces baseline):
- `recall_active_enabled: bool = false` — master gate for flavor (b); off = today's passive-only behavior, byte-identical.
- `recall_speed: float = 0.0` — return px/s.
- `recall_cooldown_s: float = 0.0` — re-throw lockout after a recall.
- Telemetry (L0-style additive): `throw_recovered` (item walked-back or recalled), `throw_abandoned` (on floor at extract), `recall_used` (active recall fired). Derive **recall rate** and **loot-thrown-and-lost** at the gate.

## Research (cited)
**Dead Cells Boomerang** — the returning weapon deals damage *on the return path*; on the way out it pierces, on the way back it bounces up to 6 times before reaching the player. The interesting design lesson: the return isn't a free "undo," it's a *second active phase* the player positions for. Their throwables (bombs, grenades) by contrast are pure spend — no recall — which is exactly the "kill = consumed" rule we keep. **Zelda boomerang** is the canonical "thrown tool returns to hand automatically, can grab distant pickups en route" pattern (the auto-collect-while-returning idea is worth stealing for active recall). The broad roguelite-design principle (risk/reward legibility, agency) cautions against verbs that quietly erase a deliberate cost — active recall must not become a free undo of the throw-economy tension.

## Graybox sketch
1. **Confirm passive (zero code):** throw → miss → verify the `junk_dropped` pickup appears and is grabbable. Add the two floor-state telemetry events.
2. **Active recall prototype:** add `recall_active_enabled` knob + `recall` action. In `thrown_item.gd`, on `recall` press while `not _spent`, flip `_dir` to point at the player each frame (homing) and resolve on player-overlap → re-add to `RunInventory` (the inverse of L1's `remove_at`). Apply `recall_cooldown_s` before the next throw. Leave kills untouched (still consume). Telemetry: `recall_used`.

## Open questions
- **Passive vs active — do we even need (b)?** Passive retrieve already exists and *already* enforces "walk into the danger." Active recall directly *removes* that walk, which is the whole pressure-valve framing. Is active recall additive fun, or does it quietly defeat the point? **[Director — fun/tone]**
- **Does active recall trivialize throw-cost?** If you can throw, miss, and yank it back from safety with only a cooldown, the "throwing spends my loot" tension collapses to "throwing costs a cooldown." Mitigations: recall only rescues *misses* (kills still consume), generous cooldown, recall fails/decays at range. Needs playtest. **[Director]**
- **Should a *killing* throw ever be recoverable?** Today no (kill = consumed). A "recall even after a kill" option would make throwing nearly free — almost certainly too strong, but flag it. **[Director — scope]**
- **Auto-collect-while-returning (Zelda-style)?** Should a returning item also sweep up floor junk it passes over? Cute, but compounds the trivialization risk. Defer.

Sources:
- [Boomerang — Dead Cells Wiki](https://deadcells.wiki.gg/wiki/Boomerang)
- [Throwable Objects — Dead Cells Wiki](https://deadcells.wiki.gg/wiki/Throwable_Objects)
- [Roguelike Itemization: Balancing Randomness and Player Agency — Wayline](https://www.wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency)
