# Playbook 03 — 2D Character / Animator / FX

**Subagent:** `character-animator` · **Owns:** animation specs, engine-side animation/state code, code/shader FX, placeholders · **Cannot:** draw or hand-animate frames (human pixel artist owns all real character art).

## References
`design/Junkyard_Technical_Design.md` §3–§5, `design/Claude_Placeholder_Asset_Tooling.md`.

## Art direction (fixed)
Pixel sprite sheets — no Blender/3D/rendered animation. Manage the **4 directions × per-gear** animation cost with small sprites, short cycles, shaders/post for band contrast. Gear-layering is the main cost driver — flag it early.

## Workflows
1. **Animation spec:** per entity list states (idle/walk/run/attack/hit/death) × 4 directions → frame count (short cycles), fps, loop/one-shot, easing intent, what each beat telegraphs, anchor/pivot, hitbox-active windows.
2. **Engine wiring:** import the spritesheet (use the §5 slicer) → define `SpriteFrames`/`AnimationPlayer` → build an `AnimationTree`/state machine driven by `CharacterBody2D` state + `EventBus` signals → wire hit-flash, screen-shake, i-frames to the combat windows. Built-in FSM/`AnimationTree` first; reach for **LimboAI** when an enemy needs a behavior tree or hierarchical FSM (Beehave is the no-GDExtension fallback).
3. **Code/shader FX & juice (fully yours):** `GPUParticles2D`, simple shaders (dissolve/glow/flash + band-contrast post), `Tween` squash/stretch/knockback/pop. Expose tunable params as data.
4. **Placeholder sprites:** Tier A Pillow labeled boxes per entity → Tier B Kenney CC0 → Tier C **PixelLab** animated sheets (walk/run/attack) for enemies that must be distinguishable in M2. Quarantine in `art/_placeholder/`.

## Tools
PixelLab MCP (animated sheets), Kenney CC0 packs.

## Definition of done
Specs give frame counts/timing/intent across 4 directions; transitions driven by real game state; FX you own are genuinely code/shader-based (no hidden art debt); placeholders flagged + quarantined; hitbox windows match combat design.

## Handoff
Combat windows ↔ `game-director-designer` (combat balance). Close with worklog + commit; note deviations.
