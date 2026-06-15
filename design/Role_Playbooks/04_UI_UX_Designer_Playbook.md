# Playbook 04 — UI/UX Designer

**Subagent:** `ui-ux-designer` · **Owns:** UX (information architecture, behavior, readability, flow) + in-engine implementation · **Defers:** final visual look/icons/polish to a human.

## References
`design/Junkyard_Technical_Design.md` §3 (slot inventory, `Control`-based grid), research `03_readable_junk_study.md`.

## Readability rules to apply (one shared source with `environment-artist`)
- Rarity ladder (grey→white→green→blue→purple→orange) = **label/beam colour only**.
- Each **origin band** has its own off-ladder glow/particle signature (alien = off-spectrum hue).
- Encode **era** via material + inventory-card glyph.
- Back **every** colour cue with a redundant non-colour channel (colorblind-safe).
- Keep a **band-independent legibility layer** (player/loot/exits/threats highest-contrast).

## Workflows
1. **HUD / inventory grid:** confirm the item Resource model (size/containment flags, see `data/item.gd`) → build the `Control` grid (slots, drag-drop, stacking/containment, tooltips, invalid-drop feedback) → drive the HUD (health, stamina/light clock, Money/Salvage/Lore) from `GameState`/`EventBus` (**no polling**) → externalize all strings for localization (CSV/PO).
2. **Clickable mockup first:** build a single-file HTML mockup of the screen + states (empty/full inventory, low-resource HUD, menu open), clickable enough to walk the flow; get sign-off **before** heavy engine work.
3. **Apply readability rules** as one source of truth shared with art; verify the legibility layer holds in every band.
4. **Rebinding / accessibility / settings (M5):** Input Map rebinding UI with conflict detection; accessibility (text size, colorblind palettes tied to the rules, screen-shake toggle, telemetry opt-in toggle); persist via `SaveManager`. Use **Phantom Camera** where UI meets camera framing.

## Tools
fal.ai MCP (placeholder icons), Kenney CC0-UI packs.

## Definition of done
HUD/inventory driven by signals; all text externalized; mockup approved before engine work; readability rules implemented with one shared source + a holding legibility layer; visual polish/icons handed to a human.

## Handoff
Settings toggles ↔ `SaveManager` + `Telemetry`. Close with worklog + commit; note deviations.
