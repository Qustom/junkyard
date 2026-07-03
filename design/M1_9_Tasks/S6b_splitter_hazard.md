# S6b — New hazard #2: the SPLITTER — Expanded Design Spec

**Milestone:** M1.9 (Scalable Opposition + Band Systems) · **Wave:** 4 (parallel worktree)
**Task id:** S6b · **BlockedBy:** S2 (components + `param_schema`), S3 (EncounterBuilder + generic levers)
**Assignees:** game-director-designer (this spec + defaults + telemetry) · general-purpose (death-spawn hook + defs) · character-animator (parent/child greybox + split burst)
**Author:** game-director-designer · **Status:** Phase-2 design (open questions unresolved — Phase-3 resolves, Director ratifies fun/tone calls)

> **What this doc is.** The per-task design for S6b, authored to the four-phase process (CLAUDE.md
> "Version breakdown authoring"). It expands the M1.9 breakdown's one-line S6b contract into (a)
> research + the determinism argument, (b) a design spec + pseudocode against the **real as-built
> APIs and the S0/S2/S3 contracts M1.9 establishes**, and (c) an explicit `Open Questions` section.
> It ships **no game code and no `.tres` yet** — the programmer + character-animator build against it in
> Wave 4. Style/rigor mirror `design/M1_1_Tasks/R1_pursuing_hazard.md`. Unlike R1's doc (written
> post-ratification), S6b's Director calls are **still open** here; §9 states them for Phase-3
> resolution.

---

## 0. Hard constraints (read first)

Straight from the M1.9 breakdown scope guardrails and the v2 opposition contract. The spec must not
violate these, and neither may the implementation built from it:

- **Content = data, not engineering (the Phase-E proof).** S6b exists to *prove the architecture*, not
  to add bespoke systems. It ships as **two `OppositionDef.tres` + one small reusable death-spawn hook**
  that lives inside S2's `ThrowInteraction`/`Lethality` component seam. If S6b needs a large new bespoke
  script, the architecture (or this design) is wrong — surface it, don't paper over it.
- **The all-off baseline is untouched.** With `oppositions_enabled` empty (the shipped `RunConfig`
  default), no `splitter`/`splitter_child` def is loaded, no node instantiates, no telemetry row appears.
  The all-off fingerprint **`e943ac9c8bc1` stays byte-identical** — S6b adds only data + a component that
  is never constructed when the def is off. This is the permanent control.
- **Generation-time `fingerprint()` is provably unaffected by splits.** The parent is placed at
  generation time by the builder (RNG-free stable walk); **children are mid-run run-state spawned only
  through `svc.spawn`**, which touches no layout RNG stream and never writes back to the generator. No
  number of splits can move the band/placement fingerprint. §1.4 restates the v2 contract precisely — it
  is the whole reason the Splitter is the second proof.
- **No HP pool.** M1 has no player-health system, so the Splitter is **not** an attritional damage enemy.
  It is a **binary lethal Actor** exactly like R1: catch → `*_kills`-gated `fail_run(&"death")`, emit-always.
  "Splitting" is about *entity count*, never a health bar. (The GDD's Field hazards that need HP stay M2.)
- **Children obey the service caps — no runaway swarm.** Every child is created via `svc.spawn`, which
  refuses (returns `null`) at `per_band_cap` / the global ceiling. The Splitter's own greybox history
  (v1 §"Open questions": "Must cap. …get them wrong and the greybox swarms to a framerate problem")
  makes this a **safety requirement with a test** — `test_splitter` proves refusal at the ceiling.
- **Reuse, don't reinvent.** Movement = S2's Movement component (the R1 toward-player steer). Catch =
  R1's distance-test + BUG6 rising-edge latch. Throw-death = S2's `ThrowInteraction` seam. Lethality =
  S2's `Lethality` (`*_kills`-gated). The *only* genuinely new logic is the death-spawn call
  `svc.spawn(child_def, cell, ctx)` — that is the point of the task.
- **Placeholder art only.** Greybox parent + child + a split "burst" tell, inline (no PixelLab — that is
  Director-gated in M1.9). Filter OFF.
- **Ships OFF by default; enabled only in `band_two`'s deck.** Per breakdown OQ5 the new hazards are
  **band-2-exclusive** until the gate says they are fun (clean A/B at SG2). Not in band 1's preset.

---

## 1. Research — why the Splitter is the second proof

### 1.1 The architectural gap it fills (and Charger doesn't)

S6a (**Charger**) proves the *canonical* Phase-E path: **def + one new movement component**, placed by
the default builder at generation time — client **(a)** in the v2 client table
(`0-scalable-opposition-system.md` §"realistic future clients", row (a)). Every spawn the Charger makes
is seed-deterministic, RNG-free, and reproducible from `seed + config`. It exercises the builder→service
happy path but **never calls `svc.spawn` mid-run**.

The Splitter is chosen precisely to exercise **the other half of the API** — client **(b)** in that table
(the fit-table row: *"death-spawn is client (b) — on throw-death the entity calls
`svc.spawn(child_def, self_cell, ctx)`; the per-band cap is free from the registry"*). It is the first
and cleanest **multi-client** proof:

| Property S6b proves | Charger (client a) | Splitter (client b) |
|---|---|---|
| `svc.spawn` called **mid-run**, reactive to player action | no | **yes** — on throw-death |
| Spawns are **run-state**, not seeded | no (gen-time) | **yes** (reaction to a player-caused death) |
| Registry **cap refusal** on a live client at the ceiling | not stressed | **yes** — the swarm hits `per_band_cap` |
| `fingerprint()` must stay unmoved **despite** new live nodes | trivially (gen-time) | **non-trivially** — the whole determinism argument (§1.4) |
| A **second def** referenced by a first def (`splitter` → `splitter_child`) | no | **yes** — cross-def reference the linter must resolve |
| Central `&"spawned"` emission fires for a **non-builder** caller | no | **yes** — the service logs the child identically |

If the Splitter ships as *two defs + a death-spawn hook* and its children spawn through the exact same
`svc.spawn` boundary the builder uses — capped by the same registry, logged by the same central
`&"spawned"` — with the generation-time fingerprint byte-identical throughout, then the two-layer
split (SpawnService mechanism / EncounterBuilder policy) is proven end-to-end for *both* determinism
classes. That is S6b's job. It is a deliberately small feature carrying a large architectural claim.

### 1.2 Prior art — splitting enemies, fun vs. annoying

Splitting/dividing enemies are a genre staple; the design literature is clear on the knife-edge between
"tense" and "tedious":

- **Asteroids (1979)** — the archetype: shoot a big rock → two mediums → four smalls. Fun because each
  generation is *faster and smaller* (rising pressure) but the tree is **shallow and finite** (3 tiers,
  hard terminal), so clearing is always *achievable*. The annoyance mode is an infinite/near-infinite
  split tree that outruns the player's clear rate.
- **Slimes / Metroid's kraid-mimics / RoR's *Jellyfish* / *Blind Pests*** — "kill splits it" teaches
  **target discipline**: kill in the open, not in a corner; sometimes *don't* kill. Fun when the split
  is a **legible consequence of the player's own action** (I chose to hit it) and **annoying** when it's
  a surprise the player couldn't have predicted or when fragments are individually still lethal *and*
  numerous enough to be unavoidable.
- **The Binding of Isaac — *Gurdy Jr. / Larry Jr. / Ragling*** — segmented/splitting foes work when the
  fragments are **weaker in aggregate threat**, not just more numerous — otherwise splitting is a pure
  punishment with no counterplay. Isaac's split foes are individually trivial; the *count* is the
  texture, not the lethality.
- **Nuclear Throne — *Big Dogs / Rhino Freaks* "everything is an object"** — the engine idiom we already
  share (v2 prior art): a death simply spawns more objects; no special "splitter system," just a death
  hook that instantiates. That is exactly the `svc.spawn`-on-death shape S6b builds.

**The distilled fun/annoyance rules S6b honors:**

1. **Finite, shallow tree.** `generations` defaults to **1** (parent → children → *terminal*). One split,
   then a real kill. This is the Asteroids "3 tiers" lesson compressed for a greybox. Deep trees are a
   Director-tunable variant, capped hard.
2. **Rising but *bounded* pressure.** Children are **faster** (`child_speed_mult > 1`) but **fewer-lethal
   in aggregate is impossible without HP** — so the tension knob is *count under a cap*, and the cap is
   the pressure ceiling. A player can always out-route (the intended answer).
3. **The consequence is the player's own choice.** The Splitter's whole point (v1 §"The idea") is that
   **throwing to kill is the *wrong* default** — it spends a sale item *and* multiplies the threat. The
   split must be a legible, regret-inducing result of *the player deciding to throw*, never a random or
   ambient event. That is why the default `split_on` is **`throw_death` only** — an environmental/clean
   death (none exist in M1 yet, but the door stays open) does *not* split.
4. **Counterplay exists.** The answer is **don't kill it — route around it** (avoidance is always viable,
   GDD Pillar; "an engineer, not a soldier"). The Splitter is the roster's deliberate counter-lesson to
   "killing is the answer," which every other hazard + the throw verb trains.

### 1.3 Fiction pitches (2–3 — tone call, Director picks)

Band 2 is **Temporal** in the GDD ("A junkyard from another *time* … stranger entities"), and the GDD's
instability text already says *"the longer you linger… entities multiply"* (GDD §Instability pressure) —
a Splitter is that line made mechanical. Three framings:

- **(A) "Fault" / "Rupture" (recommended — leans into the instability fiction).** Not a creature but a
  *tear in the pile* — a slow-drifting knot of unstable scrap that, when you strike it hard (throw), does
  not break so much as **fission**: the instability that held it as one thing splits it into two. Ties the
  hazard directly to the GDD's "entities multiply as it destabilizes" line; reads as *the band itself*
  reacting to violence. Cyrus VO hook: *"Don't hit the shivery ones. You'll just make more shivery ones."*
- **(B) "Brood" / "Scrapling nest".** A soft, sluggish salvage-organism; hitting it makes it **shed
  smaller young** that scatter and chase. More "creature," warmer, a little cuter — fits a lighter tonal
  read of Band 2. Risk: "cute bug swarm" is a well-worn trope and slightly off the melancholy-industrial
  tone.
- **(C) "Echo" / "Recurrence" (most on-theme for *Temporal*).** A time-band artifact: killing it doesn't
  end it, it **recurs** — two *earlier/later copies* of the same object peel off, each slightly out of
  step (faster = "sped-up echo"). Strongest thematic fit for a *Temporal* band; the split reads as "you
  can't kill a thing that exists across time." Slightly more abstract to read at greybox fidelity.

**Recommendation: (A) Fault/Rupture** for the tightest coupling to the existing instability fiction and
the clearest "violence backfires" read; (C) is the elegant Temporal-specific alternate if the Director
wants the band's identity front-loaded. Either way the *stable `id` stays `&"splitter"`* (fiction names
are display-only; `id`/telemetry/save never change with flavor).

### 1.4 Determinism analysis — why mid-run spawns are legitimately run-state (v2 contract, restated precisely)

This is the load-bearing argument and the reason the Splitter is the second proof. Restating the v2
contract (`0-scalable-opposition-system.md` §"realistic future clients" + §"key safety property"),
scoped to the Splitter:

**Two determinism classes, one API:**

- **Parent placement — client (a), seed-deterministic.** The `splitter` parent is placed at **generation
  time** by `EncounterBuilder.populate(band, deck, I, svc)` walking pieces in the stable RNG-free order
  (`_pieces_depth_sorted`, today `main_game.gd:734`) and striding cells
  (`main_game.gd:473`). It **never calls the global `RNG`**; any per-instance variation derives from
  `depth_index`/spawn-index (`phase_salt = depth_index * 131 + k`, `main_game.gd:505`). It feeds nothing
  to `fingerprint()` — placement is pure run-state on the already-graded band — **but is reproducible
  from `seed + config`**. This is identical to how every current hazard is placed (the R1/K5i contract).

- **Children — client (b), legitimately run-state.** A child is spawned **mid-run, in reaction to a
  player-caused throw-death**. It is *by definition* not part of the seeded layout: whether/when/how many
  children exist depends on whether the player chose to throw an item at the parent and when — a live,
  non-reproducible input. The v2 contract permits this **provided two invariants hold**:
  1. **The child routes only through `svc.spawn`.** `SpawnService` **has no access to the
     band-generation RNG stream** (it only reads the already-graded `Band`), so a child spawn *cannot*
     touch the layout stream by construction. It reads floor cells + validates placement + registers +
     `setup()` — nothing that feeds `fingerprint()`.
  2. **The child never writes back to the generator.** It is parented under the band container and freed
     by run-end teardown; it mutates no meta-state, no seed, no `Band`.

**Therefore:** `fingerprint()` is computed over the **generation-time** band + placement, which completes
*before any throw can occur*. Splits happen strictly *after* generation, in run-state, through a service
that cannot reach the generation RNG. **No number of splits — 0, 2, or a capped swarm — can move the
fingerprint for a given `seed + config`.** The all-off control (`e943ac9c8bc1`) is doubly safe: with the
def off, no parent exists, so no split can happen at all.

**The one subtlety S6b must decide (child cell derivation).** A child needs a *cell* to spawn at. The
child is client (b), so it *may* legitimately use run-state randomness (it's unseeded anyway). **But the
recommendation is to derive child cells deterministically-per-split from the parent's position** (a fixed
offset table, §2.4), **not** from the global `RNG`, for three reasons: (i) it keeps the RNG-free
discipline total — *no* global `RNG` call anywhere near placement, honoring the breakdown's
"no global `RNG` in generation-time placement; per-client RNG discipline" contract by the strictest
reading; (ii) it makes `test_splitter` deterministic (same throw at the same parent → same child cells →
assertable); (iii) it costs nothing in feel. Using `RNG` would be *contract-legal* (client (b) is
unseeded) but gratuitously non-reproducible; deterministic-from-parent is strictly better. This is the
technical open question Q7 (§9) — recommendation: **deterministic-per-split from parent cell, no `RNG`.**

### 1.5 As-built anchors S6b builds on (cite these — not v1 paths)

- **The throw-kill path (how junk kills hazards today).** `ThrownItem` (`Area2D`, mask
  `world|hazard`) detects a `hazard`-group body in `_on_body_entered`
  (`entities/thrown_item/thrown_item.gd:76-83`) and calls `_hit_hazard`
  (`thrown_item.gd:88-95`), which **emits `EventBus.throw_killed_hazard`
  (`thrown_item.gd:92`)** then **unconditionally `body.queue_free()` (`thrown_item.gd:93`)** — R1/pingpong
  "have no health → free outright." **This is the exact seam the Splitter must intercept:** today the body
  gets *no chance to react to its own death*. S2's `ThrowInteraction` extraction must route this through a
  death-response hook so the Splitter can split *before* the parent is freed (the cross-task contract in
  §3.1; verify at brief time, exactly as R1 verified TEL's signal signatures).
- **The dedicated throw-death channel.** `signal throw_killed_hazard(item_id, kind, depth, run_t_ms)`
  (`event_bus.gd:175`) is **deliberately separate** from `new_hazard_killed`
  (`event_bus.gd:149`) — the L1 signal-separation precedent (`event_bus.gd:171-175`): the two carry
  *opposite* kill directions (junk-kills-hazard vs. hazard-kills-player), so fusing them "would poison
  RG2's death counts." **S6b honors this precedent for its new events** (§5): `&"split"` is a
  hazard-lifecycle event, kept off both death channels; a child *killing the player* rides
  `opposition_killed_player` (the dedicated player-death channel), never the split vocab.
- **One existing hazard end-to-end (API grounding).** `BombHazard` (`scenes/hazards/bomb_hazard.gd`) is
  the closest template: it **snapshots `RunConfig` at `setup(cfg, player, spawn_ctx)`**
  (`bomb_hazard.gd:61-69`), reads `GameState.current_depth_index` live for telemetry, **emits pre-declared
  EventBus signals and never edits `event_bus.gd`**, routes a fatal outcome through the **existing
  `GameState.fail_run(&"death")` with no local "already ended" guard** (`bomb_hazard.gd:117-125`;
  `GameState._run_ended` owns idempotency across hazards + extract), and **self-times `run_t_ms` from
  spawn** when BUG1's clock isn't exposed read-only (`bomb_hazard.gd:128-131`). The Splitter follows every
  one of these disciplines.
- **The setup handshake + BUG6 latch + L5 gate (R1/HazardEntity).** `HazardEntity.setup` snapshots
  config + resets the un-latched state (`hazard_entity.gd:119-130`); the **BUG6 rising-edge catch latch**
  emits the catch exactly once on entry to catch-range and re-arms only on exit
  (`hazard_entity.gd:230-240`); lethality is `*_kills`-gated (L5). The Splitter parent **and** child reuse
  this catch machinery verbatim via S2's `Lethality`/catch component.
- **The spawn-ctx channel.** `_new_hazard_spawn_ctx` (`main_game.gd:496-507`) is the existing
  per-instance primitive parameter Dictionary (`initial_dir`, `room_bounds`, `phase_salt`). The
  Splitter's death-spawn hook builds the **child** `ctx` the same way (§3.2) — the per-instance override
  tier v2 names for exactly this.

---

## 2. Design spec — the two defs and the behaviour

The Splitter is **two `OppositionDef.tres`** sharing one host scene (`splitter.tscn`, an Actor =
`CharacterBody2D`) driven by S2's components. The parent `splitter.tres` is the deck-placed generation-time
opposition; `splitter_child.tres` is *never in a deck* — it exists only to be spawned by the parent's
death hook. Both are throw-killable, both are lethal-on-catch (`*_kills`-gated), both read the same script.

### 2.1 `splitter.tres` — the parent (full params + `param_schema`)

Top-level `OppositionDef` fields (the v2 schema, `0-scalable-opposition-system.md` §"Data layer"):

| Field | Value | Note |
|---|---|---|
| `id` | `&"splitter"` | stable — events/telemetry/save; fiction name is `display_name` only |
| `display_name` | `"Fault"` (per §1.3 pick) | display-only |
| `archetype` | `"actor"` | `CharacterBody2D` |
| `host_scene` | `splitter.tscn` | shared with the child |
| `credit_cost` | `3` | expensive — one Splitter is a whole encounter (builder-read; balance = M3) |
| `spawn_weight` | `1.0` | deck draw weight (builder-read) |
| `min_band` | `2` | band-2-exclusive gate (builder-read) — never eligible in band 1 |
| `per_room_cap` | `2` | at most 2 splitters+children per room |
| `per_band_cap` | `8` | **the swarm ceiling** — the v1 "hard cap 8" made a service invariant |
| `lethality` | `"lethal"` | catch = death path |
| `kills` | `true` | the L5 `*_kills` gate (per-def) |

`params` + `param_schema` (the component knob bag + its self-describing schema; the linter asserts the
`params ↔ param_schema` bijection — S2/S4 net):

| `params` key | Type | Default | Min | Max | Gloss (CSV key) | Behaviour it drives |
|---|---|---|---|---|---|---|
| `move_speed` | float | `55.0` | `0.0` | `200.0` | `CFG_GLOSS_SPLITTER_SPEED` | Slow pursuer speed toward the player (px/s). ~0.4× player — the "soft, slow" parent. `0` = a stationary tell. |
| `catch_radius` | float | `24.0` | `0.0` | `64.0` | `CFG_GLOSS_SPLITTER_CATCH` | Lethal catch distance (R1 semantics + BUG6 latch). `0` = effectively can't catch (a pure obstacle). |
| `child_count` | int | `2` | `0` | `4` | `CFG_GLOSS_SPLITTER_CHILDREN` | How many `splitter_child` to request on split. `2` = Asteroids-classic. `0` = "splits into nothing" (a clean-kill sweep control). |
| `child_speed_mult` | float | `1.6` | `0.5` | `3.0` | `CFG_GLOSS_SPLITTER_CHILDSPEED` | Child `move_speed` = parent `move_speed` × this (passed via child `ctx`). `>1` = rising pressure. |
| `generations` | int | `1` | `0` | `3` | `CFG_GLOSS_SPLITTER_GENERATIONS` | Remaining split depth. `1` = parent splits once → children are terminal (**recommended**). `0` = never splits (a clean-kill control). Each child gets `generations-1` via `ctx`. |
| `split_on` | enum(`throw_death`,`any_death`) | `throw_death` | — | — | `CFG_GLOSS_SPLITTER_SPLITON` | **`throw_death`** = only a thrown-item kill splits (the on-theme default — punishes the throw verb). `any_death` = any removal splits (future environmental deaths too). |
| `child_spread` | float | `28.0` | `0.0` | `96.0` | `CFG_GLOSS_SPLITTER_SPREAD` | Radius (px) of the deterministic offset ring children are placed on around the parent (§2.4). `0` = all at parent cell (overlap; see Q6). |
| `child_despawn_s` | float | `0.0` | `0.0` | `60.0` | `CFG_GLOSS_SPLITTER_DESPAWN` | If `>0`, a child `svc.despawn`s itself this many seconds after spawn (mercy timer). `0` = children live until the band ends or are killed (**recommended default; Q4 is a Director call**). |

> `move_speed`/`catch_radius`/`child_despawn_s` are the child's *own* concern too — see §2.2. The parent
> reads them for itself; the child reads them from its **own def** unless the parent overrides via `ctx`.

### 2.2 `splitter_child.tres` — the child

Same top-level shape, differing where it matters. **It is never placed in a deck** (`spawn_weight` is
irrelevant; `min_band` unused) — it only ever arrives via the parent's `svc.spawn`.

| Field | Value | Note |
|---|---|---|
| `id` | `&"splitter_child"` | distinct id → distinct telemetry/spawn rows |
| `display_name` | `"Fault-shard"` | display-only |
| `host_scene` | `splitter.tscn` | **same scene/script** — a child is a parametrized splitter |
| `credit_cost` | `0` | children are free (they're not builder-drawn; keeps deck math clean) |
| `min_band` | `2` | inherits the gate for hygiene; never deck-drawn regardless |
| `per_room_cap` / `per_band_cap` | `2` / `8` | **the same registry ceiling** — children + parents share the count (see §2.5) |
| `kills` | `true` | children are `*_kills`-gated too — a child catch → `fail_run(&"death")` (§2.6) |

`params` mirror the parent's schema **exactly** (the bijection is per-def, so the child needs its own
full `param_schema`) but with child-appropriate defaults:

| key | Default (child) | Rationale |
|---|---|---|
| `move_speed` | `88.0` | ≈ parent × 1.6 baked as the def default; the parent overrides via `ctx` at spawn so `child_speed_mult` is the live lever |
| `catch_radius` | `20.0` | slightly smaller (smaller body) |
| `child_count` | `2` | only used if `generations > 0` at the child |
| `child_speed_mult` | `1.6` | for recursive splits (`generations > 1`) |
| `generations` | `0` | **terminal by default** — a child does not re-split unless the parent passed `generations-1 > 0` via `ctx` |
| `split_on` | `throw_death` | same on-theme rule |
| `child_spread` | `24.0` | tighter ring |
| `child_despawn_s` | `0.0` | Director-tunable (Q4) |

**Why two defs, not one with a `tier` int?** v2's data layer is "one def = one stable `id` = one
telemetry/save identity." Distinct `id`s (`splitter` vs `splitter_child`) let SG2 count *"how often did a
split occur"* (children spawned) separately from *"how often did the player meet a fresh Splitter,"* and
let the deck reference only the parent. A `tier` field on one def would fold both identities into one row
and muddy the cap accounting. Two defs is the v2-idiomatic choice and exercises the **cross-def reference**
(`splitter.params`→`splitter_child` by id) the linter must resolve (Q8).

### 2.3 Movement — proposal (reuse S2's Movement component)

**Recommendation: a *slow direct pursuer*** — S2's Movement component in its "toward-player steer" mode
(the R1 `_physics_process` steer, `hazard_entity.gd:216-223`: `dir = (player - self).normalized()`,
`velocity = dir * move_speed`, `move_and_slide()` so walls stop it), at a **low `move_speed`** (~0.4×
player). Children reuse the same component at the higher `child_speed_mult × parent_speed`.

Why a slow pursuer over the alternatives:

- **Slow pursuer (recommended).** Creates the intended tension — it *follows* you, so "just leave it
  alone" costs positioning, and the temptation to throw-kill (which backfires) is real. Reuses R1's
  component with zero new code; children being *faster* is the legible "it got worse" read.
- **Drifter/wanderer (alternate).** A parent that ignores the player is a pure obstacle; the throw
  temptation weakens ("why kill a thing that isn't chasing me?"), softening the core lesson. Cheaper to
  read but less on-theme. Would need a small wander mode in the Movement component (marginally more work).
- **Charger-style dasher (rejected).** Overlaps S6a and makes the parent too threatening to *want* to
  leave alone — wrong for the "don't kill it, route around it" lesson.

Flag as **Q1 (Director tone/fun)** — the movement *feel* is a playtest call; the spec commits to slow
pursuer as the buildable default. No pathfinding, no navmesh, no behaviour tree (throwaway greybox, R1
rule). Wall-stuck-behind-geometry is a *feature* (refuge), not a bug.

### 2.4 The split — child placement (deterministic-per-split, no `RNG`)

On a qualifying death (§2.5), the parent requests `child_count` children from the service, placed on a
**deterministic offset ring** around the parent's *current* cell:

- **`self_cell`** = the parent's current cell. The parent barely moves (slow), but to be correct after any
  drift the recommendation is a **service helper `svc.world_to_cell(global_position) -> Vector2i`**
  (pure band-grid math already living in `main_game`'s cell↔world projection). Fallback if S0 doesn't
  expose it: the parent snapshots its origin cell from `setup` `ctx["cell"]` (the builder stamps it) and
  uses that — acceptable given the slow mover, documented in the worklog. (Contract note for S0/S3 — Q8.)
- **Child cells** = for `k in child_count`, the cell nearest to `self_cell + ring_offset(k)`, where
  `ring_offset(k)` is a **fixed table** (e.g. `k`-th of N points on a circle of radius `child_spread`,
  in graded-floor cells), snapped to the nearest **free graded floor cell** the service will accept.
  **No `RNG`** — `ring_offset` is a pure function of `k` and `child_count`. Same throw → same cells →
  `test_splitter` is deterministic (§1.4, Q7).
- **Cap refusal is graceful.** Each `svc.spawn` may return `null` (registry at `per_band_cap`/global
  ceiling, or no free/valid cell). The hook **must handle `null`** — it does *not* retry elsewhere, does
  *not* error; it simply gets fewer/no children. See §2.5 for the visible behaviour.

### 2.5 The death-spawn hook — semantics + cap-refusal behaviour

**Trigger.** The parent splits when it dies *and* the death qualifies under `split_on`:

- `split_on == throw_death` (default): **only** a `ThrownItem` kill splits. This is the throw-verb
  punishment. Reached through S2's `ThrowInteraction` seam (§3.1).
- `split_on == any_death`: any removal splits (future-proofing for environmental deaths; none exist in M1,
  so functionally identical today — a sweep/forward-compat knob).

**Terminal condition.** If `generations <= 0`, the death is **clean** — no children, the parent just frees
(and still emits `throw_killed_hazard` + the migration `&"killed_by_throw"` — a kill is a kill). This is
the "real kill" at the bottom of the shallow tree (§1.2 rule 1).

**On a qualifying split:**
1. Resolve `svc` via the `&"spawn_service"` group (per-dive node, breakdown OQ3).
2. Compute `self_cell` and the `child_count` deterministic child cells (§2.4).
3. For each child cell, `svc.spawn(child_def, cell, child_ctx)` with
   `child_ctx = {"move_speed": my_speed * child_speed_mult, "generations": my_generations - 1,
   "split_index": k, "cell": cell}` — the per-instance override tier (v2). The child reads these `ctx`
   overrides in `setup`, preferring them over its def defaults.
4. **Emit `opposition_event(&"splitter", &"split", depth, run_t_ms)` once** (§5) — the split happened.
5. Free the parent (`svc.despawn(self)` if the parent is service-registered, else `queue_free()`; a
   service-spawned parent is registered so `svc.despawn` keeps the registry count honest).

**Cap-refusal — what the player sees.** When the registry is at `per_band_cap`/global ceiling, `svc.spawn`
returns `null` and **that child simply does not appear**. Visually: the parent still bursts and dies, but
**fewer (or zero) shards emerge** — the swarm self-limits. This is *correct and desirable*: it is the
safety ceiling doing its job, and it reads in-fiction as "the space can only hold so much instability at
once." **Recommended telemetry:** on a refused child, emit
`opposition_event(&"splitter", &"split_refused", depth, run_t_ms)` so SG2 can measure how often the cap
actually binds (cap pressure = the balance signal for M3). This is the honest, testable refusal behaviour
the DoD demands (`test_splitter` fills the band to `per_band_cap`, throws to kill a parent, and asserts
**no child over the ceiling** + a `split_refused` row).

### 2.6 Kill semantics — children are `*_kills`-gated too

A child catching the player is **identical to R1**: the shared catch component runs the BUG6 rising-edge
distance test (`hazard_entity.gd:230-240`); on the rising edge it emits the player-death event and, **only
if the child def's `kills == true`**, calls `GameState.fail_run(&"death")` (L5 gate). Default `kills = true`
for both defs. `GameState._run_ended` owns idempotency, so a parent + child (or two children) catching the
same frame is absorbed — first-to-catch ends the run, exactly as R1 multi-spawn (R1 §9 Q3). A child never
adds a new end-path. Fatal catch → `opposition_killed_player(&"splitter_child", depth, run_t_ms)` (the
dedicated player-death channel, kept off the split vocab per the L1 precedent).

---

## 3. The seam — how throw-death reaches the Splitter (cross-task contract with S2)

### 3.1 The contract S6b needs from S2's `ThrowInteraction`

Today `ThrownItem._hit_hazard` **unconditionally `body.queue_free()`s** (`thrown_item.gd:93`) — the body
gets no death hook. S2 (which owns the `ThrowInteraction` component extraction, Wave 2, a hard `blockedBy`
for S6b) must make throw-death **delegable**. The minimal contract S6b requires:

> When `ThrownItem` hits a `hazard`-group body, instead of unconditionally freeing it, it consults the
> body's `ThrowInteraction` component (if present) via a single method — e.g.
> `ThrowInteraction.resolve_throw_death(killer_ctx) -> bool`. **Returns `true`** = "I handled my own death
> (spawned children and freed myself); `ThrownItem` must NOT free me again." **Returns `false` / no
> component** = today's behaviour: `ThrownItem` frees the body (R1/pingpong unchanged).

This keeps `thrown_item.gd`'s change **tiny and generic** (one delegated call, default-false), preserves
every existing hazard byte-identically, and gives the Splitter its hook. **Verify S2's actual method name
+ shape at brief time and update this doc** — exactly as R1 verified TEL's pre-declared signal signatures
(R1 §4). If S2's seam differs (e.g. a signal rather than a return-bool), S6b adapts to S2's contract (S2
owns the component surface). The `throw_killed_hazard` / `&"killed_by_throw"` emission still fires for the
Splitter (a kill *did* happen) — the split is *in addition to*, not *instead of*, the kill telemetry.

### 3.2 Pseudocode — the Splitter script (illustrative, against the real APIs)

GDScript-flavoured pseudocode for the shared `splitter.gd` (an Actor). **Illustrative, not final** — the
programmer owns the real implementation and composes S2's components; this shows the *contract usage*.

```gdscript
# scenes/hazards/splitter.gd  (illustrative — composes S2 components)
class_name Splitter
extends CharacterBody2D

var _cfg: RunConfig            # snapshot at setup (bomb_hazard.gd:61 discipline)
var _player: Node2D
var _ctx: Dictionary          # per-instance overrides (child speed/generations/cell)
var _time_alive := 0.0        # self-timed run clock (bomb_hazard.gd:128 fallback)
# S2 components (child nodes): Movement (toward-player), Lethality (catch + BUG6 latch),
# ThrowInteraction (death delegation). This script wires their params from _cfg/_ctx.

func setup(cfg: RunConfig, player: Node2D, spawn_ctx: Dictionary = {}) -> void:
    _cfg = cfg
    _player = player
    _ctx = spawn_ctx
    # Per-instance overrides (v2 ctx tier): a child prefers ctx values over def params.
    var speed: float = _ctx.get("move_speed", _param("move_speed"))
    _movement.configure(speed)                    # S2 Movement (slow toward-player steer)
    _lethality.configure(_param("catch_radius"), _def.kills)   # R1 catch + BUG6 + L5 gate
    _throw.configure(self)                        # S2 ThrowInteraction → calls resolve_throw_death
    _set_tell(_is_child())                        # greybox: parent vs shard look (§6)

# --- S2 ThrowInteraction calls THIS on a throw-kill (§3.1 contract) ---
func resolve_throw_death(_killer_ctx: Dictionary) -> bool:
    if _param_enum("split_on") == &"throw_death" or _param_enum("split_on") == &"any_death":
        _do_split()          # throw always qualifies; any_death also splits on non-throw deaths
    _free_self()
    return true              # I handled my own death — ThrownItem must not free me again

func _do_split() -> void:
    var generations := int(_ctx.get("generations", _param("generations")))
    if generations <= 0:
        return               # terminal tier — a clean kill, no children (§2.5)
    var svc := get_tree().get_first_node_in_group(&"spawn_service")
    if svc == null:
        return
    var depth := GameState.current_depth_index
    var self_cell: Vector2i = svc.world_to_cell(global_position)     # Q8 helper (or ctx["cell"])
    var n := int(_param("child_count"))
    var child_speed := _movement.speed * float(_param("child_speed_mult"))
    var made_any := false
    for k in n:
        var cell := self_cell + _ring_offset(k, n, _param("child_spread"))   # DETERMINISTIC, no RNG
        var child_ctx := {
            "move_speed": child_speed,
            "generations": generations - 1,
            "split_index": k,
            "cell": cell,
        }
        var child := svc.spawn(_child_def, cell, child_ctx)   # service enforces caps; may be null
        if child != null:
            made_any = true
        else:
            EventBus.opposition_event.emit(&"splitter", &"split_refused", depth, _run_t_ms())
    EventBus.opposition_event.emit(&"splitter", &"split", depth, _run_t_ms())   # split happened

func _free_self() -> void:
    var svc := get_tree().get_first_node_in_group(&"spawn_service")
    if svc != null and svc.has_method("despawn"):
        svc.despawn(self)     # keep the registry count honest
    else:
        queue_free()

# _ring_offset(k, n, spread): pure function → the k-th of n points on a circle of radius `spread`,
# quantised to a cell delta. NO RNG (§1.4 / Q7).
```

Notes: the parent never edits `event_bus.gd` (emits the pre-declared `opposition_event` /
`opposition_killed_player` — S0 pre-declares them, dual-emitting `throw_killed_hazard` during migration).
It never edits `game_state.gd` (routes death through the existing `fail_run`). It never touches the layout
RNG. It resolves `svc` by group, matching the per-dive-node decision (breakdown OQ3).

---

## 4. Determinism & caps — the two hard invariants restated as acceptance

1. **Generation-time `fingerprint()` unaffected by splits.** `test_splitter` (or a determinism sibling)
   generates `band_two` at a fixed seed, records `fingerprint()`, then in a driven run throws to kill a
   parent (forcing a split), and asserts `fingerprint()` recomputed is **byte-identical** — splits are
   run-state, post-generation, RNG-free-from-parent (§1.4). And the **all-off** control fp `e943ac9c8bc1`
   is byte-identical (def off → no parent → no split).
2. **Children respect the caps — refusal proven.** `test_splitter` fills a band to `per_band_cap`
   (spawning parents/children up to `8`), then kills a parent and asserts **zero children over the
   ceiling** (`svc.live_count(&"splitter") + svc.live_count(&"splitter_child") <= per_band_cap`), that
   `svc.spawn` returned `null` for the over-cap requests, and that a `&"split_refused"` row was emitted.

---

## 5. Telemetry — the `opposition_event` vocabulary S6b proposes

S6b emits **only** the two generic signals S0 pre-declares (`opposition_event`,
`opposition_killed_player`); it touches neither `event_bus.gd` nor `telemetry/`. Payloads are
primitives-only, matching v2 (`0-scalable-opposition-system.md` §"EventBus / telemetry contract"). During
migration the legacy `throw_killed_hazard` dual-emits (S0/S4 own the migration).

| Signal / `event` | Payload | When | Notes |
|---|---|---|---|
| `opposition_event(&"splitter", &"spawned", depth, run_t_ms)` | id/event/depth/ms | parent placed by the builder | **emitted centrally by `SpawnService`** — S6b writes no `spawned` emit |
| `opposition_event(&"splitter_child", &"spawned", depth, run_t_ms)` | " | each child created via `svc.spawn` | central again — the multi-client proof: a non-builder spawn logs identically |
| `opposition_event(&"splitter", &"split", depth, run_t_ms)` | " | once, when a parent splits (§2.5 step 4) | **the new event S6b introduces** — "a split occurred." Off both death channels (L1 precedent) |
| `opposition_event(&"splitter", &"split_refused", depth, run_t_ms)` | " | each child request `svc.spawn` refused at cap | **recommended** — SG2 cap-pressure signal; the balance lever for M3 |
| `opposition_event(&"splitter"/&"splitter_child", &"killed_by_throw", depth, run_t_ms)` | " | on a throw-death (parent or child) | migration mirror of `throw_killed_hazard`; a kill is logged even when it also splits |
| `opposition_killed_player(&"splitter"/&"splitter_child", depth, run_t_ms)` | id/depth/ms | on a fatal catch | dedicated player-death channel; `run_ended.reason == "death"` via `fail_run` |

**Vocabulary rationale (honoring the L1 separation precedent, `event_bus.gd:171-175`):** `&"split"` and
`&"split_refused"` are **hazard-lifecycle** events — they must never live on a *player-death* channel, or
they'd poison SG2's death counts exactly as fusing `throw_killed_hazard` into `new_hazard_killed` would.
Player-death rides `opposition_killed_player`; junk-kills-splitter rides `&"killed_by_throw"`; a *split*
is its own third thing. From these three, SG2 derives everything: **splits per run** (`&"split"` count),
**shards created** (`splitter_child` `&"spawned"` count), **cap-binding rate** (`&"split_refused"` /
requested), and **"did the player learn restraint"** (throw-kills-of-splitter trending *down* across a
session while route-arounds trend up — the whole design thesis, §1.2).

---

## 6. Placeholder asset spec (character-animator, inline greybox — no PixelLab)

Per the M1 greybox norm (`M1_As_Built.md` §"Greybox asset norm") and the M1.9 placeholder guardrail, the
tell is inline flat shapes with a clear parent/child distinction and a legible split moment. **The
readability job is to teach "killing it multiplies it" in one throw** — so silhouette *continuity* +
scale is the whole trick.

| State | Shape | Color | Scale | Motion |
|---|---|---|---|---|
| **Parent, alive** | soft blob / large circle (distinct from junk rects and from the R1 pursuer diamond) | desaturated cool-unstable (e.g. `Color(0.4, 0.5, 0.6)`) with a faint slow jitter/shiver (the "unstable" read for the Fault fiction) | **~1.4× player** | slow drift toward player |
| **Split burst** (one-shot, at the death point) | same blob | quick hot flash (`Color(0.85, 0.85, 0.95)`) then fades as children peel off | pop-and-collapse `Tween` | the parent visibly *comes apart* into the shards |
| **Child** | **the same blob shape, scaled down** | same hue, **one shade more saturated/brighter** (danger rising) | **~0.7× player** (≈ half the parent) | faster drift toward player |

**Why this reads "killing multiplies it":** the child is *literally the parent silhouette at half scale* —
the player's visual system reads "it made smaller copies of itself" instantly, no text needed. The split
**burst animation originates at the exact death point** (where the thrown item landed), so the causal link
"*I* threw → *it* split" is unmistakable. The child being *faster* (visibly quicker drift) closes the
"and now it's worse" loop. A `generations`-terminal child that dies with **no burst** (just a plain
free/fade) teaches "that one was killable for real" — the bottom of the tree reads differently from the
top. Filter OFF; a hard color swap is an acceptable fallback if even the `Tween` is over-scope (bomb
`_flash_blast` idiom, `bomb_hazard.gd:164-170`). No sprite sheets, no `AnimationTree`.

---

## 7. Files to create / touch

**Create (S6b-owned, file-disjoint from S4/S6a/S7 in Wave 4):**
- `data/oppositions/splitter.tres` — the parent `OppositionDef` (§2.1).
- `data/oppositions/splitter_child.tres` — the child `OppositionDef` (§2.2).
- `scenes/hazards/splitter.tscn` + `splitter.gd` — the shared Actor host composing S2's Movement /
  Lethality / ThrowInteraction components + the `_do_split` death hook (§3.2). New if S2 didn't already
  stub a splitter host.
- `tests/test_splitter.tscn` + `.gd` — the caps-refusal + determinism + `*_kills`-gate + telemetry test
  (§4). Runs as a **scene**, not `--script` (headless-test memory).

**Touch (coordinate, don't clobber):**
- `data/bands/band_two.tres` — **S7 owns this file**; S6b only *provides the def ids* (`&"splitter"`,
  `&"splitter_child"`) for S7's `opposition_deck` (only `splitter` is deck-listed; the child is never in a
  deck). Integration-checked at S8/SG1 per the breakdown dependency note.
- The `ThrowInteraction` death-delegation seam is **S2's** (§3.1) — S6b consumes it, does not author it.
  If S2 shipped it, S6b touches nothing there; if a gap remains, it's a cross-wave contract issue to
  surface, not to fix inside `thrown_item.gd` unilaterally.
- CSV gloss keys (`CFG_GLOSS_SPLITTER_*`) — added wherever the gloss table lives (S4's generated-menu net
  reads them). Coordinate with S4.

**Must NOT touch (contract):**
- `systems/event_bus.gd` — S0 pre-declares `opposition_event` / `opposition_killed_player`. S6b only emits.
- `systems/game_state.gd` — `fail_run(&"death")` is the run-end; `current_depth_index` the read surface.
- `scenes/game/main_game.gd` — S3 is its sole Wave-3 writer; nobody writes it in Wave 4.
- `systems/oppositions/spawn_service.gd` — S0 owns the service; S6b only *calls* `spawn`/`despawn`/
  `world_to_cell`. (If `world_to_cell` doesn't exist, that's Q8 — a contract request to S0, not an edit.)

---

## 8. Acceptance criteria (definition of done)

1. **All-off fp unmoved.** With `oppositions_enabled` empty, the all-off fingerprint is byte-identical
   **`e943ac9c8bc1`** — no def loaded, no parent, no split possible.
2. **Splits work + are legible.** With `splitter` enabled in `band_two`'s deck, a parent placed by the
   builder, on a **thrown-item kill** (`split_on == throw_death`), spawns `child_count` `splitter_child`
   nodes at deterministic-per-split cells, emits one `&"split"` event, and frees itself. Children pursue
   faster (`child_speed_mult`) and are visibly ~half-scale copies (§6). A `generations`-terminal child
   dies clean (no children).
3. **Caps refuse — proven by test.** `test_splitter` fills a band to `per_band_cap`, kills a parent, and
   asserts **no child over the ceiling**, `svc.spawn` returned `null` for over-cap requests, and a
   `&"split_refused"` row was emitted (§4.2).
4. **Generation-time `fingerprint()` unaffected by splits.** A determinism assertion shows the band
   fingerprint is byte-identical before vs. after forcing a mid-run split at a fixed seed (§4.1).
5. **`*_kills` gate holds for children.** A child catch with `kills == true` → `fail_run(&"death")`,
   `run_ended.reason == "death"`; with `kills == false` → catch emits `opposition_killed_player` (tagged)
   but does **not** end the run (L5, mirrors R1). `GameState._run_ended` absorbs same-frame dupes.
6. **`params ↔ param_schema` bijection green for both defs** (S2/S4's per-def coverage net); the
   generated debug-menu section for each def auto-appears (S4's net); the cross-def reference
   `splitter.params`→`splitter_child` resolves in the `.tres` linter (Q8).
7. **Telemetry vocabulary lands** — `&"spawned"` (central, both ids), `&"split"`, `&"split_refused"`,
   `&"killed_by_throw"` (migration mirror), `opposition_killed_player` — payloads primitives-only; legacy
   `throw_killed_hazard` dual-emits.

**Process acceptance (work-product contract):** one shared S6b worklog naming the real commit SHA(s) for
the programmer + character-animator contributions; `godot --headless --import` compiles the new
scene/script/defs; the headless smoke test + `test_splitter` are green; a **Design deviations** section.

---

## 9. Open Questions (Phase-2 — Phase-3 resolves; fun/tone flagged "needs Director review")

**Fun / tone / scope calls — needs Director review (recommendation attached):**

- **Q1 — Movement feel: slow pursuer vs. drifter.** *Fun/tone.* A slow *pursuer* creates the throw
  temptation the design needs; a *drifter* is a softer obstacle that weakens the "should I kill it" tension
  (§2.3). **Recommend slow pursuer** (reuses R1's component, no new code). Playtest-tunable at SG2.
  **Director review.**
- **Q2 — `split_on`: `throw_death` only, or `any_death`?** *Fun/tone + thematic.* v1 §"Open questions"
  strongly prefers **throw-splits-only** ("more interesting and more on-theme" — punishes the throw verb;
  keeps a future clean environmental kill meaningful). In M1 there are *no* non-throw removals, so today
  the two are functionally identical — but the default sets the intent. **Recommend `throw_death`.**
  **Director review** (it's the design thesis).
- **Q3 — `child_count`: 2 or 3?** *Fun/tone.* `2` = Asteroids-classic, gentle, easy to read; `3` = a
  sharper "oh no" but crowds the greybox and hits the cap faster. **Recommend 2** for the first gate
  (clean read; sweep to 3 later). **Director review.**
- **Q4 — Do children despawn on a timer (`child_despawn_s`)?** *Fun/scope.* A mercy timer prevents a
  band littered with immortal shards a fleeing player left behind; but a self-cleaning swarm undercuts the
  "you made a lasting mess" consequence. **Recommend `0` (no timer) as the default, knob present** so the
  Director can sweep a timed variant. **Director review.**
- **Q5 — Do children give salvage / count toward any reward?** *Fun/economy.* v1 §"Open questions"
  recommends **pure cost** ("Pure-cost best teaches avoidance" — clearing a swarm should never be
  *rewarding*, or players will farm splits). M1 has no per-kill reward wiring anyway, so the default is
  automatically pure-cost; the question is whether to *ever* wire a reward. **Recommend pure cost (no
  reward), permanently.** **Director review.**
- **Q6 — `generations` default: confirm 1.** *Fun/scope.* `1` (parent → terminal children) is the shallow,
  clearable Asteroids tree (§1.2 rule 1). `2`+ risks swarm-to-cap tedium. **Recommend 1**, knob present
  (min 0 / max 3). Likely a straightforward ratify, but it sets the difficulty ceiling — **Director
  review** to be safe.

**Technical calls — Phase-3 resolves on merit (no Director needed unless noted):**

- **Q7 — Child spawn positions: run-state `RNG` vs. deterministic-per-split from parent.** *Technical.*
  Client (b) is unseeded, so `RNG` is *contract-legal*, but **deterministic-from-parent (a fixed
  `_ring_offset(k)` table, no `RNG`) is recommended** — it keeps the RNG-free discipline total, makes
  `test_splitter` deterministic, and costs nothing in feel (§1.4). Resolve to deterministic unless a
  playtest reason for jitter emerges.
- **Q8 — `self_cell` derivation + the `svc.world_to_cell` contract.** *Technical (contract request to
  S0/S3).* Children need the parent's *current* cell. Cleanest is a service helper
  `svc.world_to_cell(global_position)` (pure grid math already in `main_game`'s projection); fallback is
  snapshotting `ctx["cell"]` at `setup` (the builder stamps it) and accepting the small drift of a slow
  mover. **Recommend requesting `world_to_cell` from S0**; fall back to the `ctx` snapshot if S0 declines.
  Also: the `.tres` linter must resolve the **cross-def reference** `splitter.tres` → `splitter_child` by
  id (a dangling child id is a fail-loud error) — confirm the linter walks def-referenced ids.
- **Q9 — Children at `self_cell` vs. adjacent free cells (overlap / physics).** *Technical.* Spawning all
  children at exactly `self_cell` stacks them — since catch is a *script distance-test* (not physics),
  overlap isn't fatal, but it reads badly (one blob, not a swarm) and all children may catch the same
  frame. **Recommend distinct adjacent free graded-floor cells** on the `child_spread` ring (§2.4),
  falling back to `self_cell` only if none are free/valid. The service already validates cells (BUG7
  entry-safe exclusion), so an invalid ring cell is just refused → the child lands nearest-free or is
  dropped. Resolve to adjacent-free-cells.
- **Q10 — Does `splitter.tscn` need to be a *new* host, or does S2 already stub a splitter host?** *Scope.*
  S2 builds "only the blocks the 4 entities + the 2 planned hazards actually need," so S2 *may* have
  stubbed the Splitter host. Confirm at brief time; if present, S6b only authors the defs + the `_do_split`
  hook + the test. Reduces S6b to nearly pure data (the Phase-E ideal).

---

---

## Resolved Decisions (Phase 3)

Resolved 2026-07-02 by a **fresh-eyes game-director-designer** (not the §1–§9 author), per the
four-phase process. Technical questions (Q7–Q10) are resolved on merit and are now closed. Fun/tone/
scope calls (Q1–Q6) remain **NEEDS DIRECTOR REVIEW** — each is sharpened below into a one-line Director
question with an endorsed recommendation. Four orchestrator cross-contract adjudications are folded in as
**RESOLVED (fixed)**. Claim corrections against the real as-built code + the S0/S2 sibling designs are
listed last — the programmer builds against *these* where they differ from the §1–§9 body.

### Orchestrator cross-contract adjudications (fixed — folded as RESOLVED)

- **A1 — The throw-death seam is S2's `on_thrown_hit`, and S6b never touches `thrown_item.gd`.**
  The delegation seam lands in **S2** (S2 §2.2 `ThrowInteraction`, S2 OQ-5). Its real shape is
  **`on_thrown_hit(item_id)` (void)**, not S6b §3.1's proposed `resolve_throw_death(killer_ctx) -> bool`.
  `thrown_item.gd` keeps emitting `throw_killed_hazard` at `:92` (kind continuity), and at `:93` becomes
  `if body.has_method(&"on_thrown_hit"): body.on_thrown_hit(item_id) else: body.queue_free()` — so a body
  that owns an `on_thrown_hit` is responsible for its **own** free (the legacy four's `ThrowInteraction`
  in mode `die` reproduces today's free byte-identically; the Splitter's does the split-then-free). S6b
  **consumes** this — it does not author or edit `thrown_item.gd`. **Align §3.1/§3.2:** replace
  `resolve_throw_death(killer_ctx) -> bool` with the Splitter host exposing `on_thrown_hit(item_id)`
  (which calls `_do_split()` then `_free_self()`); no return-bool contract. Exact ownership of the
  `throw_killed_hazard`/`&"killed_by_throw"` emit inside the seam is **S2's** call (verify at brief time).

- **A2 — Ids, location, default, deck (confirmed as written).** Def ids `&"splitter"` /
  `&"splitter_child"`; both `.tres` at `Game/data/oppositions/`; **off by default** (not in
  `oppositions_enabled`); **`band_two` deck only** (`splitter` deck-listed, `splitter_child` never in any
  deck). The §0/§2.1/§7 body already states this — confirmed, no change.

- **A3 — `&"split"` / `&"split_refused"` ride the generic `opposition_event` channel (confirmed).**
  The doc's §5 proposal stands. `opposition_event` is pre-declared by **S0**, dual-emitted for the legacy
  hazards from **S2** onward (S2 OQ-6), **S6b emits** `&"split"` / `&"split_refused"` on it, and **S4**
  adds the Telemetry subscriber (config-marked rows). S6b touches neither `event_bus.gd` nor `telemetry/`.
  The `&"spawned"` rows for parent *and* each child are emitted **centrally by `SpawnService.spawn()`**
  (S0 `spawn.gd:521-522`) — confirmed; S6b writes no `&"spawned"` emit.

- **A4 — Cap semantics: per-def `per_band_cap` + the K5 `&"new_hazards"` 48 registry domain; R1's 64 is
  separate.** Both splitter defs live in the **`cap_group = &"new_hazards"`** pool (ceiling **48**,
  `NEW_HAZARD_BAND_CEILING`, relocated onto the service by S0) — that group cap is the hard anti-swarm
  ceiling. `per_band_cap = 8` is enforced **per def** (S0's `per_band_cap` is a per-def field, `:317`), so
  it caps `splitter` and `splitter_child` **independently**, not as a summed 8 (see Correction C5). R1's
  `R1_DENSITY_BAND_CEILING = 64` (`run_config.gd:37`) is a *separate density path* and stays untouched
  through M1.9 (S0 OQ-3). **Action for the defs:** add the `cap_group = &"new_hazards"` field to both
  `.tres` (the §2.1/§2.2 tables omit it) — `per_band_cap` alone is unsafe while S0's cap-precedence
  (S0 OQ-5) is unresolved; the group cap is the guaranteed enforcement line.

### Technical resolutions (Phase-3, on merit)

- **Q7 — Child cell derivation: RESOLVED → deterministic-per-split from the parent cell, no `RNG`.**
  Endorse the doc's recommendation, but with a **sharpened rationale that corrects §1.4's overstatement**:
  children are run-state (client (b)) and feed **nothing** into `fingerprint()`, so using the global
  `RNG` would *not* move the fingerprint — determinism-from-parent is a **cleanliness + testability**
  choice, **not** a fingerprint-safety requirement. It is chosen because (i) it makes `test_splitter`
  assertable (same throw at the same parent cell → same child cells), and (ii) it keeps the RNG-free
  discipline uniform. §1.4's "honoring the no-global-`RNG` contract by the strictest reading" is fine as a
  *tie-breaker*, but the doc should not imply the fingerprint depends on it. `_ring_offset(k, n, spread)`
  is a pure function of `(k, n, spread)`.

- **Q8 — `self_cell` + the `world_to_cell` contract: RESOLVED → use `svc.world_to_cell(...)`, but this is
  a confirmed S0-surface ADDITION, not an existing method.** The parent computes its live cell via
  `svc.world_to_cell(global_position)`. **Correction to the adjudication's premise:** the S0 service as
  currently drafted exposes only the **private** `_cell_to_world` (forward projection,
  `spawn_service.gd:560`) and lists **no public `world_to_cell`** (inverse) in its API surface (S0
  §"boundary methods", `:235-254`). The inverse math already exists as `main_game.gd:_world_to_cell`
  (`:1179`); resolving Q8 in the affirmative therefore **requires S0 to expose a public `world_to_cell`
  (and, for symmetry, `cell_to_world`)** by relocating that method. This is a small, mechanical S0 add —
  **surface it to S0 as a confirmed contract request**, do not assume it exists. The §2.4 `ctx["cell"]`
  snapshot fallback is **dropped** (the parent drifts; `world_to_cell` is the correct source once S0 adds
  it). The `.tres` linter must also resolve the **cross-def reference** `splitter.params → splitter_child`
  by id — a dangling child id is a fail-loud error (confirmed as a linter requirement).

- **Q9 — Children at `self_cell` vs adjacent free cells: RESOLVED → distinct adjacent free graded-floor
  cells on the deterministic `child_spread` ring; fall back to nearest-free, drop if none.** Endorse the
  doc's recommendation. Catch is a **script distance-test, not a physics overlap**, so stacking children
  at one cell is not *fatal* (and same-frame multi-catch is absorbed by `GameState._run_ended`
  idempotency), but it reads as one blob and defeats the "it made copies" tell. Place each child at the
  nearest **`svc.valid_cells`-approved** free graded-floor cell to `self_cell + _ring_offset(k)`
  (S0 exposes `valid_cells()` for exactly this pre-filter, `spawn_service.gd:552`); `svc.spawn` re-checks
  the cell and returns `null` on an invalid/occupied/over-cap cell → that child is simply dropped (no
  retry). This is consistent with the run-state nature of the spawn — no fingerprint concern either way.

- **Q10 — Splitter host: RESOLVED → S6b authors a NEW `splitter.tscn`/`splitter.gd`; S2 does NOT stub it;
  movement reuses S2's `ChaseMove`.** S2's file list (S2 §4) creates the nine components + rewrites the
  four existing hazard scripts — it does **not** stub a splitter host. So S6b authors `splitter.tscn` +
  `splitter.gd` as a new thin host. The host composes exactly three S2 components:
  **`ChaseMove`** (the slow toward-player steer — S2 §2.2 explicitly lists `ChaseMove` "Reused by: R1;
  Splitter (slow pursuit variant)"; there is **no** separate "toward-player mode" — `ChaseMove` *is* the
  chase, `PatrolMove` is the separate pacing block the Splitter does **not** use), **`LethalContact`**
  (mode `radius`, `*_kills`-gated + BUG6 latch), and **`ThrowInteraction`** (the `on_thrown_hit` hook,
  overridden to split). The Splitter has **no DORMANT/awaken state** — it is live-from-spawn like the
  pingpong, so it uses **no** `DepthLingerTrigger` and **no** `TelegraphFSM` (the split "burst" is a
  character-animator `Tween`, juice-only). This keeps S6b at the Phase-E ideal: two defs + a small host +
  the `_do_split` hook + the test.

### Claim corrections (verified against real source + sibling designs)

- **C1 — `thrown_item.gd:92-93` claim is ACCURATE (confirmed, no change).** `:92` emits
  `EventBus.throw_killed_hazard`, `:93` is an **unconditional** `body.queue_free()`. §1.5's citation is
  correct. (Post-S2 this `:93` becomes the delegated dispatch — see A1.)
- **C2 — The L1 signal-separation cite is ACCURATE (confirmed, no change).** `event_bus.gd:171-175` is
  the `throw_killed_hazard` declaration whose comment states it is **DEDICATED** and must not fuse with
  `new_hazard_killed` (`:149`) because the kill directions are opposite. §1.5/§5 cite it correctly.
- **C3 — Seam method name (§3.1, §3.2):** `resolve_throw_death(killer_ctx) -> bool` → **`on_thrown_hit(item_id)`**
  (void), per A1. The host's `on_thrown_hit` calls `_do_split()` then `_free_self()`; there is no
  return-bool contract, and `thrown_item.gd` frees the body only when it has **no** `on_thrown_hit`.
- **C4 — Component names (§0, §1.5, §2.3, §3.2):** the doc's generic "**Movement**" and "**Lethality**"
  components are, in S2's real vocabulary, **`ChaseMove`** and **`LethalContact`**. Use the real
  `class_name`s. `ChaseMove` *is* the toward-player steer (no "mode"); there is no "Movement" component.
- **C5 — `per_band_cap` is per-def; the §4.2 combined-count assertion is over-specified.** S0's
  `per_band_cap` caps **each def independently**, so
  `live_count(&"splitter") + live_count(&"splitter_child") <= 8` (as §2.5/§4.2 assert) is **not** what the
  registry enforces. Restate the test as: **(a)** `live_count(&"splitter_child") <= 8` (the per-def cap
  refuses the over-cap children), **(b)** the `&"new_hazards"` group never exceeds **48** (the hard
  anti-swarm ceiling, A4), and **(c)** each refused `svc.spawn` returns `null` and emits one
  `&"split_refused"` row. If the Director specifically wants a *tight combined 8-thing splitter budget*,
  that is a dedicated `cap_group = &"splitter"` registered at ceiling 8 (a one-line
  `set_cap_group(&"splitter", 8)`) — but a def belongs to exactly one `cap_group` in S0, so choosing
  `&"splitter"` would remove the family from the shared 48 pool. **Recommendation: keep `&"new_hazards"`
  (48) as the enforced group** (per A4) and treat `per_band_cap = 8` as the per-id soft cap.
- **C6 — Child `ctx` must carry `depth` + `run_t_ms` for the central `&"spawned"` emit.**
  `SpawnService.spawn()` emits `opposition_event(def.id, &"spawned", int(ctx.get("depth", 0)),
  int(ctx.get("run_t_ms", 0)))` (S0 `spawn.gd:521-522`). The §3.2 `child_ctx` omits both keys, so each
  child's `&"spawned"` row would log `depth = 0`, `ms = 0`. **Add `"depth"` and `"run_t_ms"` to
  `child_ctx`** (the parent already computes both for its own `&"split"` emit).

### Fun / tone / scope — NEEDS DIRECTOR REVIEW (recommendation attached)

- **Q1 — Movement feel.** *Director: ship the Splitter as a slow toward-player pursuer (reuses `ChaseMove`,
  zero new code), not a passive drifter?* **Recommend YES (endorse §2.3).** The pursuit is what
  manufactures the throw-temptation the entire lesson rides on; a drifter you can freely ignore removes the
  regret beat that makes "don't kill it" land. Playtest-tunable at SG2.
- **Q2 — `split_on` default.** *Director: default `split_on = throw_death` (only a thrown-item kill
  splits), not `any_death`?* **Recommend YES (endorse).** It is the design thesis — the *throw verb*
  backfires. In M1 there are no non-throw removals, so the two are functionally identical today;
  `throw_death` costs nothing now and sets the intent for when clean environmental deaths exist.
- **Q3 — `child_count` default.** *Director: 2 (Asteroids-classic) or 3?* **Recommend 2 (endorse).**
  Cleaner read, slower approach to the cap, easier A/B at the first gate; sweep to 3 later.
- **Q4 — `child_despawn_s` default.** *Director: children persist until band-end/killed (`0`, no mercy
  timer), or self-despawn on a timer?* **Recommend `0`/no timer (endorse).** The lasting mess *is* the
  consequence of choosing to throw; the `&"new_hazards"` 48 cap already bounds the swarm and children free
  with the band. Knob present for a timed-variant sweep.
- **Q5 — Children give salvage/reward?** *Director: children are pure cost, no reward, permanently?*
  **Recommend YES / pure cost (endorse).** Rewarding split-clearing would make players *farm* splits,
  inverting the avoidance lesson; M1 has no per-kill reward wiring anyway, so pure-cost is also the
  path of least resistance.
- **Q6 — `generations` default.** *Director: `1` (parent → terminal children, exactly one split)?*
  **Recommend YES (endorse).** The shallow, always-clearable Asteroids tree; `2`+ risks swarm-to-cap
  tedium. Knob min 0 / max 3 for later sweeps. (Sets the difficulty ceiling, so worth an explicit nod.)

---

*Spec authored by game-director-designer for M1.9 S6b. Design-only — no game code, no `.tres`. The
programmer + character-animator build against this. §1–§9 are the Phase-2 design; the **Resolved
Decisions (Phase 3)** block above is the locked-except-for-Director-calls layer — where it corrects the
body, it wins. Fun/tone calls (Q1–Q6) are surfaced to the Director; the four orchestrator adjudications
(A1–A4) are fixed. Deviations from the built design go to `DESIGN_DEVIATIONS.md` for the Wave-4 close-out
sweep.*
</content>
</invoke>
