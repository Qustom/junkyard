# Generation Record — `surface_v2_rideshare_hoodie/`

Pixel-art character sprite derived from the painterly concept [`player_surface_life_v2_car_night`](../../../../concept_art/explorations/20260627_d/player_surface_life_v2_car_night.png).

| Field | Value |
|---|---|
| **Subject** | Protagonist surface look — worn green hoodie (off-duty rideshare driver) |
| **Date** | 2026-06-27 |
| **Service** | PixelLab AI (MCP `mcp__pixellab`) |
| **Tool / mode** | `create_character` · **v3** (highest quality, 2 generations) |
| **Body / view** | humanoid · low top-down (3/4 RPG) |
| **Size** | 64px character on 124×124 canvas |
| **Directions** | 8 (S, N, E, W, SE, SW, NE, NW) |
| **Character id** | `d4d676dc-2fe5-4a0f-a7cb-165c97590911` |
| **Cost** | 2 PixelLab generations (subscription) |
| **Files** | `south.png` … `north-west.png` (8 rotation sprites, RGBA) |

## Source → sprite

Distilled the v2 concept's prompt (rideshare driver in a faded hoodie) into a PixelLab character description:

```
Androgynous person in their early 30s with messy brown hair, tired weary expression,
wearing a worn dark green hoodie, blue jeans and sneakers. An off-duty rideshare driver.
Ordinary, working-class, relatable.
```

## Result

Clean top-down 8-direction sprite; the dark-green hoodie and ordinary working-class read carry over from the concept. Game-ready (top-down, the project's locked style). Idle/walk animations can be added via `animate_character` if wanted.
