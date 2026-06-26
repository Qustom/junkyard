# Economy / Quota / Extraction — Cross-Exploration Analysis
**Set:** economy-extraction/  ·  **Analyzed against:** hazards, procgen-bands, player-mechanics, hub-staging

The economy set is the **stakes layer**: it is the only set whose ideas exist to make every
*other* set matter once you surface. A dash, a charger, a maze, a thrown ingot — none of them
carry weight until there is a reason to keep the haul, a bar that punishes a thin run, and a
place to spend what you banked. This analysis traces how the 26 economy ideas bind to the
verbs (player-mechanics), the threats (hazards), the spaces (procgen-bands), and — most
densely — the physical body the economy needs to exist as a *place* (hub-staging). The master
README states the dependency chain outright: "the corridor's loot only matters because of
quota and the gear sink (`economy-extraction/s1`); and the gear sink only feels real when it's
a shop you walk up to (`hub-staging/h1`)" (`README.md`).

---

## Synergies (the stakes layer that gives every other idea meaning)

**1. The gear sink (`s1`) ⇄ the upgrade station / shop (`hub/h4`, `hub/h1`) — the missing
loop, given a body.** `s1` is explicitly "the missing half of the loop": today Money only
flows *in* and out to quota, never into power. `hub/h4` is "the s1 gear-upgrade tree given a
physical body" and `hub/h1` is its walk-up storefront. They are the same feature at two
layers: `s1` owns the `Upgrade` Resource + `owned_upgrades` meta + apply-at-`start_run` seam;
the hub rooms own the spatial confirmation ("the grid on the wall gains a row"). Neither is
complete without the other — `s1` without a hub is a menu; the hub rooms without `s1` are empty
props (`h4`: "s1 itself is still an exploration spec, not code").

**2. What the money sink actually buys — the player verbs.** Every `s1` upgrade axis maps 1:1
onto an already-explored player verb, which is what makes the sink legible: bigger bag
(`player/i6`, `x1` carry), faster speed (`player/m2`), **dash** (`player/m1`), extra
quick-throw slots (`player/x3`), trajectory preview (`player/t3`). `s1` is the *faucet that
turns those verbs on, paid for in Money* — the spend side those player docs all assume exists.
The consumable sink (`s2`) similarly buys the use/deploy verbs (`player/u1` flare, `player/u2`
decoy) and a new shield; `s2` is explicitly **hard-blocked** on `u1`/`u2` landing first ("a
consumable with no effect is dead weight").

**3. Extraction tools / beacon (`s3`) ⇄ deploy-place (`player/u2`).** The beacon reuses
`u2`'s player-spawn seam wholesale — deploy input → instance → `add_child` → `setup`,
placement ghost, wall rejection. `s3` and `player/u2` cite the *same* `hazard_entity.gd` /
`bomb_hazard.gd` machinery; the beacon is "the same node spawned by the player instead of the
spawn loop," just one whose payload is an `ExtractGate` instead of a bomb. The Money sink
(`s3`) and the verb (`u2`) are one build.

**4. Condition / fragility (`m4`) ⇄ the throw verb (`player/t1`, `t5`, `t6`).** `m4` adds the
"third stake" to the signature throw: beyond "did it hit / did I get it back," now "was it
worth degrading?" It couples directly to charged throw (`player/t1` — harder throw degrades
more) and to recall (`player/t6` — `t6` is where you *get the dinged item back* and feel the
loss). `t5` throw-to-place degrades little. `m4` is the economic *cost layer* on top of the
throw economy `t6` already frames ("throwing spends my loot").

**5. Map intel (`s4`) ⇄ seeded procgen ⇄ the intel table (`hub/c3`).** `s4`'s load-bearing
finding is that `BandGenerator.generate(seed, cfg, catalog)` is a pure seeded function, so
intel is "a pre-computed peek at output the generator can produce on demand" — truthful by
construction, zero new gen logic. `hub/c3` spatializes this as a ritual: the table *is* the act
of pinning the next seed. The whole mechanic depends on procgen's determinism contract
(`tests/test_bandgen_determinism.gd`) and on a new "seed pinned at the surface" step both docs
flag.

**6. Map intel (`s4`) ⇄ hazard forecast ⇄ the opposition spread (`hazards/`).** `s4`'s tier-2
product is "a manifest of *what* opposes you this run: pursuing-hazard density… exposure
pressure (the R1–R4 oppositions)." Intel is priced *against* the hazard set — the more
oppositions exist (`hazards/0-scalable-opposition-system.md` lets the band hand placement
context to the spawner), the more a forecast is worth buying. Intel's value scales with the
hazard catalogue's size.

**7. Extraction-as-objective (`e5`) ⇄ set-piece injection (`procgen/e4`) ⇄ intel (`s4`).**
`e5` "is *defined* in terms of e4 set-pieces and s4 intel — it has little independent surface."
A special deep exit is "just a set-piece whose payload is a second, better gate" (`procgen/e4`
machinery) whose location intel can sell (`s4`). Three docs describing one composed feature.

**8. Sell-location (`m3`) & extraction-tax (`e1`) ⇄ asymmetric exit geometry (`procgen/d4`).**
Both `m3` and `e1` are **inert with one gate** — they hard-depend on `procgen/d4`'s
`ExtractPlacer` shipping 2+ exits (`m3`: "hard-depends on d4 shipping 2+ exits per band; with
one gate, m3 is inert"). `d4` promotes exit placement to a seeded config axis (CO_LOCATED / MID
/ FAR); `m3` puts a goods→price table on each exit, `e1` puts a cap/tax on each. The geometry
(`d4`) is the substrate; the economic payload (`m3`/`e1`) is what makes *which* exit a
decision.

**9. The loaded return trip — `r3` full-bag-liability ⇄ `player/x1` carry-speed ⇄
`procgen/d4` ⇄ the Hunter (`hazards/5`).** `r3` is "the economic reading of x1": `player/x1`
supplies the physics (load→speed curve on the `_exposure_speed_mult` seam), `procgen/d4`'s
FAR-exit supplies the long loaded walk, and `hazards/5-the-hunter` supplies the threat that the
slowdown exposes ("the load curve must dip the player's top speed below a loaded pursuer's
chase speed," `player/x1`). `procgen/d4` names the same combo: "the loaded return trip is where
[the Hunter/alarm/tide] bite hardest." Four ideas across four sets that only become tense
*together*.

**10. Greed-escalation (`r2`) ⇄ the alarm-spawner (`hazards/5-alarm-spawner`) ⇄ the dive
clock.** `r2` is "the room-scale mirror of the macro push/cash-out." Its threat half *already
exists* in `hazards/5-alarm-spawner`'s per-room `dwell_t`; `r2` reuses that exact seam and adds
the missing reward half (a dwell→value ramp) so "the alarm's rising threat has something to
push against." The two are so close `r2` openly asks whether they should be one feature.

**11. Timed/arming extraction (`e2`) ⇄ the Hunter & pursuers (`hazards/5`, `L2`) ⇄ search
(`player/e1`).** `e2` turns the gate into "the run's final encounter" — a channel that pursuers
*interrupt*. It explicitly pairs with `hazards/5-the-hunter` ("hold the door while the Hunter
arrives") and reuses the `player/e1` search-container progress-ring UI ("the *exact same
shape* — press to start, hold/advance, cancel on release/leave/damage"). The beacon (`s3`)
arm-time *is* this same channel; `e2` unifies them on one state machine.

**12. Optional modifiers (`r1`) ⇄ the hazard knobs (`hazards/`) ⇄ the job board (`hub/c2`).**
`r1` is "the cheapest big win" because the engine *is already a modifier engine*
(`run_config.gd`'s `r1_chase_speed`, `r1_spawn_count`, `r4_*` vision…). `r1` exposes a curated
subset of those hazard knobs to the *player* with a reward multiplier; `hub/c2` (job board)
makes that selection a diegetic "pick your fight" instead of an RNG roll. `hub/c2` cites
`r1`, `q3`, and `m2` as the three things the board lets you choose.

**13. Demand-orders (`m2`) & quota-variety (`q3`) ⇄ band-keyed loot placement (`procgen`,
`junk_placer.gd`) ⇄ the job board (`hub/c2`).** Both `m2` (carrot) and `q3` (stick) key off the
same `JunkItem` axes (`tier`, `origin_band`) and both "push routing" toward the bands/rooms
`junk_placer.gd` places those goods in. `hub/c2` is where you *accept* an order/objective. The
routing pull is the synergy: an order keyed to a band "makes those rooms the rational target —
the order is *why* you push past the safe extract" (`m2`).

**14. The persistent stash (`p1`) ⇄ the vault room (`hub/h2`) ⇄ banking mode (`q2`).** `hub/h2`
is "the visible skin over that p1 data model" — `p1` owns the `vault_junk` meta field +
schema bump; `h2` owns the shelves that render it. Both become *load-bearing* only under `q2`
expire/deduct, where "banking goods, not money, is the only cross-cycle carry" (`p1`, `q2`,
`h2` all state this identically). Under `q2` rollover, the stash is just money piling up.

**15. Soft-meta (`p2`) ⇄ visible growth (`hub/g1`) ⇄ staggered vendors (`hub/h1`).** `hub/g1`
is "soft meta-progression (`p2`) given a body" — `p2`'s abstract `unlocks` array (the
wipe-protected meta field) drives which vendors physically appear (`hub/h1`: "present-or-hidden
is derived from `GameState.unlocks`"). The milestone that survives a wipe (`p2`) is the same
event that re-roofs the lean-to (`g1`). One `hub_state` derivation, read three ways
(`g1`/`v3`/`n2`).

**16. The recovery-run anchor (`hub/g2`) ⇄ seeded procgen ⇄ the within-run loss (`e3`/`e4`).**
`hub/g2` extends `e3`'s pockets-loss: instead of discarding the non-pockets remainder, snapshot
it into a `pending_cache` (band_id + `run_seed`) that a recovery run re-stages via the same
seed. It depends on procgen determinism (re-passing the seed regenerates the identical layout)
and is the corpse-run that gives `e3`'s soft loss a baited next run.

**17. Fluctuating prices (`m1`) ⇄ item familiarity (`p3`) ⇄ the sell screen.** `m1` makes value
dynamic between runs; `p3` is the legibility lever — "an unfamiliar type shows a *fuzzy*
multiplier and only reveals the exact number once you've sold a few." Familiarity converts the
floor read from "grab everything" into "I know this is the valuable one," and creates real
mis-sell risk when stacked with `m1` (you can't read a price spike on junk you can't appraise).

**18. Debt/loans (`s5`) ⇄ the gear sink (`s1`) ⇄ quota escalation (`q5`).** `s5` exists "to
**front-load the s1 gear-upgrade buys**" — borrow against future quota headroom to buy power
now. It compounds against `q5`'s rising bar ("leverage is cheap early, dangerous late"), making
the *when* of borrowing self-balancing. `s5` reuses the quota itself as the repayment vehicle
(a surcharge on `quota_target`), so it adds no new wipe path.

**19. Quota tiers (`q1`) ⇄ the gear sink (`s1`).** `q1`'s bonus-tier reward "feeds the s1
gear-upgrade sink: a bonus-hit drops a discount or a blueprint toward a gear track." The
stretch goal above the survival floor is most motivating when it pays into the durable sink
`s1` owns — converting dead surplus into progress.

**20. Partial extraction (`e4`) ⇄ deliberate-drop (`player/i3`) ⇄ loadout-vs-cargo
(`player/x3`).** `e4` ("ship some now, keep diving") maps onto `player/x3`'s cargo/loadout
split — "only **cargo** ships (loadout throwables stay)." `player/r3`/`x1`'s full-bag liability
names `e4` and `player/i3` as the two relief valves that "trade value for speed on demand." The
ship surface can reuse the `s3` beacon ("a placed beacon could offer 'ship now'").

**21. One-way commitment (`e3`-extraction) ⇄ verticality/asymmetry (`procgen/e3`, `d4`) ⇄ the
door verb (`player/e2`).** The commit-gate "reuses `SocketSealer._place_wall_cap()`" and "the
lever/door verb (player-mechanics e2) supplies a triggerable one-way door," and "dovetails with
procgen e3 verticality one-way flow and d4 asymmetric entry/exit, where the band already drains
forward." The seal is the limit case of `r2`-return-cost ("return cost → ∞").

**22. The calm hub (`hub/v1`) ⇄ the dive clock & exposure (the whole tension engine).**
`hub/v1`'s thesis is that the economy's *absence* is the reward: "no `DiveClock`, no
`ExposureMeter`" — the exhale that resets tolerance so the next dive's clock lands harder. It is
the negative space the entire economy/extraction tension is defined against, and the audio bed
(`audio_director.gd` `current_intensity = 0`) the band-depth escalation resolves toward.

---

## Contradictions & tensions

**A. The keystone contradiction — GDD "no total resets" vs the built K2 full wipe (`p4`).**
`p4` (the reset-severity dial, flagged "PIVOTAL IDENTITY DECISION") surfaces a live,
unreconciled contradiction in the *shipped* build: GDD §6 says "No total resets — the run
resets, the life persists" and §13 files permadeath as "explicitly not a design focus," yet K2
shipped `wipe_meta()` (full meta nuke) as the Director's *FINAL* disposition. `p4` recommends
`STANDARD` (persist meta, reset only the quota counter) as default with `HARSH` (the K2 wipe) as
opt-in — but flags that the Director must declare which document is canonical. **This is the
single biggest contradiction in the set, and it reframes nearly every sibling** (see Shared
dependencies). The master README and `hub/v3` both call it out independently.

**B. Fragility (`m4`) discourages the signature throw verb.** `m4` itself names this as "the
central tension": the GDD wants players *throwing freely*, but a per-throw condition cost pushes
the opposite (hoard the rare, never throw it) — the Breath-of-the-Wild durability trap `m4`
cites as the cautionary tale. It directly fights the throw set (`player/t1`–`t6`), whose whole
design assumes throwing is the cheap, default, signature action. `m4`'s mitigation (value-only,
never destroys; debit meaningful only for charged throws of high-tier items) is exactly the
knife-edge the Director must tune.

**C. Hub rent (`hub/v2`) undercuts the calm-hub relief (`hub/v1`).** `hub/v1`'s entire value is
the timer-free exhale; `hub/v2`'s recurring drain "turns the safe room into another clock, just
a slower one" (`v2`'s own load-bearing worry). Both docs flag this against each other. The
recommendation (ship `v1` always-on, A/B `v2` modestly) is the producer-level resolution, but
the underlying tension — *does the exhale have teeth?* — is a tone call the Director owns.

**D. Double/triple money-pressure stacking.** Several economy ideas each add a money squeeze,
and they risk *compounding* into a crush a soft-toned life-sim shouldn't have:
- the rising quota (`q5`) **+** hub rent (`hub/v2`) **+** debt service (`s5`) is "three money
  pressures stacked" (`hub/v2` explicitly: recommend rent and quota as *A/B alternatives, not
  co-shipped*).
- `q2`-expire **+** `s5`-debt "risks a death spiral where the cycle drain prevents ever paying
  principal" (`q2` and `s5` both flag joint-tuning-required).
- pure `q2`-expire stacked on K2's existing miss-wipe is "two punishments at once" (`q2`).

**E. Double *time/threat*-pressure stacking at the gate.** `e2`'s channel + the dive clock
draining *during* the channel + an ambush (the Hunter) is flagged as possibly "fun desperation
or unfair pile-on" (`e2`'s headline judgment). Layer `procgen/d4`'s loaded FAR-return + `r3`
full-bag slowness + the Hunter waking and it is the same pile-on at run scale — `procgen/d4`
names it a potential "death-spiral (can't fight through, can't outrun the clock)."

**F. Overlapping economic mechanics that may be redundant.**
- **`q3` quota-variety vs `m2` demand-orders** — both key off the same `JunkItem` axes; both
  push routing. `m2` differentiates them as stick (survival) vs carrot (optional), and both flag
  "forbid an order that duplicates the active quota's filter," but a player may not perceive two
  typed-loot systems as distinct.
- **`e1` extraction-tax vs `r2` return-cost vs `m3` sell-location** — three things that all
  modify value/cost at-or-near the gate. `e1` is "a value-tax *on top of* R2's clock/exposure
  toll for the same deep gate" — possible double-charging; `e1` flags "a gate either taxes value
  *or* sits behind R2's toll, never both." `m3` notes "m3 + e1 + m1 stacked is three price
  modifiers at one moment — is that depth or noise? May want to **pick one or two**."
- **`r2` greed-escalation vs the dive clock + depth curve** — `r2` openly asks "does it just
  duplicate the global dive clock / depth curve?" and whether it should merge with the
  alarm-spawner.
- **The Hunter (`hazards/5`) vs the dive clock** — flagged in the hazard doc itself: "does a
  wake-and-chase add panic the bar can't, or is it just the timeout with extra steps?"

**G. Map intel (`s4`) / familiarity (`p3`) vs the Knowledge track.** Both risk being made
redundant by the GDD's Knowledge meta ("Knowledge unlocks safe routes"). `s4`: "if Knowledge
already unlocks safe routes, is *paid* intel redundant once Knowledge is high — does the money
sink die in the late game?" `p3` asks whether familiarity is "a facet of Knowledge or a parallel
resource." Both recommend Knowledge be the *standing* capability and Money the *per-run* bleed —
but whether that muddies the four-track model is a Director call.

**H. Selection (`hub/c2`, `r1`, `s4`) vs RNG surprise.** Making run-variety a *menu* (`hub/c2`
job board) risks killing the "what will I get" thrill. `hub/c2` proposes the hybrid (choose the
modifier frame, leave the band layout seeded-random underneath) — a tension between the
economy's *agency* goal and procgen's *surprise* value.

**I. Soft-meta (`p2`) / grace (`q4`) / stash-safety (`p1`) all sand down the stakes K2 added.**
M1.4 went ITERATE *because* the loop was low-stakes; K2's wipe was the fix. `q4` flags it
directly: "grace risks sanding that back off." `p2`: "soft meta directly fights the M1.4 stakes
thesis." These three forgiving mechanics each pull *against* the harshness the Director
deliberately added — which is precisely why `p4` must set the overall harshness stance *first*,
so they aren't "stacked-soft by accident" (`q4`).

---

## Shared dependencies & build-order notes

**What the economy NEEDS from the other sets (it cannot ship in a vacuum):**

- **The player verbs to sell/spend on.** `s1`/`s2`/`s3` are sinks with nothing to buy until
  `player/m1` (dash), `player/m2` (speed), `player/x3` (loadout zones), `player/i6` (bag),
  `player/u1`/`u2` (consumables/deploy) exist. `s2` is *hard-blocked* on `u1`/`u2`; `s3` reuses
  `u2`'s spawn seam.
- **Multi-exit band geometry.** `m3` and `e1` are inert without `procgen/d4`'s `ExtractPlacer`
  (2+ exits). `e3`-commitment and `e5`-special-exit need `procgen/e4` set-pieces + `procgen/e3`
  one-way flow.
- **Seed-pinning + determinism.** `s4` intel, `hub/c3` table, and `hub/g2` recovery-run all
  need the next-run seed decided at the surface (today minted at dive-start,
  `main_game.gd:_next_seed()`), plus the procgen determinism contract held.
- **A recoverable-cache record.** `hub/g2` needs a new `pending_cache` meta field (and notes
  `lost_proxy.gd` is a *naming-collision red herring* — it's navigation telemetry, not lost
  loot).
- **The hazard catalogue.** `r1`/`s4` price difficulty against the hazards that exist; `e2`/`r2`
  need pursuers (the Hunter, alarm-spawner) to *be* the threat the channel/dwell answers.
- **HP pool (M2).** The shield consumable (`s2`) and several zone hazards that fragility (`m4`)
  couples to wait on the M2 HP pool flagged across sets.

**What the economy PROVIDES to the other sets — the reason any of it matters:**

- It is the **reason loot matters**: `s1` turns banked Money into power; the quota turns a thin
  run into a real loss. Without the economy, the charger/maze/dash are mechanics with no stakes
  (master README's chain).
- It gives extraction geometry *meaning*: `procgen/d4`'s exit-distance becomes "the core tension
  number" (`d4`) only once `r3`/`x1` make the loaded walk costly and `m3`/`e1` make *which* exit
  pay differently.
- It gives the hub a *purpose*: `hub-staging/` is almost entirely the economy made physical
  (h1/h2/h3/h4 = s1/p1/x3/s1; c2/c3 = q3+r1+m2 / s4; g1/v3 = p2/p4; g2 = corpse-run).

**The reset-severity dial (`p4`) as the keystone that reframes the whole set.** `p4` states it
plainly: stash safety (`p1`), soft meta (`p2`), familiarity (`p3`), grace (`q4`), debt-on-loss
(`s5`), gear persistence (`s1`) "are all *meaningless if a loss wipes everything anyway*." Under
`HARSH` they're moot; under `STANDARD` they're load-bearing. The dial also drives what the hub
*renders*: `hub/v3` ("the visible expression of whatever p4 picks"), `hub/g1` (growth vs
decay), and `hub/g2` (the cache is "moot under HARSH"). **Build-order consequence: `p4` must be
dispositioned before specifying `p1/p2/p3/q4/s5` or any hub growth/decay room** — every doc that
touches loss flags this dependency (`q4`, `p1`, `p2`, `hub/v3` §3 "build p4's decision first").

**Recommended build sequence implied by the dependency graph:**
1. `p4` disposition (identity call) — unblocks everything below.
2. `s1` gear sink + `hub/h1`/`h4` (the missing loop + its body) — the highest-value pairing.
3. `r1` optional modifiers + `hub/c2` job board — cheapest win, rides existing knobs.
4. `procgen/d4` multi-exit → then `m3`/`e1`/`e2` extraction-depth layer.
5. `player/u1`/`u2` verbs → then `s2`/`s3` consumable/beacon sinks.
6. M2-era: `q3`/`m2` typed quotas/orders (need real bands), `m4` fragility, `p1`/`h2` item
   vault, `s5` debt, `m1`/`p3` market+familiarity.

---

## Notable design information

**The economy is the "missing half" the whole 120-idea set orbits.** `s1` names it directly —
today's chain is "dive → salvage → extract → sell → Money → (meet quota) → dive again," and
"nothing converts [Money] into *power*." Almost every economy idea is a variation on *closing
that loop*: a sink (`s1`/`s2`/`s3`/`s4`/`s5`), a reason-to-over-earn (`q1`/`r1`/`r2`/`m2`), a
reason-to-keep (`p1`/`p2`/`p3`), or a sharpening of the extract bet (`e1`–`e5`/`m3`/`r3`). The
other four sets supply the *content* of the loop; this set supplies the *loop*.

**The hub (`hub-staging/`) is the economy's physical body.** The hub README is explicit: "Most
hub elements are the **physical front-end of an economy mechanic** already explored." The
mapping is near-total — h1/h4↔s1, h2↔p1, h3↔x3, c2↔q3+r1+m2, c3↔s4, g1↔p2, v3↔p4, g2↔corpse-run.
The hub adds almost no new *systems*; it adds *places*. This means the economy set and the hub
set should be dispositioned and built as **paired features**, not separately — building `s1`
without deciding `hub/h1` (or vice-versa) wastes the synergy.

**Two architecture docs exist; an economy/meta architecture doc does not.** The set has the
`hazards/0-scalable-opposition-system.md` and `procgen/0-scalable-band-generation-system.md`
architecture docs — each a data-`.tres` + composable-stages + all-off-parity + seed-determinism
spine. The economy set has **no equivalent `0-` architecture doc**, yet it introduces a
comparable amount of cross-cutting structure: a shared `Upgrade`/`QuotaObjective`/`BuyerOrder`/
`ExtractRule`/`ExitMarket` Resource family, a wave of **new meta fields** (`owned_upgrades`,
`unlocks`, `vault_junk`, `familiar_items`, `loan_outstanding`, `next_run_seed`, `pending_cache`)
each needing a `schema_version` bump + migration + QA fixture, and the `p4` dial that all loss
paths must route through. **Recommendation (Director call):** an economy/meta architecture doc
is likely warranted — at minimum to (a) batch the seven-plus schema additions into one
coordinated migration (every persistence doc independently flags "batch the schema bump"), and
(b) define the `p4` `reset_severity` enum as the single seam all three loss paths and all
forgiving siblings read, before the siblings are specced piecemeal. Without it, the schema bumps
and the harshness-stance risk being decided ad hoc across a dozen docs.

**The all-off RunConfig knob contract holds across the whole set** — every economy idea ships
behind a default-off knob whose all-off state reproduces the current baseline byte-identically,
with config-marked telemetry, consistent with the M1.x experiment discipline (master README's
fourth cross-cutting thread). This is the proven A/B vehicle that lets the Director gate each
economy idea against the baseline at a playtest re-gate rather than committing blind.

---

## Top 5 things for the Director

1. **Disposition `p4` (reset-severity) FIRST — it is the keystone.** The live K2-full-wipe vs
   GDD-"no total resets" contradiction is unresolved, and `p4` gates the meaning of `p1`, `p2`,
   `p3`, `q4`, `s5`, `s1`-persistence, and every hub growth/decay room (`hub/v3`, `g1`, `g2`).
   Recommendation: `STANDARD` default, `HARSH` opt-in — but the canonical-document call is yours.

2. **Build `s1` gear-sink and `hub/h1`/`h4` as one paired feature — it's the missing loop.**
   `s1` is "the missing half"; the hub rooms are its body. Highest-value synergy in the set;
   neither half is worth shipping without the other.

3. **Watch the money-pressure stack: quota (`q5`) + rent (`hub/v2`) + debt (`s5`) is a crush.**
   Multiple docs independently flag that co-shipping these (or `q2`-expire + `s5`) over-squeezes
   a soft-toned life-sim. Treat rent vs quota as A/B alternatives, not co-shipped, until
   co-tuned.

4. **Fragility (`m4`) vs the signature throw is a real conflict — tune it to bite only on
   "I flung my best loot."** Value-only (never destroys), meaningful only for charged throws of
   high-tier items; otherwise it teaches players to stop using the verb the game is built on.

5. **Consider an economy/meta architecture doc.** The set introduces ~7 new meta fields (batch
   the schema migration) and the `p4` `reset_severity` seam, but unlike hazards and procgen it
   has no `0-` architecture spine — the siblings risk being specced (and schema-bumped) ad hoc.
