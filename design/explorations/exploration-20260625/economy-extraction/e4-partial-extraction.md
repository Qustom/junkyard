# Partial Extraction
**Category:** Extraction mechanic depth

## The mechanic
Ship *some* of your haul out mid-dive — bank it safe into meta — and keep diving
with the rest still at risk. Today a run is one binary bet: walk to the gate and
keep everything, or die/time-out and keep only a "pockets" fraction. Partial
extraction lets greed **and** safety coexist *inside one run*: secure the reactor
core you already found, then push deeper for more knowing that, if you die, you
only lose what you chose to keep carrying. It softens the all-or-nothing death
cliff into a series of smaller bets — "how much do I lock in before I gamble the
next floor?" — without removing the gamble.

## What exists today
Extraction is **all-or-nothing at one fixed gate**. `extract_gate.gd` is dumb: an
A2 interact calls `GameState.extract_and_end_run()`, which banks the *entire*
`run_inventory` into `banked_junk` and **ends the run** in the same call — there
is no "bank and keep playing." On death/timeout, `fail_run()` keeps only
`_resolve_pockets()` (`floor(pre_value * pockets_fraction)`, default 0.20) and
drops the rest (E3). The run-vs-meta boundary in `game_state.gd` is *exactly* the
safe-vs-at-risk line: `banked_junk` (meta) survives, `run_inventory` (run-state)
is wiped on every end. What's missing is a transfer that moves *chosen items*
run→meta **without** flipping `run_active` off — a mid-run partial commit of the
same `run_inventory.items[] → banked_junk[]` move that `extract_and_end_run`
already does for the whole bag.

## How to fit it in
- **A mid-run "ship" action.** Add a third path beside extract/fail:
  `ship_items(selected: Array[JunkItem])` that appends the selected items to
  `banked_junk`, removes them from `run_inventory`, persists meta
  (`SaveManager.save_meta(0)`), emits a new `EventBus.items_shipped(value)`, and
  **does not** end the run. The run-end machinery is untouched.
- **Where you ship.** Reuse existing surfaces: a one-press ship at the gate
  ("ship the highlighted item, keep diving" vs. the full extract); a **drop-chute**
  prop; or the **s3 beacon** doubling as a ship point. Beacon synergy is strong —
  a placed beacon could offer "ship now" before its full arm-extract completes.
- **Maps onto loadout-vs-cargo (x3).** Cargo is "loot I'm protecting"; shipping is
  *graduating cargo into permanent safety*. A natural rule: only **cargo** ships
  (loadout throwables stay), so the two zones gain a second axis.
- **Push/cash-out (E2).** E2's "Holding: N" HUD now splits into *shipped-safe* vs
  *still-at-risk*, sharpening the push decision: a high at-risk number makes
  "ship before I push" the live choice.
- **Death loss (E3) becomes partial-by-design.** Pockets math is unchanged — it
  just operates on a *smaller* at-risk bag, because the player already secured the
  rest. Securing-as-you-go is the player's lever on E3 loss.
- **RunConfig + telemetry.** Knob `e4_partial_ship_enabled` (default **off** =
  byte-identical M1.0 baseline, per the M1.1 contract). Optional `ship_cost`
  (flat Money or a % tax) and `ship_limit` (N ships/run). Emit `items_shipped`
  `{value, depth, run_t_ms}` and at run-end `value_secured_via_ship` vs
  `value_lost_on_death` so the gate can see whether shipping *enabled deeper play*
  or merely *de-risked the same play*.

## Research (cited)
- **Tarkov secure container** — items in the small secure case are kept on death
  while the main inventory is lost. That's "secure a subset, risk the rest," but
  *space-limited and pre-committed* rather than an in-raid transfer; partial
  extraction is the *active, repeated* version of the same safe-vs-risk split.
- **Deep Rock Galactic — M.U.L.E. ("Molly")** — call the mule and **deposit
  minerals mid-mission** (depositing *is* the objective progress); banked
  resources are then safe regardless of how the rest of the mission goes. The
  clearest "bank-as-you-go to a mobile point" template — directly informs the
  chute/beacon ship surface.
- **DRG Drop Pod / DMZ Personal Exfil** (via s3) — player-triggered, timed exits;
  pair a "ship now" with an arm-time "leave now" on the same device.
- **Roguelite framing** — the genre's defining tension is "permadeath of the run,
  persistent meta gain"; partial extraction lets the player **convert run-state to
  meta-state incrementally** instead of only at the end, which is exactly the
  faucet the run-vs-meta boundary in `game_state.gd` is built to support.

## Open questions
- **Does it remove too much risk?** If shipping is free and unlimited, a careful
  player ships after every find and the death cliff vanishes — the core push-luck
  tension with it. A **cost or limit** (tax, N ships/run, or arm-time at a beacon)
  is likely required. *(Director: fun/tension call — playtest free vs. taxed.)*
- **Ship cost shape.** Flat Money fee, a % value tax, or a time cost (animation /
  arm-time while the dive clock and pursuers run)? Time-cost keeps it diegetic and
  couples to opposition; Money-cost is a clean economy lever. *(Economy sweep.)*
- **UX of choosing what to ship under pressure.** Selecting items from the bag
  mid-fight is fiddly. "Ship highlighted" (reuse L1's selector) is fast but blunt;
  a multi-select panel is precise but pauses the action. Lean fast for graybox.
- **Interaction with the quota (K2).** Does shipped value count toward the run's
  quota immediately, or only the final sell? Immediate counting could let a player
  ship-to-quota then suicide-dive risk-free — likely undesirable. *(Director.)*
- **Refund/unship?** Once shipped it's meta and gone from the run — almost
  certainly one-way, but confirm no "pull it back" expectation.

Sources:
- [Secure containers — EFT Wiki](https://escapefromtarkov.fandom.com/wiki/Secure_containers)
- [Looting — EFT Wiki](https://escapefromtarkov.fandom.com/wiki/Looting)
- [M.U.L.E. — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/M.U.L.E.)
- [How to call Molly the Mule — The Click](https://www.theclick.gg/gaming/guides/deep-rock-galactic-how-to-call-molly-the-mule-to-you/)
- [Roguelike vs Roguelite — RogueRanker](https://rogueranker.com/roguelike-vs-roguelite/)
