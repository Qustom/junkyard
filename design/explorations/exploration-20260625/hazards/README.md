# Explorations — 2026-06-25: Enemy & Hazard Graybox Spread

> ← Part of the [2026-06-25 exploration set](../README.md) (oppositions · [bands](../procgen-bands/README.md) · [player mechanics](../player-mechanics/README.md) · [economy](../economy-extraction/README.md) · [hub](../hub-staging/README.md)).

A spread of enemy/hazard ideas ("oppositions") grouped by **the kind of decision each forces on the player**. For a graybox, the value is *behavioral distinctness* — each should make the player think differently, not just look different.

Each file explores one idea: **the idea** (and its behavioral distinctness), **how it fits THE FAR YARD** (the real verbs — move, mouse-aimed throw, loot, extract-before-clock — and the existing hazard/inventory systems), a **graybox sketch**, **synergies & counters**, and **open questions** (with vision/fun/scope calls flagged for the human Director).

## 0 — Cross-cutting architecture
*How all of the below get built without one-script-per-enemy sprawl.*
- [Scalable Opposition System](0-scalable-opposition-system.md) — a single `.tres` descriptor + composable behavior components over Actor/Field/Fixture archetypes, placed by a credit-budget Director that generalizes the M1.5 fair-share allocator. Absorbs the shipped hazards, the 35 ideas below, and future ones while preserving all-off baseline parity + seed determinism. Includes prior-art research (Isaac, RoR2, Nuclear Throne, Dead Cells, L4D Director, LimboAI/Beehave) and a per-category fit table. **Director flag:** several zone/Field oppositions depend on a player HP pool M1 lacks → likely M2.

## 1 — Pursuers & movement enemies
*Force movement/spacing decisions.*
- [Charger](1-charger.md) — bait the straight-line rush, dodge the overshoot
- [Ambusher](1-ambusher.md) — punishes blind looting
- [Pack hunters](1-pack-hunters.md) — keep your back to a wall
- [Patroller w/ vision cone](1-patroller-vision-cone.md) — stealth/timing puzzle
- [Splitter](1-splitter.md) — makes killing a bad default
- [Mirror](1-mirror.md) — maneuver it into other hazards
- [Burrower](1-burrower.md) — denies an area on a rhythm
- [Leaper](1-leaper.md) — room geometry won't save you
- [Tethered pair](1-tethered-pair.md) — the threat is the line, not the bodies

## 2 — Ranged & projectile enemies
*Force read-and-position decisions.*
- [Sentry](2-sentry.md) — lane control
- [Lobber](2-lobber.md) — punishes standing still
- [Spinner](2-spinner.md) — read the gaps
- [Suppressor](2-suppressor.md) — non-damaging; sets up other hazards

## 3 — Static & environmental traps
*Force timing/route decisions (extend the M1.5 hazard system).*
- [Pop-up spikes](3-popup-spikes.md) — memorize the beat
- [Crusher / piston](3-crusher-piston.md) — slams a corridor shut on a cycle
- [Flame vent](3-flame-vent.md) — safe between pulses
- [Sweeping laser](3-sweeping-laser.md) — wipes edge to edge
- [Conveyor / wind tile](3-conveyor-wind-tile.md) — pushes you, thrown items, enemies
- [Ice tile](3-ice-tile.md) — momentum carries you past your stop
- [Collapsing floor](3-collapsing-floor.md) — one-way routes
- [Turret on a track](3-turret-on-track.md) — moving sentry

## 4 — Zone & area-denial
*Force keep-moving / loot-blind decisions (tension with the extraction clock).*
- [Gas cloud](4-gas-cloud.md) — chip damage forces movement
- [Darkness pocket](4-darkness-pocket.md) — loot blind
- [Sound aggro zone](4-sound-aggro-zone.md) — rewards patience
- [Electrified floor](4-electrified-floor.md) — find the safe tile
- [Magnet field](4-magnet-field.md) — drags you/metal loot toward a hazard

## 5 — Time-pressure / extraction-specific
*Lean on the in-dive countdown (~300s). Key question per file: does it double up with the clock?*
- [Rising tide](5-rising-tide.md) — the map shrinks as you linger
- [Spreading fire](5-spreading-fire.md) — greed costs you loot
- [The Hunter](5-the-hunter.md) — activates at a timer threshold, beelines for you
- [Alarm spawner](5-alarm-spawner.md) — lingering spawns reinforcements

## 6 — Inventory & throw-synergy
*Make the core verbs (throw + inventory management) matter most.*
- [Thief](6-thief.md) — steals an item and flees
- [Eater](6-eater.md) — grows from thrown items; can't cheese it
- [Reflector](6-reflector.md) — throw at an angle, not head-on
- [Armored / shelled](6-armored-shelled.md) — heavy throw / hit from behind
- [Mimic loot](6-mimic-loot.md) — every chest is a small gamble
- [Weight plate](6-weight-plate.md) — fires only when your inventory is heavy

---
*36 explorations across 6 categories. Authored by the `game-director-designer` role as a parallel fan-out; not yet dispositioned by the Director.*
