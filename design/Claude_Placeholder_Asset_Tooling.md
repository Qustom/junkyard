# THE FAR YARD — Placeholder Asset Tooling for Claude

**Companion to:** `Claude_NonProgrammer_Roles.md`, `Junkyard_Technical_Design.md`
**Version 0.1 — research note**
**Premise:** Art and audio are the roles Claude is weakest at (§2, §3, §5 of the roles doc). Assume a human artist/composer replaces *all* art and audio before ship. The question here: what dedicated tools best let **Claude itself** stand up temporary, throwaway assets in the meantime — prioritizing things Claude can drive via API, code, or CLI rather than GUI tools a human has to operate.

---

## 0. Two principles for disposable assets

1. **Throwaway changes the calculus.** Because every asset here is scheduled for replacement, optimize for *speed, coverage, and zero cost* over fidelity or licensing permanence. A grey box with a label beats a beautiful sprite you'll delete. Keep all placeholders in clearly-marked folders (`/art/_placeholder`, `/audio/_placeholder`) so the human replacement pass has an obvious checklist.
2. **"Claude-drivable" has three tiers**, and the cheapest reliable one wins:
   - **Tier A — Code Claude writes and runs itself**, no external account, no network: Python/Pillow for images, NumPy/SoX/ffmpeg for audio, plus Godot's own built-in placeholders. Zero cost, zero licensing, instant. This should be the default for the truly disposable.
   - **Tier B — Free CC0 asset packs** Claude fetches and wires up. No generation, no risk. Kenney is the anchor.
   - **Tier C — Generative APIs / MCP servers** Claude calls when a placeholder needs to actually *read* as the thing (a recognizable enemy, a band's mood). Costs money and needs a key; use selectively.

The recommended stack uses all three: **Tier A + B for the bulk, Tier C for the few placeholders that need to communicate.**

---

## 1. Temporary ART

### Tier A — code-generated, zero dependency (Claude's default)

Claude can write and run these in the sandbox right now, no API key, no network:

- **Pillow (PIL) placeholder sprites/tiles:** labeled colored rectangles at exact engine sizes (16×16, 32×32, 48×48), e.g. a brown box stamped "JUNK-3" or a red box stamped "ENEMY-BAND2". Generate a whole content set in one script driven by the same `.tres` data the designer authored, so every item/enemy/tile that exists in data gets a matching placeholder automatically.
- **Programmatic tilesets:** Claude can emit a checkerboard/Wang-style placeholder tileset PNG + the Godot TileSet import, so level-design can proceed against real tile slots.
- **Godot built-ins:** `PlaceholderTexture2D`, `ColorRect`, and simple `_draw()` calls need *no external file at all* — Claude writes scenes that render boxes/shapes directly. Ideal for greybox milestones (M1).

This tier is the best fit for the project's debt-themed, cost-sensitive reality: it's free, instant, fully under Claude's control, and trivially deletable.

### Tier B — free CC0 packs (Claude fetches & wires)

- **Kenney (kenney.nl)** — the **All-in-1** pack is 60,000+ assets (2D sprites, tiles, UI, even SFX), all **CC0**, commercial use, no attribution. Perfect for prototyping/placeholder. Claude can pull a pack, pick fitting sprites, and write the import/atlas wiring. Single best free source.
- Itch.io CC0 collections (top-down sprite, CC0-UI packs) as supplements for specific gaps.

Because Kenney is CC0, there's no licensing cleanup later even if a stray placeholder survives longer than planned — a meaningful safety margin over AI-generated art.

### Tier C — generative APIs (selective, when a placeholder must communicate)

Use only where a grey box won't do — e.g. an enemy that must be visually distinguishable, or a band whose mood the team wants to feel during M2.

- **PixelLab** — the standout for this project. It's a **pixel-art API built for indie devs**, generating characters, **animations** (walk/run/attack via text or skeleton control), and **Wang tilesets** that tile seamlessly. Crucially it offers a **Python SDK *and* an MCP server**, so Claude can drive it directly from the coding environment — the only listed tool that closes Claude's biggest gaps (animation + consistent tilesets, §2/§3 of the roles doc) programmatically. Best first paid art tool to adopt.
- **fal.ai** — cheapest, fastest general image-gen infrastructure (985 endpoints, REST); good for concept/mood frames, UI icons, and non-pixel overworld backdrops. Claude drives it via simple REST calls.
- **Sprite AI / similar** — generate at exact engine pixel sizes with sprite-sheet export; more GUI-oriented, so better as a human-assist than Claude-driven.

> **Licensing flag:** AI-generated images sit in murky copyright territory (the US Supreme Court declined to hear an AI-art copyright case in March 2026). For *throwaway* placeholders this is low-risk, but it's another reason to keep them quarantined and replaced — don't let AI placeholders drift into shipped art.

---

## 2. Temporary AUDIO

### Tier A — code-generated, zero dependency

- **Synthesized SFX** via Python (NumPy/SciPy) or **SoX/ffmpeg**: beeps, blips, noise bursts, simple envelopes for pickups, hits, UI clicks. Claude writes a script that emits a labeled `.wav` per cue in the SFX list. Ugly but functional and free.
- **Placeholder music** as simple chiptune/looped tones generated in code — enough to test the per-band intensity-layer crossfades in the adaptive system without any real composition.

This covers the M1–M2 need to *hear something on the right event* with zero cost or accounts.

### Tier C — generative APIs (when placeholders should sound real)

- **ElevenLabs SFX (v2)** — best Claude-drivable SFX option. Single REST endpoint (`POST /v1/sound-generation`), text→effect, now with **seamless looping**, up to 30s, 48kHz, and **batch generation** for pipeline automation. Paid plans carry royalty-free commercial rights. Claude can script the whole cue list against it.
- **ElevenLabs TTS** — scratch **VO**, directly useful for Cyrus's recording transcripts (which the roles doc already has Claude authoring). Commercial rights on paid plans; 32 languages. Claude generates a temp read per transcript so dialogue scenes can be timed before a real VO actor is hired.
- **Music (Suno-class)** — note Suno has **no official public API**; access is via third-party providers (apiframe, sunor, APIPASS) with REST endpoints, pay-as-you-go (~$0.01–0.11/track), and stem export (Vocals/Drums/Bass/Melody) useful for the adaptive layer prototype. Licensing is provider- and tier-dependent — acceptable for temp tracks, but verify terms and keep them replaceable. **Stable Audio** (Stability) is an alternative with a first-party API if you want cleaner licensing.

> Quality caveat from the earlier research still holds: AI music "can feel repetitive" and precise in-game sync is manual. Fine for temp, not for ship.

---

## 3. How Claude actually reaches Tier C

None of these generative tools are in the connector registry today, so there are three practical paths, best first:

1. **Install the tool's MCP server as a connector** — **PixelLab ships an MCP server**; adding it lets Claude generate sprites/animations/tilesets directly in-session. This is the smoothest Claude-driven path and the one I'd set up first.
2. **Claude writes the scripts, you run them with your key** — for fal.ai / ElevenLabs / Suno-provider REST APIs, Claude writes the Python/SDK calls and the integration code; you supply the API key and run it (the sandbox's network is allowlisted, so direct calls from here may be blocked). This keeps secrets with you and still offloads all the code to Claude.
3. **GUI tools as human-assist** — Sprite AI, Aseprite, a DAW — Claude writes the briefs/prompts and does the import wiring; a human operates the tool.

---

## 4. Recommended placeholder stack

| Need | First choice | Why |
|---|---|---|
| Junk/item/prop sprites | **Tier A: Pillow, data-driven** | Free, instant, one sprite per `.tres` automatically |
| Tiles for level design | **Tier A box tileset → PixelLab Wang tiles** | Greybox free; upgrade to readable tiles via MCP when needed |
| Enemies (must be distinguishable) | **Kenney (B) → PixelLab (C)** | Free first; generate only the ones that must read |
| Character animation | **PixelLab (C)** | Only listed tool that does animation Claude can drive |
| UI/HUD icons | **Kenney CC0-UI (B) → fal.ai (C)** | Free icon sets cover most of it |
| SFX | **Tier A synth → ElevenLabs SFX (C)** | Code for blips; ElevenLabs for cues that must read, looping support |
| Music (per-band layers) | **Tier A loops → Suno-provider / Stable Audio (C)** | Test the adaptive crossfades cheaply first |
| Scratch VO (Cyrus) | **ElevenLabs TTS (C)** | Times dialogue scenes before hiring a VO actor |

**Bottom line:** Claude can cover almost all placeholder needs with **free, code-driven Tier A + Kenney CC0 (Tier B)** — appropriate for a debt-themed budget. Add exactly **two paid tools** when greyboxes stop being enough: **PixelLab** (closes the animation + tileset gap, has an MCP server Claude can drive) and **ElevenLabs** (SFX + scratch VO via clean REST). Everything stays quarantined in `_placeholder` folders for the human art/audio pass to replace.

---

## Sources

- [PixelLab API — Pixel Art Generation for Indie Game Developers](https://www.pixellab.ai/pixellab-api)
- [PixelLab MCP Server — GitHub](https://github.com/pixellab-code/pixellab-mcp)
- [AI API Comparison 2026: fal.ai vs Replicate — TeamDay.ai](https://www.teamday.ai/blog/ai-image-video-api-providers-comparison-2026)
- [12 best pixel art generators 2026 — Sprite-AI](https://www.sprite-ai.art/blog/best-pixel-art-generators-2026)
- [Kenney Game Assets All-in-1 (CC0)](https://kenney.nl/assets)
- [Kenney's Assets (CC0) — Godot Forum](https://forum.godotengine.org/t/kenneys-assets-free-and-creative-commons-cc0/36658)
- [ElevenLabs SFX Model v2 — looping, 30s, API](https://blockchain.news/ainews/elevenlabs-launches-sfx-model-v2-high-quality-ai-sound-effects-with-seamless-looping-and-extended-duration)
- [ElevenLabs Sound Effects — Documentation](https://elevenlabs.io/docs/overview/capabilities/sound-effects)
- [ElevenLabs Pricing & Commercial Rights 2026 — BIGVU](https://bigvu.tv/blog/elevenlabs-pricing-2026-plans-credits-commercial-rights-api-costs)
- [Top 7 Suno API Providers 2026 — FontsArena](https://fontsarena.com/blog/top-7-suno-api-providers-for-ai-music-generation-in-2026/)
- [Suno Commercial Use: Free vs Pro Rights 2026 — Dynamoi](https://dynamoi.com/learn/ai-music-distribution/suno-commercial-rights-explained)
- [AI art (copyright status) — Wikipedia](https://en.wikipedia.org/wiki/AI_art)
