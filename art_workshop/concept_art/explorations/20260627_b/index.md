# Exploration Batch — 2026-06-27 (b) · Surface art-style study

> **Not direction.** These are exploratory AI-generated style probes — see [`../README.md`](../README.md). They do not define the game's art direction; they may be *referenced* by canonical docs that do.

## What this batch probed

The **Surface** — the Bellweather Salvage **office** and the **junkyard area before the portals**. Building on the liked `surface_junkyard_golden_hour_portal` piece (in the [`../20260627/`](../20260627/) batch), this holds the **same scene** (warm golden-hour yard, office shed, faint uncanny portal glow deep in the scrap) rendered in **7 different art styles** to compare rendering registers. The game's locked style is top-down **pixel art**, so a pixel-art take is included as the on-style anchor. No "THE FAR YARD" game title in any image (the legible "BELLWEATHER SALVAGE" is the in-world office sign).

## Index

| File | Art style | Model | Note |
|---|---|---|---|
| [`surface_office_style_pixelart_16bit.png`](surface_office_style_pixelart_16bit.png) | 16-bit pixel art (SNES-era) | Nano Banana Pro | **On-style anchor** (game is pixel art). Crisp, cohesive, legible sign, clear portal glow. Top pick. |
| [`surface_office_style_retro_adventure_painted.png`](surface_office_style_retro_adventure_painted.png) | '90s point-and-click painted bg (LucasArts/Sierra) | Nano Banana Pro | Closest to the liked original in spirit. Inviting, explorable, one wrong note. Top pick. |
| [`surface_office_style_gouache_storybook.png`](surface_office_style_gouache_storybook.png) | Gouache storybook | Nano Banana 2 | Cleanest "warmth + one wrong note" balance; tactile brush texture. |
| [`surface_office_style_ghibli_anime.png`](surface_office_style_ghibli_anime.png) | Studio Ghibli-style anime | Nano Banana 2 | Very warm/cozy — possibly too charming for cosmic-dread; good warm pole. |
| [`surface_office_style_comic_ink.jpg`](surface_office_style_comic_ink.jpg) | Graphic-novel ink (Mignola-esque) | FLUX.1 dev | Bold silhouettes, deep one-point perspective into a sunset ravine. |
| [`surface_office_style_noir_highcontrast.jpg`](surface_office_style_noir_highcontrast.jpg) | Film-noir high-contrast | FLUX.1 dev | Pushes the *dread* pole; lonely night, single warm window. Has a stray garbled watermark (see record). |
| [`surface_office_style_watercolor.png`](surface_office_style_watercolor.png) | Loose watercolor | FLUX.2 Klein 9B | Soft mood swatch; lowest fidelity; fully text-free. Cheapest. |

## Generation log

- [`surface_office_style_pixelart_16bit_GENERATION.md`](surface_office_style_pixelart_16bit_GENERATION.md)
- [`surface_office_style_retro_adventure_painted_GENERATION.md`](surface_office_style_retro_adventure_painted_GENERATION.md)
- [`surface_office_style_gouache_storybook_GENERATION.md`](surface_office_style_gouache_storybook_GENERATION.md)
- [`surface_office_style_ghibli_anime_GENERATION.md`](surface_office_style_ghibli_anime_GENERATION.md)
- [`surface_office_style_comic_ink_GENERATION.md`](surface_office_style_comic_ink_GENERATION.md)
- [`surface_office_style_noir_highcontrast_GENERATION.md`](surface_office_style_noir_highcontrast_GENERATION.md)
- [`surface_office_style_watercolor_GENERATION.md`](surface_office_style_watercolor_GENERATION.md)

## Method note

To isolate **style** as the only variable, the base scene prompt was held constant across all 7 images; only the trailing `ART STYLE:` clause changed (the noir variant additionally shifted golden-hour → night-into-dusk to suit the register). This makes the batch a clean side-by-side style comparison of the same subject.

## Model comparison (observed this batch)

| Model | $ / image* | Style fidelity here | Notes |
|---|---|---|---|
| **Nano Banana Pro** | $0.15 | Best — held pixel-art and painted-bg styles crisply, kept the sign legible | Used for the two anchor styles |
| **Nano Banana 2** | $0.08 | Strong, vivid, illustrative | Great for gouache/anime warmth |
| **FLUX.1 dev** | ~$0.015 | Good mood, cheaper, JPEG out | Comic & noir; can add stray signature watermarks |
| **FLUX.2 Klein 9B** | ~$0.0065 | Softest/lowest detail; **text-prone** | Watercolor; sign omitted + hard no-text negative (lesson from batch `20260627`) |

\* Nano Banana = flat per-image; FLUX = per-megapixel (~0.59 MP at the sizes used here).

## Cost summary

| | Pieces | Cost |
|---|---|---|
| This batch | 7 images (2 Pro, 2 Nano-2, 2 FLUX.1 dev, 1 FLUX.2 Klein) | **≈ $0.50** |

Running concept-art folder total across batches: `20260627` (~$0.49) + `20260627_b` (~$0.50) ≈ **$0.99**.

## Recommendation (for the Director — not a decision)

For a top-down pixel-art game, **`pixelart_16bit`** is the natural on-style anchor and the **`retro_adventure_painted`** / **`gouache_storybook`** pieces are the strongest *mood/illustration* references to aim that pixel art at. The noir take is a useful "how dark can the surface go" data point. None of this sets direction — flagged for the Director if any of it should be cited by the visual-language spec.
