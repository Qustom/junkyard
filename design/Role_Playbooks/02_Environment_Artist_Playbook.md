# Playbook 02 — 2D Environment / Tile Artist

**Subagent:** `environment-artist` · **Owns:** visual-language spec, placeholders, pipeline code · **Cannot:** paint shippable pixel art (human artist owns every shippable pixel + the final aesthetic call).

## References
`design/Junkyard_Technical_Design.md` §4–§5, `design/Claude_Placeholder_Asset_Tooling.md`, research `02_band_visual_language_study.md`, `03_readable_junk_study.md`.

## Art direction (fixed)
Hand-authored **pixel art only** — no Blender/3D/rendered-to-2D. Band contrast comes from palette, silhouette, lighting/shaders, and post on shared 2D assets.

## Visual-language spec to apply
- One **shared master palette** + Dead Cells **grayscale + gradient-map** pipeline.
- Escalate dread along **five dials** — geometry, symmetry, colour logic, light motivation, familiarity — not just "darker."
- Keep a **band-independent legibility layer**: player, loot, exits, threats always highest-contrast.

## Workflows
1. **Maintain the visual spec** with do/don't examples per band; make it enforceable.
2. **Placeholders (default = free):**
   - **Tier A** — Python/Pillow labeled box tiles/props at the locked pixel size; a checkerboard/Wang placeholder tileset + Godot `TileSet` import; or `PlaceholderTexture2D`/`ColorRect` for pure greybox (M1).
   - **Tier B** — pull Kenney CC0 tiles/props.
   - **Tier C** — generate Wang tilesets via **PixelLab MCP** only when a band's mood must be felt in M2.
   Quarantine everything in `art/_placeholder/`.
3. **Pipeline:** lock conventions (naming, base resolution, pixels-per-unit, filter-off, palette source) → write a naming enforcer, batch import-preset script, spritesheet/JSON slicer, and palette checker → commit `.import` settings. Lead with built-in `TileSet`/`TileMapLayer`.

## Tools
PixelLab MCP (Wang tiles/props/sprites), fal.ai MCP (concept/mood frames), Kenney CC0 packs. Tier A/B come first; Tier C is selective and costs credits.

## Definition of done
Placeholders labeled + quarantined; pipeline enforced by script; visual spec documented and applied; no generated art leaks toward ship.

## Handoff
Readability rules are **shared one-source** with `ui-ux-designer`. Close with worklog + commit; flag any deviation from the pixel-only / five-dial direction.
