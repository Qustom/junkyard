# Extraction Tools (personal beacon)
**Category:** Money sink / investment loop

## The mechanic
A **personal extraction beacon** is a consumable you **buy between runs** (expensive,
limited stock), carry into a dive, and **place** anywhere. After a short **arm time** it
opens a one-shot extraction at that spot — you don't have to find or fight your way back
to the fixed gate. It directly sells the **deep-dive fantasy**: today the deeper you go,
the more your run is hostage to where the exit happens to be. A beacon converts Money into
*the right to leave from here*, so a player can commit to a risky band knowing they bought
an escape hatch. It stays a **decision**, not a crutch, because it's costly (a real Money
sink that competes with quota and upgrades) and **limited** (1–2 per run, consumed on use):
spend it too early and a juicy deep pocket is unreachable; hold it too long and you die
holding an unused investment.

## What exists today
Extraction is a **single fixed gate per band** (`extract_gate.gd` + E1): one hand-authored
`ExtractGate` at `GameState.GATE_SPAWN_OFFSET`, deliberately dumb — it just detects an A2
interact and calls `GameState.extract_and_end_run()`. There is **no found/rare deep exit**
and no second way out; you walk to the one gate or you die/timeout (`E3`), losing the
unbanked haul. So the "hostage to finding an exit" problem isn't even *present* yet — the
beacon is what *introduces* a deep-dive exit at all (and pre-empts a frustrating "one gate,
far away" future). The **deploy/place machinery already exists**: `hazard_entity.gd` /
`bomb_hazard.gd` are persistent, self-running, player-spawnable nodes with the locked
`setup(cfg, player, spawn_ctx)` family signature, and `u2-deploy-place.md` already designs
the player-spawn seam (deploy input → instance → `add_child` → `setup`, placement ghost,
wall rejection). **Missing:** a beacon prefab (an armed timer that, on completion, *is* a
second `ExtractGate` — or directly calls `extract_and_end_run`), a between-runs purchase +
inventory of beacons (Money sink, persists in meta-state), and the arm-time state machine.

## How to fit it in
- **Buy → carry → place.** Beacon is a meta-state consumable bought at the surface (Money
  sink in `game_state.gd`'s `money`), carried as inventory, **deployed via u2's seam**
  (reuse the ghost + wall-reject placement UX).
- **Arm time ties to `e2` timed-extraction.** Placed beacon runs a visible countdown; on
  completion it spawns/becomes an `ExtractGate` (reuse `extract_gate.gd` unchanged) so the
  existing one-press extract path is the only exit logic. Arm time is the cost/tension lever.
- **Economy.** Price it against the **K2 quota** (`K2_quota_system.md`) and upgrades: a
  beacon should cost roughly a chunk of a deep run's haul, so buying one *raises* the quota
  pressure it relieves — you must dive deeper to afford the safety that lets you dive deeper.
- **Tension vs the free fixed gate (`e1` extraction-cost).** The gate stays free but
  shallow-friendly; the beacon is the *paid* deep-dive tool. This is the money-sink seam:
  free exit for cautious play, bought exit for committed deep play.
- **RunConfig + telemetry.** Knob `s3_beacon_enabled` (default off = byte-identical baseline,
  per the M1.1 contract). Emit `beacon_bought{price}`, `beacon_placed{depth, run_t_ms}`,
  `beacon_used{depth, arm_completed}`, `beacon_wasted{unused_at_death}` so the gate can see
  **depth-at-beacon-use** and whether it actually unlocks deeper play vs. just shortcutting.

## Research (cited)
The closest prior art is **Warzone 2.0 DMZ's "Private/Personal Exfil"** — a **Buy-Station
item** that activates an exfil at an otherwise-unused point: a *bought, player-summoned exit*,
exactly this mechanic. **Deep Rock Galactic's Drop Pod** is the **arm-time + walk-to-it**
template: after the quota is met you call the pod and a **3–5 minute countdown** runs before
it leaves — a player-triggered, timed extraction (informs `e2`). **Hunt: Showdown** keeps
multiple fixed extracts (no summoning) as the contrast case for "hostage to a found exit"
the beacon removes. Tarkov has **no callable extract** (fixed/conditional only), underscoring
how unusual a *bought, placeable* exit is and why it sells the deep-dive fantasy.

## Open questions
- **Does it trivialize finding exits?** With only the one fixed gate today, there's nothing
  to trivialize — but if `e5`-style *found rare deep exits* later ship, a bought beacon could
  undercut them. Keep beacons **limited + costly** so found exits stay the cheaper path.
  *(Director: scope call once deep exits exist.)*
- **Cost vs quota.** What fraction of a deep haul should a beacon cost? Too cheap = every run
  buys one (no decision); too dear = never bought. Needs the economy sweep.
- **Arm-time vs pursuers.** A long arm time is the real cost — but does a placed, ticking
  beacon **attract opposition** (a defend-the-beacon beat, like DRG's pod), or arm silently?
  Defend-beat is more dramatic but couples to the `u2`/opposition system. *(Director: fun call.)*
- **Limit per run.** 1 (pure commitment) vs 2 (a hedge)? And is an **unused** beacon refunded
  on a free-gate extract, or consumed-on-place (sunk cost)? Refund softens the decision.
- **Place-anywhere vs zones.** Anywhere is the strongest fantasy but risks cheese (beacon next
  to a loot pocket); restricting to "open floor away from the gate" preserves traversal stakes.

Sources:
- [Personal Exfil — DMZ (Gameranx)](https://gameranx.com/features/id/461305/article/call-of-duty-warzone-2-0-dmz-how-to-use-the-personal-exfil-personal-exfil-explained/)
- [How to exfil in Warzone 2 DMZ — Dexerto](https://www.dexerto.com/call-of-duty/how-to-exfil-in-warzone-2-dmz-mode-locations-more-1988958/)
- [Drop Pod — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/Drop_Pod)
- [Drop Pod — DRG Fandom (countdown timings)](https://deeprockgalactic.fandom.com/wiki/Drop_Pod)
