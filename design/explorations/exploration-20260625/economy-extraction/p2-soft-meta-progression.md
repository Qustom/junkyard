# Soft Meta-Progression
**Category:** Run-to-run persistence

## The mechanic
Even on a game-over reset (the K2 quota-miss wipe, `game_state.gd:410 wipe_meta()`),
a small set of **permanent unlocks survives** and is **applied at the next run's
start** — so a loss still moves you forward. Three unlock *types*, deliberately
small:
- **A starting item** — begin a fresh run with a low-value junk item (or a tool)
  already in the bag, so depth 0 isn't empty.
- **A known shop / facility** — a between-run service (per the gear shop, `s1`) is
  *unlocked* once and stays unlocked across wipes; you don't have to re-discover it.
- **A small stat** — a tiny permanent buff (e.g. +1 inventory slot, +2% move
  speed) earned by hitting a milestone.

This is classic roguelite cushioning: the *life* persists, the *run* resets, but
the wipe stings *less* each ladder because you carry a thin permanent floor up.

## What exists today
KEY: the build **already has a persistent-meta frame** — soft meta-progression is
half-built. The wipe (`wipe_meta()`) and the meta/run boundary it enforces are the
exact machinery this mechanic rides on; what's missing is the *opposite* of a wipe:
a meta field that the wipe **does not** clear.

- **Persistent meta is real.** `money`, `salvage`, `lore`, `knowledge_level`,
  `unlocked_recipes`, `banked_junk` are all meta-state (`game_state.gd:33-42`),
  serialized by `to_meta_dict()`. The GDD already frames Knowledge / recipes / lore
  as durable meta-gates (`GDD §12`, §"Repair/fixing": *"recipes — bought, found,
  or unlocked via Lore"*).
- **But `wipe_meta()` nukes ALL of it** (`game_state.gd:410-428`) — money, lore,
  knowledge, recipes, banked junk *all* reset to construction defaults. There is
  currently **nothing that survives a wipe**. The roguelite "keep your unlocks"
  half of the GDD's *"keep all meta-progression"* promise (GDD §loop, line 76) is
  unbuilt *for the wipe path* — it only holds for the non-wipe extract/death path.
- The apply-at-run-start seam exists too: `start_run()` already lazy-inits quota
  meta and reads `active_run_config` (`game_state.gd:113-155`), so adding "seed the
  bag / apply owned buffs from meta here" is a clean insertion, not a rework.

**What's missing:** (a) a meta field for survives-the-wipe unlocks
(`unlocks: Array[StringName]` or `{id:level}`); (b) the carve-out in `wipe_meta()`
that preserves it; (c) the apply hook in `start_run()`; (d) the data defining what
each unlock *is* and how it's *earned*.

## How to fit it in
- **New meta field, wipe-protected.** Add `unlocks: Array[StringName]` to
  `game_state.gd`, persisted in `to_meta_dict()`/`from_meta_dict()` under a
  **schema bump + migration + QA fixture** (standing save rule). The single change
  that makes it "soft": `wipe_meta()` **does NOT reset `unlocks`** (it resets
  everything else). One deliberate omission = loss-as-progress.
- **Apply at run start.** In `start_run()`, after binding `active_run_config`,
  iterate `unlocks` and apply each: a starting-item unlock pushes a `JunkItem` into
  the fresh `run_inventory`; a stat unlock overrides the effective run knob (the
  same derive-effective-from-meta seam `s1`'s shop uses — bag size, speed); a
  shop unlock just flags a between-run scene available. Unlocks are meta → effects
  are *derived* into run-state, never mutating the unlock data (run/meta boundary).
- **Earning them.** Unlocks drop from **milestones, not the cash loop** — e.g.
  "reached depth N once," "survived to run #5," "banked a band-2 item." Keeping the
  trigger a *milestone* (not Money) means soft meta doesn't compete with the
  spend-vs-quota tension `s1` owns; it's a parallel, slower cushion.
- **Interaction with the reset-severity dial (`p4`, sibling).** Soft meta is the
  **forgiving end** of that dial. `p4` decides *how much* survives a wipe across the
  whole game; this mechanic is the concrete "starting item / known shop / small
  stat" answer for the gentle setting. The two must be co-tuned: a harsh-`p4` build
  keeps `unlocks` tiny (or empty); a gentle build lets them accumulate.
- **Gear sink (`s1`) overlap.** `s1`'s open question (a) is precisely "do shop
  upgrades survive a wipe?" Soft meta is the affirmative answer for a *curated
  subset*: most `s1` gear is wipe-cleared (keeps the miss costly), but a few
  **milestone unlocks** (the first shop tier, +1 slot) are flagged wipe-proof and
  live in `unlocks`. Keep the bulk of bought power resettable; only the
  loss-cushion is permanent.
- **Knowledge/recipes relate.** Knowledge and recipes are *already* the GDD's "soft
  meta" in spirit — but today they wipe. A clean first cut: move a **small starter
  recipe** (or the depth-1 Knowledge tier) into the wipe-protected set, so a wiped
  player keeps the *frame* of what they'd learned, not the wealth.
- **RunConfig knob + telemetry.** Add `soft_meta_enabled` (default **off** = today's
  full-wipe baseline, the permanent control). Telemetry on each wipe:
  `unlocks_owned_at_wipe`, `unlock_earned(id, trigger, run_number)`,
  `unlocks_applied_at_start` — so the gate can read *unlocks earned per loss* and
  whether the cushion correlates with players continuing after a wipe.

## Research (cited)
Prior art is the spine of the roguelite genre — the loss-as-progress cushion is
what separates roguelite from roguelike:
- **Hades — Mirror of Night / keepsakes / weapons.** Permanent unlocks bought with
  meta-currency that *survive every death*; failing a run still advances story beats
  and unlocks. The polished template for "losing is progress."
- **Rogue Legacy — castle + lineage.** *"each time you die… you keep all the gold,"*
  spent on permanent manor upgrades applied to every future heir — the 2013 game
  that crystallized the modern roguelite meta-progression model.
- **Dead Cells — blueprints.** You unlock weapons/mutations that *enter the pool*
  for future runs (a permanent *known shop*-style unlock, not a stat) — the closest
  analogue to our "known shop / starting item" types over a raw stat buff.
- **Risk of Rain 2 — survivor/item unlocks** and **Spelunky — shortcuts**: both
  show *milestone-triggered* permanent unlocks (do X once → it's yours forever),
  matching our "earn from milestones, not the cash loop" recommendation and
  Spelunky's shortcut = our "known shop you don't re-discover."

## Open questions
- **[DIRECTOR — fun/severity, defer to `p4`] How much permanent power before the
  wipe stops mattering?** Soft meta directly fights the M1.4 stakes thesis ("a quota
  miss is a *real* wipe"). Too generous and the loss is toothless; too thin and it's
  cosmetic. **Recommendation:** ship a *tiny* first set — one starting item, one
  shop-unlock, one +1-slot stat — and let `p4` set the ceiling. *Co-tune with `p4`;
  this is the gentle pole of that dial.*
- **[DIRECTOR — roguelike vs roguelite identity] Does THE FAR YARD want a permanent
  floor at all?** The GDD says soft-roguelite (*"keep all meta-progression,"* line
  76) for death/timeout — but the K2 quota *wipe* was deliberately added as a hard
  reset. Whether the wipe should carry a soft floor is a **vision call**, not a
  technical one. **Recommendation:** yes, a *thin* one — it matches the stated
  soft-roguelite identity and the genre norm — but flag explicitly for the Director,
  since it softens the headline stake K2 just introduced.
- **Unlock pacing — milestone vs grind?** If unlocks come too fast they trivialize
  early ladders; too slow and the cushion never materializes before a frustrated
  player quits. **Recommendation:** gate the first unlock on an *early, reachable*
  milestone (survive run #3, or reach depth 5 once) so the very first wipe already
  yields something — the cushion is most needed at the start of the learning curve.
  *Pacing is a tuning call for the economy model (M3) + playtest.*

Sources:
- [Hades' Mirror of Night Does Upgrades Right — TheGamer](https://www.thegamer.com/hades-mirror-of-night-roguelite-progression/)
- [Upgrades — Rogue Legacy Wiki (Fandom)](https://rogue-legacy.fandom.com/wiki/Upgrades)
- [Roguelite Games With The Best Progression Systems — Game Rant](https://gamerant.com/roguelite-games-with-best-progression-systems/)
- [Roguelike vs Roguelite: The Difference That Actually Matters — Pudgycat](https://pudgycat.io/roguelike-vs-roguelite-difference-explained/)
