# The Recovery-Run Anchor
**Category:** The hub as the home of meta-progression

## The idea
The hub holds your **unfinished business**. When a run fails (death / timeout —
E3), the haul you couldn't carry isn't simply deleted: a slice of it becomes a
**lost cache** that the hub shows as *still out there* — a pin on a board, a
glowing marker on a map, a blinking light on the handler's terminal. From the
hub you then *choose* whether to mount a **recovery run** back into that same
band to reclaim it. It is the Dark Souls bloodstain / Hollow Knight Shade
pattern — your loot waits at the place you died — **anchored to a place you
visit**: the hub is where the lost cache lives in fiction until you go get it.

The hook this buys: a failed run stops being a dead end. It plants a *reason to
go back in* — "my stuff is down there" — turning loss into a baited next run
instead of a flat penalty. The hub becomes a ledger of what you still owe
yourself.

## What exists today
Honest read: **nothing recovers a lost haul today, and `lost_proxy.gd` is a
red herring for this.** `entities/dive/lost_proxy.gd` is a *navigation*
lost-proxy — a telemetry tracker that emits `nav_lost_proxy` when you wander
without making depth progress ("lost" as in *disoriented*, not *lost loot*). It
writes nothing to meta/save and is unrelated to a recoverable cache. Naming
collision only.

The real anchor point is **E3** (`fail_run`, `game_state.gd:444/459`): on
death/timeout you keep a "pockets" fraction (~20%, highest-value first,
`run_rules.tres`) and **everything else is discarded — `run_inventory.clear()`,
gone, permanently.** There is no persistent record of the lost remainder, no
pending-cache flag, and no path to re-enter that band.

What *does* exist and makes recovery cheap to build:
- **Determinism.** `start_run(band_id, seed)` is the locked signature
  (`game_state.gd:113`) and `RNG.seed_from(seed)` reseeds everything. Re-passing
  the **stored `run_seed`** regenerates the *same* layout — the recovery run can
  be the literal same band the cache was lost in (`band_generator.gd`).
- The **commitment seam** (`stage_run_config`, c2/c1) already lets a hub fixture
  stage and depart a run.

**Missing:** (1) a persistent **pending-cache** record (band_id + seed + the
discarded items/value) surviving on meta; (2) a hub fixture that surfaces it;
(3) a recovery-run entry that re-stages that seed.

## How it could fit in
1. **On fail (E3 extension):** instead of dropping the non-pockets remainder to
   nothing, snapshot it into a meta-persistent `pending_cache` (band_id,
   `run_seed`, items, value, a created-timestamp/run-counter). One record at a
   time. This is a small additive meta field → schema bump + migration + QA
   fixture (`save_manager.gd` rules).
2. **In the hub:** a greybox `Area2D` anchor (board pin / glowing marker).
   Interact → a panel: "Last run's cache — band X, ~$N — still out there.
   Recover it?"
3. **Departure:** choosing it calls `GameState.stage_run_config(...)` with a
   recovery flag and re-passes the stored `band_id`/`seed`, reusing the c1
   departure walk. The cache is placed in that seeded layout; reaching and
   banking it clears `pending_cache`.
4. **The teeth:** a **second failure** before reclaiming **loses the cache for
   good** (Hollow Knight's double-loss). This ties straight to the
   **reset-severity dial (p4)** — under `STANDARD` the cache is the *stake* of a
   forgiving loss; under `HARSH` it's moot (meta wipes anyway).

Feature-gated: all-off = today's E3 (remainder discarded, no cache, no anchor),
so the M1 baseline is untouched and recovery is measured as an additive cohort.

## Research (cited)
- **Dark Souls — Bloodstain:** death drops *all* souls at the death spot; touch
  it to recover. Die again first and the **old bloodstain vanishes** — pure
  double-loss. The canonical risk-to-reclaim loop.
- **Hollow Knight — Shade:** Team Cherry explicitly built on Souls' corpse run.
  Your Geo waits in a Shade at the death room; **die again and the previous
  Shade (and its Geo) is lost forever**, the new one replaces it. Same
  one-cache-at-a-time, double-loss-is-permanent rule recommended above.
- **Escape from Tarkov — Insurance:** the *softer*, extraction-genre variant —
  insured gear left in a raid returns **after a delay (12–36h)** and only if no
  one else looted it. Recovery as a *timed, conditional* return rather than a
  go-fetch run — a design fork worth noting (passive vs. active reclaim).

The split this topic sits on: **active reclaim** (Souls/HK — go back in, risk a
double loss) reads as a *baited run* and fits THE FAR YARD's dive loop; **passive
return** (Tarkov insurance) reads as a *safety net* and fits a life-sim downtime
beat. The seeded-determinism we already have makes the active version cheap.

## Open questions
- **Does `lost_proxy` cover any of this?** No — confirmed it's navigation
  telemetry, not lost-loot. New system entirely. (Worth renaming one to avoid
  confusion — *minor, flag.*)
- **How long does a cache persist?** Forever until reclaimed/double-lost, or does
  it **decay** (expires after N runs / Instability creep makes it unrecoverable)?
  Decay adds urgency but can feel-bad if you can't afford the trip. *Recommend
  "persists until next failure" (HK rule) for legibility; flag decay as a tuning
  lever — fun/scope call for Director.*
- **Double-loss harshness vs. p4.** Permanent double-loss is the genre standard
  but harsh; under the recommended `STANDARD` reset-severity it may be the right
  amount of teeth. Or soften: a second failure *shrinks* the cache rather than
  voiding it. **Vision/tone call — Director.**
- **Is recovery a special run type or just a normal run into a fixed seed?** A
  dedicated mode could add flavor (no quota pressure? a tighter clock?) but adds
  surface area. *Recommend: a normal run with the seed pinned + a cache placed,
  no special rules, for M-early; flag richer variants as post.*
- **Pockets vs. cache overlap.** Does the recoverable cache = the *full*
  discarded remainder, or a further-reduced slice? Recovering 100% of what you
  "lost" may undercut E3's sting. *Recommend cache = remainder × a recovery
  fraction (a new `run_rules` knob); tune at the gate.*

## Sources
- [Bloodstain — Dark Souls Wiki (Fandom)](https://darksouls.fandom.com/wiki/Bloodstain)
- [Shade — Hollow Knight Wiki](https://hollowknight.wiki/w/Shade)
- [Shade — Hollow Knight Wiki (Fandom, double-loss & Team Cherry origin)](https://hollowknight.fandom.com/wiki/Shade)
- [Insurance — Escape from Tarkov Wiki (Fandom)](https://escapefromtarkov.fandom.com/wiki/Insurance)
