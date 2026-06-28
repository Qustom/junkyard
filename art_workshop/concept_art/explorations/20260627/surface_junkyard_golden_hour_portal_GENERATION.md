# Generation Record — `surface_junkyard_golden_hour_portal.png`

## Summary

| Field | Value |
|---|---|
| **Output file** | `surface_junkyard_golden_hour_portal.png` |
| **Subject** | Surface band — Bellweather Salvage junkyard, golden hour, with an uncanny portal |
| **Date** | 2026-06-27 |
| **Service** | fal.ai (via MCP `mcp__fal-ai` tools) |
| **Model** | `fal-ai/nano-banana-pro` (Google Nano Banana Pro — state-of-the-art image generation/editing) |
| **Resolution** | 1376 × 768 px, 8-bit RGB PNG (~1.9 MB) |
| **Aspect ratio** | 16:9 |
| **Images generated** | 1 |
| **Cost** | **$0.15** (Nano Banana Pro: $0.15/image flat × 1) |
| **fal request id** | `019f0af7-0def-7032-927f-e1f64dc34525` |

---

## Design intent

Establish the GDD's central tonal pillar — **"cosmic dread with warmth"** (`design/Junkyard_GDD.md` §2 Pillar 3, §13 Art & Audio Direction). The chosen subject is the **Surface band**: the inherited *Bellweather Salvage* lot (§3 Story & Premise), which should read as warm, mundane, and lived-in *except* for the one impossibility — a portal that "doesn't add up" (§1 High Concept, §4 The World).

Source grounding from the GDD:
- **Warmth:** "the surface is warm, hand-painted, lived-in" (§13); inherited junkyard, Cyrus's office shed (§3).
- **Dread:** "Diegetic dread. Horror through wrongness" (§13); the portals and space that doesn't add up (§1, §4).
- The contrast itself is the point (Pillar 3: "The contrast is the point").

---

## Process

1. **Read the GDD** (`design/Junkyard_GDD.md`) to extract setting, tone, and the warm/uncanny contrast.
2. **Model selection** — called `mcp__fal-ai__recommend_model` for "high-quality atmospheric concept art illustration, painterly mood piece." Top-ranked text-to-image options were FLUX.2 Klein 9B, Nano Banana 2, GPT Image 2, FLUX.1 dev, and **Nano Banana Pro**. Chose **Nano Banana Pro** for top-tier quality and strong prompt adherence on detailed atmospheric scenes.
3. **Generate** — single `mcp__fal-ai__run_model` call, returned `status: completed` synchronously (no polling needed).
4. **Download** — `curl` the returned image URL into this folder under a descriptive name.
5. **Verify** — read the PNG back to confirm it matched the brief.

### Exact prompt used

```
Atmospheric video game concept art for 'THE FAR YARD', a roguelite extraction game.
A sprawling, cluttered American junkyard at golden hour — towering piles of rusted
cars, scrap metal, broken appliances, old machinery, tangled wire, and tarp-covered
heaps. A small lived-in salvage yard office shed with a flickering warm light,
'BELLWEATHER SALVAGE' faded hand-painted sign. The mood is warm, nostalgic,
melancholy — long golden shadows, dust motes in the air. But hidden among the scrap,
an uncanny WRONGNESS: a faint impossible portal glowing with cold otherworldly
violet-cyan light deep between two car-stacks, casting an unnatural glow that doesn't
belong in the warm scene — cosmic dread leaking into a cozy place. Painterly,
hand-painted illustration style, rich textures, cinematic lighting, high detail,
moody and evocative concept art. Wide establishing shot.
```

### Input parameters

```json
{
  "prompt": "<above>",
  "aspect_ratio": "16:9",
  "num_images": 1
}
```

---

## Result

**Outcome: strong match to the brief.** The image delivers the intended tonal contrast:

- **Warmth landed:** golden-hour sun flare over stacked rusted cars, long warm shadows, the `BELLWEATHER SALVAGE` shed with a glowing warm-lit window on the left. Reads as nostalgic and lived-in, exactly per §13.
- **Dread landed:** a vivid violet/cyan **spiral portal** sits between the scrap stacks at center, casting cold light that visibly clashes with the warm scene — the "wrongness leaking into a cozy place" the brief asked for.
- **Composition:** clean wide establishing shot; readable silhouette of the yard; clear focal hierarchy (shed → portal → junk piles).

### Caveats / notes

- The model **added a `THE FAR YARD` title-logo treatment** (bottom-right) unprompted. Fine as a key-art mock, but should be **cropped out or regenerated without text** if a clean plate is needed.
- The portal rendered as a clean "spiral" — more polished/arcane than "faint." If a subtler, more unsettling effect is wanted, dial down the portal description (e.g. "barely-visible shimmer / heat-haze tear" instead of "glowing portal").
- This is a **painterly concept piece**, not the in-game pixel-art style. Use for mood/marketing/internal direction only.

### Suggested follow-ups

- Generate matching mood pieces for the deeper bands (**Near → Temporal → Lateral → Far**) to visualize the GDD's palette gradient: "familiar grime → desaturated nostalgia → impossible color → non-Euclidean dark" (§13).
- A clean (text-free) variant of this Surface plate.
- An interior/cozy-contrast piece (the town/diner side) to show the warm half the horror is earned against.

---

## Reproduce

Via the fal.ai MCP tools in this environment:

1. `mcp__fal-ai__run_model` with `endpoint_id: "fal-ai/nano-banana-pro"` and the input JSON above.
2. `curl -sS -o <name>.png "<result.images[0].url>"` into this folder.

> Note: the fal CDN URL from the original run is time-limited and may expire — re-run the model to regenerate rather than relying on the old link.
