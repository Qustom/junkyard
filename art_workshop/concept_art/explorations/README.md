# Concept Art — Explorations

This folder holds **dated, exploratory concept-art batches** for THE FAR YARD.

## What these are — and are NOT

> **These explorations do NOT define the art direction of the game in any way.**

They are quick, AI-generated mood/idea probes — throwaway visual brainstorming used to *feel out* tone, palette, and the depth gradient. They are **not** decisions, not style guides, and not the shippable look (the game is locked to top-down **pixel art** per `CLAUDE.md` → Conventions; these painterly pieces are deliberately off-style).

**However**, an exploration here *may be referenced from outside this folder* (e.g. by the visual-language spec, a GDD/TDD art note, a task spec, or a Role Playbook) when something in it is chosen to **inform** the direction. Direction is set by those canonical documents — not by anything in here. If a piece ends up cited, the citation lives in the referencing doc; this folder remains the non-authoritative scratchpad.

## Batches

| Batch | Contents |
|---|---|
| [`20260627/`](20260627/) | First mood pass — Surface key piece + warm town + the four-band depth gradient (Near → Temporal → Lateral → Far). 6 images across several fal.ai models. |
| [`20260627_b/`](20260627_b/) | Surface art-style study — the Bellweather Salvage office + junkyard before the portals (same scene as the liked golden-hour piece) rendered in 7 styles: pixel-art, painted adventure-bg, gouache, Ghibli anime, comic ink, noir, watercolor. |
| [`20260627_c/`](20260627_c/) | "One prompt, every model" sweep — the winning 16-bit pixel-art prompt run through **118** text-to-image models on fal.ai (every runnable distinct endpoint) to compare interpretations. Consolidated `index.md` (no per-image records). |
| [`20260627_d/`](20260627_d/) | First **player character** concept pass (Nano Banana Pro) — the engineer-salvager protagonist in 5 angles: full-body dive gear, turnaround sheet, action pose, portrait, and warm surface-life look. |

---

## Required template (every exploration batch MUST follow this)

Each batch is its own **dated folder** `YYYYMMDD/` (the date the batch was generated). Inside it:

```
explorations/
└── YYYYMMDD/                                   ← one folder per batch, named by date
    ├── index.md                                ← REQUIRED — the batch index (see below)
    ├── <name>.<ext>                            ← each generated image (png/jpg)
    └── <name>_GENERATION.md                    ← REQUIRED — one per image, same basename
```

Rules:
1. **Folder name = `YYYYMMDD`** of generation. A second batch on the same day appends a suffix: `YYYYMMDD_b`, `YYYYMMDD_c`, …
2. **Every image gets a sibling `<same_basename>_GENERATION.md`** — no orphan images.
3. **Every batch has exactly one `index.md`** (not `README.md` — that name is reserved for *this* explorations-level file).
4. **Image naming:** `<subject_or_band>_<descriptor>.<ext>`, lowercase, underscores.
5. Add a row to the **Batches** table above when a new batch folder is created.

### `index.md` (per-batch index) must contain

- **Title + one-line summary** of what the batch was probing.
- **Index table** of every image: file link · subject/band · model · short note.
- **Generation log** — links to each `*_GENERATION.md`.
- **Model comparison** — observed strengths/weaknesses of the models used.
- **Cost summary** — per-batch and running total.

### `<name>_GENERATION.md` (per-image record) must contain

- **Summary table:** output file · subject · date · service · **model** · resolution · aspect ratio / image size · images generated · **cost** · fal request id · seed (if returned).
- **Design intent** — what it's probing, grounded in the GDD (cite sections).
- **Prompt** — the exact prompt used (in a code block) + the input parameters.
- **Result** — honest assessment of the output: what landed, caveats (stray text, off-palette, re-rolls), and suggested follow-ups.

> Use the files in [`20260627/`](20260627/) as the reference implementation of this template.
