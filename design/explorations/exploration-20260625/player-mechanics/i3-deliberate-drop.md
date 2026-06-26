# Deliberate Drop
**Category:** Inventory as an active system

## The mechanic
A carried item can be **intentionally ejected** to free its slots. The bag is count-capped (`max_slots`, footprint = `slot_size`); when it's full, a missed grab just flashes red and the junk stays in the world (`junk_pickup.gd:88`). Deliberate drop turns that dead-end into a *choice*: stand over a rare, bulky find you can't fit, drop the two cheap-but-large pieces you've been hauling, and grab it. The greed-triage moment is the **regret**: you can't take everything, so you actively decide what to abandon — and that thing you leave is gone the moment you extract.

## What exists today
Most of the plumbing is already built — this mechanic is largely *exposure*, not invention.
- **The model already supports it.** `RunInventory.remove_at(index)` returns the removed `JunkItem` and re-emits `run_inventory_changed` (`run_inventory.gd:80-86`). No model change needed.
- **The drop-to-world path exists.** `EventBus.junk_dropped(item, world_pos)` is wired: `JunkSpawner._on_junk_dropped` re-spawns an ordinary, re-grabbable `JunkPickup` at that position (`event_bus.gd:66`, per L1 §research, `junk_spawner.gd:73-77`). Dropped junk **persists and re-picks-up** identically to planned junk — no special "dropped" state.
- **A drop gesture already exists in UI.** D2's `inventory_panel` has a `drop_requested` flow (`inventory_panel.gd:127-141`, referenced in L1) that the L1 throw also leans on.
- **What's missing:** a clean, intentional player-facing *"drop THIS one, here, at my feet"* action that isn't a throw and isn't a thrown-projectile miss. Today the eject paths are throw (L1) or death/timeout dump (E3). There is no calm "make room" drop bound to a single key.

## How to fit it in
- **Control mapping.** Reuse L1's selector (Q/E highlight a slot) + a new `drop` action (recommend **G**, "give up"). `main_game.gd` already owns the selector seam and player resolution (`highlighted_index()`, group query); a `drop` handler is `remove_at(idx)` → `EventBus.junk_dropped.emit(item, player.global_position)`. Drops at feet (not thrown) so it reads as "set down," fully reversible until extract.
- **Tension hook (E2).** This is the inventory face of the push/cash-out decision: deeper bands mean richer junk than what's already in your full bag (Instability `I` raises loot tier). Deliberate drop is the *swap* you make to capitalize on going deeper — and every drop is haul you walked past, sharpening the "should I have left earlier?" feeling E2 measures.
- **RunConfig + telemetry.** Add `deliberate_drop_enabled: bool = false` (all-off baseline byte-identical). Emit a telemetry row per drop: `item_id`, `value`, `slot_size`, `world_pos`, `dive_time_remaining`, `band_depth`. The killer metric is **value left behind at extract** (sum of dropped-and-not-regrabbed value) — a direct greed-triage signal, comparable across config versions.

## Research (cited)
- **Tarkov** makes inventory triage the core loop: limited grid space forces drop/swap decisions and prioritization tables for "take vs leave" ([EFT Wiki — Looting](https://escapefromtarkov.fandom.com/wiki/Looting)). Our count-cap is the gentler cousin — the *decision* survives, the spatial-Tetris friction does not.
- **Diablo / ARPG loot triage** — drop-to-make-room for a higher-tier drop is the canonical "is this upgrade worth my space" beat.
- **Spelunky drop** — a single intentional-drop button to free your hands for a pickup; proves the one-key set-down at feet reads cleanly.
- **Resident Evil discard** — explicit, deliberate "discard from inventory" with the sting of permanence; the model for making the *abandon* feel like a real cost.

## Graybox sketch
Smallest proof: bind **G**, on press call `RunInventory.remove_at(highlighted_index)`, emit `junk_dropped` at player position. The dropped greybox lands and is re-grabbable via the existing spawner path. Test the moment: full bag (cheap big items) standing over a rare bulky find → drop one → grab the rare. If the player *feels* the abandon, it lands.

## Open questions (for the Director)
- **Despawn?** Does dropped junk persist for the whole dive, or despawn after N seconds / on band-change? Persist-for-dive is simplest and matches L1's miss behavior; a despawn timer adds urgency but risks losing a deliberately-staged swap.
- **Fat-finger safety.** A single key that permanently sheds your rarest item is grief-prone. Options: confirm-hold for high-value items, an undo window, or rely on persistence (you can always re-grab before extract). Recommend persistence + no confirm for M1, revisit if testers misfire. *Needs Director review.*
- **Drop vs. throw collision.** With L1's throw (Space) and this drop (G) both consuming the highlighted slot, is two eject verbs one too many? Recommend shipping drop knob-gated and A/B-ing against throw-only in the gate.
