# Reset Severity Dial
**Category:** Run-to-run persistence — PIVOTAL IDENTITY DECISION

## The mechanic

A single tunable that answers: **when you fail (quota miss / death / timeout), what dies — the run, or the life?**

- **Roguelike end of the dial:** a loss **wipes meta** — money, salvage, lore, gear, recipes, banked junk, the quota ladder. You start over at Run 1 / $50 with nothing. Skill is the only thing that persists. (This is literally what K2's `wipe_meta()` does today, `game_state.gd:410`.)
- **Roguelite end of the dial:** a loss **resets only the quota counter** — the *run* ends, but money/gear/stash/familiarity all persist. You retry the same quota with everything you built. The "life" never resets; only the dive does.

It is pivotal because it is the **one knob that sets the emotional shape of the whole game**, and it **reframes every other sibling in this set.** Stash safety (p1), soft meta (p2), familiarity (p3), grace (q4), debt-on-loss (s5), gear persistence (s1) are all *meaningless if a loss wipes everything anyway* — a roguelike wipe makes them moot, a roguelite reset makes them load-bearing. The dial is the parent that decides whether the siblings even matter. **It is the decision of this set.**

## What exists today

The run/meta boundary (`game_state.gd:32-83`) is a **hard binary**: meta persists (`money/salvage/lore/exposure/knowledge_level/unlocked_recipes/banked_junk` + the K2 quota ladder), run-state is disposable (`run_inventory`, `unbanked_value`, depth). A loss today does **two different things at two severities**:

1. **Death/timeout** (`fail_run`, `game_state.gd:459`) is **soft** — you keep a "pockets" subset (~20% of haul, highest-value first, `run_rules.tres`) and lose the rest; **all meta survives.** This matches the GDD: *"the run resets, the life persists"* (GDD §6, line 88).
2. **Quota miss** (`_evaluate_quota` → `wipe_meta`, `game_state.gd:410`) is **maximally harsh** — a full meta wipe, money to $0, ladder to Run 1. This was the **Director's FINAL disposition for K2** (`K2_quota_system.md:15`).

**This is an unreconciled contradiction in the live build.** The GDD §6 promises soft-roguelite ("No total resets"); GDD §13 explicitly files **permadeath as optional, "explicitly not a design focus"** (line 198). Yet K2 shipped a *full wipe* as the default quota-fail path. The two loss types sit at opposite ends of a spectrum **that has never been named as a spectrum.** The dial makes that boundary an explicit, single tunable — and forces the contradiction to a decision.

What's missing: a `reset_severity` knob (currently the behavior is hard-forked between `fail_run`'s pockets path and `wipe_meta`'s nuke), and any preset between "keep pockets, lose nothing else" and "lose everything."

## How to fit it in

Add **one ordered enum knob** to `RunConfig` — `reset_severity` — that all three loss paths (death/timeout/quota-miss) route through. It selects a **preset bundle** that sets the siblings coherently:

| Preset | money/gear/stash | quota ladder on miss | familiarity (p3) | debt-on-loss (s5) | emotional shape |
|---|---|---|---|---|---|
| **`HARSH` (roguelike)** | wiped (`wipe_meta`) | reset to Run 1 | wiped | n/a (nothing to owe) | NetHack/Tarkov-wipe. Every run is the whole game. Massive highs, brutal lows, low retention for casual players. Skill is the only accumulator. |
| **`STANDARD` (roguelite — RECOMMENDED)** | **persists** | **counter resets, you retry this quota** | persists | debt *increases* on miss (s5) | Hades/Rogue Legacy. A miss costs *momentum and money* (the debt grows, p2/s5), never your gear. "I'm behind, not dead." Honors GDD §6 + §10 "keep Act 1 forgiving." |
| **`FORGIVING`** | persists + stash-safe (p1) | counter resets, **grace charge consumed** (q4) | persists | small flat penalty | The "I just want to explore" cut. A streak/grace buffer (q4) absorbs the first miss outright. Maximum retention, minimum stakes. |

The **`STANDARD` recommendation** keeps the GDD's promise intact: a quota miss is a *debt event*, not a wipe — the s5 debt curve and p2 soft-meta become the stakes ("you owe more now"), the gear (s1) and stash (p1) you built stay, and the quota ladder simply doesn't advance until you clear it. The wipe (`HARSH`) becomes an **opt-in hardcore mode** exactly as GDD §13 already frames permadeath — not the default.

**Knob (the dial itself, a literal config):**

```gdscript
# data/run_config/run_config.gd — new @export_group, all loss paths read it
@export_enum("harsh_wipe", "standard_persist", "forgiving_grace") var reset_severity: int = 1
# 0 = K2 wipe_meta() (today's quota-fail behavior, now opt-in)
# 1 = persist meta, reset quota counter only (RECOMMENDED default — matches GDD §6)
# 2 = persist + consume a grace charge (q4) before any reset bites
```

`game_state._evaluate_quota` already branches on miss (`game_state.gd:387`); the dial swaps `wipe_meta()` for `reset_quota_counter()` (a new no-wipe op: leave money/gear, just don't advance the ladder, optionally fire s5 debt). The all-off default must still reproduce the M1.3 baseline — so the default-play preset, not the all-off control, carries `reset_severity` (mirrors K2's `quota_enabled` gating, `K2_quota_system.md:42`).

**Telemetry:** stamp `reset_severity` on the `run_started` row (additive `data`, the BUG6 precedent) and on `quota_evaluated`. The gate metrics that decide the identity: **loss frequency per preset, run-1-restart rate (HARSH only), and recovery behavior** — do players *come back and clear the bar next run* (STANDARD) vs *quit after a wipe* (HARSH)? Wipe-rate and session-continuation-after-loss are the two numbers that tell the Director which end retains.

## Research (cited)

The genre line is exactly this dial. **Roguelikes** (Rogue, NetHack, Spelunky) delete everything on death — *"the dungeon was gone, the save file deleted, you start over with nothing except what you learned"*; the reward for play is **insight, skill is the only accumulator**. **Roguelites** (Rogue Legacy 2013 → Hades) keep meta-progression — *"when you fail you almost always earn something that makes you feel stronger… in the next run."* Critically for retention: *"Hades brought millions of players to runs-based games who would have quit a pure roguelike inside the first week"* — the forgiving end **democratizes** the genre ([ScreenRant](https://screenrant.com/roguelike-roguelite-difference-permadeath-hades-rogue-slay-spire/), [PudgyCat](https://pudgycat.io/roguelike-vs-roguelite-difference-explained/), [TheGamer](https://www.thegamer.com/roguelike-roguelite-difference-hades-darkest-dungeon/)).

**Tarkov's wipe** is the harsh extraction-genre data point: a global meta reset every ~6 months. It's *loved by hardcore players* because *"every bolt, tool, med item, extraction matters"* — but the studio's 2026 move is telling: they made **wipe characters opt-in seasonal profiles separate from a permanent 1.0 main character** — i.e. they **split the dial**, letting hardcore players choose the wipe while the default progression persists ([SeasonDex](https://seasondex.com/tarkov), [DTGRE](https://www.dtgre.com/2026/05/escape-from-tarkov-seasonal-characters-2026-wipe-system-explained.html), [GamesRadar](https://www.gamesradar.com/games/fps/escape-from-tarkov-review/)). That convergence — *persist by default, wipe by opt-in* — is precisely the `STANDARD`-default / `HARSH`-opt-in recommendation, validated by the genre's most-watched harsh title walking back toward it.

The takeaway each end buys: **HARSH** = peak tension and meaning-per-action, narrow audience, high churn. **STANDARD/FORGIVING** = broad retention, sustained engagement, the cost being that no single action is existential.

## Open questions

1. **THE identity call — `STANDARD` or `HARSH` as default? (HUMAN DIRECTOR'S VISION CALL.)** This is not resolvable on technical merit; it is *what THE FAR YARD is*. The evidence points one way: the **GDD already decided** — §6 "the run resets, the life persists," §10 "keep Act 1 forgiving," §13 permadeath "explicitly not a design focus." The genre data agrees (forgiving = retention; even Tarkov split the wipe out as opt-in). **My recommendation: ship `STANDARD` (roguelite) as default, expose `HARSH` as an opt-in hardcore mode.** *But* — the live K2 build shipped a full wipe on the Director's *explicit FINAL disposition* (`K2_quota_system.md:15`), which **directly contradicts the GDD.** That contradiction is the real decision here: **does the Director stand by the K2 wipe (and the game is harsher than the GDD claims), or does the GDD win and K2's wipe is dialed back to a counter-reset?** Per the orchestrator's surface-judgment rule, I present this as the recommendation and the contradiction — **the Director resolves which document is canonical.**

2. **Does the dial apply uniformly to all three loss types, or per-cause?** Could be `STANDARD` for death/timeout (already is — pockets) but `HARSH` only for quota-miss (the K2 status quo). A per-cause matrix is more expressive but harder to read. Recommendation: one dial for all causes for legibility; revisit per-cause only if playtest wants "death is soft, debt-failure is final."

3. **If `STANDARD`: what *is* the stakes on a quota miss, if not a wipe?** A counter-reset alone is toothless. The sibling answer is **s5 (debt grows) + p2 (soft-meta cost)** — recommend the miss *raises the debt* so failure still bites without nuking gear. This makes p4 and s5 a package: the dial's "standard" preset is only stakeful if debt-on-loss is wired with it.

4. **Migration / save impact.** `reset_severity` is run-config (not meta) so no schema bump — but if the default flips from K2's wipe to persist, the `wipe_meta()` path stays in code (for `HARSH`) and just stops being the default. Confirm no save-fixture churn (there shouldn't be — the meta *fields* are unchanged; only *whether they're zeroed on miss* changes).

---

*Summary:* The reset-severity dial is the single roguelike↔roguelite identity knob — recommend `STANDARD` (persist meta, reset only the quota counter, debt grows on miss) as default with `HARSH` (the current K2 full-wipe) as opt-in hardcore, since the GDD and genre data both favor forgiving — but flag the live K2-wipe-vs-GDD contradiction as the Director's canonical-vision call.
