# Hub / Staging Area — Cross-Exploration Analysis
**Set:** hub-staging/  ·  **Analyzed against:** hazards, procgen-bands, player-mechanics, economy-extraction

The hub is the one set that is almost entirely **front-end**: it adds essentially no
new *systems*, it gives a **place, a verb, and a visible body** to systems the other
four sets already define. Read against the economy set especially, every hub room is
the diegetic skin over an economy/player mechanic that currently lives only as a
`RunConfig` knob or a meta field. The big risks are not architectural — they are
**art-authoring cost**, **one shared `hub_state` doing three jobs**, and a cluster of
**tone contradictions** (calm vs. rent, warmth vs. decay, Cyrus-absence vs. a talking
handler). All citations are `folder/file.md`.

---

## Synergies (the place that spatializes / hosts other ideas)

1. **`h1` shop-vendor ⇄ `economy-extraction/s1` gear-upgrades + `s2` consumable-loadout.**
   `s1` is flagged "THE MISSING LOOP" — Money has no spend side. `h1` is the *walk-up
   body* for `s1`'s buy UI and `s2`'s consumable buy step. The vendor stall is the
   spatial wrapper; the menu is the `s1`/`s2` work. Neither exists without the other:
   `h1` is empty greybox without `s1` data, and `s1` has no diegetic home without `h1`.

2. **`h4` upgrade-station ⇄ `s1` permanent-power tiers (and the player verbs `m1`/`x3`/`i1`/`t3`).**
   `h4` is explicitly "`s1` given a physical body" — buying a dash (`player-mechanics/m1`),
   quick-slots (`player-mechanics/x3`), a bigger grid (`player-mechanics/i1`), or
   trajectory preview (`player-mechanics/t3`) visibly bolts a module onto the bench.
   `h4` reads the `s1` catalog `.tres`, debits Money, writes `owned_upgrades`, and
   applies at `start_run` — the exact seam `s1` specs. The "vendor vs. station" split
   (`h1` = *stock up* / consumable, `h4` = *grow* / permanent) maps cleanly onto `s2`
   (consumables) vs. `s1` (permanent gear).

3. **`h2` stash-vault ⇄ `economy-extraction/p1` persistent-stash + `q2` banking-rollover.**
   `h2` is the *visible skin* over `p1`'s `vault_junk`/`vault_money` data model — shelves
   that render the meta you own. The pairing is load-bearing under `q2`: if `q2` lands on
   *expire/deduct* (use-it-or-lose-it), the **goods on the shelves become the only
   cross-cycle carry**, so `h2` *dramatizes exactly what is safe*. Under `q2` *rollover*
   (today's default) the safe is simply a wealth meter filling.

4. **`h3` loadout-bench ⇄ `player-mechanics/i1` rotate, `i2` repack, `x3` loadout-zones, `s2` consumables.**
   `h3` is the calm-rehearsal home for *every inventory verb too slow to do mid-run*. It
   directly resolves `player-mechanics/i2`'s open "pause-vs-real-time" question: the
   **bench is the safe deliberate pause** (no clock), so the live dive overlay can stay
   tense and small. It hosts `i1` rotation/tetris, reserves the `x3` quick-throw loadout
   slots, and packs the `s2` consumables bought at `h1`. This requires a new **packed-loadout
   meta field** that `start_run` seeds into the fresh `RunInventory` (see Dependencies).

5. **`c2` job-board ⇄ `q3` quota-variety + `m2` demand-orders + `r1` optional-modifiers.**
   `c2` is the diegetic front-end for *selecting* a run's shape. Its three card types map
   1:1 onto economy docs: "read the quota terms" = the K2/`q3` objective; "modifier-for-
   multiplier" = `r1` optional-modifiers (a curated `RunConfig` preset + value multiplier);
   "buyer's order" = `m2` demand-orders. `c2` adds **zero new commitment plumbing** — it
   dresses `GameState.stage_run_config()`, turning the CFG debug menu into player agency.

6. **`c3` map-intel-table ⇄ `economy-extraction/s4` map-intel.**
   `c3` is the *place* for `s4`'s three tiers (partial map / hazard forecast / high-value
   pin). Both share the load-bearing fact that band generation is a **pure seeded function**
   (`procgen-bands/0-scalable-band-generation-system.md`, `band_generator.gd`): a forecast
   is a truthful headless peek. Both depend on the same new seam — **pinning the next seed
   at the surface** (`RunConfig.seed_override`) — that `s4` flags as a programmer call.
   `c3` also reads the GDD's **Knowledge** track as the free/standing forecast path.

7. **`c1` departure-point ⇄ `economy-extraction/e3` one-way-commitment.**
   `c1` puts the *entry* commitment in the player's feet (walk through the gate = irrevocable
   start); `e3` puts the *exit* commitment on the far end (cross the threshold = no retreat).
   They are deliberately the two poles of one fiction — "choose to go in by walking in,
   choose to come out by reaching the exit alive." Both reuse `stage_run_config()`/
   `SocketSealer`; `c1`'s "back out free grace window" question explicitly overlaps `e3`.

8. **`g2` recovery-run-anchor ⇄ `e3`/`e4` extraction + `p4` reset-severity + procgen seeded determinism.**
   `g2` is the hub fixture that surfaces a **lost cache** from a failed run and re-stages
   that *same seed* (`procgen-bands` determinism makes the recovery band byte-identical).
   It extends E3's `fail_run` (today the non-pockets remainder is discarded forever) into a
   persistent `pending_cache`. Its "double-loss is permanent" teeth tie directly to
   `economy-extraction/p4` — under STANDARD the cache is the stake of a forgiving loss;
   under HARSH it's moot (meta wipes anyway). Pairs with `e4` partial-extraction as the
   *failure-side* counterpart to mid-run shipping.

9. **`g1` visible-growth + `v3` persistence-of-failure ⇄ `p2` soft-meta + `p4` reset-severity.**
   `g1` is "`p2` soft-meta given a body" — the wipe-protected `unlocks` field rendered as a
   vendor arriving, a path cleared, lights coming on. `v3` is the **decay arm of the same
   system**: a quota miss dims a lamp, posts a debt notice. Crucially, *what `v3` renders is
   downstream of `p4`* — STANDARD/FORGIVING = recoverable mood that lifts; HARSH = the wipe
   made visible (vendors gone, room reset to Run-1 bare). Build the `hub_state` mapping once;
   `v3` is `g1`'s inverse sign (see Contradictions).

10. **`v2` hub-rent ⇄ `q2` banking (deduct/expire), `s5` debt-loans, K2 quota.**
    `v2` is "q2's use-it-or-lose-it pressure *with a fiction*" — a posted, diegetic drain
    that makes hoarding cost something and pushes Money into the `s1`/`h4` sinks each cycle.
    It explicitly distinguishes itself from `s5` (rent = cost of staying in the game; debt =
    the thing you're killing) and warns against stacking quota + rent + `s5` debt (three
    money pressures). The strongest cross-link: **rent is the targeted fix `q2` itself
    proposes** for "rollover makes the quota toothless mid-game."

11. **`v1` calm-no-timer space ⇄ the dive clock & oppositions (the contrast manufacturer).**
    `v1` is defined by what it *removes*: no `DiveClock`, no `ExposureMeter`, none of the
    `hazards/` oppositions. It is the calm pole `audio_director.gd`'s band-escalation curve
    resolves *toward* (the `_on_player_died` TODO's "surface bed" is literally this room).
    It is the *baseline always-on* hub that every other hub feature (v2, h1, n1) bolts onto —
    the permanent default, not a `RunConfig` experiment. Its value is making the *next* dive's
    first clock-tick land harder.

12. **`h1`/`g1`/`n2` staggered presence ⇄ `p2` unlocks + procgen depth milestones.**
    A vendor *arriving* is `h1`'s physical unlock keyed to `GameState.unlocks` (`p2`); the
    triggers ("banked a band-2 item," "reached depth N") read directly off procgen depth and
    the persistent meta the economy set already tracks. The hub is a **readout of progression
    you were tracking anyway** — free narrative payoff.

13. **`h3` loadout-bench ⇄ `player-mechanics/x1` carry-load→speed (the greed tax).**
    `x1` (Director-prioritized) makes a fat bag slow. `h3` is where you *pre-commit* to that
    tradeoff calmly — reserving loadout/throwable slots (`x3`) eats into protectable cargo,
    so the bench is where the greed-tax bet is *planned* before the dive *charges* it.

14. **`c3` intel + `c2` board ⇄ procgen archetypes/principles (`a4`, `d1`, `d4`).**
    Intel about "the band's spine/shape" and "high-value rooms" is most legible against
    procgen's **critical-path-plus-side-rooms (`a4`)**, **radial/concentric (`d1`, danger
    scales with distance)**, and **asymmetric entry/exit (`d4`, the loaded return trip)** —
    the archetypes that make a *forecast* and a *routing decision* meaningful. `c2`'s
    "deep contract" modifier is the player-facing knob over those generation parameters.

15. **`n1` handler ⇄ K2 quota signals + `c2` board + `m2` orders.**
    `n1` gives a *mouth* to signals that already fire faceless: `quota_evaluated`,
    `quota_advanced`, `meta_wiped`, `exposure_threshold_crossed`. The handler reads the
    `c2` board's terms aloud and voices the `m2` "Cyrus wants 3 copper coils" order as a
    *recorded standing order* (not Cyrus live). Lowest greybox priority — the loop works mute.

16. **`n2` environmental-storytelling ⇄ exposure (GDD §9) + `m1`/`m2` wealth signals.**
    `n2` can render the GDD's core irony directly: visible wealth (a new truck, a flashy
    sign) reads as "thriving" *and* silently advances the `exposure` fiction — the set-dressing
    literally shows the thing the meter punishes. This is the same wealth the economy set's
    sells/orders generate, made visible.

17. **`h2` stash capacity-as-sink ⇄ `p1` Tarkov stash-space + the Yard/Salvage track.**
    Both `h2` and `p1` flag "buy more shelves" as a clean **Salvage/Yard-track money sink** —
    a hub money-sink-made-physical that also forces a stash-vs-sell tension. This is one of the
    few places the hub proposes a *genuinely new economic lever* rather than skinning one.

18. **`g2` recovery + `e4` partial-extraction ⇄ the run/meta boundary in `game_state.gd`.**
    Both convert run-state → meta-state at non-standard moments (`e4` mid-run shipping; `g2`
    re-importing a lost cache). They are the same `run_inventory.items[] → banked_junk[]`
    move the gate already does, just at new trigger points — clean fits for the boundary the
    architecture is built to support.

---

## Contradictions & tensions

- **Calm relief (`v1`) vs. rent pressure (`v2`) — the load-bearing tone clash.** `v1`'s
  entire thesis is the hub as *exhale* (no meter, no clock). `v2` admits this directly: "a
  drain you can't escape turns the safe room into another clock, just a slower one." Both
  docs land on the same mitigation (modest, predictable, *posted* rent on a slow day-clock,
  never a surprise in-hub meter), but they cannot both ship at full strength. **This is the
  single sharpest contradiction in the set** (see Top 5). It is a vision/tone call: does
  THE FAR YARD want teeth in its exhale (lean-roguelike, Recettear pole) or a genuine
  pressure-release (cozy life-sim, Animal-Crossing pole)?

- **One `hub_state` machine, three masters (`g1` growth / `v3` decay / `n2` mood).** All
  three explicitly ride the *same* meta-state→set-dressing mapping read three ways: `g1`
  adds growth flags, `v3` removes/dims them, `n2` reads the aggregate as *mood*. This is a
  genuine **coherence risk**, not just a build efficiency note: a prop must not pop in/out on
  every wipe (`g1`'s own caution), decay must read as *worn, not erased* (`g1` recommends),
  and the `n2` mood must stay legible while `g1`/`v3` toggle individual props. If these three
  are specced separately they *will* fight over the same nodes. **They must be co-designed as
  one system** — which is itself the argument for a hub architecture doc (see below).

- **The handler (`n1`) vs. Cyrus-must-stay-absent (GDD §14/§3).** A live, banter-every-run
  handler **cannot be Cyrus** without detonating the "is he alive?" mystery. `n1` resolves
  this carefully (recommend the diner-owner confidant; handler-as-acquaintance ≠ the
  Exposure-gated confidant *unlock*; the handler may *play you Cyrus's tapes* but never
  *speak for* Cyrus). But the seam is delicate: the `c2`/`m2` "Cyrus wants 3 copper coils"
  flavor must read as a *recorded standing order*, not Cyrus live. This is a continuity call
  that must be locked before any handler VO is written.

- **Warmth (Pillar 3 "the town heals") vs. decay floor (`v3`, `n2`).** Pushed too far, a
  ruined hub stops being "cozy lived-in" and becomes grim, fighting the warm-surface pillar.
  `n2` and `v3` both flag the *floor on decay* as a Director tone call. Coupled with `v2`
  rent, an aggressive build could render a hub that is simultaneously draining your wallet
  *and* visibly falling apart after one miss — punishing the player twice (mechanically +
  emotionally), the exact churn `p4` warns about.

- **Selection (`c2`/`c3`) vs. RNG surprise.** `c2` flags that fully-chosen runs lose the
  "what will I get" thrill, and `c3` flags that a high-value-room pin can flatten exploration
  into a beeline. Both propose the same hybrid (choose the *frame*, keep the *content* seeded-
  random) — but `c2` (commit: pick + accept) and `c3` (inform: read forecasts) **risk
  duplicating each other** as fixtures. The seam ("board commits, table informs") needs a
  Director ruling on whether they are one fused surface or two beats.

- **Hub features depend on systems not yet built.** Several rooms are blocked on seams the
  economy/player sets own and that *do not exist today*:
  - `h2`/`g2`/`h3` need **new meta save fields** (`vault_junk`, `pending_cache`,
    packed-loadout) → each a `schema_version` bump + migration + QA fixture.
  - `c3`/`s4` need **seed-pinning** (today `_next_seed()` mints the seed at dive-start —
    "you cannot sell intel about a run with no seed yet").
  - `h3` needs the **packed-loadout seam** that survives run→start (`RunInventory` is
    run-state, wiped at run end — it cannot hold a pre-pack).
  - `h4` needs the **`owned_upgrades` apply-at-`start_run` seam** that `s1` defines but is
    unbuilt.
  None of these is hub work — but the hub room is empty greybox until its upstream economy/
  player feature lands. The hub cannot lead the build order for these rooms.

- **`p4` is the silent parent of the whole hub set.** `economy-extraction/p4` (reset-severity)
  governs what `v3` renders (recoverable mood vs. visible wipe), whether `h2`/`p1` stash
  survives a loss, whether `h4`/`s1` upgrades empty on a wipe, and whether `g2`'s cache
  matters at all. The live build's K2 full-wipe **contradicts GDD §6 "no total resets"** — and
  that single unresolved contradiction *flips the emotional content of half the hub*. The hub
  set cannot be locked before `p4` is dispositioned.

---

## Shared dependencies & build-order notes

**Already exists to surface (hub = thin skin):**
- Meta money/salvage/lore persistence (`game_state.gd:33-37`) → `h2` safe, `g1`/`n2` wealth.
- `banked_junk` cross-run by-id persistence → `h2` shelves (display only, no new field).
- `stage_run_config()` + `RunConfig` preset machinery → `c1`, `c2`, `c3` commit (no new plumbing).
- K2 quota + `quota_evaluated`/`meta_wiped`/`exposure_threshold_crossed` signals → `n1`, `v3`.
- Seeded determinism (`band_generator.gd`) → `c3` truthful intel, `g2` recovery same-seed.
- `add_currency()` negative-delta debit → `h1`/`h4`/`v2` spends.

**Genuinely new seams the hub forces (mostly upstream-owned):**
| Seam | Owner doc | Blocks hub room |
|---|---|---|
| The hub scene itself (walkable surface) | *new — every hub doc names this* | ALL hub rooms |
| One `hub_state` derivation (meta→prop flags) | `g1` (co-design `v3`,`n2`) | `g1`,`v3`,`n2`,`h1` staggered presence |
| `owned_upgrades` + apply-at-`start_run` | `economy-extraction/s1` | `h4`, `h1` |
| Item-vault meta field (`vault_*`) | `economy-extraction/p1` | `h2` (literal-shelf version) |
| Packed-loadout meta + `start_run` seed | `player-mechanics/i2`/`x3` (via `h3`) | `h3` |
| Next-seed pinning (`seed_override` as meta) | `economy-extraction/s4` | `c3` |
| `pending_cache` meta + recovery re-stage | `g2` (extends E3 `fail_run`) | `g2` |
| `reset_severity` dial | `economy-extraction/p4` | `v3`, `h2`, `h4`, `g2` (content flips on it) |
| Dialogue Manager hub NPC | `n1` | `n1` |

**Recommended ordering (cheapest, lowest-dependency first):**
1. `v1` bare calm room — no dependencies, always-on baseline, the control surface others bolt onto.
2. `c1` departure-point — dresses an existing seam; makes the room a *loop*, not a dead end.
3. `h1` vendor + `h4` station — *gated on `s1`/`s2` data*; the headline "Money for power" payoff.
4. `g1`/`v3`/`n2` as **one co-designed `hub_state`** — gated on the meta fields above + `p4`.
5. `c2`/`c3` run-selection — gated on `r1`/`q3`/`m2`/`s4` and the seed-pinning seam.
6. `h2` literal vault, `g2` recovery, `h3` deep loadout — gated on their new save fields; batch
   the schema bumps (`vault_*`, `pending_cache`, packed-loadout) into **one migration**.
7. `n1` handler — lowest priority; texture on a proven, mute loop.

---

## Notable design information

- **The hub is the missing connective scene.** The current flow (`menu → dive → sell →
  repeat`) has **no exhale and no home for meta** — every state is active pressure or a flat
  menu. `v1` names the gap precisely: `audio_director.gd` escalates by band depth but "has no
  calm bed to escalate *away from* and resolve *back to*." The hub is that bed. It is also
  where the economy set's "missing half" (`s1`) finally has a body, where run-selection
  (`c2`/`c3`) becomes agency instead of a debug menu, and where progression (`g1`) becomes
  visible. **Almost every other set quietly assumes a hub exists** — the economy sinks need a
  shop, the commitment docs need a door, the recovery loop needs an anchor.

- **"Build the state machine once" is the keystone insight.** `g1`, `v3`, and `n2` are not
  three features — they are *one* meta-state→set-dressing mapping read three ways (growth /
  decay / mood). The master README confirms this ("its growth/decay/texture faces are the
  same meta-state rendered three ways"). Speccing them separately risks three docs fighting
  over the same nodes. The single highest-leverage hub decision is to **author one
  `hub_state` system** with growth flags, a decay/dim arm, and a mood read, all keyed to the
  same meta thresholds, with `p4` setting whether decay is recoverable.

- **The hub is mostly front-end — the open question is art cost, not architecture.** Unlike
  `hazards/0-` and `procgen-bands/0-` (which propose genuinely new *generative* architectures),
  the hub adds almost no systems. Its risk profile is inverted: the architecture is trivial
  (a `TileMap` room, reused player controller, `Area2D` interactables), but the *content*
  (every prop in 2+ states, staggered vendor art, the growth/decay vocabulary) is real
  per-asset work that **multiplies combinatorially** with hub states. Every hub doc flags
  art-authoring cost as its top Director question.

- **Does the hub deserve its own `0-` architecture doc?** *Recommendation: yes — a lean one.*
  Not for *generation* (there is none) but to **lock the three cross-cutting contracts** that
  span all 14 hub ideas: (1) the single `hub_state` mapping (resolving `g1`/`v3`/`n2`); (2)
  the shared hub-scene skeleton + interactable pattern; (3) the **batched save-schema plan**
  (`vault_*` + `pending_cache` + packed-loadout in one migration) so the hub's new meta fields
  don't trickle in as N separate schema bumps. This is the hub's equivalent of the other sets'
  "compose from data, preserve baseline parity" contract — and it is the natural place to
  record the `p4` dependency and the `v1`-vs-`v2` tone resolution once the Director rules.

---

## Top 5 things for the Director

1. **Resolve `p4` (reset-severity) first — it is the silent parent of half the hub.** Whether
   `v3` renders recoverable mood or a visible wipe, whether `h2`/`h4` survive a loss, and
   whether `g2`'s cache matters all flip on it; the live K2 full-wipe contradicts GDD §6.
2. **The single sharpest tension: calm relief (`v1`) vs. rent pressure (`v2`).** A vision call
   on whether the exhale has teeth — they cannot both ship at full strength; recommend A/B,
   not co-ship, with rent (if any) modest, posted, and on a slow day-clock.
3. **Mandate "build `hub_state` once" — `g1`/`v3`/`n2` are one system, not three.** Co-design
   the growth/decay/mood mapping or three docs will fight over the same props; this is the
   highest-leverage build decision in the set.
4. **`h1`+`h4` are the headline payoff but are gated on `s1`/`s2` — sequence them together.**
   The hub's biggest synergy ("Money becomes power, visibly") is empty greybox until the
   economy set's missing spend-loop lands; don't build the rooms ahead of their data.
5. **Lock the Cyrus-absence continuity rule before any `n1` handler content.** The handler may
   be a Cyrus-adjacent confidant and may *play his tapes*, but must never *be* or *speak for*
   Cyrus, or the GDD's central mystery collapses; the `c2`/`m2` "Cyrus wants…" flavor must read
   as a recorded standing order.
