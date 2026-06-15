# THE FAR YARD — Claude as the Non-Programmer Crew

**Companion to:** `Junkyard_Technical_Design.md` (v0.1), `Junkyard_GDD.md` (v0.2)
**Version 0.1 — research note**
**Question this answers:** Of the non-programmer roles in §6 of the Technical Design, which can Claude realistically own, which can it co-pilot, and which still need a human? With concrete workflows, tools, and gaps for each.

---

## 0. The one thing to understand first

Claude is a text-and-code engine. It reads images and files and produces text, code, and structured data — but it does **not** itself paint pixels or render audio. (Even the current flagship, Opus 4.8, "supports image inputs with text output… it does not function as an image synthesis engine.") That single fact draws the line through the whole roster:

- Where a role's deliverable is **words, rules, data, or code** — design specs, dialogue, balance models, test plans, schedules, the `.tres` content the engine eats — Claude can do the bulk of the work.
- Where the deliverable is **finished pixels or finished sound**, Claude's job shifts to *director and pipeline-builder*: it writes the briefs, drives external generative tools, writes the import/processing code, and critiques results — but a human (or a dedicated generative tool) produces the asset, and a human signs off on the aesthetic.

So the honest framing is not "can Claude replace this role" but "how much of this role collapses into authoring text/data/code, and what residue still needs a human eye or ear." The sections below grade each role on that basis.

**Legend:** 🟢 Claude can own it · 🟡 Claude co-pilots, human leads/approves · 🔴 Human (or dedicated tool) required; Claude only assists at the edges.

| § | Role (from Tech Design §6) | Overall | Why |
|---|---|---|---|
| 1 | Game Director / Designer | 🟢→🟡 | Owns systems design, balance, and *all* content data; human keeps the vision call. |
| 2 | 2D Artist — environment / tiles | 🔴→🟡 | Can't draw the art; can brief, code the tile pipeline, and enforce conventions. |
| 3 | 2D Artist / Animator — characters / FX | 🔴 | Weakest fit. Sprite consistency and animation are beyond text output. |
| 4 | UI/UX Designer | 🟡 | Strong at HUD/menu layout *in code* and UX logic; weak on visual polish. |
| 5 | Audio Designer / Composer | 🔴→🟡 | Can't compose; can spec the adaptive system and wire `AudioStreamInteractive`. |
| 6 | Narrative Designer / Writer | 🟢 | Best creative fit — dialogue, lore, recordings, branching scripts. |
| 7 | QA / Playtest Coordinator | 🟢 | Test plans, repro steps, bug triage, automated headless test code. |
| 8 | Producer | 🟢 | Schedules, milestone tracking, risk register, status digests. |

---

## 1. Game Director / Designer — 🟢 systems & data, 🟡 vision

**Role per §6:** vision, GDD ownership, systems & balance, content data authoring.

**What Claude can own.** This is where Claude is most useful relative to how the project is architected. The Tech Design deliberately makes content **data-authored** — items, recipes, enemies, bands, zone-pieces, and upgrades are `.tres` Resources, "no recompile, diff-friendly, moddable." That is exactly the kind of structured authoring Claude excels at: generating large, internally-consistent sets of Resource definitions, keeping costs expressed in Money/Salvage/Lore coherent across the four upgrade tracks, and refactoring them en masse when balance shifts. Claude can also build and maintain the **economy balance model** the Tech Design explicitly calls for (§9: "a spreadsheet model of currency inflows/sinks across acts before M3 tuning") — simulation-based economy modelling with player archetypes and stress-testing is a mainstream 2026 practice, and Claude can write the simulation and the spreadsheet.

**Concrete workflows.**

- Author and bulk-edit `.tres` content as text/data; validate cross-references (recipe inputs exist, upgrade costs are payable in-band) with a small Python linter Claude writes.
- Build the economy spreadsheet/sim (xlsx skill) that models inflows vs. sinks per act; run "what-if" passes when a currency feels too tight or too loose.
- Draft and maintain the GDD/Tech Design themselves — keep version, changelog, and the run-state vs. meta-state boundary documented and consistent.
- Turn fuzzy design intent ("dread should escalate per band") into concrete, testable parameters and thresholds.

**Where the human leads.** The actual *creative direction* call — is the push/cash-out tension fun, does the tone (dread + warmth) land, should we cut a system — is a judgment that lives with a human, validated by playtest (the M1 "is it fun?" gate). 2026 studio practice is explicit that "human oversight remains central at every stage." Claude proposes, models, and documents; the Director decides.

---

## 2. 2D Artist — environment / tiles — 🔴 art, 🟡 pipeline & briefs

**Role per §6:** tilesets, props, band aesthetics, the yard.

**Hard limit.** Claude cannot produce the tileset or props. Finished pixel art has to come from a human artist or a dedicated image model, and even those carry real limitations for this use case: AI image generation in 2026 still struggles with the *consistency* a tileset demands (matched palette, seamless edges, stable perspective across hundreds of tiles), and pixel art's tight palette/grid discipline is where generators are weakest. So Claude does not own this role.

**What Claude can genuinely contribute.**

- **Art briefs and the styles catalog** the Tech Design wants pre-M2 (§9: catalog CrossCode/Moonlighter-style high-detail pixel vs. painterly vs. flat-vector, with cost and team-fit trade-offs). This is research + writing — Claude's strength.
- **Band visual-language spec:** define, in words, how mundane → temporal → lateral → alien reads through palette and silhouette while staying cohesive. A human artist then executes against the spec.
- **Pipeline code:** the Aseprite→`/art`→Godot import flow (§5). Claude can write naming-convention enforcers, batch import-preset scripts, spritesheet/JSON slicers, and palette-consistency checkers — keeping "filter off, consistent pixels-per-unit" honest across the repo.
- **Directing a generative tool:** if the team uses an image model for *concept exploration* (mood, not shippable tiles), Claude can write and iterate the prompts and critique outputs against the band spec.

**Gap that stays human:** every shippable pixel, and the final aesthetic call.

---

## 3. 2D Artist / Animator — characters / FX — 🔴 weakest fit

**Role per §6:** player, enemies, NPCs, effects, juice.

This is the role Claude fits *least*. Beyond the same "can't draw" limit as §2, animation compounds it: a walk cycle or an enemy attack needs frame-to-frame coherence and timing feel that text output can't deliver, and 2026 generators remain unreliable at character consistency across frames. Claude's realistic contribution is narrow:

- Write **animation specs** (state list, frame counts, timing/easing intent, what each "juice" beat should communicate).
- Write the **engine-side animation code** — `AnimationPlayer`/`AnimationTree` setup, `Tween`-based juice, state-machine hookups, hit-flash and screen-shake logic — once a human supplies the frames.
- Author **FX that are code/shader-driven rather than hand-drawn** (procedural particles, simple shaders), which sidesteps the drawing limit.

Treat this as a human role with Claude doing the programming-adjacent glue. Don't plan to staff the artistry here with Claude.

---

## 4. UI/UX Designer — 🟡 layout-in-code strong, visual polish weak

**Role per §6:** HUD, inventory grid, menus, readability.

**Split the role in two.** The *UX* half — information architecture, what's on the HUD, how the slot-inventory grid behaves, readability rules, the rebinding-UI flow, accessibility — is design-as-reasoning, and Claude is strong here. The *visual* half — the actual look, iconography, polish — needs a human eye.

**What Claude can own.**

- Implement the `Control`-based inventory grid and HUD directly in Godot (the Tech Design already specifies a "`Control`-based grid"). Claude writes the scene/script, the slot/containment logic, drag-drop, and tooltips.
- Produce **interactive HTML/clickable mockups** of menus and HUD states for fast review before committing engine time — this is a Claude strength (it builds working HTML readily).
- Encode **readability/UX rules** — the "readable-junk study" from §9 (signalling item value/era/band at a glance) is partly a UX-conventions question Claude can research and spec.
- Wire the rebinding UI and accessibility/settings menus (M5 work) in code.

**Gap that stays human:** final visual design, icon art, and the "does this *feel* clear" gut check on a real screen. Pair Claude (layout + logic + mockups) with a part-time visual designer for polish — matching the "part-time / contract" staffing §6 already assumes.

---

## 5. Audio Designer / Composer — 🔴 composition, 🟡 system design

**Role per §6:** adaptive soundscape, SFX, music, Cyrus VO.

**Hard limit.** Claude generates no audio. Music, SFX, and voice must come from a human or from dedicated generative tools (e.g. Suno-class music generators, Firefly-style SFX generators, TTS for scratch VO). Those tools exist and are usable for *temp/scratch* assets in 2026, but with real caveats: AI music "can feel repetitive," quality "isn't always consistent," and precise in-game sync is still manual. So the composing/sound-design craft stays with a human.

**Where Claude is actually valuable — the system, not the sound.** The Tech Design's open question (§9) is the *adaptive middleware decision*: FMOD vs. native `AudioStreamInteractive`/buses against the "dread escalates by band" goal. That's an engineering/architecture question, and Claude can:

- Write the **decision memo** comparing FMOD vs. native on cost, pipeline complexity, and fit, with a recommendation.
- **Design the adaptive system**: define the music-state model (per-band intensity layers, crossfade rules, what game events drive transitions via the `EventBus`), then implement it with `AudioStreamInteractive`/buses or the FMOD integration.
- **Spec assets**: write the brief for each band's stem set and the cue list for SFX, which a composer or a generative tool fills.
- Manage **VO transcripts** — Cyrus's recordings are "triggerable audio + transcript Resources"; Claude writes/maintains the transcripts and the trigger data, and can stand up scratch TTS VO for prototyping.

**Gap that stays human:** the music and final sound design itself, and the aesthetic sign-off.

---

## 6. Narrative Designer / Writer — 🟢 strongest creative fit

**Role per §6:** story, dialogue, recordings, lore fragments.

**Best fit on the board.** This deliverable *is* text, and the architecture is built to consume authored text: Dialogue Manager scripts, "Cyrus recordings as triggerable audio + transcript Resources," and lore fragments. Claude can own the bulk of writing production:

- Draft and revise **branching dialogue** directly in Dialogue Manager (Nathan Hoad) syntax, so output drops into the pipeline with no translation step.
- Write **Cyrus's recording transcripts**, the overworld NPC scenes, and the **lore fragments** that gate Knowledge, keeping voice and continuity consistent across a large corpus (consistency-tracking is a known LLM narrative goal Claude is well-suited to with a maintained story bible).
- Maintain a **story bible / continuity tracker** so the secrecy/confidant choices and exposure crises stay coherent as branches multiply.
- Support **localization** (§4) — Godot's CSV/PO pipeline — drafting source strings cleanly and prepping the translation keys.

**Watch-outs.** LLM prose can drift toward generic or repetitive without a strong voice guide, and tone control for "dread + warmth" needs human editing passes. The right model is Claude as the staff writer producing volume and structure, with the Director/Narrative lead editing for voice and making the canonical story calls — which fits §6's "Director can cover early" note well.

---

## 7. QA / Playtest Coordinator — 🟢 plans, triage & test code

**Role per §6:** test plans, playtest logistics, bug triage.

**Strong fit.** QA is called out as "one of the most practical, high-impact applications of AI in 2026," and it maps cleanly onto Claude's strengths in both writing and code.

- **Test plans & cases:** write structured plans per milestone gate (M1 "is the loop fun in 30s," M2 full-day loop, etc.), with explicit steps and expected results.
- **Automated tests:** write the GUT / GdUnit4 unit/integration tests the Tech Design wants on "pure-logic systems (economy, exposure, save/load, proc-gen determinism)," plus the **headless smoke test** for CI (`godot --headless`). Determinism testing (seeded-replay) is a natural fit since the RNG is seeded.
- **Save-migration tests** across schema versions (a named §8 risk).
- **Bug triage:** ingest playtest reports/logs, cluster and prioritize, draft clean repro steps, and route. AI-assisted triage is documented to shorten QA cycles and improve edge-case detection.
- **Playtest instrumentation:** write the telemetry hooks and the analysis scripts for the M3 "where do players stall/quit" cohort.

**Gap that stays human:** coordinating real human playtesters and interpreting the subjective "is it fun" signal — logistics and human judgment. Claude handles the artifacts and automation around it.

---

## 8. Producer — 🟢 planning & tracking

**Role per §6:** schedule, milestones, external coordination.

**Strong fit for the artifacts.**

- Maintain the **milestone roadmap** (M0–M5), turn it into trackable task breakdowns, and keep the **risk register** (§8) current.
- Generate **status digests** from the issue tracker (GitHub Projects/Linear/Trello) — and this is a natural candidate for a *scheduled* recurring report (e.g. a weekly milestone-health summary).
- Draft **feedback-gate checklists** (each milestone's "who reviews, what question") and capture decisions back into the living docs.
- Keep the dependency map between the parallel research spikes (aesthetic study, proc-gen spike) and the milestones they gate.

**Gap that stays human:** actual external coordination (contracts, hiring the part-time audio/narrative/art help, stakeholder relationships) and the authority to move dates and cut scope. Claude is the producer's tireless coordinator and scribe, not the decision-maker.

---

## 9. Recommended division of labor

The cleanest split is by deliverable type:

- **Claude owns (text / data / code):** content-data authoring, economy model, design docs, narrative, QA plans + automated tests, production tracking, and *all* engine-side glue code for art/UI/audio. These are roles 1, 6, 7, 8 outright, plus the code half of 4.
- **Claude co-pilots, human approves:** UX/HUD design and mockups (4), audio *system* design (5), art *direction and pipeline* (2), the vision call inside design (1).
- **Human or dedicated tool required:** every shippable pixel and audio asset — character/animation art (3), tile/prop art (2), music and sound (5). Generative tools can supply *temp/concept* assets under Claude's direction, but a human owns the final aesthetic.

This maps neatly onto §6's existing staffing assumptions: the roles §6 already marks "part-time / contract" (UI/UX, audio, narrative, QA, producer) are mostly the ones Claude can carry a large share of, letting a small human team concentrate on the irreducibly visual and sonic craft — and on the judgment calls.

**Suggested next step:** pick the highest-leverage role to pilot first. The economy balance model (role 1, §9) and the narrative corpus (role 6) are both low-risk, high-value places to prove the workflow before M3.

---

## Sources

- [Claude Opus 4.8 — Models overview, Claude API docs](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Claude Opus 4.7 and AI Image Generation: capabilities & limits — JuheAPI](https://www.juheapi.com/blog/claude-opus-4-7-and-ai-image-generation-capabilities-limits-how-it-stacks-up)
- [Claude Opus 4.8 explained — decodethefuture.org](https://decodethefuture.org/en/claude-opus-4-8-explained/)
- [GPT Image — Wikipedia](https://en.wikipedia.org/wiki/GPT_Image)
- [Pixel art — Wikipedia](https://en.wikipedia.org/wiki/Pixel_art)
- [Suno AI for Game Developers: Video Game Soundtrack Guide (2026) — Hook Genius](https://hookgenius.app/learn/suno-for-game-developers/)
- [Best AI Sound Effect Generators 2026 — PixVerse](https://pixverse.ai/en/blog/best-ai-sound-effect-generator)
- [In-Game Economy Balancing Algorithms 2026 — PatSnap Eureka](https://www.patsnap.com/resources/blog/rd-blog/in-game-economy-balancing-algorithms-2026-patsnap-eureka/)
- [How Game Studios Use AI in 2026 — Starloop Studios](https://starloopstudios.com/how-game-studios-use-ai-in-2026/)
- [The Future of QA: Autonomous Game Testing — Medium](https://medium.com/@peterscott040/the-future-of-qa-autonomous-game-testing-and-neural-debugging-guide-79ff8f30165a)
- [Narrative intelligence — Wikipedia](https://en.wikipedia.org/wiki/Narrative_intelligence)
