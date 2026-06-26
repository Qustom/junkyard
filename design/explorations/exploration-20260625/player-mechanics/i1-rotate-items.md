# Rotate Items
**Category:** Inventory as an active system

## The mechanic
Turn a junk piece 90° before/while placing it so an awkward footprint fits a gap the unrotated shape would waste. Rotation only matters if the inventory is *spatial* (a 2D grid of cells with shaped items) rather than count-based: it converts "do I have N free slots?" into "can I make this specific shape *physically* fit *here*?" That second question is a skill — the player who packs tightly carries more out per dive, so the same 300s of looting yields a richer haul for the better packer. Rotation is the cheapest, most legible verb that adds that skill ceiling.

## What exists today
Honest read: **rotation is not representable today, because the inventory is not spatial.** `run_inventory.gd` is the count-based model locked for M1 (D1 Open questions, recommendation: "Lock in simple-count"). Capacity is `sum(item.slot_size) <= max_slots` — `used_slots()` is a plain integer sum, `can_accept()` just checks `slot_size <= free_slots()`. There is no cell grid, no occupancy map, no placement coordinates. Items are stored as a flat `Array[JunkItem]`, added by `append`, removed by index.

The *forward-compat hook exists but is dormant*: `JunkItem.grid_footprint: Vector2i` is authored on every item and explicitly flagged "advisory in M1" — nothing reads it. D1 deliberately deferred the spatial/Tetris variant ("occupied-cell 2D arrays, rotation, fit-search, drag-placement … a large UI and validation cost"). So rotation is a **gated downstream of a model swap**: the data carries `grid_footprint` so no content migration is needed, but the model, the fit-search, and the D2 UI (currently a slot list, not a draggable canvas) must all become spatial first.

What's missing to support rotation: (1) a spatial `RunInventory` storing per-item placement (`Vector2i` origin + orientation) and an occupancy mask; (2) shape representation as a cell mask, not just a `Vector2i` bounding box (an L-piece needs a mask); (3) a 90°-transform on that mask; (4) a drag/rotate/place UI in D2.

## How to fit it in
- **Shape as mask, not box.** Extend `JunkItem` with a `cell_mask: PackedByteArray` (or `Array[Vector2i]` of filled cells) alongside `grid_footprint`. Rectangular junk degenerates to a full box; interesting junk (engine manifold = L, pipe = 1×4) gets a real mask. Rotation = rotate the mask 90° CW: `(x,y) -> (h-1-y, x)`.
- **Looting under the clock.** This is where rotation earns its place. At a full-ish bag the player finds the engine block, sees it won't drop in flat, and spends ~1s rotating to cram it — *deciding to spend clock-time on packing* trades against more looting (`dive_clock.gd`, ~300s). That is the exact "one more piece" tension D1 wants, sharpened spatially.
- **Control mapping (L6).** Mouse: a **Rotate key (R / right-click) while the piece is held** at the cursor, ghost-preview snapping green/red for fit. Controller: **rotate on a bumper (RB)** while the piece is grabbed on the twin-stick cursor. Press-edge latch (same pattern as the L6 throw rework) so a held key rotates once per press, not every frame.
- **RunConfig knob + telemetry.** Gate behind `RunConfig.spatial_inventory` (default **off → reproduces the count-based baseline**, the standing all-off-control contract). Add `EventBus.item_rotated(item_id, orientation)` and `inventory_packed_efficiency(used_cells, total_cells)` on cash-out. Telemetry tracks rotations/run and packing efficiency so the gate can measure whether rotation actually deepens packing or just adds friction.

## Research (cited)
- **RE4 attaché case** — a 6×10 grid; items snap, move, and rotate to fit; the canonical "Tetris your loot" feel ([Bloody Disgusting](https://bloody-disgusting.com/video-games/3658221/resident-evil-4-perfected-inventory-system-resident-evil-25/), [RE Wiki](https://residentevil.fandom.com/wiki/Attache_Case)). Rotate-to-fit is a documented, expected verb ([Steam discussion](https://steamcommunity.com/app/254700/discussions/0/558749190741844331/)).
- **Tarkov** — grab/rotate/place in a grid; packing is a survival-stakes skill ([Code Monkey breakdown](https://unitycodemonkey.com/video_comments.php?v=fxaDBE71UHA)).
- **Backpack Hero** — polyomino items rotated via right-click/arrow-keys while dragging; a long halberd turned horizontal to fit under a row; proves rotation + irregular masks create real depth (and pairs with adjacency synergy) ([Grokipedia](https://grokipedia.com/page/Backpack_Hero), [Gamerant tips](https://gamerant.com/backpack-hero-tips/)).
- **Save Room** — RE4's case extracted into a *pure* rotation/packing puzzle, evidence the verb alone carries a game ([Kotaku](https://kotaku.com/resident-evil-4-save-room-attache-case-puzzle-inventory-1848875111)).

## Graybox sketch
Smallest version proving depth: a fixed **5×4 grid**, three hand-authored masks — a 1×1 bolt, a 1×4 pipe, and a 2×2-minus-one L (engine bracket). Drag from a "found junk" tray, **R rotates the held mask**, ghost shows green/red, place commits. Goal: pack all three. With rotation, the L+pipe+bolt fit; without rotation the L blocks the pipe and one piece is left behind. If a tester *feels* the difference between "fits / doesn't fit" purely from rotating, the mechanic is proven — promote it; if it's fiddly busywork, the count model stays.

## Open questions
- **Mask representation.** `Array[Vector2i]` (readable, easy rotate) vs `PackedByteArray` bitmask (compact, cache-friendly for fit-search)? Affects `.tres` authoring ergonomics for the designer.
- **Auto-rotate vs manual.** Offer a "best-fit auto-place" (RE4 has an auto-sort) that finds an orientation for you — convenient but it *removes the skill the mechanic exists to add*. Recommend manual-only at first; revisit if testers find packing tedious. **Director call (fun/tone).**
- **Controller ergonomics.** Twin-stick cursor + grab + bumper-rotate + place is a lot of simultaneous input under the clock; may need a snap-assist or coarse cell-snapping for pad parity. **Needs L6/Director review.**
- **Scope.** Spatial inventory is the D1-deferred large cost; is the packing puzzle worth it *on top of* the value puzzle, or does it dilute M1's "what's worth the space" question? This is a **vision/scope call for the Director**, not a self-resolve — recommend prototyping behind the off-by-default knob before committing.
