# Subagent Review against Technical Design v0.3

**Reviewed:** `Junkyard_Technical_Design.md` v0.3 (consistency review) vs. the 8 role
subagents in `Role_Subagents/` and their `Role_Playbooks/`.
**Question:** per role, what needs updating, and what is now extraneous?

---

## What changed in v0.3 that touches the non-programmer roles

Most §9 research spikes are now **resolved (✅)** and promoted into §1–§4. The
ones that move the subagents:

- **Art direction flipped to HD-2D primary.** §9 now decides *low-poly-3D-
  rendered-to-2D / HD-2D* (Blender → Godot) as the **primary** route, pixel art
  as **fallback** — but §5/§6 still assume pixel art, and §4 flags this as an
  **OPEN conflict to reconcile at the M2 art-direction gate.** Crucially, the §4
  tooling note found **no AI 3D-asset generation tool** available.
- **Audio middleware decided: native Godot** (`AudioStreamSynchronized` +
  `AudioStreamInteractive` + buses); FMOD is fallback-only. The "FMOD vs native"
  question is closed. New `AudioDirector` autoload (§2).
- **Telemetry is now a first-class autoload** (`Telemetry`, §2) with opt-in
  privacy toggle, JSONL logs, defined event set.
- **Testing standardized on GdUnit4** (§4) — no longer "GUT or GdUnit4".
- **Economy model fully specified** (§9): an 8-tab workbook at
  `/design/economy_model.xlsx` under version control.
- **Readable-junk, band visual-language, exposure tuning all decided** (§3/§9) —
  these were "studies to do"; now they're rules to implement.
- **Add-ons pinned** (§4): Dialogue Manager v3.10.4, LimboAI v1.7.1, Phantom
  Camera v0.11.0.2.
- **Save architecture, proc-gen, instability scaling, performance budget** all
  decided (§3/§4) — mostly programmer-facing, but QA and Director touch them.

Net: the **strong-fit text/data roles** (Director, Narrative, QA, Producer) need
mostly *additive* tweaks. The **art and audio roles** need real revision — and
one workflow each is now extraneous.

---

## 1. game-director-designer — minor updates

**Updates needed**
- **Economy model:** the agent says "build a spreadsheet or Python sim." v0.3
  specifies the exact artifact — an **8-tab workbook** (Globals, Sources, Sinks,
  Run_EV, Upgrade_Tracks, Debt_Curve, Balance_Dashboard, Sensitivity) at
  **`/design/economy_model.xlsx`**, before M3. Point the agent at that spec/path.
- **Exposure spec:** reference the decided **Blades-style "Heat" model** (0–100,
  3–4 telegraphed thresholds, costly mitigation sinks, partly-permanent top-band
  escalation) so any data the agent authors matches §3.
- **Currencies/tracks:** name them explicitly (Money / Salvage / Lore; tracks =
  Gear/Tech, Yard, Relationships, Knowledge) per the now-enumerated §3.

**Extraneous:** none. The agent's lane is unchanged and correct.

---

## 2. environment-artist — **needs revision** (art-direction conflict)

**Updates needed**
- The agent is written entirely for **pixel art + PixelLab**. v0.3's primary
  route is **HD-2D (Blender → render-to-spritesheet)**, with pixel art only as a
  fallback decided at the **M2 gate**. The agent must branch on that gate, not
  assume pixels.
- **PixelLab applies only to the pixel-art fallback.** Since §4 found **no AI
  3D-asset tool**, the HD-2D route gets **no generation head start** — placeholders
  there mean Tier A boxes / Kenney / greybox 3D renders, all manual. Make this
  explicit so the agent doesn't reach for PixelLab on the HD-2D path.
- The **styles catalog and band visual-language spec are now DECIDED** (§9
  `01`/`02`): shared master palette, Dead Cells grayscale + gradient-map, dread
  via five dials (geometry, symmetry, colour logic, light, familiarity), plus a
  **band-independent legibility layer**. Change the agent's "produce the catalog/
  spec" workflows to "**implement/maintain the decided spec**."

**Extraneous**
- Workflow A (styles catalog) and B (band visual-language) as *open research* are
  now largely extraneous — they're resolved. Keep only the "execute the decision +
  maintain the spec" remainder.

---

## 3. character-animator — **needs revision** (art-direction conflict)

**Updates needed**
- Same pixel-vs-HD-2D branch. The agent assumes **hand-drawn pixel sprite sheets**;
  on the HD-2D route, animation comes from **Blender rigs rendered to sheets**, and
  the §9 decision explicitly chose HD-2D partly to **dodge the 4-directions ×
  per-gear animation tax** — directly relevant to this role. Reflect both pipelines.
- **PixelLab (animated sprite sheets) is fallback-route-only.** On HD-2D there is
  no AI-generation shortcut for animation; placeholders are Tier A boxes / Kenney /
  simple rendered loops.
- Note **LimboAI v1.7.1** is the chosen behavior-tree/FSM add-on (§4) — relevant
  where animation state machines meet enemy behavior; prefer built-in FSM/
  `AnimationTree` first per §4.

**Extraneous:** the implicit "pixel is the world" framing. Otherwise the lane
(specs, engine wiring, code/shader FX) holds for either route.

---

## 4. ui-ux-designer — minor updates

**Updates needed**
- **Readable-junk is decided** (§9 `03`), not a study to run. Replace "research
  conventions" with **implement the decided rules**: standard rarity ladder
  (grey→…→orange) reserved for **label/beam colour**; each **origin band gets an
  off-ladder glow/particle signature** (alien = off-spectrum hue); era via
  material + inventory-card glyph; every colour cue backed by a **redundant
  non-colour channel** (colorblind-safe).
- Add the **band-independent legibility layer** (player, loot, exits, threats
  always highest-contrast) from §9 `02` as a HUD/readability requirement.
- Note **Phantom Camera v0.11.0.2** (§4) for framing where UI meets camera feel.

**Extraneous:** the "readable-junk study" as open research.

---

## 5. audio-designer-composer — **update; one workflow now extraneous**

**Updates needed**
- **The middleware decision is closed: native Godot** (`AudioStreamSynchronized`
  for vertical stem layering + `AudioStreamInteractive` for beat-aligned
  transitions/stingers + buses for per-band reverb/low-pass/ducking). Rewrite the
  system-design workflow around these named APIs.
- **FMOD is fallback-only** — keep it solely as the §9 *switch-triggers checklist*
  (`06_…md`) to consult before M4 if native limits block "dread escalates by band."
- Reference the **`AudioDirector` autoload** (§2) as the integration home.
- ElevenLabs (SFX/scratch VO) and Suno/fal.ai (placeholder music) stay valid.

**Extraneous**
- **Workflow A "Middleware decision memo (FMOD vs native)" is now extraneous** —
  it's decided. Demote it to a one-line "fallback trigger check," not a memo to
  write.

---

## 6. narrative-writer — trivial update

**Updates needed**
- Pin the tool version: **Dialogue Manager v3.10.4** (§4) is the approved,
  Godot-4.6-compatible release. Otherwise the agent is fully aligned (text is
  unaffected by the art/audio decisions).

**Extraneous:** none.

---

## 7. qa-playtest-coordinator — update (several specifics landed)

**Updates needed**
- **Standardize on GdUnit4** (§4). Drop "GUT/GdUnit4"; GUT is only a noted
  alternative, not a default.
- **Telemetry now exists as an autoload**, not something QA writes from scratch.
  Point the telemetry workflow at the `Telemetry` autoload's **JSONL event log**
  and defined events (run start/end + duration + cause, currency in/out per
  source/sink, exposure crossings, band-depth, deaths); respect the **opt-in
  privacy toggle / no-PII** rule. QA's job becomes **analysis** over that log.
- **Save-migration tests** now have a concrete target: per-slot **`meta.sav` +
  `run.sav`** via `FileAccess.store_var()` (objects OFF), integer
  **`schema_version`**, ordered stepwise migrations, **atomic writes + `.bak`**.
  Test exactly those.
- **Performance budget** is now defined (§4): **60 FPS / ~16 ms** on a mid-range
  laptop at the locked base resolution, with per-band node caps. Add perf-budget
  checks to the QA plan.
- Proc-gen determinism testing aligns perfectly with the decided **seeded
  room-graph** model — keep it.

**Extraneous:** the "build telemetry hooks from zero" framing — that's now an
architecture autoload; QA consumes it.

---

## 8. producer — update (open-questions map shifted)

**Updates needed**
- **Dependency map:** most §9 spikes are **done**, so the "spikes gate M1/M2"
  tracking is largely closed. The remaining open items to track are: the **M2
  art-direction gate** (the live conflict), and the three **🔬 validate-via-
  playtest** items (run-length, economy, exposure) whose *numbers* land in M1–M3.
- **Risk register** wording changed in §3/§8: the audio risk is now "native
  interactive-music limits → FMOD fallback before M4"; add-on rot is mitigated by
  the **pinned versions**. Mirror the current register, and **add the art-pipeline
  conflict as an explicit open risk** with the M2 deadline.
- Track the **economy workbook** (`/design/economy_model.xlsx`, before M3) and the
  **performance budget confirmation** (at M2) as scheduled deliverables.

**Extraneous:** treating the research spikes as in-flight — they've resolved;
the producer now tracks *decisions-to-validate*, not *questions-to-answer*.

---

## Extraneous / friction inside the TDD itself

A few things in v0.3 are redundant or in tension and worth a cleanup pass:

1. **The pixel-art assumption in §5 and §6 is now extraneous/premature.** §4
   already flags the conflict; §5 (filter-off pixel-perfect import presets) and §6
   ("2D Artist", "2D Artist/Animator") still presume pixels and contradict the
   HD-2D-primary §9 decision. Either gate them behind the M2 decision explicitly or
   add the HD-2D variant inline (the §4 note half-does this; §5/§6 don't).
2. **Decision text is duplicated** between §1–§4 and §9. That's deliberate
   ("promoted"), but the long research narratives now living **inside the §3
   implementation table** (proc-gen, exposure, scaling, saves paragraphs) bloat a
   table meant for quick reference — consider trimming §3 cells to the decision +
   a `/research` link and letting §9 carry the detail.
3. **"GUT remains a viable alternative" (§4)** mildly undercuts the same line's
   "standardize on GdUnit4." Pick one sentence; the hedge is extraneous.
4. **§6 audio role still says "adaptive soundscape… music"** as if middleware is
   open; it's fine, but a one-word nod to "native-first" would keep §6 consistent
   with §4.

None of these are errors — they're the normal lag between a fast-moving decision
log and the surrounding prose. The single load-bearing one is **#1 (art
pipeline)**, because two subagents and §5/§6 all hang on it.

---

## Recommended actions (priority order)

1. **Resolve or explicitly gate the art-pipeline conflict** (drives subagents 2 &
   3 and TDD §5/§6). Until M2, update both art subagents to **branch on the gate**
   and stop assuming pixels/PixelLab on the HD-2D path.
2. **Audio subagent:** delete the FMOD-vs-native memo workflow; rewrite around
   native `AudioStream*` + `AudioDirector`; keep FMOD as a fallback checklist.
3. **QA subagent:** GdUnit4 default; consume the `Telemetry` autoload; target the
   decided save format; add the 60 FPS/16 ms budget.
4. **Director, UI/UX, Narrative, Producer:** apply the additive tweaks above
   (economy workbook path, decided readable-junk rules, Dialogue Manager pin,
   shifted open-questions map).

I can apply these edits to the eight subagent files on request — the art-pipeline
ones I'd write as a gate-branch rather than committing to HD-2D, since that
decision is still open.
