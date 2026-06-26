# Armored / Shelled
**Category:** Inventory & throw-synergy

## The idea
An enemy that ignores light throws: it **only staggers/cracks from a heavy item** (a high-`slot_size` junk like the engine block), **or only takes damage from behind**. A pebble bounces off; a fridge breaks its shell. The behavioral distinctness: it puts a *price tag* on every throw by making the throw verb care about *which* item you spend. The slot inventory already carries items of wildly different bulk and value (`slot_size`, `base_sell_value`); the Armored enemy is the first hazard that *reads* that bulk. The skill it forces: inventory triage as combat — "do I spend my bulky 6-slot engine block (worth 120 at sale) to crack this shell, or kite it?" The most valuable, sale-worthy items become your heaviest weapons, putting the keep/spend tension at the center of a fight.

## How it fits THE FAR YARD
It makes `JunkItem.slot_size` a *combat stat*, not just an inventory-tetris constraint (GDD §6 "bulky items / inventory tetris"). The throw projectile already carries the full `JunkItem`; the Armored enemy checks `item.slot_size >= heavy_threshold` (or checks the hit came from its rear arc) before taking stagger/damage — a light item just `junk_dropped`-re-drops off its shell, wasting the throw window. This sharpens the L1 economy: your best *weapon* and your best *payday* are often the same object. It pressures **extraction** because cracking it costs you a high-value item you'd rather sell — a clean push-your-luck moment. First appears **Band 2 (Temporal)** as the "you can't pebble everything" lesson; the rear-only variant fits **Band 3+** where positioning matters more.

## Graybox sketch
A hexagon with a thick shell outline. Variant A (heavy): a thrown item with `slot_size < threshold` bounces (re-drops, no effect); `slot_size >= threshold` cracks the shell one step (3 cracks → dies). Variant B (rear): a front/side hit bounces; a hit landing in its rear 90° arc damages it — and it slowly turns to face the player, so you must circle. States: FACE/CHASE → CRACK (on qualifying hit) → BREAK. No art: shell outline thickness = remaining armor; a facing wedge shows the weak arc.

## Synergies & counters
**Synergy with Reflector and Eater:** all three reject the naive head-on light throw, but each demands a *different* fix (angle / withhold / weight or flank) — together they make the throw verb a real decision space rather than one button. **Synergy with the thief:** a thief stealing your one heavy item right before an Armored fight is a vicious combo. Counter: carry/save one bulky item as a "shell-cracker," flank for the rear variant, or lure it onto a hazard (engineer-not-soldier).

## Open questions
- **Heavy-throw vs. rear-only — ship one or both?** Both risk overlapping with Reflector's "hit the right side." Recommend heavy-throw as the signature (it's the unique inventory hook); rear-only is a softer variant. *Director scope call.*
- Does spending the heavy item *destroy* it (real cost) or re-drop it cracked-but-intact (recoverable)? Re-drop softens the trade and may undercut the tension. Recommend destroy-on-use for the heavy variant. *Economy/fun call.*
- What `heavy_threshold` keeps it fair given a 12-slot bag — does a mid-bulk item qualify, or only the rare 6-slot ceiling? *Tuning, defer to economy workbook.*
