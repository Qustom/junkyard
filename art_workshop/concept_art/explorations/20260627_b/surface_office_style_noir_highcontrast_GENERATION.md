# Generation Record — `surface_office_style_noir_highcontrast.jpg`

## Summary

| Field | Value |
|---|---|
| **Output file** | `surface_office_style_noir_highcontrast.jpg` |
| **Subject** | Surface — Bellweather Salvage office + yard before the portals |
| **Art style** | Film-noir / high-contrast chiaroscuro |
| **Date** | 2026-06-27 |
| **Service** | fal.ai (MCP `mcp__fal-ai`) |
| **Model** | `fal-ai/flux/dev` |
| **Resolution** | 1024 × 576 px, JPEG (~0.59 MP) |
| **Image size** | `landscape_16_9` |
| **Images generated** | 1 |
| **Cost** | **~$0.015** ($0.025/MP × 0.59 MP) |
| **fal request id** | `019f0b1c-e2cc-7791-b836-98dbaabf577b` |
| **Seed** | 1312917294 |

## Design intent

Style study pushing the *dread* pole instead of warmth — a lonely, near-monochrome night register with a single warm window as the only comfort. Tests how dark the surface can go and still read as "home."

## Prompt

```
[base scene, shifted to night-into-dusk] ... ART STYLE: stark film-noir, high-contrast
chiaroscuro, near-monochrome with a single warm amber accent from the window, deep inky
shadows, dramatic and lonely mood. No game title, no title card, no logo, no watermark,
no UI.
```

Parameters: `{ "image_size": "landscape_16_9", "num_images": 1 }`

## Result

**Moody and lonely — effective.** A dark blue-grey dusk over a forested junkyard road, the office shed's amber window + porch lamp the only warmth, scrap heaps receding into gloom. Strong, atmospheric, and the most overtly *unsettling* surface take.

**Caveats:** the office sign rendered as illegible scribble; **a faint garbled signature-like watermark appears bottom-right** (a FLUX artifact, not the game title — crop if used). The violet portal hint got lost in the darkness. **No game-title text.**
