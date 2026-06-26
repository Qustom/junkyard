# Player Mechanics — Cross-Exploration Analysis
**Set:** player-mechanics/  ·  **Analyzed against:** hazards, procgen-bands, economy-extraction, hub-staging
**Date:** 2026-06-25  ·  Author: `game-director-designer` cross-pass (not Director-dispositioned)

The player set is the **verbs**. Almost nothing in it is self-justifying: a verb only earns its build cost when it *answers a specific opposition*, *needs a specific band geometry to exist*, *is sold by the economy*, or *is prepped in the hub*. This pass traces those connections. The single most load-bearing finding: three player files (`x2` noise, the spatial-inventory model, the HP pool) are **substrates other sets silently assume** — they are dependencies for whole clusters, not standalone mechanics.

---

## Synergies (verbs that counter / enable / are bought-and-sold-against other ideas)

1. **Charged throw (`t1`) IS the counter the Armored/Shelled enemy asks for.** `hazards/6-armored-shelled.md` only cracks from a heavy item *or* a high-force hit; `t1` explicitly proposes "a full charge is the heavy hit that staggers/cracks a shell, so charge **is** the counter-verb that file asks for." `t1` also reaches the out-of-range `2-sentry.md` lane enemy that baseline 320px range can't touch. These two oppositions are the *reason* charged throw exists.

2. **Arc-vs-straight (`t2`) is the player-side mirror of the Lobber, and answers the Sentry-behind-cover.** `t2` names `hazards/2-lobber.md` ("the Lobber arcs shells over *your* cover; arc-vs-straight lets you arc one *back*") and `2-sentry.md`. It is the verb that makes `procgen-bands/b1-open-field-with-cover.md` and `e3-verticality-fakes.md` matter: a lob is the only answer to a wall a flat throw can't pass, and `e3` itself names "throw loot or a lure *down* a pit" / "arc across a gap at a pursuer stranded on the far lip." `t2` ↔ `e3` is a true two-way dependency (arc needs the fake-Z that `e3` height also wants).

3. **Bounce/wall-throw (`t4`) turns the Reflector into a solvable duel and kills corner-sentries.** `hazards/6-reflector.md` bounces *your* throw back; `t4` notes "your own bounce knowledge predicts the return path," and both reference `Vector2.bounce`. `t4` is the canonical answer to around-corner ambushers in dense geometry (`procgen-bands/c1-dense-maze.md`). Crucially `t4` needs **no fake-Z** (pure 2D reflection) — the cheap throw-deepener.

4. **The Eater (`hazards/6-eater.md`) is the negative-space that justifies throw-to-place (`t5`), use (`u1`), and deploy (`u2`).** The Eater punishes the throw-at-it reflex; the player's answer is to throw *around* it (`t5` bait to a spot), lure it (`u1` LURE, `u2` decoy), or drop it onto a hazard. The Eater is the opposition that *forces* the non-throw item verbs to exist.

5. **Trajectory preview (`t3`) is a hard dependency of `t2`/`t4`, not a nicety.** Both `t2` and `t4` state a lob/bounce "over a wall is a blind guess" / "unfair without a trustworthy predicted-impact dot." `t3` must mirror whatever throw depth ships (straight → segment, arc → curve, bounce → reflected segments) via one shared helper. Build order: `t3` before/with `t2`+`t4`.

6. **Deploy/place (`u2`) reuses the entire hazard architecture — the strongest build-economy synergy in the set.** `u2` spawns a player-owned `bomb_hazard`/`spike_hazard`/decoy using the *same* `setup(cfg, player, spawn_ctx)` family from `hazards/0-scalable-opposition-system.md`; the only new concept is **ownership** (flip the proximity test to read the `enemy` group). A player-deployed light counters `hazards/4-darkness-pocket.md`; a decoy counters the `1-*` pursuers.

7. **Carry-load→speed (`x1`) is the physics; the economy supplies the stakes.** `economy/r3-full-bag-liability.md` is explicitly "not a separate build — it is x1 plus an E2-HUD value-at-risk readout." `x1` dips the player's top speed toward/under the loaded pursuer's chase speed (`hazards/1-charger`, the Hunter `5-the-hunter.md`), creating the "I can't outrun it carrying this" moment. Its relief valve is deliberate-drop (`i3`).

8. **Noise→aggro (`x2`) is the listener for the Sound-Aggro Zone and unblocks sprint/sneak.** `hazards/4-sound-aggro-zone.md`'s `noise` accumulator literally *becomes* "sum of `noise_emitted` inside the zone." `x2` is the substrate `m2` (sprint pays noise), `m3` (sneak reduces noise), and the sound zone all plug into. Throw (`t*`) doubles as a deliberate noise *lure* against the Patroller cone (`hazards/1-patroller-vision-cone.md` "a thrown item draws the cone").

9. **Sneak (`m3`) and Hide (`e3`) are the player half of the Patroller vision-cone.** Both are *hard-blocked* on `hazards/1-patroller-vision-cone.md` (no enemy perception exists). `m3` shrinks the cone's effective `pat_cone_range`; `e3` breaks LoS entirely. They compose ("sneak to a locker, then hide in it") and deliver the GDD stealth pillar as player-chosen verbs.

10. **The gear shop (`economy/s1`) is the faucet that *sells* the player verbs.** `s1` explicitly lists its purchasables as: dash (`m1`), bag size (`i6`/`x1`), move speed (`m2`), quick-throw slots (`x3`), trajectory preview (`t3`). The shop is the missing money-sink whose entire inventory is this folder. `economy/s2-consumable-loadout.md` sells single-use `u1`/`u2` items (flare/decoy/shield).

11. **The loadout bench (`hub/h3`) is the resolution of `i2`'s pause-vs-real-time tension.** `h3` states it directly: deep packing (rotate `i1`, tetris `i2`, protected pocket, quick-slots `x3`, consumables `s2`) moves to the *calm, clockless* bench; the dive keeps only fast value-vs-space + quick-throw. The bench is the "safe pole" `i2` deliberately left unresolved.

12. **Levers/doors (`e2`) weaponize the static-trap group and reuse the socket-sealer.** `e2` "close-door-on-pursuer" reuses `socket_sealer.gd` geometry and stops `hazard_entity.gd` (world-masked) for free; "switch-fire-trap" turns `hazards/3-crusher-piston.md` / `3-popup-spikes.md` / `3-flame-vent.md` from obstacles into player-aimed weapons. A door is "a connector whose seal/unseal state is toggleable" — latent in the band generator.

13. **Push/pull (`e4`) solves the Weight Plate and barricades pursuers.** `e4` shoves an object onto `hazards/6-weight-plate.md` so *it* trips the plate instead of your over-heavy body; the conveyor (`hazards/3-conveyor-wind-tile.md`) must apply its `hcv_force` to a Pushable (same body). It builds cover where `procgen-bands/b1` put none.

14. **Weight Plate (`hazards/6-weight-plate.md`) reads the *same* load metric as carry-load (`x1`) and is beaten by the throw verb.** The plate fires on `slots_used`/`run_haul_value()`; `x1` slows you on `used_slots()/max_slots`. The plate's intended counter — "throw your haul across, walk light, re-collect" — is a traversal use of `t5` throw-to-place. One inventory state drives two systems.

15. **Search-containers (`e1`) ties looting to the clock and creates the vulnerability window the ambusher/mimic want.** `e1`'s timed open is the "commit to standing exposed for N seconds" beat; it pairs with `hazards/6-mimic-loot.md` (the container *is* a mimic), ambushers waking mid-search, and `hazards/5-alarm-spawner.md` ticking during the search. It's the loot-side cousin of the throw-economy: time is the cost.

16. **The Thief (`hazards/6-thief.md`) attacks the inventory directly — making deliberate-drop (`i3`), swap (`i4`), and repack (`i2`) defensive verbs.** The thief calls `remove_at(highest_value_index)`; the throw verb recovers the stolen item via `junk_dropped`. The thief makes the bag "a thing you must defend," giving the inventory verbs combat stakes. (Note the vicious combo it flags with Armored-shelled and Eater.)

17. **Loadout-vs-cargo (`x3`) scopes the throw verb and is the home of the quick-slot upgrade.** `x3` makes only the small loadout zone throwable (your reactor core is no longer "as throwable as a rock"). It's a *count-based* partition (smaller than `i2`'s spatial rework), it's purchasable via `s1`'s quick-slots axis, and it's prepped at `hub/h3`.

18. **Dash (`m1`) is the free spacing answer that complements the throw against pursuers.** Against `hazards/1-charger`/`1-pack-hunters`/`1-leaper` (and the Hunter), `m1` buys distance/angle so the throw can land — but only *with i-frames* does it answer the ranged `2-*` group and cross `3-*` hazard tiles. It's a `s1` purchasable.

19. **Use/consume light & reveal (`u1`) is the player counter to the darkness pocket and magnet/gas zones' loot-blind.** `u1` LIGHT/REVEAL flood `VisionFog` against `hazards/4-darkness-pocket.md`; LIGHT trades a sellable item for `+dive-clock seconds`, coupling the verb to the ~300s clock. (HEAL waits on the M2 HP pool — see contradictions.)

20. **Vault/slide (`m4`) needs the cover/decay geometry and is negated by the Leaper.** `m4` is hard-gated on `procgen-bands/b1` cover or `e5-wear-decay-state` rubble carrying a `vaultable` edge flag; `hazards/1-leaper.md` "leaps the same wall you vaulted" — the one pursuer geometry won't shake (mirroring how the Leaper also negates `e3`'s drop edges).

21. **Combine/craft (`i5`) must be a subset of the GDD recipe system, not a rival — and Knowledge gates it.** `i5` recommends one `CraftRecipe.tres` spine shared with surface crafting (`economy/s1` track / hub upgrade station `hub/h4`), with in-dive combine as the *fast, costly, clock-spending* face. This keeps the three-currency economy (Money/Salvage/Knowledge) coherent.

22. **Container items (`i6`) unify cleanly with cargo (`x3`): "a container can literally BE the cargo hold."** Both are count-based slot-bucket ideas; `i6`'s depth-1 nesting is the cargo region, `x3`'s flat slots are the loadout. `i6` is a `s1` bag-size purchasable and a `hub/h3` pre-pack surface.

---

## Contradictions & tensions

- **Dash i-frames (`m1`) vs. the throw-as-signature-answer identity.** This is the sharpest internal contradiction in the set. `m1`'s fork: i-frames make dash a *defensive answer in its own right* ("dodge it" instead of "kill it"), which **competes with** and can hollow out the throw — the verb the whole `hazards/6-*` throw-synergy group and `economy/m4` are built around. The economy literally taxes throwing (fragility, item-spend); if dash trivializes threats, that tax has nothing to tax. `m1` recommends `dash_iframes=false` to protect the throw; the Director must rule.

- **The spatial-inventory model swap vs. the count-based reality every other set assumes.** `i1` (rotate) and `i2` (real-time repack) need a 2D grid/footprint/occupancy model that **does not exist** — D1 locked count-based for M1, with `grid_footprint` "advisory." But `i3` (drop), `i4` (swap), `i6` (containers), `x1` (carry-load), `x3` (cargo), and crucially the *economy and hazard* sets that read `used_slots()`/`slot_size`/`run_haul_value()` (`hazards/6-armored-shelled`, `6-weight-plate`, `economy/r3`) all assume the cheap **count** model. Going spatial for `i1`/`i2` either forks the inventory (two models) or forces a migration that ripples into hazards + economy. This is a one-or-the-other scope call, not an additive one.

- **Real-time repack (`i2`) vs. the PAUSABLE dive clock.** `DiveClock` is `PROCESS_MODE_PAUSABLE`, so any menu-pause freezes the whole dive "for free." `i2`'s pitch (manage the bag *while chased*) requires a non-pausing overlay; the safe-puzzle alternative is "just Tarkov stash admin." `hub/h3` partially defuses this by moving deep packing to the clockless bench — but that *also* undercuts `i2`'s reason to exist mid-dive. Director call: is in-dive inventory a tense skill or does the bench own it?

- **Condition/fragility (`economy/m4`) deliberately taxes the signature throw — and stacks with three other throw-taxes.** `m4` chips item value on every throw (more on charged `t1` throws of high-tier items). But the throw is *already* costed: it consumes the item on a kill (L1), and `t6` recall only rescues misses. Layering fragility on top, plus `x3` scoping throwables, plus the Eater eating items, risks the BotW failure `m4` itself cites: players hoard and stop throwing. The set has a coherent throw-economy *or* an over-taxed one depending on how many of these ship together.

- **Throw-to-place (`t5`) vs. deploy/place (`u2`) — two "put something on the ground" verbs.** Both files flag the overlap and draw the line (`t5` = relocate inert junk at range; `u2` = spawn an active device at feet). It's a legibility risk under one control scheme; both recommend "keep separate only if the line stays clean, else merge." A live scope call.

- **Charge-gating overload on the throw button.** `t1` (hold = charge), `t5` (tap = place / charge = hit), and `u1`'s context-input option all want to overload the *same* throw input with charge/tap semantics. Three different meanings on one button is a real mis-fire risk under chase (a panicked tap meant to kill becomes a soft drop). The set leans toward *separate buttons* for `u1`/`u2` but charge-disambiguation for `t1`/`t5`.

- **HP-pool gating: heal (`u1`) and damage-tradeoffs are out until M2.** Hazards are binary-lethal today (`r1_catch_kills`/`hpp_kills` → instant run-end). `u1` HEAL, `s2`'s one-use shield (intercepting the lethal flag), and most zone/Field oppositions (gas, electrified floor) all wait on the M2 HP pool — a cross-set dependency flagged in the master README too.

- **Stealth as a pillar vs. a light option — an unresolved scope spine across `m3`/`e3`/`x2`.** All three recommend "ship the light option, measure if testers use it before investing in a pillar." If the Director wants a real stealth pillar, `x2` + cones + search states + lures must interlock (a large build); if a light option, a single radius + one cone enemy may be all that's wanted. The decision sizes a whole cluster.

- **Soft-lock fairness (`e4`) vs. connectivity guarantees.** Push/pull can wall off the only route to the gate; this collides with the band set's standing "connectivity guarantee" rule (`procgen-bands/0`, `b1`'s `clear_lane_guarantee`). Needs a fairness ruling (only-promote-where-a-path-survives, or allow pull) before it ships beyond graybox.

---

## Shared dependencies & build-order notes

Four substrates gate large clusters. Build these *first* or the dependent verbs are no-ops:

1. **Noise→aggro (`x2`) — the foundational substrate.** Unblocks `m2` (sprint-noise fork), `m3` (sneak noise-mult), and `hazards/4-sound-aggro-zone.md`. `x2` itself recommends being scheduled as a *named substrate task ahead of* those three so they land as small additions. Contract: `EventBus.noise_emitted(pos, loudness, source)` + a `HearingTrigger` component (same shape as the opposition taxonomy's `ProximityTrigger`).

2. **Enemy perception (the Patroller vision-cone, `hazards/1-patroller-vision-cone.md`) — gates the stealth verbs.** `m3` (sneak), `e3` (hide), and throw-as-distraction all read enemy perception, which does not exist (`vision_fog.gd` is the *player's* cosmetic sight, not enemy LoS). `e3` recommends landing the `player_concealment_changed` signal contract early so the patroller can be authored against it.

3. **The HP pool (M2) — gates the survival verbs.** `u1` HEAL, `s2` shield, damage-taking tradeoffs, and the zone/Field oppositions. Same flag as the opposition architecture's M2 line.

4. **The spatial inventory model — gates the packing verbs.** `i1` (rotate) and `i2` (repack) need the dormant grid/footprint model + fit-search + a drag-placement UI (D2 is a slot list today). Everything else inventory-side (`i3`,`i4`,`i6`,`x1`,`x3`) is *cheap precisely because it stays count-based* — the swap is the expensive fork. `hub/h3` is where the spatial UI would live without time pressure.

**Reused-architecture wins (cheap because the machinery exists):**
- **The hazard system** (`hazards/0`) → `u2` deploy (player-owned hazards), `e2` switch-fired traps.
- **The socket/sealer geometry** → `e2` doors (toggleable sealed sockets), `m4` vault edges (mirrors `e3`'s dormant `is_drop` meta).
- **The `junk_dropped` re-spawn path** → `i3` drop, `i4` swap, `t5` place, `t6` recall, Thief recovery — all already plumbed (~90% for `i3`).
- **The `_exposure_speed_mult` seam** → `x1` carry-load (a second multiplicative term, zero new data).
- **The A2 Interactable + `interaction_requested`** → `e1` search, `e2` levers, `e3` hide — all just new Interactable ids.

**Cheapest standalone wins (no upstream substrate):** deliberate-drop (`i3`), swap-in-place (`i4`), carry-load→speed (`x1`), trajectory-preview (`t3`), bounce (`t4`, no fake-Z), deploy (`u2`, reuses hazards). These can ship into M1.x behind their all-off knobs without waiting on noise/perception/HP/spatial.

---

## Notable design information

- **The player set is the verbs; its targets, spaces, stakes, and home all live in the other four sets.** A verb with no opposition is untested (dash without a charger), with no geometry is impossible (vault without cover, arc without walls), with no economy is meaningless (a bigger bag with nothing to spend Money on), and with no hub has nowhere to be prepped (the bench, the shop). The cross-set README's "dash → charger → corridor → quota → shop" chain is the literal dependency spine; this set sits at its head.

- **The loadout bench (`hub/h3`) is the single cleanest resolution of an internal player-set tension.** It takes `i2`'s unresolved pause-vs-real-time question and answers it spatially: *deliberate packing happens in a clockless place; the dive is where the plan meets the Hunter.* It also seeds `s2` consumables and `x3` quick-slots and requires a new meta-state "packed loadout" seam that `start_run()` reads into the fresh `RunInventory` — respecting the run/meta boundary.

- **The economy explicitly *sells* this folder.** `s1`'s purchasable list is dash/bag/speed/quick-slots/preview — i.e. `m1`/`i6`/`m2`/`x3`/`t3` are the shop inventory. This means the player-verb RunConfig knobs (`dash_enabled`, etc.) become *derived from owned upgrades at `start_run`*, not config-toggled — the verbs already exist as run-state, the shop just becomes their source. This is a tidy, already-aligned seam.

- **One inventory number drives a surprising amount.** `used_slots()`/`slot_size`/`run_haul_value()` is read by `x1` (speed), `r3` (value-at-risk), `hazards/6-weight-plate` (trigger), `hazards/6-armored-shelled` (heavy-throw threshold), `i4` (swap arithmetic), and the Thief's target pick. Keeping the **count model** keeps all six cheap; going spatial taxes all six.

- **The throw is over-subscribed as both the kill-verb and the economy's victim.** It is the answer to the entire `hazards/6-*` group, the stealth lure (cone/sound), the traversal tool (weight-plate, throw-to-place), *and* the thing the economy taxes four ways (consume-on-kill, fragility, throwable-scoping, Eater). The Director's throw-economy verdict (how many taxes, dash-i-frames or not) is the highest-leverage single decision touching this set.

---

## Top 5 things for the Director

1. **Dash i-frames vs. pure-reposition (`m1`) is the identity call for the whole combat model** — i-frames make "dodge it" compete with the throw ("kill it") that the entire `hazards/6-*` group and the throw-economy are built around. Recommend ship pure-reposition default, A/B i-frames. *(Biggest contradiction.)*

2. **Build noise→aggro (`x2`) as a named substrate before sprint/sneak/sound-zone** — it unblocks `m2`, `m3`, and `hazards/4-sound-aggro-zone` as small additions instead of three parallel new systems.

3. **Resolve the count-vs-spatial inventory fork before committing to `i1`/`i2`** — count is cheap and is what hazards (`6-weight-plate`, `6-armored-shelled`) and economy (`r3`, `x1`) already read; spatial forces a cross-set ripple. The bench (`hub/h3`) may make spatial worth it, or make it unnecessary.

4. **Cap the throw-tax stacking** — `economy/m4` fragility + consume-on-kill + `x3` scoping + the Eater can collectively trigger the BotW "hoard, stop throwing" failure. Pick a coherent subset; the throw is the signature verb.

5. **Use the loadout bench (`hub/h3`) to settle `i2`'s pause-vs-real-time question, and decide stealth's scope (`m3`/`e3`/`x2`) as one call** — both are cluster-sizing decisions, not single-file ones; ship the light option and measure engagement before funding a full stealth pillar.
