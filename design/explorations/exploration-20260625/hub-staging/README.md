# Explorations — 2026-06-25: The Hub / Staging Area

> ← Part of the [2026-06-25 exploration set](../README.md) ([oppositions](../hazards/README.md) · [bands](../procgen-bands/README.md) · [player mechanics](../player-mechanics/README.md) · [economy](../economy-extraction/README.md) · hub).

The between-runs space — a **place** instead of a menu. Each file covers: **the idea** (as a place, and the experiential value of spatializing it), **what exists today**, **how it could fit in** (the new hub scene, which economy mechanic it spatializes, the GDD surface fiction), **research** (cited prior art), and **open questions** (Director-flagged).

**Grounding reality:** there is **no hub scene yet** — the flow is currently menu → dive → sell → repeat, with no exhale and no physical home for meta-progression. But the GDD already designs the surface in depth (Bellweather Salvage, the *"the yard unsettles, the town heals"* tone pillar, confidants, the exposure meter, the debt, Cyrus's recordings) — so the hub is **strongly grounded in design intent**. Most hub elements are the **physical front-end of an [economy mechanic](../economy-extraction/README.md)** already explored, riding the real run/meta state (`systems/game_state.gd`) + the R0 staged-config seam that already feeds a run.

## H — The hub as the money sink made physical
*Everything money buys becomes a place instead of a menu list.*
- [A shop / vendor](h1-shop-vendor.md) — walk-up buy (spatializes `economy/s1`,`s2`); staggered vendor unlocks = visible growth
- [A stash / vault](h2-stash-vault.md) — the physical home of persistent loot (`economy/p1`); seeing wealth beats a number
- [A loadout bench](h3-loadout-bench.md) — where the inventory mechanics *breathe* (`player/i1`,`i2`,`x3`); the safe deliberate pause that resolves i2's pause-vs-real-time tension
- [An upgrade station](h4-upgrade-station.md) — buy capability (`economy/s1`); each purchase visibly changes your space

## C — The hub as run-selection / commitment
*The next run gets chosen here, not "press continue."*
- [A departure point](c1-departure-point.md) — walk through the door = the commit; fires the real `start_run` staging seam
- [A job board / contract picker](c2-job-board-contract.md) — select run variety (`economy/q3`,`r1`,`m2`) instead of RNG-rolling it
- [A map / intel table](c3-map-intel-table.md) — buy a forecast then choose entry (`economy/s4`); makes seed-pinning diegetic

## V — The hub as a pressure release / pacing valve
*The exhale between held breaths — but it can have teeth.*
- [A safe, calm, no-timer space](v1-safe-calm-no-timer.md) — the absence of the clock IS the reward; cheapest high-leverage win (likely always-on baseline)
- [Hub-level quota pressure (rent / upkeep)](v2-hub-quota-rent.md) — a recurring drain keeps the squeeze without an in-run timer *(in tension with v1's relief)*
- [Persistence of failure](v3-persistence-of-failure.md) — a missed quota dims the hub *(the decay arm of the g1 hub-state system; downstream of `economy/p4`)*

## G — The hub as the home of meta-progression
- [Visible growth](g1-visible-growth.md) — the hub physically upgrades at milestones; abstract soft-meta (`economy/p2`) made legible
- [The recovery-run anchor](g2-recovery-run-anchor.md) — your last failure's lost cache shown as still-out-there; stage a seeded recovery run *(corpse-run pattern)*

## N — The hub as light narrative / texture *(lowest graybox priority, real later)*
- [A handler / NPC](n1-handler-npc.md) — one character delivers quota + reacts; cheap tonal work *(recommend the diner-owner confidant; never Cyrus, who stays a recordings-only absence)*
- [Environmental storytelling](n2-environmental-storytelling.md) — the hub's state (thriving ↔ desperate) IS the story, wordless; perfect for graybox

---
**Recurring Director-decision flags across these docs:**
- **It's one hub scene + one `hub_state`.** Visible growth (`g1`), persistence of failure (`v3`), and environmental storytelling (`n2`) are the *same* meta-state-driven hub rendered in three directions (grow / decay / texture) — build the state machine once. The art-authoring cost of multiple hub states is the main scope question.
- **The hub is mostly front-end, not new systems.** Money, banked junk, milestones, quota, and the run-staging seam all already exist — most rooms *surface* them. The genuinely new work: a hub scene, an item-vault save-schema bump (`h2`), a "packed loadout" meta seam (`h3`), seed-pinning (`c3`), and a recoverable-cache flag (`g2`, since `lost_proxy.gd` is navigation telemetry, not lost loot).
- **The exhale-vs-teeth tension** — `v1` (calm relief) vs `v2` (rent pressure): the agents flag that recurring rent may undercut the very relief that makes the hub valuable, and that its harsher economy fits awkwardly with the GDD's soft tone. Recommend shipping `v1` always-on and A/B-ing `v2` modestly rather than stacking it on quota + debt.
- **Cheapest wins:** the calm no-timer space (`v1`) and environmental storytelling (`n2`) are high-leverage and nearly free; the departure point (`c1`) and job board (`c2`) just dress the existing config-staging seam.
- **Narrative canon-fit (`n1`)** — whether the handler is a confidant, a new character, or Cyrus-adjacent is a Director/narrative-lead vision call (Cyrus must remain recordings-only per canon).

*14 explorations across 5 groups. Authored by `game-director-designer` (systems rooms) + `narrative-writer` (N group) as a parallel fan-out; not yet dispositioned by the Director.*
