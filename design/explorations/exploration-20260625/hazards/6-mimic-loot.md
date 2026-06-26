# Mimic Loot
**Category:** Inventory & throw-synergy

## The idea
A hazard **disguised as a junk pickup**. It sits on the floor looking exactly like a grabbable `JunkPickup` — same greybox shape, same value-glint — but **grabbing it triggers it**: it lunges, bites a slot, spawns, or explodes. The behavioral distinctness: it makes the *loot verb itself* a gamble. Looting is the game's reward reflex (the whole point of a junkyard); the Mimic injects a beat of hesitation into it, so every chest/pickup becomes a tiny risk read. It also feeds the throw verb beautifully — a thrown item can **trigger a suspected mimic from range**, "testing" a pickup without putting your body or your bag in reach. So the player who learns to *throw at suspicious loot* defangs it safely, spending an item to gain information.

## How it fits THE FAR YARD
It's built on the existing `JunkPickup` (`entities/junk_pickup/junk_pickup.gd`) — same `Area2D`, same `interactable_id`/focus interaction, same `_draw_greybox` look — so it reads as loot until interacted with. On `interaction_requested` it does *not* `try_add` to the inventory; it transforms into a hazard (pursuer-like, or a one-shot bite that `remove_at`s a slot, or a bomb-style burst). It directly taxes the **slot inventory** (a grab that costs you a slot instead of filling one) and pressures the **extract timer** by punishing greedy fast-looting. It pairs perfectly with **band/instability flavor**: surface mimics are obvious-on-inspection, deep mimics are near-perfect, so the GDD's "readable junk" promise (§Aesthetic) erodes as you descend — a diegetic dread beat. First appears **Band 2 (Temporal)**, rare; common and convincing by **Band 4 (Far)**.

## Graybox sketch
A pickup-shaped greybox with **one subtle tell** (a faint pulse, a slightly-wrong color, a tiny jitter every few seconds). States: DISGUISE (looks like loot) → on player-grab OR thrown-item-overlap → TRIGGER (becomes the chosen hazard). Throw-trigger reveals it harmlessly-ish (it activates at range, away from the player); grab-trigger catches you at point-blank. No art: the tell is a 1-pixel-equivalent wrongness — present but missable when rushing.

## Synergies & counters
**Synergy with the throw verb (the core hook):** spend a cheap item to throw-test a pickup you don't trust — converts the throw into a *scouting* tool, a second distinct use beyond combat. **Synergy with the thief/Eater:** in a cluttered loot room you can't throw-test everything (clock + item cost), so you must read tells. **Anti-synergy to avoid:** if mimics are too common, players stop looting, killing the core reward loop — so density must stay low. Counter: read the tell; throw-test the suspicious ones; or accept the gamble when the clock is short.

## Open questions
- **How punishing is a triggered mimic?** Slot-bite (annoying, recoverable) vs. spawns-a-pursuer (escalates) vs. lethal burst (brutal). Recommend slot-bite/pursuer at shallow bands, save lethal for Far. *Director fun/tone call.*
- **Tell visibility** is the whole balance: too obvious = no gamble, too subtle = feels unfair. This is a pure playtest dial. *Defer to the fun gate.*
- Should a *thrown* item that triggers a mimic be lost, or recoverable post-trigger? Recoverable keeps throw-testing cheap and encourages the smart play. Recommend recoverable.
