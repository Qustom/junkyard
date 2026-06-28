# Game-Art Explorations — pixel-art sprites

Exploratory **pixel-art** assets for THE FAR YARD, generated with the **PixelLab AI API**. Unlike `art_workshop/concept_art/` (painterly mood/concept illustrations), this folder holds work in the game's **actual locked style** — top-down pixel art (`CLAUDE.md` → Conventions: "Pixel art only").

> **Still exploratory.** These are direction probes / placeholders, not final committed game assets. They do not lock character design; a human pixel artist / the Director owns canon.

---

## Batch: Player surface-life sprites (2026-06-27)

The five painterly **surface-life** player concepts ([`concept_art/explorations/20260627_d/`](../../../concept_art/explorations/20260627_d/), variants v2–v6) translated into **top-down 8-direction character sprites** via PixelLab `create_character` (v3 mode). Each concept's prompt was distilled into a PixelLab character description; each sprite folder holds all 8 directional rotations (S/N/E/W + diagonals) plus a `GENERATION.md`.

| Sprite folder | Source concept (painterly) | Look | PixelLab character id |
|---|---|---|---|
| [`surface_v2_rideshare_hoodie/`](surface_v2_rideshare_hoodie/) | `player_surface_life_v2_car_night` | Worn green hoodie (rideshare driver) | `d4d676dc-…590911` |
| [`surface_v3_diner_flannel/`](surface_v3_diner_flannel/) | `player_surface_life_v3_diner_counter` | Red flannel over hoodie, coffee mug | `ec495065-…1eb9e3` |
| [`surface_v4_gate_headlamp/`](surface_v4_gate_headlamp/) | `player_surface_life_v4_yard_gate_dusk` | Hoodie + flannel, **holding a glowing headlamp** | `d6bfef5e-…b27460` |
| [`surface_v5_mechanic_jacket/`](surface_v5_mechanic_jacket/) | `player_surface_life_v5_androgynous_casual` | Beanie + oversized mechanic jacket (most neutral) | `6b1dbcbc-…1ea980` |
| [`surface_v6_apartment_hoodie/`](surface_v6_apartment_hoodie/) | `player_surface_life_v6_apartment_debt` | Baggy grey hoodie, exhausted | `afd12037-…3c86b9d` |

### Basic player template + animations

An iteration of `surface_v3` with the **coffee mug removed (empty hands)** to serve as the reusable **base player sprite**, plus three template animations.

| Asset folder | What | Contents |
|---|---|---|
| [`player_basic_template/`](player_basic_template/) | Base player (flannel + hoodie, empty hands) | `rotations/` (8 dirs) + **`move/`** (walk, 8×6f) + **`pickup/`** (8×5f) + **`throw/`** (8×7f) |

- **Base character id:** `3cb56375-df23-4c9f-9aea-bbfe1a737268` (`create_character`, v3, low top-down, 64px/124px canvas).
- **Animations** via `animate_character` template mode: Move=`walk` (6f), Pickup=`picking-up` (5f), Throw=`throw-object` (7f) — all 8 directions; frames named `frame_000.png…`.
- **Cost:** 2 (base) + 3×8 (animations) = **26 PixelLab generations**. Queued sequentially (Tier-1 8-concurrent cap = one 8-direction animation at a time).

### Generation parameters (surface-life sprites)

- **Tool:** `mcp__pixellab__create_character`, **mode `v3`** (highest quality, always 8 directions, 2 generations each at this size).
- **View:** `low top-down` (~20° 3/4 RPG angle) — matches the top-down game.
- **Size:** 64px character, rendered on a 124–128px canvas (extra room for future animation frames).
- **Output:** 8 rotation PNGs per character (RGBA, transparent background), game-ready.
- **Cost:** 5 × 2 = **10 PixelLab generations** for the surface-life sprites (subscription; Tier 1 "Pixel Apprentice", 2000/cycle). v6 queued ~3 min after the first four due to the Tier-1 8-concurrent-job cap. The basic template + 3 animations added **26 more** → **batch total 36 generations**.

### Notes & next steps

- **Fidelity:** outfits carry over well from the painterly concepts; v4 even retained the glowing headlamp, and v5 is the cleanest gender-neutral read (good default-surface candidate).
- **Consistency:** each sprite was generated independently from text, so the face/hair vary slightly between outfits (same as the painterly concepts). To lock one identity across outfits, pick a base and use PixelLab's character-state / edit flow rather than fresh text each time.
- **Animation:** every character supports `animate_character` (idle/walk/etc. from PixelLab's template library). The five surface-life sprites are static rotation sets; the **`player_basic_template/`** asset demonstrates the animation flow (move / pickup / throw, 8 directions each).
- **Full re-download:** each character also has a PixelLab `download` endpoint (zipped) under `https://api.pixellab.ai/mcp/characters/<id>/download` if the rotation PNGs aren't enough.

## Folder convention

Each pixel-art subject is its own folder (`<subject>/`) holding its sprite frames + a `GENERATION.md` (source concept link, PixelLab params, character id, description, result). Add a row to the batch table above for each new sprite.
