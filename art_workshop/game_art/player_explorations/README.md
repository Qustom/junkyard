# Game-Art Explorations

This folder holds **dated, exploratory pixel-art batches** for THE FAR YARD — assets generated in the game's **actual locked style** (top-down **pixel art**, `CLAUDE.md` → Conventions: "Pixel art only"), typically via the **PixelLab AI API**.

This is the pixel-art counterpart to [`../../concept_art/explorations/`](../../concept_art/explorations/): concept-art explorations are painterly *mood/direction* probes (deliberately off-style); game-art explorations are *in-style* sprites/tiles meant to feed real assets.

## What these are — and are NOT

> **These explorations do NOT define the game's art or character design in any way.**

They are quick PixelLab-generated probes / placeholders — useful for feeling out how a design reads as an actual game sprite, and as scaffolding a human pixel artist can refine. They are **not** committed game assets and do **not** lock character/tile design.

**However**, an exploration here *may be referenced from outside this folder* (a visual-language spec, a task spec, a Role Playbook, the GDD/TDD) when something in it is chosen to **inform** or seed a real asset. Direction is set by those canonical documents and by the human pixel artist / Director — not by anything in here. This folder remains the non-authoritative scratchpad.

## Batches

| Batch | Contents |
|---|---|
| [`20260627/`](20260627/) | Player **surface-life** sprites — the five painterly surface-life player concepts (`concept_art/explorations/20260627_d/` v2–v6) translated into top-down 8-direction character sprites via PixelLab `create_character` (v3 mode). |

---

## Required template (every game-art exploration batch MUST follow this)

Each batch is its own **dated folder** `YYYYMMDD/` (the date generated). A second batch on the same day appends a suffix: `YYYYMMDD_b`, `YYYYMMDD_c`, … Inside a batch:

```
explorations/
└── YYYYMMDD/                              ← one folder per batch, named by date
    ├── index.md                           ← REQUIRED — the batch index (see below)
    └── <asset_name>/                       ← REQUIRED — one folder PER asset (sprite/tileset/object)
        ├── <frame>.png  (× N)              ← the pixel-art frames (e.g. 8 directional rotations)
        └── GENERATION.md                   ← REQUIRED — one per asset folder
```

> **Format note vs. concept_art:** concept-art batches are *flat* (each image is a file with a sibling `<name>_GENERATION.md`). Game-art batches add **one extra folder layer per asset**, because a single pixel-art asset is usually a *set* of files (directional rotations, animation frames, tileset cells). So the per-asset `GENERATION.md` lives **inside** the asset's folder, not beside it.

Rules:
1. **Batch folder name = `YYYYMMDD`** of generation (suffix `_b`, `_c`, … for same-day batches).
2. **Each asset = its own subfolder** holding all its frames + exactly one `GENERATION.md`. No loose frame PNGs at the batch root.
3. **Every batch has exactly one `index.md`** (not `README.md` — that name is reserved for *this* explorations-level file).
4. **Naming:** asset folders `<subject>_<descriptor>/`, lowercase + underscores; frames named by their role (`south.png`, `walk_01.png`, `tile_03.png`, …).
5. Add a row to the **Batches** table above when a new batch folder is created.

### `index.md` (per-batch index) must contain

- **Title + one-line summary** of what the batch was probing.
- **Asset table:** each asset folder · its source (e.g. the concept-art image it derives from, linked) · short look description · tool/id reference.
- **Generation parameters** shared across the batch (tool, mode, view, size, output format, cost in PixelLab generations).
- **Notes / next steps** (fidelity, consistency, animation, re-download).

### `GENERATION.md` (per-asset record) must contain

- **Summary table:** subject · date · service (PixelLab) · **tool + mode** · body/view · size/canvas · directions or frame count · **asset/character id** · cost (generations) · files.
- **Source → asset** — the upstream concept/prompt it derives from (link it) + the exact description/params handed to PixelLab.
- **Result** — honest read of the sprite: what carried over, caveats (lost detail at sprite scale, identity drift), and follow-ups (e.g. animation, identity-lock).

> Use the assets in [`20260627/`](20260627/) as the reference implementation of this template.
