# Concept Art — THE FAR YARD

Mood / tone-setting concept illustrations for **THE FAR YARD** (top-down roguelite extraction + life-sim). These are **painterly concept pieces** to establish atmosphere and palette — **not** the shippable in-game style, which is locked to top-down **pixel art** (see `CLAUDE.md` → Conventions: "Pixel art only").

Source of truth for tone & setting: `design/Junkyard_GDD.md`.

---

## Index

Ordered as the **depth gradient** (GDD §4) — warm surface → non-Euclidean deep — plus the warm town overworld.

| File | Band / Subject | Model | Notes |
|---|---|---|---|
| [`surface_junkyard_golden_hour_portal.png`](surface_junkyard_golden_hour_portal.png) | **Surface** — Bellweather Salvage | Nano Banana Pro | The core "cosmic dread with warmth" key piece: warm golden-hour salvage yard with a cold portal glowing wrong among the scrap. *(Has an unprompted title-logo — see its record.)* |
| [`surface_town_diner_golden_hour.png`](surface_town_diner_golden_hour.png) | **Surface town** — the life-sim overworld | Nano Banana 2 | The warm human pole the horror is earned against: cozy roadside diner at dusk, rideshare car out front. *(Intentional diegetic "OPEN/DINER" signage.)* |
| [`band1_near_city_dump_breakeryard.jpg`](band1_near_city_dump_breakeryard.jpg) | **Band 1 — Near** (a junkyard elsewhere *now*) | FLUX.1 dev | Foggy grey-blue dump/breaker's ravine; a towering scrap-entity silhouette — first "things that came through." Restrained, mundane-but-wrong. |
| [`band2_temporal_eras_fog.png`](band2_temporal_eras_fog.png) | **Band 2 — Temporal** (another *time*) | FLUX.2 Klein 9B | Era-blend: '50s rusts + war surplus + a spike of future-tech debris in fog. Desaturated nostalgia. |
| [`band3_lateral_broken_physics.png`](band3_lateral_broken_physics.png) | **Band 3 — Lateral** (another *reality*) | Nano Banana 2 | Physics-wrong scrapyard, impossible angles, iridescent aurora, glowing anomaly. Loud "impossible color." |
| [`band4_far_cosmic_dark.png`](band4_far_cosmic_dark.png) | **Band 4 — Far** (alien/magical) | Nano Banana Pro | Near-black void of colossal ribcage wreckage, pulsing lore-cores, a tiny lone figure. Non-Euclidean dark terminus. |

---

## Generation log

Per-image details — model, prompt, settings, cost, and how the result turned out — are in the matching `*_GENERATION.md` file:

- [`surface_junkyard_golden_hour_portal_GENERATION.md`](surface_junkyard_golden_hour_portal_GENERATION.md)
- [`surface_town_diner_golden_hour_GENERATION.md`](surface_town_diner_golden_hour_GENERATION.md)
- [`band1_near_city_dump_breakeryard_GENERATION.md`](band1_near_city_dump_breakeryard_GENERATION.md)
- [`band2_temporal_eras_fog_GENERATION.md`](band2_temporal_eras_fog_GENERATION.md)
- [`band3_lateral_broken_physics_GENERATION.md`](band3_lateral_broken_physics_GENERATION.md)
- [`band4_far_cosmic_dark_GENERATION.md`](band4_far_cosmic_dark_GENERATION.md)

---

## Model comparison (observed)

All generated via fal.ai. Quick read on the models used so far:

| Model | $ / image* | Output | Character | Best for |
|---|---|---|---|---|
| **Nano Banana Pro** | $0.15 | 1376×768 PNG | Most painterly, best restraint & dark-palette control, strong prompt adherence | Hero/key mood pieces, dark atmospheric bands |
| **Nano Banana 2** | $0.08 | 1376×768 PNG | Vivid, illustrative/comic-splash, high saturation | High-energy, colorful, "impossible color" scenes |
| **FLUX.1 dev** | ~$0.015 | 1024×576 JPEG | Restrained, cohesive, cinematic; cheapest with good mood | Cheap moody establishing shots |
| **FLUX.2 Klein 9B** | ~$0.0065 | 1024×576 PNG | Fast & cheapest; **prone to rendering label text into the image** | Cheap iterations — keep labels OUT of the prompt |

\* Nano Banana = flat per-image; FLUX = per-megapixel (figures are for the sizes used here, ~0.59 MP).

**Lesson learned:** text-prone models (FLUX.2 Klein especially) will *draw* any band name / label you put in the prompt as in-image signage. Keep band labels out of the prompt body and add a strong "no text, no words, no letters, no signs with writing" negative.

---

## Cost summary

| Batch | Pieces | Cost |
|---|---|---|
| Initial key piece | `surface_junkyard_golden_hour_portal` (Nano Banana Pro) | $0.15 |
| This batch (5, + 1 re-roll on band2) | bands 1–4 + town diner | ~$0.34 |
| **Folder total** | **6 images** | **≈ $0.49** |

---

## Conventions for this folder

- **Naming:** `<band_or_subject>_<descriptor>.png` (lowercase, underscores).
- **Generation record:** every image gets a sibling `<same_name>_GENERATION.md` documenting model, prompt, parameters, and result assessment.
- **This README is the index** — add a row to the table above for each new piece.
