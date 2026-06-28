# Generation Record — `surface_town_diner_golden_hour.png`

## Summary

| Field | Value |
|---|---|
| **Output file** | `surface_town_diner_golden_hour.png` |
| **Subject** | The Surface town — the warm life-sim overworld (diner at golden hour) |
| **Date** | 2026-06-27 |
| **Service** | fal.ai (MCP `mcp__fal-ai`) |
| **Model** | `fal-ai/nano-banana-2` (Google Nano Banana 2) |
| **Resolution** | 1376 × 768 px, PNG |
| **Aspect ratio** | 16:9 |
| **Images generated** | 1 |
| **Cost** | **$0.08** (Nano Banana 2: $0.08/image flat × 1) |
| **fal request id** | `019f0b04-050c-77c2-bd0b-6667d3bff49c` |

## Design intent

Visualize the **warm half** of the tone contrast — the life-sim overworld the horror is "earned" against (GDD Pillar 3 "The contrast is the point"; §11 Day Cycle "evening = limited life actions," the diner; §13 "warm, hand-painted, lived-in; warm acoustic/lo-fi overworld"). Subject: the town diner at golden-hour evening, the protagonist's rideshare car out front.

## Prompt

```
Atmospheric video game concept art. THE SURFACE TOWN — the warm human overworld the
horror is earned against. A cozy small-town American diner at golden-hour evening,
warm amber windows glowing, a few regulars inside, neon 'OPEN' sign, the protagonist's
beat-up rideshare car parked out front, telephone wires against a peach-and-lavender
sunset sky. Nostalgic, lived-in, hopeful-but-melancholy, lo-fi warmth. Painterly
hand-painted illustration, rich warm textures, cinematic golden lighting, high detail
concept art. No text, no title, no logo, no watermark, no UI.
```

Parameters: `{ "aspect_ratio": "16:9", "num_images": 1 }`

## Result

**Strong, evocative match.** A glowing amber roadside diner at dusk under peach-lavender sky, wet reflective street, a parked sedan out front — warm, lo-fi, lived-in, exactly the cozy counterweight to the bands. This is the warm pole the dread plays against.

**Note on text:** the prompt deliberately asked for a `neon 'OPEN' sign`, so the model drew **in-world diner signage** ("OPEN", "DINER", a "THE NEST"-style marquee). This is *diegetic* signage, not the game-title text the user asked to avoid — so it's kept intentionally. If a fully text-free plate is preferred, drop the "neon 'OPEN' sign" clause and add the strong no-text negative used on `band2`.
