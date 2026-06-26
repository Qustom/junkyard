# Levers, Doors, Switches
**Category:** Interaction & environment verbs

## The mechanic
A single interaction verb (the `interact` press, A2) bound to *world actuators* — levers, switches, and the doors they drive — that change the band's traversable shape and danger at runtime. The verb is identical to junk-grab; only the actuator's effect differs. Three uses, mapped to the dive's core tension (push deeper vs. extract on the ~300 s clock):

1. **Open a shortcut.** A lever unseals an otherwise-blocked connector, collapsing two corridor legs into one — buys time back on the dive clock (`systems/dive_clock.gd`), or opens a one-way exit toward the gate.
2. **Close a door to block a pursuer.** Toggle a door *shut* behind you to put a wall between the player and the HazardEntity chaser — wall-collision already stops it (`hazard_entity.gd` masks `world` only), so a closed door is an instant, deliberate refuge that costs the pursuer a re-route (or strands it).
3. **Trigger a hazard onto enemies.** A switch fires an environmental trap (crusher, flame vent, popup spikes) on the *enemy's* side — turning the explored traps (`hazards/3-*`) into player-aimed weapons rather than only obstacles.

## What exists today
The pieces are nearly all present — this verb is mostly *wiring*, not new systems.

- **Doors already exist as a concept**: sockets are "openable connectors," and `socket_sealer.gd` is the post-placement pass that *seals* a perimeter edge by writing a WALL cap, with an exact guard that leaves mated doorways walkable. A door is precisely "a connector whose seal/unseal state is toggleable at runtime instead of fixed at materialisation." `data/zone_socket.gd` gives the cardinal mating vocabulary.
- **`test_corridor_lever.gd` is NOT a world lever** — despite the name it tests a *generator* corridor-rarity down-weight (`lvl_corridor_weight_mult` / `lvl_short_corridors`) and corridor-time telemetry. It proves the RunConfig-knob + deterministic-fingerprint discipline, but there is no in-world, player-pullable lever yet.
- **Interaction** (A2): `InteractionDetector` + `Interactable` + EventBus `interaction_requested(id, target)` is the exact hook a lever needs — a lever is just an `Interactable` with `interactable_id = &"lever"`.
- **Hazards** snapshot RunConfig at `setup()` and run their own state machines; the crusher (`3-crusher-piston.md`) is already an `AnimatableBody2D` with OPEN/WARN/CLOSED phases.

**Missing:** a runtime door entity that toggles a connector's walkability; a `Switch`/`Lever` Interactable that emits a wiring signal; and a hazard "external trigger" entry point (today hazards are autonomous timers).

## How to fit it in
- **Door = runtime toggle over the sealer's geometry.** A `Door` node owns one connector's cells and flips them between FLOOR (open: no collision) and WALL (closed: reuse `socket_sealer`'s `GREYBOX_SOURCE_ID`/`WALL_ATLAS` cap on a TileMapLayer). It must update the player's *and* hazard's pathable space — since the hazard only does local `move_and_slide`, a closed WALL stops it for free; no navmesh rebuild needed.
- **Switch/Lever = Interactable → EventBus emitter.** On `interaction_requested(&"lever", self)`, the lever emits a new `EventBus.actuator_toggled(actuator_id, new_state)`. Doors and hazards subscribe by `actuator_id` (data-authored wire), keeping the decoupling rule — the lever never holds a hard ref to its target.
- **Hazard external trigger.** Add an optional `trigger(...)` entry on the trap so a switch can force its WARN→CLOSED stroke (the crusher already has the stroke; this just front-loads its timer), emitting `throw_killed_hazard`-style telemetry but for switch kills.
- **Dive-clock coupling.** A shortcut grants clock relief; closing a door costs nothing but a press, so its value is *time bought from the pursuer*, not from the clock — the two map onto the same scarcity differently.
- **Control mapping:** reuse `interact`; no new binding. Doors prompt "Close"/"Open" via the A2 prompt's `prompt_text`, recomputed from state.
- **RunConfig knob + telemetry:** gate behind `lvl_actuators_enabled` (all-off default → baseline byte-identical, no nodes spawned), and emit a config-marked `actuator_used(kind, effect, depth, run_t_ms)` so the gate measures whether players actually use doors to escape / traps to kill.

## Research (cited)
Closing doors as a tactical verb is well-proven. In **Left 4 Dead**, survivors shut doors to stall the Infected and buy heal/resupply time, and doors are a deliberate finale defense tool ([L4D Tactics](https://left4dead.fandom.com/wiki/Tactics)). **Resident Evil** uses doors as both barrier and weapon: a fast double-tap *kicks* a door open to stun enemies behind it, half-open doors break enemy detection, and most enemies cannot open fully-closed doors ([RE Door mechanics](https://residentevil.fandom.com/wiki/Door_mechanics)) — directly validating "close behind you to break a chaser." **Spelunky** makes traps symmetric: enemies trigger arrow traps, spikes, and lava exactly as the player does, so luring/throwing foes into hazards is core emergent play ([Spelunky Traps](https://spelunky.fandom.com/wiki/Arrow_Trap_(HD))) — the model for switch-fired traps onto pack hunters. **Immersive sims** generalize this: simulated systems respond to varied player actions for emergent solutions ([Immersive sim, Wikipedia](https://en.wikipedia.org/wiki/Immersive_sim)) — a switch is the canonical "one verb, many systemic effects" actuator.

## Graybox sketch
One corridor with a mid-point `ColorRect` door (closed = WALL collision on, open = off) and a wall-mounted `Lever` Interactable a few cells away. Press `interact` at the lever → `actuator_toggled` → the door flips state + the A2 prompt label swaps Open/Close. Drop a HazardEntity on the far side: the player runs through, doubles back to the lever, slams the door, and watches the chaser stall against it. Second graybox: wire the same lever to a crusher's `trigger()` instead of a door, and bait the pursuer under it. No art — colored rects only.

## Open questions
- **Door-vs-socket model:** does a Door own raw cells (simple, but duplicates sealer logic) or wrap a `ZoneSocket` instance the generator marks `openable`? The latter is cleaner long-term but couples runtime state into bandgen; flag for the Director.
- **Can enemies open/break doors?** RE-style "enemies can't open closed doors" makes the refuge reliable (good for the M1 greybox), but a permanently safe door trivializes the pursuer. Options: doors are pursuer-proof (greybox default), or a chaser can *bash* a closed door after a delay (restores tension). Recommend pursuer-proof for the first graybox; revisit at the fun gate.
- **One-way / re-closeable?** A shortcut that re-seals behind you (commitment, like a collapsing floor) vs. a freely toggleable door (puzzle/refuge). They feel different — Director call per actuator.
- **Hazard-trigger authoring:** who owns the lever→hazard wire — a `target_actuator_id` field on the hazard `.tres`, or a separate wiring resource? And should a switch *arm* a trap (it then runs its own cycle) or *fire one stroke*? Affects the trap's external-trigger API surface.
- **Telemetry richness:** is "actuator used" enough, or do we need to attribute *pursuer escapes* and *switch kills* distinctly to judge whether the verb earns its complexity at G4?

---
*Summary:* Doors already exist latently as toggleable sealed sockets and hazards already run trigger-able strokes, so levers/switches are mostly an A2-Interactable → new `actuator_toggled` EventBus wire delivering three verbs (open-shortcut, close-door-on-pursuer, switch-fire-trap), gated behind an all-off `lvl_actuators_enabled` knob; the live open calls are the door-vs-socket ownership model and whether the chaser can breach a closed door.
