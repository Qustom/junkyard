# Generation Record — `player_basic_template/`

The **basic player template** — an iteration of [`surface_v3_diner_flannel`](../surface_v3_diner_flannel/) with the **coffee mug removed (empty hands)** so it works as a clean, reusable base character, plus three template animations.

Upstream painterly concept: [`player_surface_life_v3_diner_counter`](../../../../concept_art/explorations/20260627_d/player_surface_life_v3_diner_counter.png).

## Summary

| Field | Value |
|---|---|
| **Subject** | Player basic template — red flannel over green hoodie, empty hands |
| **Date** | 2026-06-27 |
| **Service** | PixelLab AI (MCP `mcp__pixellab`) |
| **Base tool / mode** | `create_character` · **v3** (8 directions, 2 generations) |
| **Body / view** | humanoid · low top-down (3/4 RPG) |
| **Size** | 64px character on 124×124 canvas |
| **Directions** | 8 (S, N, E, W, SE, SW, NE, NW) |
| **Character id** | `3cb56375-df23-4c9f-9aea-bbfe1a737268` |
| **Animations** | move, pickup, throw (template animations, 8 directions each) |
| **Cost** | base 2 gens + 3 animations × 8 dirs × 1 gen = **26 PixelLab generations** |

## Folder layout

```
player_basic_template/
├── rotations/        8 base directional poses (south.png … north-west.png)
├── move/             walk — 8 dirs × 6 frames   (frame_000…005)
├── pickup/           pick up — 8 dirs × 5 frames (frame_000…004)
├── throw/            throw  — 8 dirs × 7 frames  (frame_000…006)
├── metadata.json     PixelLab export metadata
└── GENERATION.md     (this file)
```

All frames are RGBA PNG (transparent), 124×124, low-top-down, game-ready.

## Source → asset

PixelLab character description (the v3 prompt with the mug dropped + "empty hands"):

```
Androgynous person in their early 30s with messy brown hair, friendly tired expression,
wearing an open red plaid flannel shirt over a green hoodie, blue jeans and sneakers.
Empty hands. Ordinary, working-class, warm and approachable.
```

## Animations (PixelLab template animations, `animate_character`)

| Folder | Requested as | Template id | Frames/dir | Reads as |
|---|---|---|---|---|
| `move/` | Move | `walk` | 6 | Walk cycle, mid-stride |
| `pickup/` | Pickup | `picking-up` | 5 | Crouch + reach down to grab |
| `throw/` | Throw | `throw-object` | 7 | Wind-up + overhand throw |

Each animation was generated for all 8 directions (1 generation/direction). They were queued **sequentially** because Tier-1 PixelLab caps at 8 concurrent jobs (8 directions = a full batch).

## Result

Clean, consistent base sprite with empty hands — good as the reusable player template the other outfits can branch from. All three template animations carry the character identity and read clearly at sprite scale (walk, crouch-grab, overhand throw). Game-ready for a top-down prototype.

**Next steps if wanted:** add idle/run/death etc. (same template flow); or use `create_character_state` to spin outfit variants (dive gear, the other surface looks) *off this template* so they share one identity instead of being independent text generations.
