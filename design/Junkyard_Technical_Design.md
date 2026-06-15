# THE FAR YARD — Technical Design Document

**Companion to:** `Junkyard_GDD.md` (v0.2)
**Version 0.4 — living document**
**Changelog:**
- v0.4 — **art pipeline decided: 2D pixel art only** (no Blender/3D tooling); HD-2D/rendered option rejected. Reconciled §4 and §9 to the pixel-art commitment.
- v0.3 — consistency review: added `Telemetry` autoload + privacy note (§2), enumerated the 3 currencies / 4 tracks (§3), standardized testing on GdUnit4 and added a performance budget (§4), gave the economy workbook a home (§9), refreshed stale "to decide" language (M0, §8), and flagged the **open art-pipeline conflict** with a tooling note (§4).
- v0.2 — folded in recommendations from the §9 research spikes (see `/research`). Resolved decisions promoted into §1–§4; §9 now records each question's outcome.
**Engine:** Godot 4.6.x (latest stable at time of writing: 4.6.3, May 2026)
**Target platform (V1):** PC (Windows/Linux/macOS) via Steam. Console as a stretch.
**Project scope:** 2D, top-down, single-player, roguelite extraction + life-sim overworld.

---

## 1. Engine & Language Decisions

### Why Godot 4.6.x
- First-class **2D pipeline** (top-down is a 2D-native fit), tile-based tooling, and lightweight builds.
- **GDScript** for fast iteration on gameplay; **C#** available if a subsystem needs the performance or static typing.
- Permissive MIT license — no royalties, important for a debt-themed indie shipping commercial.
- Strong **procedural-generation** ergonomics (everything is a Node/Resource; scenes instance cheaply) — central to our band-assembled dives.

### Language policy
- **GDScript is the default.** Use it for all gameplay, UI, and tools unless profiling proves otherwise.
- **C# (or GDExtension) only where justified** — e.g. heavy procedural generation, pathfinding over large dungeons, or save serialization if it becomes a bottleneck. Decide per-system, not project-wide; mixing languages adds build/debug overhead.
- **Avoid premature GDExtension/C++.** Reserve for a proven hot path late in development.

> **Resolved (research §9, `08_gdscript_vs_csharp_benchmark.md`):** Type all GDScript — it's the free win (~34–59% faster than untyped on math/vector code) and likely sufficient. Move a system to **C# only** when profiling shows a genuinely compute-bound kernel (large loops / grid crunching, where C# can be several× to ~11× faster) **and** the work isn't dominated by engine-bound calls like scene instancing (whose marshalling tax can erase C#'s edge — and our proc-gen stitches `PackedScene`s). If a **web export** is ever required, prefer a **C++/Rust GDExtension** kernel over C#, since C# web export remains experimental/unmerged as of 2026.

### Version policy
- Pin the **exact patch version** in the repo (`.godot-version` note + README). Upgrade deliberately, never mid-milestone.
- Track Godot 4.6.x maintenance releases; adopt patch bumps between milestones after a smoke-test pass.

---

## 2. Core Architecture (Godot-idiomatic)

A few load-bearing patterns to agree on before code grows:

- **Scene composition over inheritance.** Entities (player, enemies, junk, props) are scenes built from reusable component nodes (Health, Hurtbox, Interactable, Carryable, Loot). Favor composition so designers can recombine.
- **Autoload singletons for global state** — keep them few and disciplined: `GameState` (run + meta), `EventBus` (signals), `SaveManager`, `AudioDirector`, `RNG` (seeded), `Telemetry` (opt-in playtest analytics). Everything else is local.
- **Telemetry as a first-class subsystem.** Three §9 questions (run-length, economy, exposure) can only be settled with real play data, so a `Telemetry` autoload listens on `EventBus` and logs structured, timestamped events (run start/end + duration + cause, currency in/out per source/sink, exposure threshold crossings, band-depth reached, deaths). It writes to a local JSONL log (and an optional opt-in upload for external cohorts). Privacy: opt-in with a clear toggle in settings; no PII; required for the M1/M3 telemetry feedback gates.
- **Signal-driven decoupling.** Systems communicate via a central `EventBus` (signals) rather than hard references, so the dive layer, exposure system, and UI stay independent and testable.
- **Data as Resources.** Items, recipes, enemies, band definitions, zone-pieces, and upgrades are custom `Resource` (`.tres`) files. This makes content data-authored (no recompile), diff-friendly, and moddable later.
- **Deterministic, seeded RNG.** A single seeded RNG service drives procedural assembly so runs are reproducible for debugging and could support daily-seed/leaderboard modes.
- **Strict separation of run-state vs. meta-state.** Run-state (current dive, unbanked haul) is disposable; meta-state (tools, yard, relationships, Knowledge, exposure) persists. This boundary mirrors the GDD and must be enforced in the save schema.

---

## 3. Key Systems → Implementation Notes

| GDD System | Godot Implementation Approach |
|---|---|
| **Top-down movement & dives** | `CharacterBody2D` + `TileMapLayer` worlds; navigation via `NavigationRegion2D` / `NavigationAgent2D` for enemies. |
| **Procedural band assembly** | **Decided (research §9):** **modular room-graph stitching** (Spelunky/Dead Cells lineage) as the base — the hand-authored zone-piece `PackedScene` is the atomic unit, instanced and seed-deterministic. Augment with a cyclic-loop backbone (Unexplored-style) for pacing and **WFC-style socket-adjacency matching** to guarantee coherent seams. Full grammar engines and pure-WFC master generation rejected. |
| **Extraction & banking** | Run inventory held in `GameState`; banking at gate nodes commits haul to meta-save. Death/timeout drops unbanked minus a "pockets" fraction. |
| **Slot inventory** | Data-driven slot model; items are Resources with size/containment flags. UI is a `Control`-based grid. |
| **Recipe-based repair/crafting** | Recipe Resources (inputs → output). A `CraftingService` validates and consumes. No minigame. |
| **Three currencies + four tracks** | Currencies: **Money / Salvage / Lore(Knowledge)**. Four investment tracks: **Gear/Tech, Yard, Relationships, Knowledge** (per GDD §8). Ledger in `GameState`; upgrade nodes are Resources with cost expressed in Money/Salvage/Lore — and many upgrades are cross-fed (buyable *or* built from Salvage *or* unlocked via Lore). |
| **Exposure & secrecy** | A meta value driven by `EventBus` events; crisis triggers are data-defined thresholds firing overworld story scenes. **Tuning decided (research §9):** moderate-but-relentless Blades-in-the-Dark "Heat" model — 0–100 with a large inert buffer, 3–4 **deterministic, telegraphed** crisis thresholds (randomized event flavor), slow passive decay plus **active/costly** mitigation sinks, and partly-permanent top-band escalation to deter brinkmanship. |
| **Day cycle / time-as-resource** | In-dive clock (light/stamina) as a depleting resource; overworld day advances on sleep. State machine for day phases. |
| **Threats ("things that came through")** | Enemy scenes with composed behavior (behavior tree / FSM via **LimboAI** — see §4); band-scaled stats as Resources. **Scaling decided (research §9):** a single **Instability scalar `I`** drives enemy HP/damage, spawn budget, **and** loot tier/value together — `I` grows linearly per second within a band with a **+15% multiplicative kick on band entry** (Risk of Rain 2 model). Tiered telegraphing (Spelunky/Dredge) and a Tarkov-style sunk-cost carry penalty on death/timeout. |
| **Yard base & defenses** | Persistent overworld scene with placeable upgrade/defense nodes; Act 3 raid = wave logic reusing enemy AI. |
| **Dialogue / story / recordings** | Dialogue add-on (see §4) driving overworld scenes; Cyrus recordings as triggerable audio + transcript Resources. |
| **Saves** | **Decided (research §9):** model meta/run state as typed Resources **in memory**, but serialize to disk via `FileAccess.store_var()` with **object serialization OFF** (safe-by-default — no `.tres` code-execution risk, compact, migration-friendly). Separate per-slot `meta.sav` + `run.sav` (plus a small JSON header), each with an integer `schema_version` driving an ordered stepwise migration chain. **Atomic writes + `.bak` backups** so autosave-on-sleep/extract can never corrupt meta-state. |

---

## 4. Libraries, Add-ons & Tools

### Godot add-ons (vetted — research §9, `07_addon_vetting_pass.md`)
All three candidates **APPROVED**: MIT-licensed, Godot 4.6-compatible, actively maintained. **Pin exact versions** and vendor critical ones into the repo.

- **Dialogue: *Dialogue Manager* (Nathan Hoad) — APPROVED, pin v3.10.4** (Apr 2026, explicit Godot 4.6 support). Mature branching dialogue for overworld/story.
- **State machines / AI: *LimboAI* — APPROVED, pin v1.7.1** (Jun 2026; behavior trees **+** hierarchical state machines, via GDExtension). Prefer Godot's **built-in FSM / `AnimationTree`** for simple enemies first; *Beehave* v2.9.2 is the pure-GDScript fallback if a no-GDExtension build is needed.
- **Camera: *Phantom Camera* — APPROVED with caution, pin v0.11.0.2.** Still pre-1.0, so pin carefully and re-verify on upgrade. Top-down framing/feel.
- **Tweening/juice:** built-in `Tween` covers most; *GodotJolt* not needed (2D).
- **Debugging:** *Godot Debug Draw 2D* for nav/collision/AI visualization during proc-gen work.
- **Input:** built-in Input Map + a rebinding UI; controller support from day one.
- **Localization:** Godot's built-in CSV/PO translation pipeline — wire up early even if EN-only at first.

> Policy: prefer **built-in Godot features** first; add an add-on only when it clearly saves weeks. Vet each add-on's license, maintenance status, and Godot 4.6 compatibility before adopting.

### Content creation tools
> **Art pipeline: DECIDED — pixel art only.** No Blender or any 3D/rendered-to-2D tooling. The §9 aesthetic study's HD-2D / low-poly-rendered option is explicitly **rejected**; the team commits to hand-authored pixel art. This keeps tooling (Aseprite), import presets, pixel-perfect conventions (§5), and 2D-artist roles (§6) all aligned. Band contrast is achieved through palette, silhouette, lighting/shaders, and post-processing on shared 2D assets (see §9 `02_band_visual_language_study.md`), not 3D re-lighting.

- **Pixel art / 2D:** Aseprite (sprites, animation) — exports spritesheets + JSON. Alternatively Krita for painterly overworld backdrops.
- **Tilemaps:** **Decided (research §9):** lead with Godot 4.6's built-in **TileSet/TileMapLayer** (settled, non-deprecated since 4.3) — zone-pieces stay native `PackedScene`s with zero import round-trip, clean version control, and best fit for the modular proc-gen pipeline. **LDtk** is a contingency only, adopted only if it decisively wins a time-boxed authoring bake-off (its single-maintainer importer still emits deprecated `TileMap` nodes — a risk).
- **Audio:** REAPER/Audacity for editing. **Decided (research §9):** build "dread escalates by band" on **Godot 4.x native audio** — `AudioStreamSynchronized` (vertical stem layering), `AudioStreamInteractive` (beat-aligned transitions + stingers), and audio buses (per-band reverb/low-pass, SFX ducking). Zero licensing, no extra build complexity, no third-party dependency across the 4.6 upgrade.
- **Music:** native-first (as above). **FMOD** is the fallback *only* if a dedicated audio designer needs a DAW-style authoring loop or native interactive-music limits become blocking (FMOD free indie tier under $200k revenue; community `utopia-rise/fmod-gdextension`). Skip Wwise unless someone already knows it. See `06_adaptive_audio_middleware_decision.md` for the switch-triggers checklist.
- **Concept/UI:** Figma or Penpot for UI mockups and the HUD.

### Engineering tooling
- **VCS:** Git + **Git LFS** for binary assets (art, audio). Host on GitHub/GitLab.
- **Project structure:** feature-first folders (`/entities`, `/systems`, `/bands`, `/ui`, `/data`, `/art`, `/audio`), plus a `/tools` folder for editor scripts.
- **CI/CD:** GitHub Actions running **`godot --headless`** for export builds and test runs; itch.io (Butler) for nightly playtest builds, Steam pipeline later.
- **Testing:** standardize on **GdUnit4** (active Godot 4.x maintenance, CI runner, scene/integration support) for unit/integration tests on pure-logic systems (economy, exposure, save/load, proc-gen determinism). Headless smoke test in CI. *(GUT remains a viable alternative; pick one to avoid split tooling — GdUnit4 is the default.)*
- **Issue tracking / planning:** GitHub Projects, Linear, or Trello — team's choice.
- **Profiling & performance budget:** Godot's built-in profiler + monitors; custom in-game perf overlay. **Targets (placeholder — confirm at M2):** 60 FPS on a mid-range laptop (e.g. integrated GPU) at the locked base resolution; frame budget ~16 ms; cap loot/enemy node counts per band and profile against them. Optimize only against these numbers (see §8).

---

## 5. Asset & Build Pipeline

1. **Authoring** — artists export from Aseprite/Krita to a watched `/art` source folder; naming convention enforced.
2. **Import** — Godot import presets standardized (filter off for crisp pixels, consistent pixels-per-unit, compression rules). Commit `.import` settings.
3. **Data authoring** — designers create/edit `.tres` Resources (items, recipes, bands, enemies) directly in-editor; no code changes needed for content.
4. **Integration** — feature branches → PR → review → merge to `main`. CI builds headless export and runs tests.
5. **Playtest builds** — nightly/weekly automated export pushed to itch.io for the team and external testers.
6. **Release** — versioned export templates, signed builds, Steam upload via steamcmd.

**Conventions to lock early:** consistent base resolution & camera zoom (pixel-perfect settings), a single source of truth for the color palette, input action names, and the save-schema version. Cheap now, expensive to retrofit.

---

## 6. Team Roles

Scaled for a small indie team; one person may wear several hats early.

| Role | Responsibility | Min. for V1 |
|---|---|---|
| **Game Director / Designer** | Vision, GDD ownership, systems & balance, content data authoring | 1 (can be lead dev) |
| **Gameplay Programmer (Godot)** | Core loop, dive systems, inventory, crafting, AI | 1–2 |
| **Tools/Systems Programmer** | Proc-gen, save system, CI, editor tooling | 1 (can overlap gameplay early) |
| **2D Artist (environment/tiles)** | Tilesets, props, the band aesthetics, yard | 1 |
| **2D Artist/Animator (characters/FX)** | Player, enemies, NPCs, effects, juice | 1 (can be same person early) |
| **UI/UX Designer** | HUD, inventory grid, menus, readability | part-time / contract |
| **Audio Designer / Composer** | Adaptive soundscape, SFX, music, Cyrus VO | contract/part-time |
| **Narrative Designer / Writer** | Story, dialogue, recordings, lore fragments | part-time (Director can cover early) |
| **QA / Playtest Coordinator** | Test plans, playtest logistics, bug triage | part-time, ramps near vertical slice |
| **Producer** | Schedule, milestones, external coordination | part-time / Director |

**Realistic minimum core team:** Director-designer, 1–2 programmers, 1–2 artists, plus contract audio and narrative. ~4–6 people.

---

## 7. Milestone Roadmap

Each milestone ends with a **feedback gate** (who reviews, what question it answers). Durations are placeholders pending team size.

### M0 — Pre-production & Tech Foundations
- Repo, Git LFS, project structure, CI headless build, coding standards.
- Architecture spike: autoloads (incl. `Telemetry`), EventBus, Resource-based data, seeded RNG, save stub.
- Apply the decided GDScript/C# boundaries (§1); install + pin the approved add-ons (§4).
- **Feedback gate:** internal tech review — *Is the architecture sound and iterable?* No external feedback yet.

### M1 — Greybox Core Loop (Playable Prototype)
- Top-down movement, one greybox band, slot inventory, pick-up junk, a single gate, extract-and-bank, death-drops-haul.
- Push/cash-out gate working; placeholder sell screen converts junk → Money.
- **Feedback gate:** internal playtest — *Is the push/cash-out tension fun in 30 seconds of decision-making?* This is the **first critical "is the game fun" check.** Kill/pivot risk lives here.

### M2 — Vertical Slice (One Full Day)
- Full single-day loop: morning prep → dive (2 bands) → extract → sell → upgrade → evening (one NPC scene) → sleep.
- Recipe-based repair, one tool with traversal use, first "thing that came through" enemy with avoid/fight choice, basic exposure stub.
- First-pass *real* art for one band + the yard (establish the aesthetic).
- **Feedback gate:** small external playtest (5–10 trusted players) + art direction review. *Does the core fantasy land? Does the tone (dread + warmth) read?*

### M3 — Systems Breadth (Acts 1–2 Content)
- Bands 1–3, the three currencies and four upgrade tracks fully wired, Knowledge gating, yard rebuilding + defenses (incursions), exposure crises firing, several NPCs and the confidant/secrecy choices.
- Procedural assembly robust across bands; enemy variety per band.
- **Feedback gate:** wider closed playtest (itch.io key cohort) + telemetry. *Are progression and economy paced well? Where do players stall or quit?* Begin balance tuning.

### M4 — Content Complete (Act 3 + Endings)
- Band 4, rival diver antagonist + yard raids, Cyrus mystery payoff & recordings throughout, all ending branches, full audio pass (adaptive soundscape), localization wiring.
- **Feedback gate:** beta (NDA or wishlist cohort) + full playthrough QA. *Does the narrative escalation and ending branching satisfy? Difficulty curve across all acts?*

### M5 — Polish, Optimization & Ship
- Performance pass, save-system hardening, accessibility & rebinding, settings, controller polish, bug burn-down, Steam page/build, achievements.
- **Feedback gate:** release-candidate playtest + soak test. *Is it stable and shippable?* Then launch.

### Post-launch (Future)
- Co-op (scoped in V1 fiction but built later), permadeath hardcore mode polish, daily-seed mode, console ports, content updates.

> **Feedback cadence summary:** internal at M0–M1, first external eyes at M2 (vertical slice), broadening cohorts M3→M4, RC soak at M5. The single most important early gate is **M1** — prove the loop is fun before building breadth.

---

## 8. Risk Register (Technical)

- **Proc-gen feeling samey or unfair.** Mitigate with hand-authored zone-pieces + rule-based assembly and heavy seeded-replay testing; budget tuning time in M3.
- **Scope creep from four progression tracks + life-sim + roguelite.** The vertical slice (M2) must prove the *minimum* fun; defer any system not needed to feel good.
- **Save/load complexity** (run vs. meta split, versioning). Design the schema in M0; test migrations in CI.
- **Adaptive audio: native interactive-music limits** (decided: native, §4). Risk is now that `AudioStreamInteractive`/`Synchronized` can't hit the "dread escalates by band" bar; prototype the band-escalation soundscape in M2 and use the §9 switch-triggers checklist to fall back to FMOD before M4 if needed.
- **Add-on rot.** Pin versions, prefer built-ins, vendor critical add-ons into the repo.
- **Performance of many loot/enemy nodes on big maps.** Profile early; consider pooling and `MultiMeshInstance2D` for dense props.

---

## 9. Research Questions — Outcomes

The first research pass is complete; full reports with citations live in `/research`. Each question below records its **resolution** (✅ decided) or **status** (🔬 to validate via prototype/playtest). Resolved decisions are also promoted into §1–§4.

### Art & aesthetics
- ✅ **Top-down aesthetic study** (`01_top-down_aesthetic_study.md`). **Decision: hand-authored pixel art only** (Hyper Light Drifter/Moonlighter school). The report's HD-2D / low-poly-rendered-to-2D option is **rejected** — no Blender or 3D tooling. Manage the animation cost (4 directions × gear) with small sprites, short cycles, and heavy reliance on shaders/post for band contrast (palette, silhouette, lighting). See §4 Content tools.
- ✅ **Band visual-language study** (`02_band_visual_language_study.md`). **Decision:** one shared master palette + Dead Cells grayscale-plus-gradient-map pipeline; escalate dread along five independent dials (geometry, symmetry, colour logic, light motivation, familiarity) — not just "darker." Keep a **band-independent legibility layer** (player, loot, exits, threats always highest-contrast).
- ✅ **Readable-junk study** (`03_readable_junk_study.md`). **Decision:** reserve the standard rarity ladder (grey→white→green→blue→purple→orange) for label/beam colour; give each **origin band its own off-ladder glow/particle signature** (alien = off-spectrum hue); encode era via material + inventory-card glyph; back every colour cue with a redundant non-colour channel (colorblind-safe).

### Procedural generation
- ✅ **Proc-gen approach spike** (`04_procgen_approach_spike.md`). **Decision:** modular room-graph stitching + cyclic-loop backbone + WFC-style socket matching for seams (see §3). Prototype in M1.
- ✅ **Difficulty/instability scaling model** (`05_difficulty_instability_scaling_model.md`). **Decision:** single **Instability scalar `I`** driving enemies + loot, linear time growth + **+15% per band** (RoR2 model), tiered telegraphing, sunk-cost carry penalty (see §3).

### Audio
- ✅ **Adaptive audio middleware decision** (`06_adaptive_audio_middleware_decision.md`). **Decision:** Godot 4.x native audio (`AudioStreamSynchronized` + `AudioStreamInteractive` + buses); FMOD as fallback only (see §4). Decision checkpoint documented in the report.

### Engine/tooling
- ✅ **Add-on vetting pass** (`07_addon_vetting_pass.md`). **Decision — approved + pinned:** Dialogue Manager v3.10.4, LimboAI v1.7.1 (Beehave v2.9.2 fallback), Phantom Camera v0.11.0.2 (caution, pre-1.0). All MIT, Godot 4.6-compatible (see §4).
- ✅ **GDScript vs. C# benchmark** (`08_gdscript_vs_csharp_benchmark.md`). **Decision:** typed GDScript default; C# only for proven compute-bound kernels, not scene-instancing; GDExtension over C# if web export is needed (5-condition decision rule in §1 / report).
- ✅ **Level-design tooling** (`09_level_design_tooling.md`). **Decision:** built-in TileMapLayer leads; LDtk only via a time-boxed bake-off (see §4).
- ✅ **Save architecture** (`10_save_architecture.md`). **Decision:** typed Resources in memory, serialized via `store_var` (objects off), per-slot meta/run files, versioned stepwise migrations, atomic writes + `.bak` (see §3).

### Design-adjacent (🔬 validate via prototype/playtest — direction set, numbers TBD)
- 🔬 **Run-length tuning** (`11_run_length_tuning.md`). **Direction:** 15/30/60-min tiers are reasonable (action roguelites cluster 20–45 min). **Validate in M1–M2** via run-length histograms peaking near each label, mid-run abandonment < ~25%, runs-per-session > 1.5, and a drop-off funnel.
- 🔬 **Economy balance model** (`12_economy_balance_model.md`). **Direction:** faucet/drain value-chain model; distinct roles for Money/Salvage/Lore; debt curve motivating-not-crushing. **Action:** build the specified 8-tab workbook (Globals, Sources, Sinks, Run_EV, Upgrade_Tracks, Debt_Curve, Balance_Dashboard, Sensitivity) before M3 tuning; store it at `/design/economy_model.xlsx` under version control.
- 🔬 **Exposure pacing** (`13_exposure_pacing.md`). **Direction:** moderate-but-relentless Blades-style Heat model (see §3). **Validate with M3 telemetry** against the six metrics listed in the report.

---

## 10. Immediate Next Steps

1. Stand up the repo, Git LFS, project skeleton, and headless CI build (M0).
2. Architecture spike: autoloads + EventBus + Resource data + seeded RNG + save stub — implement the save stub on the decided `store_var`/versioned-migration model (§3).
3. Install + pin the approved add-ons (§4) and stand up the **modular room-graph generator** prototype (§3) — the proc-gen approach is now decided; goal is a sample generator for M1.
4. Build the M1 greybox loop and run the first internal "is it fun?" playtest; begin capturing run-length telemetry to validate the 15/30/60-min targets (§9).
5. Build the §9 economy workbook ahead of M3 tuning.

---

*This document is a living companion to the GDD. Update version and changelog as decisions resolve.*

---

**Sources for engine version reference:**
- [Godot | endoflife.date](https://endoflife.date/godot)
- [Godot 4.6 release coverage — Digital Production](https://digitalproduction.com/2026/01/28/godot-4-6-arrives-with-major-cg-friendly-updates/)
- [Godot Engine 4.6.3-stable — SourceForge mirror](https://sourceforge.net/projects/godot-engine.mirror/files/4.6.3-stable/)
