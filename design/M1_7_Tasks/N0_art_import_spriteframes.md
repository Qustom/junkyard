# N0 — Foundation: art import + `SpriteFrames` + signal seam (Phase-2 design)

**Milestone:** M1.7 (Player Embodiment) · **Task id:** N0 · **Roles:** character-animator + general-purpose
**Authored:** 2026-06-27 (Phase 2, expanding `design/M1_7_Tasks/M1.7_Breakdown.md` §3 N0 row, §6, §7 N0 bullet).
**Status:** Phase 2 design — open questions below to be resolved Phase 3 (fresh eyes) / Director.

N0 is the **single-writer foundation pass** that unblocks the M1.7 build wave. It does three file-disjoint things:
1. **Copies** the `player_basic_template` PNG frame sequences out of `art_workshop/` (repo root, outside the Godot
   project) into `Game/art/player/…` so `res://` can see them.
2. **Authors** the `SpriteFrames` resource (`res://entities/player/player_frames.tres`) — the 8-direction × 4-state
   animation set N1's `AnimatedSprite2D` plays.
3. **Pre-declares** the one new EventBus signal `debug_player_art_toggled(enabled: bool)` (tooling only) so N2 emits
   against a stable contract without re-editing `event_bus.gd`.

N0 writes **no gameplay code, no scene changes, no RNG, no `RunConfig` field** — it is pure asset + data + one signal
declaration. It must not move the determinism fingerprint (`e943ac9c8bc1`).

---

## (a) Research on the premise

### Why this task
M1.0–M1.6 stood up the full surface/dive loop, but the player is still the greybox in `Game/entities/player/player.tscn`:
a teal `Visual` `ColorRect` (lines 16–21, `-14..14` = a 28px box) plus a `Nose` `Polygon2D` (lines 23–25) on a
`CharacterBody2D` whose `CircleShape2D` is `radius = 14.0` (lines 7–8). The breakdown's "one thing to prove" (§1) is that
the player **reads as a real animated character**. Before N1 can hang an `AnimatedSprite2D` on the player and drive it from
the existing `facing`/`aim`/`velocity`/EventBus seams, the **animation asset has to exist** and the **frames have to live
under `res://`**. That is N0. Everything in the dependency map (§4) is `blockedBy` N0.

### What in-repo this builds on (cited)
- **`Game/entities/player/player.tscn`** — the greybox the sprite will sit on. Collision is `CircleShape2D radius = 14.0`
  (lines 7–8); the visual box spans `offset_left/top = -14` … `offset_right/bottom = 14` (lines 16–20). **N0 touches none of
  this** — it only authors the asset N1 will add an `AnimatedSprite2D` for. The r=14 body is the reference the sprite
  scale/offset (Open Question OQ-5) must read against.
- **`Game/entities/player/player.gd`** — `aim` / `facing` default `Vector2.DOWN` (lines 29, 34), kept in sync each frame
  (line 85); `velocity` is the standard `CharacterBody2D` field stepped by `step_velocity` (lines 127–133). N1 quantizes
  these; N0 just names the animations so `idle/walk/pickup/throw_<dir>` line up with N1's quantizer. The existing
  `_update_facing_visual()` (lines 136–142) null-guards on `Nose` and is explicitly described as "No-op until a directional
  sprite exists" (line 139) — N0 produces exactly that sprite asset.
- **`Game/systems/event_bus.gd`** — the central signal hub. The file groups signals by milestone with a banner comment and
  an "owner" note (e.g. M1.6's `# === M1.6 signals (sole event_bus.gd edit this milestone, owner = M0) ===`, line 183).
  N0 follows that exact house style: one new `# === M1.7 …` banner, owner = N0, one signal. The pre-declare discipline
  (declare-before-emit, single writer) is the M1.1 rule cited throughout the file (e.g. lines 82–87, 118–124).
- **`Game/project.godot`** — `textures/canvas_textures/default_texture_filter=0` (line 165). `0` = **nearest** = no
  bilinear smoothing **project-wide**. This is the pixel-art discipline already locked (CLAUDE.md "Conventions"); it means
  the imported frames need **no per-texture filter override** — the project default already does the right thing.
- **`Game/art/`** — currently only `art/_placeholder/.gitkeep`. The real-art destination `art/player/` does not yet exist;
  N0 creates it. (`_placeholder` is the quarantine for Tier-A/B/C placeholders per the playbook; this is *real* art, so it
  lives in `art/player/`, **not** under `_placeholder/`.)
- **`.gitattributes`** — `*.png filter=lfs diff=lfs merge=lfs -text` (line 7) → every copied frame is **automatically an LFS
  pointer**, no action needed. `*.import text` and `*.tres text` (lines 33, 34) stay plain-text diffable. **Confirmed: the
  copy plan needs no `.gitattributes` change.**

### The art source (read, confirmed on disk)
`art_workshop/game_art/player_explorations/20260627/player_basic_template/` (per `GENERATION.md` + directory listing):
- `rotations/` — **8 static directional poses**, one PNG each: `south.png, south-east.png, east.png, north-east.png,
  north.png, north-west.png, west.png, south-west.png`.
- `move/<dir>/frame_000.png … frame_005.png` — **8 dirs × 6 frames** (walk cycle, mid-stride).
- `pickup/<dir>/frame_000.png … frame_004.png` — **8 dirs × 5 frames** (crouch + reach-down grab).
- `throw/<dir>/frame_000.png … frame_006.png` — **8 dirs × 7 frames** (wind-up + overhand throw).
- All frames **124×124 RGBA PNG**, low-top-down (3/4 RPG), a **64px character on the 124×124 canvas** (GENERATION.md §Summary).
- `metadata.json` + `GENERATION.md` are provenance — **not copied into `Game/`** (the engine never loads them; provenance
  stays in `art_workshop/`).

8 directions, lowercase, hyphenated: `south, south-east, east, north-east, north, north-west, west, south-west`. The
destination filenames normalize the hyphen to underscore (`north-east` → `north_east`) so they are valid Godot
node/animation-name fragments and clean `res://` paths.

### How the frames become a Godot animation asset (prior-art grounding)
A `SpriteFrames` resource is Godot's native multi-clip 2D sprite container: a dictionary of **named animations**, each a
list of `AtlasTexture`/`Texture2D` frames with a per-animation **FPS** and **loop** flag. An `AnimatedSprite2D` (added by
N1) holds one `SpriteFrames` and plays a clip by name (`play("walk_south")`). This is the lightest-weight path for
**8-dir × 4-state with one-shot pickup/throw**: no `AnimationTree` graph, no blend spaces, no `AnimationPlayer` track
authoring — just `play(state + "_" + dir)` and a `animation_finished` signal for the one-shots. (See OQ-1 for the explicit
trade-off vs. `AnimationPlayer`/`AnimationTree`.) Filter-off (project default nearest) keeps the 124×124 frames crisp at
integer-ish scales — the standard pixel-art import recipe.

### Source → destination copy plan (exact)
Copy **frames only** (not `metadata.json`/`GENERATION.md`) from
`art_workshop/game_art/player_explorations/20260627/player_basic_template/` into `Game/art/player/`, **preserving the
state/direction structure**, normalizing `-` → `_` in direction names:

| Source (under `art_workshop/.../player_basic_template/`) | Destination (under `Game/`) | `res://` path | Count |
|---|---|---|---|
| `rotations/<dir>.png` | `art/player/rotations/<dir>.png` | `res://art/player/rotations/<dir>.png` | 8 |
| `move/<dir>/frame_00N.png` | `art/player/move/<dir>/frame_00N.png` | `res://art/player/move/<dir>/frame_00N.png` | 48 |
| `pickup/<dir>/frame_00N.png` | `art/player/pickup/<dir>/frame_00N.png` | `res://art/player/pickup/<dir>/frame_00N.png` | 40 |
| `throw/<dir>/frame_00N.png` | `art/player/throw/<dir>/frame_00N.png` | `res://art/player/throw/<dir>/frame_00N.png` | 56 |

`<dir>` ∈ `{south, south_east, east, north_east, north, north_west, west, south_west}`. **Total 152 PNGs.** (See OQ-7 on
whether to instead pack a spritesheet — recommended **no** for M1.7.)

After copying, run **`godot --headless --path Game --import`** once. Godot generates a `<file>.png.import` next to every
PNG and the imported `.ctex` into `Game/.godot/imported/`. Because `default_texture_filter=0` is project-wide, each
`.import` inherits nearest filtering — **no per-file override stanza needed**. Commit the `.png` (LFS pointers) **and** the
generated `.png.import` text files (the `.import` is the stable import contract Godot needs to resolve `res://` UIDs; it is
plain-text per `.gitattributes` line 35). The `.godot/imported/` cache is **not** committed (already gitignored as build
output).

### Determinism / invariant grounding
Adding textures + a `SpriteFrames` `.tres` + one EventBus signal touches **no RNG, no `RunConfig` `@export`, no generator
code**. The all-off `RunConfig` fingerprint stays **byte-identical `e943ac9c8bc1`** (breakdown §6.1). Collision and movement
are untouched (§6.5). N0 is the only writer of `event_bus.gd` and `player_frames.tres` this milestone (§4), so no
parallel-edit collision.

---

## (b) Pseudocode / concrete spec

### The EventBus signal (in `Game/systems/event_bus.gd`)
Appended after the M1.6 block (last group, ends line 226), matching the per-milestone banner + owner-note house style:

```gdscript
# === M1.7 signals (sole event_bus.gd edit this milestone, owner = N0) =========
# A SINGLE tooling signal — the M1.7 "disable player art" debug toggle (N2). This
# is NOT a gameplay or telemetry signal and NOT a RunConfig knob: it stays OUTSIDE
# the config_menu MANIFEST / has_full_coverage() set, so the 89-knob count holds
# (breakdown §6.2). Emitted by the Meta-tab CheckButton (N2); the Player listens
# (N1's swap seam) and swaps AnimatedSprite2D <-> greybox + gates the movement-lock.
# Default state is art ON; `enabled == true` means "player art ON" (greybox hidden).

# --- N2 debug view toggle (tooling, not gameplay) ----------------------------
signal debug_player_art_toggled(enabled: bool)
```

> Semantics locked here so N2 has no ambiguity: **`enabled == true` → player art ON** (AnimatedSprite2D shown, greybox
> hidden, movement-lock active). `enabled == false` → greybox (M1.6 byte-for-byte, lock off). Default = ON.

### The `SpriteFrames` resource (`res://entities/player/player_frames.tres`)
**Recommended scheme: 32 named clips — `<state>_<dir>` — in ONE `SpriteFrames`.** State ∈
`{idle, walk, pickup, throw}`, dir ∈ the 8 normalized names. This is the scheme the breakdown §3 N0 row already names
(`idle_<dir>`, `walk_<dir>`, `pickup_<dir>`, `throw_<dir>`) and N1's quantizer maps onto directly (`play(state + "_" + dir)`).

| State | Source | Frames/clip | Clips | FPS (recommend) | Loop |
|---|---|---|---|---|---|
| `idle_<dir>` | `rotations/<dir>.png` | **1** | 8 | 1 (irrelevant — single frame) | **true** (held still) |
| `walk_<dir>` | `move/<dir>/frame_000..005` | 6 | 8 | **10** | **true** |
| `pickup_<dir>` | `pickup/<dir>/frame_000..004` | 5 | 8 | **20** (≈0.25 s) | **false** (one-shot) |
| `throw_<dir>` | `throw/<dir>/frame_000..006` | 7 | 8 | **24** (≈0.29 s) | **false** (one-shot) |

**FPS rationale (tie to the §1 movement-lock window of ~0.2–0.3 s):**
- `walk` @ 10 fps = a 0.6 s, 6-frame cycle — a calm top-down walk cadence; not tuned to literal foot-speed (N1 owns the
  walk↔idle threshold, not frame-to-ground sync). Flag for RG2 eyes (OQ-2).
- `pickup` @ 20 fps → 5 frames = **0.25 s**; `throw` @ 24 fps → 7 frames = **~0.29 s**. Both land **inside** the breakdown's
  ~0.2–0.3 s lock window so the one-shot clip plays **fully** under N1's movement-lock (the clip and the lock end together).
  These FPS values are the **single tuning point** N1 reads against — if the Director wants a longer/shorter committed
  action, change FPS here (and the lock default in N1) together. Exposed as the resource's per-animation `speed`.
- `idle` is a single held frame; its FPS is immaterial. `loop = true` keeps it displayed (a non-looping 1-frame clip would
  emit `animation_finished` immediately and stop — harmless but `loop = true` is cleaner; see OQ-6).

**`.tres` shape (illustrative — 4 of 32 clips shown; the real resource lists all 32):**

```
[gd_resource type="SpriteFrames" load_steps=N format=3]

[ext_resource type="Texture2D" path="res://art/player/rotations/south.png" id="idle_south_0"]
[ext_resource type="Texture2D" path="res://art/player/move/south/frame_000.png" id="walk_south_0"]
# ... move/south frame_001..005, all dirs, all states ...

[resource]
animations = [
  {
    "name": &"idle_south",
    "loop": true,
    "speed": 1.0,
    "frames": [ { "duration": 1.0, "texture": ExtResource("idle_south_0") } ],
  },
  {
    "name": &"walk_south",
    "loop": true,
    "speed": 10.0,
    "frames": [ {"duration":1.0,"texture":ExtResource("walk_south_0")}, ... x6 ],
  },
  {
    "name": &"pickup_south",
    "loop": false,
    "speed": 20.0,
    "frames": [ ... x5 ],
  },
  {
    "name": &"throw_south",
    "loop": false,
    "speed": 24.0,
    "frames": [ ... x7 ],
  },
  # ... the remaining 7 directions for each of the 4 states (28 more clips) ...
]
```

> **Authoring note:** hand-writing 152 `ext_resource` lines + 32 animation entries is error-prone. Recommended path:
> open the project in the editor, create the `SpriteFrames` on a throwaway `AnimatedSprite2D`, drag each state/dir frame
> run in, set FPS + loop per the table, save as `res://entities/player/player_frames.tres`, then discard the throwaway
> node. The N1 scene references the saved `.tres`. (A generator script under `tools/` that walks `art/player/` and emits
> the `.tres` is an acceptable alternative — but it is a build aid, not shipped game code, and must not touch RNG.)

### Import step (generates `.import`, no per-texture override)
```bash
godot --headless --path Game --import
```
This compiles every new `res://art/player/**.png` → a `.png.import` (filter inherits project `default_texture_filter=0`,
so **nearest**, no override stanza) → `.ctex` in `Game/.godot/imported/`. Commit the `.png` (LFS pointers, automatic via
`.gitattributes:7`) and the generated `.png.import` (plain text, `.gitattributes:35`). Do **not** commit `.godot/imported/`.

### Verification N0 leaves for the orchestrator
- `godot --headless --path Game --import` exits 0 (all 152 PNGs import, all 152 `.png.import` present).
- `godot --headless --path Game --script res://tools/ci_smoke_test.gd` stays **green** and the all-off fp is still
  **`e943ac9c8bc1`** (proof N0 touched nothing deterministic).
- A trivial headless load check: `load("res://entities/player/player_frames.tres")` returns a `SpriteFrames` whose
  `get_animation_names()` has **32** entries and `get_frame_count("walk_south") == 6`, `pickup_south == 5`,
  `throw_south == 7`, `idle_south == 1` (N1 will add the real visual tests; this just proves the asset is well-formed).
- `git lfs status` shows the 152 PNGs as pointers, not blobs.

---

## (c) Open Questions

**OQ-1 — Animation container: `SpriteFrames` vs. `AnimationPlayer`/`AnimationTree` vs. a code-only frame table.**
*Recommendation: `SpriteFrames` + `AnimatedSprite2D`.* It is the simplest thing that does 8-dir × 4-state with one-shot
pickup/throw: N1 plays `state + "_" + dir`, listens to `animation_finished` for the one-shots, done. `AnimationTree` blend
spaces would give smooth directional interpolation but are overkill for **hard 8-way snapping** (the breakdown explicitly
wants quantized directions, not blends) and add a graph N1 would have to author + a much larger learning/maintenance
surface. A pure code frame-table (32 arrays of `Texture2D`) avoids the `.tres` but loses the editor preview, the built-in
FPS/loop handling, and `animation_finished`. **Flag:** mild tech call — recommend `SpriteFrames`; confirm in Phase 3.

**OQ-2 — Per-clip FPS (walk cadence + pickup/throw duration vs. the lock window).** Proposed: walk 10, pickup 20
(≈0.25 s), throw 24 (≈0.29 s), so the one-shots fit the §1 ~0.2–0.3 s movement-lock and play fully under it. Trade-off:
faster walk fps reads more energetic but can look "skittery" at 6 frames; slower pickup/throw fps overruns the lock
(clip still playing after movement frees → either truncate the clip or lengthen the lock). **Walk cadence is a
feel/readability call best confirmed by the Director's eyes at RG2** (it is cosmetic, not gameplay) — flag as
*needs Director review at RG2*, not a build blocker. Pickup/throw fps is **coupled to N1's lock default** and must be tuned
*together*; N0 sets the FPS, N1 sets the lock — keep them in one tuning conversation.

**OQ-3 — Sprite scale + Y-offset (64px-on-124px character on the r=14 body).** The character occupies ~64px of a 124×124
canvas; the r=14 collision circle = a 28px-diameter footprint. **Recommendation: set scale + offset on N1's
`AnimatedSprite2D`, NOT here** — N0 ships raw 124×124 frames untouched (collision is sacrosanct, §6.5; N0 changes no
geometry). A *starting* recommendation for N1: scale ≈ **0.45–0.5** (so the 64px figure renders ~29–32px tall, reading
on the 28px body) with a **negative Y-offset** (sprite drawn up so the feet sit at the body center / slightly below, not the
torso). Exact scale + the feet-anchor offset are an **N1 visual-tuning call** against the live scene — flagged here so N1
owns it; N0 only guarantees the frames arrive un-pre-scaled. **Do not bake scale into the textures** (loses crispness +
couples to collision).

**OQ-4 — Idle source: 1-frame "animations" from `rotations/` vs. frames selected on the `AnimatedSprite2D`.**
*Recommendation: 1-frame looping `idle_<dir>` animations from `rotations/<dir>.png`* (8 clips in the same `SpriteFrames`).
This keeps N1's controller uniform — every state is `play(state + "_" + dir)`, idle included, no special-casing "stop and
show a static texture." Alternative (don't): leave idle out of `SpriteFrames` and have N1 swap a separate static
`Sprite2D` texture — that bifurcates the rendering path. Recommend the uniform 1-frame-clip approach.

**OQ-5 — Loop flag on the 1-frame idle clips.** `loop = true` (held) vs. `loop = false` (plays once, emits
`animation_finished`, holds last = same visual). *Recommendation: `loop = true`* — semantically "idle is ongoing," avoids
an `animation_finished` fire on entering idle that N1 would have to ignore. Cosmetically identical; cleaner state logic.
Minor — Phase-3 confirm.

**OQ-6 — Direction-name normalization & clip-name scheme.** Source uses hyphens (`north-east`); Godot animation names and
`res://` paths are cleaner with underscores. *Recommendation: normalize `-` → `_` on copy* (`north_east`) and name clips
`<state>_<dir>` (e.g. `walk_north_east`). N1's quantizer must emit the same normalized tokens — lock the token set here:
`south, south_east, east, north_east, north, north_west, west, south_west`. Low-risk; just needs to be *stated* so N0 and
N1 agree (done — this is the contract).

**OQ-7 — Keep 152 individual PNGs vs. pack one spritesheet (atlas).** *Recommendation: keep the 152 individual files for
M1.7.* Pros of individual files: a 1:1 map to the source, trivial `ext_resource` references, no atlas-region bookkeeping,
easy hand-inspection, and each is an independent LFS object. Cons: 152 small files + 152 `.import` files (repo noise) and
152 draw-texture binds (negligible at this count, single character). A packed sheet (one PNG + `AtlasTexture` regions)
would cut file count and is the right move once there are many characters — but it adds an offline packing step + region
math now, for one sprite, with no perf need. **Defer the spritesheet to a later "art-pipeline consolidation" iteration; keep
individual frames for M1.7.** Flag if Phase 3 disagrees on repo-noise grounds.

**OQ-8 — LFS commit shape (frames as pointers).** Confirmed *not really open*: `.gitattributes:7` already makes `*.png`
LFS-tracked, so the copied frames commit as pointers automatically and the `.png.import`/`.tres` stay plain text. Stated
here only to record there is **no `.gitattributes` change** and **no per-file LFS action** in N0. Verify with `git lfs
status` post-copy (frames listed as LFS objects, not blobs).

---

## Definition of done (N0)
- 152 frames copied into `Game/art/player/{rotations,move,pickup,throw}/…` (hyphens normalized to underscores); provenance
  files **not** copied.
- `godot --headless --path Game --import` exits 0; all `.png.import` present and committed; filter inherits project nearest
  (no per-file override).
- `res://entities/player/player_frames.tres` exists with **32 named clips** (`<state>_<dir>`), correct frame lists, FPS, and
  loop flags per §(b); loads headlessly as a `SpriteFrames` with the asserted frame counts.
- `event_bus.gd` declares **exactly one** new signal `debug_player_art_toggled(enabled: bool)` under an M1.7 owner=N0 banner,
  matching house style; no other signal touched; `run_ended` arity unchanged.
- Determinism fp still **`e943ac9c8bc1`**; smoke test green; PNGs are LFS pointers.
- Worklog at `worklogs/2026-06-27-N0-character-animator.md` (one per task, names every contributing agent + commit SHA),
  with a Design deviations section.

---

## Resolved Decisions (Phase 3, fresh-eyes — 2026-06-27)

Resolver: a fresh-eyes pass (not the N0 author). Verdicts below are technical/design calls resolved on merit; items needing
a vision/fun/feel verdict are flagged **needs Director review** with a recommendation. Cross-checked against the sibling
`N1_player_visual_state_machine.md` so clip names, FPS-vs-lock-window, and scale ownership stay consistent.

- **OQ-1 (container choice) — RESOLVED: `SpriteFrames` + `AnimatedSprite2D`.** It is the minimal container for 8-dir × 4-state
  with one-shot pickup/throw: N1 plays `"%s_%s" % [state, dir]` and listens to `animation_finished` (which N1's `_on_anim_finished`
  depends on). `AnimationTree` blend spaces are overkill — the breakdown wants hard 8-way *quantized* snapping (N1's
  `quantize_dir`), not interpolation; a code-only frame table loses the editor preview and built-in FPS/loop/`animation_finished`
  N1 relies on. Confirmed consistent with N1, which selects clips by name only.

- **OQ-2 (per-clip FPS) — SPLIT.** (a) **pickup 20 fps / throw 24 fps — RESOLVED as the starting values**, purely a
  lock-fit/timing matter: 5 frames @ 20 = 0.25 s and 7 frames @ 24 = ~0.29 s both land inside the ~0.2–0.3 s lock window so a
  clip-driven lock (N1 OQ-3 recommends clip-driven) plays each one-shot fully. These are coupled to N1's lock and must be tuned
  *with* N1, not independently. (b) **walk 10 fps cadence — needs Director review at RG2.** This is a walk-feel/readability call,
  not a timing fit (10 is a reasonable, calm starting cadence). *Recommendation: ship walk @ 10 fps for RG1 and let the Director's
  eyes confirm or adjust at RG2.* No build blocker either way.

- **OQ-3 (sprite scale + Y-offset) — RESOLVED: ownership is N1's, N0 ships raw 124×124 frames un-pre-scaled.** This matches N1
  OQ-6 ("Scale + Y-offset is N0's authored decision; N1 just consumes the `.tscn` transform") — minor doc inconsistency in the
  *prose* (N0 says N1 owns it; N1 says N0 owns it), but both agree the **frames are never pre-scaled** and the transform lives on
  the `AnimatedSprite2D` in `player.tscn`. **Lock: scale/offset is set on the `AnimatedSprite2D` node in `player.tscn` (the N1
  scene-edit task owns the actual value), not baked into textures.** N0's only obligation: deliver untouched 124×124 frames. The
  starting value (~0.45–0.5 scale, negative Y-offset to seat feet on the r=14 body) is a fine N1 starting point. Collision is
  untouched — confirmed (N0 authors no geometry).

- **OQ-4 (idle source) — RESOLVED: 1-frame looping `idle_<dir>` clips from `rotations/<dir>.png`, in the same `SpriteFrames`.**
  Keeps N1's controller uniform (`play(state + "_" + dir)` for every state incl. idle — N1's `select_state` returns `&"idle"` and
  expects a clip to exist). The alternative (separate static `Sprite2D` swap) bifurcates N1's render path. Consistent with N1's
  asset contract (it lists `idle_<dir>` 8×1).

- **OQ-5 (loop flag on idle) — RESOLVED: `loop = true`.** Semantically "idle is ongoing"; avoids an immediate `animation_finished`
  fire on entering idle that N1's `_on_anim_finished` would otherwise have to ignore. Visually identical to `loop=false` (1-frame
  holds the last frame either way). Cleaner state logic.

- **OQ-6 (direction-name normalization + clip scheme) — RESOLVED: normalize `-` → `_` on copy; clips named `<state>_<dir>`.**
  Locked token set: `south, south_east, east, north_east, north, north_west, west, south_west`. This is a hard shared contract
  with N1 — N1's `quantize_dir` emits exactly these underscored `StringName`s and N1 OQ-7 recommends a `_ready()` startup assert
  (`has_animation("idle_south")` etc.) to catch a spelling mismatch loudly. **N0 MUST author with this exact spelling.** Confirmed
  byte-identical to N1's `DIRS` set.

- **OQ-7 (152 individual PNGs vs. packed spritesheet) — RESOLVED: keep 152 individual files for M1.7.** 1:1 source map, trivial
  `ext_resource` references, no atlas-region math, independent LFS objects, negligible draw-bind cost for one character. A packed
  atlas is the right consolidation once there are many characters — defer to a later art-pipeline iteration. Repo-noise (152 PNG +
  152 `.import`) is acceptable for the first character and is the lower-risk path now.

- **OQ-8 (LFS commit shape) — CONFIRMED (not open): no `.gitattributes` change, no per-file LFS action.** `*.png filter=lfs`
  (`.gitattributes:7`) makes every copied frame a pointer automatically; `.png.import`/`.tres` stay plain-text diffable. Verify
  post-copy with `git lfs status` (frames as pointers, not blobs). No determinism fingerprint moves (no RNG/`RunConfig`/generator
  touched) and no collision is touched (asset + data + one signal only) — both invariants confirmed.

- **Copy-not-move contract — CONFIRMED HONORED (LOCKED, not re-litigated).** The doc's copy plan §(a) says **copy** frames from
  `art_workshop/.../player_basic_template/` into `Game/art/player/`, leaving the exploration source untouched (breakdown §6.6:
  "COPIED — never moved"). Provenance files (`metadata.json`, `GENERATION.md`) are correctly **not** copied. Honored as written.

### Needs Director review (do NOT self-resolve)

- **Walk cadence (OQ-2a, 10 fps walk).** A walk-feel/readability call. *Recommendation: ship 10 fps for RG1; confirm at RG2 with
  the Director's eyes.* Pickup/throw FPS are resolved (timing fit) and only the *walk* cadence is the open feel call.

---

## Director Disposition (ratified 2026-06-27)

- **OQ-2 walk cadence → RATIFIED: ship 10 fps for RG1**, revisit at RG2 as a cosmetic-feel item. Pickup/throw FPS stay as
  resolved (lock-fit). All other N0 Resolved Decisions stand. Copy-not-move from `art_workshop/` is a LOCKED contract (§6.6).
