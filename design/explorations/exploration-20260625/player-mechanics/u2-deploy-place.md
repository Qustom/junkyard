# Deploy / Place
**Category:** Other item verbs (besides throwing)

## The mechanic
**Deploy** turns a held item into a persistent world object with its own behaviour
that runs after you walk away: a **decoy** (draws a pursuer off you), a **light**
(burns back a darkness pocket), or a **trap** (a player-placed bomb/spike that fires
on enemy contact). The verb makes the player a **hazard-author** — the same system
that currently spawns enemy-owned bombs and pursuers becomes something the player
spends salvage to spawn *for their own ends*. Deploy is a deliberate, low-tempo setup
beat (place → reposition yourself → bait something into it), the inverse of throw's
reactive snap.

## What exists today
**KEY win:** the hazard system already instantiates persistent, self-running objects.
`scenes/hazards/hazard_entity.gd` (a `CharacterBody2D` that wakes and chases) and
`scenes/hazards/bomb_hazard.gd` (a `Node2D` distance-test state machine: idle ring →
pulse → detonate) are exactly the shape a deployable needs. Both share the locked
`setup(cfg, player, spawn_ctx)` family signature, both snapshot `RunConfig`, both emit
pre-declared `EventBus` signals and route lethality through `GameState.fail_run`. A
deployable is **the same node spawned by the player instead of the K5i spawn loop.**

**What's missing:** (1) a notion of **ownership** — today every hazard targets the
player; a player-deployed trap must target *enemies* (flip whose proximity arms it),
and a decoy must be a *target pursuers prefer over the player*. (2) An **item →
deployable-prefab mapping** on `data/junk/junk_item.gd` (which junk yields which
hazard prefab when deployed). (3) A **player spawn seam** (the deploy input → instance
+ `add_child` + `setup`), parallel to but distinct from the throw spawn in
`entities/thrown_item/thrown_item.gd`.

## How to fit it in
- **Mapping:** add an optional `deploy_prefab: PackedScene` (+ `deploy_kind` enum:
  decoy / light / trap) to `junk_item.gd`. Null ⇒ item isn't deployable. Reuse the
  scalable-opposition prefab roster from `0-scalable-opposition-system.md`.
- **Decoy vs pursuers (`1-*`):** the decoy registers in the `pursuer` target set with
  higher salience than the player for N seconds; `hazard_entity._chase` retargets to
  the nearest decoy if one exists (small read-only addition gated by a knob). Mirrors
  MGS's active decoy and DRG's "shoot the turret not me" diversion.
- **Light vs darkness (`4-darkness-pocket.md`):** a deployed light is a static radius
  that suppresses the darkness overlay — DRG flares as a placed (not thrown) source.
- **Trap vs packs:** a player-owned `bomb_hazard`/`spike_hazard` whose proximity test
  reads the *enemy* group, not the player. Bait pack hunters across it.
- **Dive clock (`systems/dive_clock.gd`):** deploy costs ~1–2s of setup tempo; it
  trades clock-now for safety-later, a real ~300s decision.
- **Control:** a dedicated *Deploy* button (separate from Throw), with a placement
  ghost like DRG's blue/orange hologram so walls reject bad spots.
- **RunConfig + telemetry:** `u2_deploy_enabled` (default off = baseline), plus
  `item_deployed{kind, depth, run_t_ms}` and `deployable_triggered` so the gate can
  see whether players actually author hazards.
- **DIFFERENTIATE from `t5` throw-to-place:** t5 lobs a *normal* item that just lands
  and rests (a discard/positioning of inventory). Deploy spends a *special* item to
  spawn an *active, behaving* object. Throw-to-place = ballistics + inert result;
  deploy = no arc, a persistent agent.

## Research (cited)
- **DRG LMG turret / flare:** hologram preview, blue/orange valid-placement tell,
  recallable, choke-point tactics — the deploy-UX template.
- **Don't Starve Tooth Trap:** placed, multi-use, *bait food next to it* — the
  trap-plus-lure loop; traps don't aggro, supporting stealthy attrition.
- **MGS Active Decoy:** thrown-then-deployed humanoid balloon that pulls aggro and
  buys an escape — the decoy archetype.

## Graybox sketch
Smallest version: one deployable item type → a **player-owned `bomb_hazard`**. Deploy
button instances `bomb_hazard.tscn`, `add_child`, `setup(cfg, player, {"owner":
"player"})`. Add a one-line owner check so the proximity test reads the `enemy` group
instead of the player. Reuse the existing pulse/blast tells unchanged. Knob-gated,
all-off = byte-identical baseline. Validate "set bomb → lure a `hazard_entity` over it
→ it dies" before touching decoy/light variants.

## Open questions
- **Ownership model:** a per-instance `owner` flag in `spawn_ctx`, or separate
  player-hazard prefabs? Flag is cheaper but threads conditionals through the hazard
  scripts. *(Director: scope call.)*
- **Cost gate:** deploy consumes the item (salvage sink) vs a cooldown vs limited
  charges. Item-cost ties it to the economy; cooldown keeps it spammy-but-free.
- **Decoy salience:** does it perfectly redirect pursuers, or only weight them? Perfect
  redirect risks trivialising `1-*` opposition.
- **Overlap with `t5`:** if t5 ships, is "throw a deployable so it lands armed at range"
  a fusion of the two verbs, or kept strictly separate to avoid a muddy control scheme?
- **Recall (DRG):** can you pick a deployable back up (Don't Starve allows it), or is
  placement committal? Recall softens the cost decision.

Sources:
- [LMG Gun Platform — Deep Rock Galactic Wiki](https://deeprockgalactic.wiki.gg/wiki/LMG_Gun_Platform)
- [Sentry placement tactics — DRG discussion](https://steamcommunity.com/app/548430/discussions/1/5294572213373195259/)
- [Tooth Trap — Don't Starve Wiki](https://dontstarve.wiki.gg/wiki/Tooth_Trap)
- [Trap (baiting) — Don't Starve Wiki](https://dontstarve.fandom.com/wiki/Trap)
- [Decoy (device) — Metal Gear Wiki](https://metalgear.fandom.com/wiki/Decoy_(device))
