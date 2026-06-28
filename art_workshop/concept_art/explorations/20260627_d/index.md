# Exploration Batch — 2026-06-27 (d) · Player character concept

> **Not direction.** Exploratory AI probes — see [`../README.md`](../README.md). These do not define the game's character design or art direction; they're a first visual pass on the protagonist.

## What this batch probed

A first concept pass on the **protagonist** of THE FAR YARD, all via **Nano Banana Pro**, grounded in the GDD: a laid-off engineer drowning in student debt who inherited Bellweather Salvage and now dives the junkyard — **"an engineer, not a soldier"** who fights with jury-rigged tools (Pillar 2), with a slot-based pack and improvised gear (§6–§7). The character is **player-named, default-neutral gender** (§14), so the design aims androgynous / ordinary / working-class. Five angles: dive-gear design, action, face, turnaround, and the warm surface-life look.

## Index

| File | Subject | Aspect | Note |
|---|---|---|---|
| [`player_fullbody_salvager.png`](player_fullbody_salvager.png) | Full-body dive-gear design | 3:4 | **Primary reference.** Coveralls + scrap armor, slot backpack, headlamp, breather. Clean design-sheet pose. |
| [`player_turnaround_sheet.png`](player_turnaround_sheet.png) | Front/side/back turnaround | 16:9 | Consistent 3-view model sheet; backpack + saw-on-pole read from behind. Good sprite reference. |
| [`player_action_magnet_grapple.png`](player_action_magnet_grapple.png) | Action dive pose | 16:9 | Mid-dive leap firing the magnet-grapple; saw-on-pole stowed; cold-violet junk behind. |
| [`player_portrait.png`](player_portrait.png) | Close-up bust portrait | 3:4 | Weary-but-kind face, grime, headlamp + respirator. Emotionally readable. *(reads a touch masculine — see record.)* |
| [`player_surface_life.png`](player_surface_life.png) | Surface / everyday look | 3:4 | Hoodie + flannel, coffee, rideshare phone, golden-hour town — the warm life-sim pole. |

### Surface-life iterations (more versions of `player_surface_life`)

| File | Variation | Note |
|---|---|---|
| [`player_surface_life_v2_car_night.png`](player_surface_life_v2_car_night.png) | Late shift in the rideshare car | Driver's seat, glowing phone mount, rainy city lights — lonely late-shift. **Strong.** |
| [`player_surface_life_v3_diner_counter.png`](player_surface_life_v3_diner_counter.png) | At the diner counter | Coffee + pie, flannel, half-smile, amber light — warmest/most social. |
| [`player_surface_life_v4_yard_gate_dusk.png`](player_surface_life_v4_yard_gate_dusk.png) | At the junkyard gate | Ordinary clothes + headlamp in hand, faint violet glow ahead — "between two lives." Most thematic. |
| [`player_surface_life_v5_androgynous_casual.png`](player_surface_life_v5_androgynous_casual.png) | Most gender-neutral casual | Mechanic jacket + beanie, plain bg — cleanest neutral/androgynous read. |
| [`player_surface_life_v6_apartment_debt.png`](player_surface_life_v6_apartment_debt.png) | Late night with the debt | Couch, laptop, scattered bills — quiet melancholy; the debt stakes. |

## Generation log

- [`player_fullbody_salvager_GENERATION.md`](player_fullbody_salvager_GENERATION.md)
- [`player_turnaround_sheet_GENERATION.md`](player_turnaround_sheet_GENERATION.md)
- [`player_action_magnet_grapple_GENERATION.md`](player_action_magnet_grapple_GENERATION.md)
- [`player_portrait_GENERATION.md`](player_portrait_GENERATION.md)
- [`player_surface_life_GENERATION.md`](player_surface_life_GENERATION.md)
- [`player_surface_life_v2_car_night_GENERATION.md`](player_surface_life_v2_car_night_GENERATION.md)
- [`player_surface_life_v3_diner_counter_GENERATION.md`](player_surface_life_v3_diner_counter_GENERATION.md)
- [`player_surface_life_v4_yard_gate_dusk_GENERATION.md`](player_surface_life_v4_yard_gate_dusk_GENERATION.md)
- [`player_surface_life_v5_androgynous_casual_GENERATION.md`](player_surface_life_v5_androgynous_casual_GENERATION.md)
- [`player_surface_life_v6_apartment_debt_GENERATION.md`](player_surface_life_v6_apartment_debt_GENERATION.md)

## Notes

- **Model:** all 5 via `fal-ai/nano-banana-pro` (the on-style reference winner from prior batches). Painterly character-design register, not the game's locked top-down pixel art — these are direction/mood references to aim sprite work at.
- **Consistency:** without a fixed reference image, the five generations vary slightly in face/age/build (the portrait skews more masculine; surface-life skews younger/androgynous). For a locked design, pick the strongest base (likely `player_fullbody_salvager`) and regenerate the others *from* it as an image reference to lock identity.
- **No game-title text** in any image; gear matches the GDD tool set (magnet-grapple, saw-on-pole, breather rig, headlamp, slot pack).

## Cost

10 images × $0.15 (Nano Banana Pro flat per-image) = **$1.50** (initial 5-angle pass $0.75 + surface-life iteration $0.75).

## Recommendation (for the Director — not a decision)

`player_fullbody_salvager` + `player_turnaround_sheet` are the strongest design anchors; `player_surface_life` nails the warm contrast pole. Open calls for the Director: **how androgynous/neutral** to push the default look, and how much scavenged-armor bulk vs. plain-coveralls the silhouette should carry. None of this sets canon — flagged for review if any piece should inform the character spec.
