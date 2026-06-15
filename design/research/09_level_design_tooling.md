# Level-Design Tooling: Built-in TileMap vs. LDtk

*Research companion to the THE FAR YARD Technical Design Doc §9 (level-design tooling: "Built-in TileMap vs. LDtk import — trial both with a level designer for ergonomics").*

This report compares the level-authoring path that ships inside Godot 4.6 (the `TileSet` resource plus `TileMapLayer` nodes and their editor) against authoring in **LDtk** (Level Designer Toolkit) and pulling the result into Godot via an import plugin. The evaluation is framed by THE FAR YARD's specific constraints: a 2D top-down game, tile-based levels, and — crucially — **levels assembled from hand-authored "zone-piece" scenes** that feed a modular, rule-based proc-gen pipeline (see §9 proc-gen spike). That last constraint matters more than any single feature checkbox: whatever tool we pick, its output has to be a clean, instanceable, version-controllable *unit* that the generator can stamp down repeatedly.

---

## 1. The TileMap → TileMapLayer change (and why it's settled in 4.6)

The single most important context for "use the built-in tools" is that the built-in tools changed shape in **Godot 4.3** (released August 2024). Historically a `TileMap` node held *all* layers internally. As of the 4.3 dev 6 snapshot, "TileMap layers are now exposed as individual `TileMapLayer` nodes ... which means less clutter in the inspector, a simpler API, and is also more in line with common Godot design patterns" ([Godot 4.3 dev 6 blog](https://godotengine.org/article/dev-snapshot-godot-4-3-dev-6/)).

The supported model going forward is **one `TileMapLayer` node per layer, all sharing a single `TileSet` resource**. The old `TileMap` node "is marked as deprecated but will stay for a while (it will not get any new features though)" ([Godot 4.3 dev 6 blog](https://godotengine.org/article/dev-snapshot-godot-4-3-dev-6/)). A one-click editor action converts an old `TileMap` into a set of `TileMapLayer` nodes; scripts need light updating but the API is "very similar."

For THE FAR YARD this is good news, not a hazard:

- **It is settled, not in flux.** As of Godot 4.6 (2026), `TileMapLayer` is the recommended, actively-developed path; `TileMap` remains only for backward compatibility and is not being removed ([Ziva: Godot Tilemap in 2026](https://ziva.sh/blogs/godot-tilemap), [GameFromScratch](https://gamefromscratch.com/godot-tilemap-replaced-with-tilelayers/)). Because we are starting fresh, we author `TileMapLayer` nodes directly and never touch the deprecated class.
- **It fits the zone-piece model.** A `TileMapLayer` is an ordinary node, so a zone-piece scene can be a small tree of one or more `TileMapLayer` nodes (e.g. floor / walls / decals) plus entity nodes — exactly the atomic `PackedScene` unit the generator wants to instance. Per-layer nodes also play nicely with Godot's own systems: 2D navigation-mesh baking parses all `TileMapLayer`s ([Godot 4.3 dev 6 blog](https://godotengine.org/article/dev-snapshot-godot-4-3-dev-6/)).

One related 4.3 change directly improves version-control friendliness: `PackedByteArray` properties in `.tscn`/`.tres` are now base64-encoded, "which is more compact, especially for bigger arrays" and reduces "inflated file sizes, and noisy diffs" ([Godot 4.3 dev 6 blog](https://godotengine.org/article/dev-snapshot-godot-4-3-dev-6/)). Tile data lives in arrays, so this meaningfully shrinks and de-noises tilemap diffs.

---

## 2. Feature comparison

### 2.1 Godot built-in `TileSet` / `TileMapLayer`

Godot's `TileSet` resource is the data hub, and it is feature-rich. Per the engine's own tiles editor work and current docs, a `TileSet` can carry ([Godot tiles editor progress #3](https://godotengine.org/article/tiles-editor-progress-3/), [GameDevArtisan: custom data layers](https://gamedevartisan.com/tutorials/godot-fundamentals/tilemaps-and-custom-data-layers)):

- **Physics layers** — per-tile collision polygons, with a snap tool and a default-shape shortcut for fast authoring.
- **Navigation layers** — per-tile walkable polygons for pathfinding.
- **Custom data layers** — arbitrary *typed* named values per tile (numbers, strings, bools, etc.), readable at runtime via `get_cell_tile_data(...).get_custom_data(name)`.
- **Terrain sets / terrains** — "a more powerful replacement of autotiles that can support transitions from one terrain to another," with match modes ("Match corners and sides," "Match corners," "Match sides"). A single tile may belong to several terrains at once ([tiles editor progress #3](https://godotengine.org/article/tiles-editor-progress-3/)).
- **Scene Collection sources** — you can add *scenes* as if they were tiles: drag a `.tscn` from the FileSystem into a Scene Collection and paint instances of it onto the map. This is the "scene-in-tile" capability and it is significant for a top-down game with interactive props.
- **Rendering layers**, atlas sources, alternative/flipped tiles, occlusion, Y-sort, etc.

**Entity placement** in the built-in workflow is *node-based*: you place enemies, pickups, spawn points, etc. as actual Godot nodes in the scene, or as scene-tiles via a Scene Collection. There is no separate "entity layer" abstraction — entities are just part of the scene tree, which is both simpler and less structured than LDtk's model.

A known caveat: Godot's native terrain/autotiling has historically been the weakest part of the editor (corner-match edge cases, no transition rules across more than the built-in match modes). The community plugin **Terrain Autotiler** ([dandeliondino/terrain-autotiler](https://github.com/dandeliondino/terrain-autotiler)) exists precisely to paper over those gaps, which tells you the built-in version is usable but not best-in-class for complex transitions.

### 2.2 LDtk

LDtk is a free, open-source, "pay-what-you-want" 2D level editor from Sébastien Bénard, lead designer of *Dead Cells*. It is deliberately scoped to **platformers and top-downs** ("Sorry, no isometric 3D here!") — a perfect match for our perspective ([ldtk.io](https://ldtk.io/)). Its standout level-design features:

- **Auto-layers / auto-rendering** — "Define some simple rules in a visual editor and let LDtk do the boring part of the skinning job." Rules are visual, previewable (hover a rule to see which cells it affects), and far more expressive than Godot's terrain system ([ldtk.io](https://ldtk.io/), [GameFromScratch: LDtk features](https://gamefromscratch.com/ldtk-the-level-designer-toolkit/)).
- **IntGrid layers** — paint abstract integer values (e.g. "1 = wall, 2 = water") that drive auto-layers and gameplay logic, decoupling *meaning* from *art*. This is genuinely better than the built-in tools for keeping collision/logic separate from tiles.
- **Highly customizable entities** — define entities (player start, enemies, items, triggers) with arbitrary **typed fields** (hit points, patrol paths, item inventories, even EntityRefs pointing at other entities). Entity authoring is LDtk's strongest area versus Godot's "just place a node" approach ([ldtk.io](https://ldtk.io/)).
- **Worlds** — organize levels in "Grid-vania," "linear," or "free" layouts with drag-n-drop, switching views with the mouse wheel.
- **Per-tile custom data**, tile stacking, flipping, Aseprite live-reload, strong backups, and a documented JSON output. There's also a **"Super Simple Export"** mode (a few PNGs per level plus a tiny JSON) for engines without a full importer ([ldtk.io](https://ldtk.io/)).

The current stable release is **LDtk 1.5.3** ([ldtk.io download](https://ldtk.io/download/)); the JSON schema the Godot importer targets is the 1.4.x line.

---

## 3. Getting LDtk into Godot: the importer landscape

LDtk has no native Godot runtime; you need an import plugin that turns the `.ldtk` JSON into Godot scenes/resources. The state of these plugins is the crux of the LDtk decision.

- **`heygleeson/godot-ldtk-importer`** is the de-facto maintained option for Godot 4. Latest release **2.0.1 (September 19, 2024)**, ~240 stars, MIT-licensed, supports **Godot 4.1+** and **LDtk 1.4.1** ([heygleeson/godot-ldtk-importer](https://github.com/heygleeson/godot-ldtk-importer)). It is feature-complete for our needs: it generates `TileMap`s from Tiles/IntGrid/AutoLayer types, generates atlases from LDtk tilesets, supports flipped tiles, normal maps, and tile custom data, parses entity/level fields into Godot types, handles EntityRefs, and exposes four **post-import script hooks** (TileSet / Entity / Level / World) for converting LDtk entities into your own scenes.
- **`afk-mario/amano-ldtk-importer`** is the lineage heygleeson forked from / credits as inspiration ([afk-mario/amano-ldtk-importer](https://github.com/afk-mario/amano-ldtk-importer)).
- The **original `ldtk-importer`** is unmaintained (last meaningful work ~April 2023); the Asset Library entry and older repos (`levigilbert/godot-LDtk-import`, `JoshLee0915/GodotLDtkImporter`, `Picalines/godot-ldtk-import-mono` for C#) are mostly stale or niche ([Godot Asset Library #2181](https://godotengine.org/asset-library/asset/2181), [levigilbert](https://github.com/levigilbert/godot-LDtk-import)).

**Maintenance risk is real and must be weighed.** The most viable importer is a single-maintainer, ~240-star community project whose last release predates Godot 4.6 by well over a year and still targets the deprecated `TileMap` node in its generated output (per its README). It works today, but a small open-issue queue (19 issues at time of writing) and the lack of a 4.4/4.5/4.6-tagged release mean we would be betting our level pipeline on a hobby plugin tracking two moving targets — Godot's release cadence *and* LDtk's JSON schema. That is the central liability of the LDtk path.

---

## 4. Workflow ergonomics for a level designer

This is where LDtk genuinely shines and is the reason §9 says "trial both ... for ergonomics."

- **LDtk is a purpose-built level editor.** Auto-layer rules, IntGrid abstraction, instant rule previews, world-level organization, and typed-field entities make hand-building and iterating on zone-pieces *fast and pleasant*. A designer who is not a Godot engineer can be productive in LDtk almost immediately, and the rule-based auto-rendering removes most of the tedium of skinning ([ldtk.io](https://ldtk.io/), [GameFromScratch](https://gamefromscratch.com/ldtk-the-level-designer-toolkit/)). It keeps the designer out of the Godot scene tree, which can be a feature (focus) or a friction (context-switching).
- **Godot's built-in editor is good and improving, but more "engineer-shaped."** Painting tiles, adding collision/nav/custom-data per tile, and placing entity nodes all happen *in the engine*, in the same scene the game runs. There's no export/import step, no second app, and the designer has the full power of the scene tree (signals, exported properties, instanced sub-scenes). Terrain authoring is the rough edge; everything else is solid.

The decisive ergonomic question for THE FAR YARD is **who authors zone-pieces.** If a dedicated level designer (possibly non-programmer) owns level content, LDtk's authoring comfort is a strong pull. If zone-pieces are authored by the same people writing the generator and gameplay code, staying in-engine removes a whole tool, file format, and importer from the loop.

---

## 5. Round-trip / iteration friction

This is LDtk's structural weakness for our pipeline.

- **Built-in TileMapLayer = zero round-trip.** The scene *is* the source of truth. Edit, hit play, done. Collision/nav/custom-data edits to the `TileSet` are immediately live. Nothing to re-export or re-import.
- **LDtk = one-directional import with edit-preservation caveats.** You edit in LDtk, save the `.ldtk`, and Godot re-imports it into generated `.tscn` scenes and `TileSet` resources. The heygleeson importer is explicitly designed so that "it is easy to manually edit the generated TileSets inside the project directly — reimporting the LDtk file will preserve these changes" (e.g. physics layers and collision polygons you add in Godot survive a reimport) ([heygleeson README FAQ](https://github.com/heygleeson/godot-ldtk-importer)). That is a thoughtful design, but it is still a **one-way pipeline**: changes made in Godot do *not* flow back into the `.ldtk` file. Anything you want to be authoritative must live in LDtk or be reconstructed via post-import scripts on every reimport.

For a proc-gen pipeline that instances zone-pieces, this means the "true" zone-piece is the generated `.tscn`, and the `.ldtk` is an upstream authoring artifact. That extra layer of indirection (LDtk file → importer → generated scene → instanced by generator) is more moving parts than (designer's `.tscn` → instanced by generator).

---

## 6. Version-control friendliness

Both options are git-friendly in the abstract — Godot's `.tscn`/`.tres` are text, and LDtk's `.ldtk` is JSON ([Tres Sims: LDtk in Godot](https://tres-sims.com/game_dev/ldtkingodot/)). The nuance:

- **Built-in:** the unit of version control is the zone-piece scene itself. Diffs are readable; the 4.3 base64 change shrinks tile-data noise. Merge conflicts are possible on large shared maps, but our zone-pieces are *small, separate scenes*, which keeps conflicts local.
- **LDtk:** you version the `.ldtk` JSON and **must `.gitignore` the importer's generated output** (or commit it and accept churn). A single big `.ldtk` project file is a merge-conflict magnet if two people edit different levels in it; LDtk's optional *external levels* mode (one file per level) mitigates this and should be enabled if we go LDtk. So LDtk is fine for version control *only with discipline* (external levels on, generated files ignored).

---

## 7. Interaction with the modular proc-gen pipeline

This is the deciding axis, given §9's proc-gen spike. The generator stitches hand-authored zone-pieces into bands at runtime by instancing `PackedScene`s and reasoning about connectivity/metadata. What each tool yields:

- **Built-in TileMapLayer:** a zone-piece is *natively* a `PackedScene` — a small node tree of `TileMapLayer`s + entity nodes + exported metadata (door positions, band tags, purpose). The generator instances it directly. Connection metadata can live as exported variables, marker nodes, or tile custom-data. Nothing is generated or imported; the authoring artifact and the runtime artifact are the same file. This is the lowest-friction fit by a wide margin.
- **LDtk:** zone-pieces are LDtk levels (or entities-within-levels) that the importer converts to `.tscn`. The generator then instances those generated scenes. Workable, and LDtk's per-level worlds + typed entity fields are a nice way to encode door/connection metadata — but you carry the importer dependency, the one-way pipeline, and a regeneration step in the loop. Every Godot or LDtk version bump is a risk to the whole content pipeline.

In short: the built-in path makes zone-pieces *first-class Godot citizens*; LDtk makes them *imported guests*.

---

## 8. Recommendation

**Lead with Godot's built-in `TileSet` + `TileMapLayer`, and treat LDtk as a contingency for the authoring-ergonomics gap.**

Rationale: the proc-gen pipeline wants zone-pieces to be plain `PackedScene`s, and the built-in tools deliver exactly that with zero round-trip, no third-party importer to track across Godot 4.6+ releases, no second application, and clean per-scene version control. The built-in feature set (physics/nav/custom-data layers, terrains, Scene Collection scene-tiles) covers everything THE FAR YARD needs except possibly the *comfort and speed* of authoring, where LDtk is clearly superior. The one credible reason to adopt LDtk — better designer ergonomics, especially auto-layer rules and typed entities — is real but is bought at the price of a single-maintainer importer (latest release Sept 2024, still emitting deprecated `TileMap`s) sitting on the critical path of our content pipeline.

### "Trial both" plan

Run a **time-boxed (1 week) bake-off** with the person who will actually author zone-pieces. Build the **same two representative zone-pieces in each tool**: one combat room and one "junk-dense" traversal room, each with floor/wall/decal layers, collision, one nav region, 3–4 entity types, and door/connection metadata on all four sides.

Concrete evaluation criteria (score each 1–5):

1. **Time-to-first-piece** — how long for the designer to produce a finished, playable zone-piece from a blank start (including tool setup / importer setup).
2. **Iteration speed** — measured edit→see-it-in-game loop time, including any export/reimport step.
3. **Entity/metadata authoring** — how cleanly door positions, band tags, and per-entity properties are expressed and how they survive into the runtime scene.
4. **Collision / nav / custom-data fidelity** — can the designer set these without engineer help, and do they round-trip / survive reimport?
5. **Autotiling quality** — author one multi-terrain transition (e.g. floor↔rubble↔pit) and judge result quality and rule-authoring effort (this is where LDtk is expected to win, Godot to struggle).
6. **Proc-gen integration** — wire one generated/authored piece into a throwaway instancing test; rate friction of getting it into the generator as a `PackedScene`.
7. **Version-control hygiene** — make two conflicting edits and resolve them; rate diff readability and merge pain.
8. **Maintenance / risk** — explicitly score the dependency surface: built-in = none; LDtk = importer + LDtk + version-coupling risk.

**Decision rule:** adopt LDtk *only if* it wins criteria 1–3 and 5 by a clear margin **and** the importer cleanly handles our Godot 4.6 + LDtk 1.5.x versions in the trial (verify it can emit `TileMapLayer`s or that the deprecated `TileMap` output is acceptable). Otherwise, default to built-in `TileMapLayer`. A reasonable middle path if the bake-off is close: author *art/auto-layers* in LDtk for speed, but keep *entities, collision, nav, and connection metadata* native in Godot — though this hybrid doubles the toolchain and should only be chosen if the designer's ergonomic gain is decisive.

---

## Sources

- [Dev snapshot: Godot 4.3 dev 6 — Godot Engine (TileMapLayer nodes, deprecation, base64 PackedByteArray)](https://godotengine.org/article/dev-snapshot-godot-4-3-dev-6/)
- [Godot Tilemap in 2026: TileMapLayer Migration Guide — Ziva](https://ziva.sh/blogs/godot-tilemap)
- [Godot TileMap Replaced with TileMapLayers — GameFromScratch](https://gamefromscratch.com/godot-tilemap-replaced-with-tilelayers/)
- [TileMap System — godotengine/godot DeepWiki](https://deepwiki.com/godotengine/godot/4.10-tilemap-system)
- [Tiles editor progress report #3 — Godot Engine (terrains, custom data, physics/nav layers)](https://godotengine.org/article/tiles-editor-progress-3/)
- [Using Godot 4's TileMaps and Custom Data Layers — Game Dev Artisan](https://gamedevartisan.com/tutorials/godot-fundamentals/tilemaps-and-custom-data-layers)
- [Terrain Autotiler (community plugin) — dandeliondino](https://github.com/dandeliondino/terrain-autotiler)
- [LDtk — official site (features, platforms, Super Simple Export, auto-layers, entities)](https://ldtk.io/)
- [LDtk Download (current 1.5.3)](https://ldtk.io/download/)
- [LDtk — The Level Designer Toolkit — GameFromScratch](https://gamefromscratch.com/ldtk-the-level-designer-toolkit/)
- [LDtk APIs / importers list](https://ldtk.io/api/)
- [heygleeson/godot-ldtk-importer — GitHub (v2.0.1, features, post-import hooks, FAQ)](https://github.com/heygleeson/godot-ldtk-importer)
- [afk-mario/amano-ldtk-importer — GitHub](https://github.com/afk-mario/amano-ldtk-importer)
- [levigilbert/godot-LDtk-import — GitHub (original/unmaintained)](https://github.com/levigilbert/godot-LDtk-import)
- [LDtk Importer — Godot Asset Library #2181](https://godotengine.org/asset-library/asset/2181)
- [Setting up LDTK and exporting Scenes to Godot — Tres Sims (git-friendliness, import friction)](https://tres-sims.com/game_dev/ldtkingodot/)
- [LDtk Projects in Godot, Part 1: Setup — LetsMake.games](https://letsmake.games/code/godot/ldtk/0001.plugin.html)
