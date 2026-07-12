# TASKS — THE FAR YARD

The orchestrator's task queue (mirror of GitHub Projects). The orchestrator consumes the
top *unblocked* task, dispatches the assigned subagent(s), and moves it through `STATUS.md`.
Each task carries: **id · milestone · assignee subagent · spec · definition of done · blockedBy**.
Finished tasks move to `TASKS_COMPLETED.md` (this file holds only **active + backlog**).

Format:
```
### <ID> — <title>
- Milestone: M<n>   Assignee: <subagent(s)>   BlockedBy: <ids|none>
- Spec: <path to the design doc>
- Goal: <one sentence>
- Done when: <verifiable acceptance criteria>
```

> A single task may span a programmer + an asset role (see `CLAUDE.md` → Dispatch). The
> primary assignee is listed first; a `(+ role: scope)` note marks the secondary agent.

---

## M1.12 — Scaling Debt Paydown (R2–R10) — ✓ **DONE 2026-07-12** (verdict GO → M2)

All 13 tasks (V1–V9 · V3b · V4b · VG1–VG3) built, integrated, verified green, and archived to
`TASKS_COMPLETED.md`. Behavior-preserving R2–R10 debt paydown; game provably unchanged. Findings +
verdict: `design/M1_12_Tasks/G4_findings_M1.12.md`. Deviations archived → `DESIGN_DEVIATIONS_HISTORY.md §M1.12`.

## M1.2 — Legibility & Level Scale — ✓ **DONE 2026-06-19** (re-gated → ITERATE → M1.3)

All built + re-gated: Waves 1/2 + BUG5 + RG1 → Director playtest → RG2 → **RG3 verdict ITERATE**. Findings + Director
decisions: `design/M1_2_Tasks/G4_findings_M1.2.md`. All tasks archived → `TASKS_COMPLETED.md`.

---

## M1.3 — Legibility & Density — ✓ **DONE 2026-06-21** (re-gated → ITERATE → M1.4)

All built + re-gated: Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 → Director playtest → **RG3 verdict ITERATE**.
Findings + the Director feedback work-order: `design/M1_3_Tasks/G4_findings_M1.3.md`. Tasks archived → `TASKS_COMPLETED.md`.

---

## M1.4 — Stakes, Variety & Legibility — ✓ **DONE 2026-06-21..24** (re-gated → ITERATE → M1.5)

All waves built + re-gated: Waves 1–3 (K0–K7, K5a/b/c/i) + RG1 + Wave-5 bug-wave (BUG7/BUG8/TUNE2/FB5) → Director
playtest → **RG3 verdict ITERATE → M1.5** (`design/M1_4_Tasks/G4_findings_M1.4.md` §RG3). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.5 — Agency & Legibility — ✓ **DONE 2026-06-24..26** (re-gated → ITERATE → M1.6)

All waves built + re-gated: Waves 1–3 (L0–L5 + RG1) + Wave 4 (L6 control rework) + post-RG3 tuning → Director re-test →
**RG3 verdict ITERATE → M1.6** (`design/M1_5_Tasks/G4_findings_M1.5.md` §"RG3 re-test verdict"). Tasks archived →
`TASKS_COMPLETED.md`.

---

## M1.6 — Surface & Staging — ✓ BUILD DONE; RG1 published; RG2/RG3 Director-pending

Build (M0·M1·M2·M4·M3) + RG1 (itch published `m1-20260627-41106de` + FB1–FB4) all on `main`, archived →
`TASKS_COMPLETED.md`. **Open (Director-gated, non-blocking M1.7):** **RG2** (telemetry/flow analysis) + **RG3** verdict
(go/iterate/pivot) in `design/M1_6_Tasks/G4_findings_M1.6.md` — these await the Director's re-test. M1.7 below is
**Director-directed content** opened ahead of that formal verdict.

---

## M1.11 — Third Generation Backend + Open-Field Band + Ranged Oppositions (ACTIVE — Director-directed; design LOCKED 2026-07-06)

Prove the seams hold at **N = 3 with declining marginal cost**: a third genuinely-different
generator (`ScatterBackend` — open-field arena + order-stable poisson cover, no pieces/no CA)
slots behind the same `BandPipeline` with materialisation expected at **~0 new lines** (the
M1.10 synthetic-piece path is backend-agnostic), and **two ranged oppositions** (Lobber +
Sentry — the at-range axis; all 9 shipped defs are contact-lethal) land as def + one component
each. Breakdown + 13 cross-task amendments + Director ratifications D-RAT-1…8:
`design/M1_11_Tasks/M1.11_Breakdown.md`. Every task doc carries a BINDING `Resolved Decisions
(Phase 3)` section. **Contracts:** FOUR permanent controls byte-identical at every wave
boundary (all-off fp `e943ac9c8bc1` + `band_greybox` + `band_two` + `band_three` fps); scatter
determinism = order-stable sampling + connectivity/2×2-passability **by construction**
(`min_cover_spacing >= 3` + `chunks_x >= 5` validate() clamps — no carve); **cost-ledger** in
every build worklog (the N=3 trend is UG3's evidence; U1's target = 1 line, U3's = 0);
per-def bijection at 11 defs; knob model frozen; no save change; single-writer-per-file per
wave (`main_game.gd`: U1 through Wave 2 → U4's one `BAND_ROUTES` row Wave 4;
`band_pipeline.gd`/`band_profile.gd`: U0 only); parallel agents in worktrees; the shared
`config_strings.csv` gloss rows applied by the orchestrator in ONE Wave-1 merge commit;
PixelLab Director-gated (tint-only).

### Wave 1 — Backend + the two oppositions  *(U0 ∥ U2a ∥ U2b, parallel worktrees, file-disjoint)*

### U0 — ScatterBackend: open-field arena generator + `ScatterBandConfig` + pipeline dispatch
- Milestone: M1.11 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_11_Tasks/U0_scatter_backend.md` (body + §10 Resolved Decisions RD-0…RD-18)
- Goal: `ScatterBandConfig` (integer-only canonical schema RD-11: `grid_width/height` (56×36; `chunks_x >= 5` clamp), `cover_density_pct`, `min_cover_spacing` (>= 3 hard clamp), `border_margin` (>= 2), `cover_w_1x1/2x1/1x2/2x2` weights, `edge_cover_bias_pct`, `clear_lane_width`, `chunk_cells` 8, `cell_size_px` 16 — NO retry fields) + a `ScatterBackend` in `systems/bandgen/`: arena floor → **stratified grid-jitter poisson cover stamping** (fixed-length `1+4·S` RNG stream; sorted order) → ≤2×2 footprints as non-floor → full-width seed-drawn clear lane → **chunk partition** (content-hashed `scat_` ids; `max_depth >= chunks_x−1 >= 4`) → lane-aligned west-most 2×2-open entry anchor. Connectivity + 2×2 passability BY CONSTRUCTION (RD-6 proof — every floor cell ∈ the 2×2-open set; no carve). Replace the pipeline scatter fail-loud with dispatch; `validate()` scatter branch (flavors fail-loud; both clamps). `cave_backend.gd` byte-untouched (duplicate chunk/emit machinery, RD-14). Touches ONLY `systems/bandgen/` + `data/bands/*.gd` schema + tests — NOT `main_game.gd`.
- Done when: `test_scatter_backend` S1–S11 green (same seed → same fp ×2; diff seed → diff fp; single connected FLOOR component; spacing/stratum non-vacuity stats; chunk depth bar; 2×2 throat; S11(a) full-width lane == interior width; cover-budget bound); all FOUR control fps byte-identical; existing bandgen suite green (P7/C8 fail-loud cases survive unedited); worklog + cost ledger + commit.

### U2a — New opposition #7: Lobber "The Mortar" (def + one `MortarCycle` component)
- Milestone: M1.11 (Wave 1)   Assignee: general-purpose (+ character-animator: marker/placeholder)   BlockedBy: none
- Spec: `design/M1_11_Tasks/U2a_lobber.md` (body + §Resolved Decisions; D-RAT-3)
- Goal: `lobber.tres` (**credit_cost 2 · per_room_cap 1 · per_band_cap 5** — amendment 1; min_band=4, off by default) + the ONE new `MortarCycle` component: AIM (`fire_period_s`) → IN-FLIGHT (`arc_time_s`; **marker locked at fire time** — the fairness contract; `lead_factor 0` D-RAT-3) → one-frame IMPACT (**centre-in-radius** distance test, drawn ring == `blast_radius`, `kills`-gated via `LethalContact &"external"` `apply_contact` — the `command_hit` host-position test is wrong for a remote shell) → cycle. **Single shell**; geometry-ignoring (no LOS); body non-lethal, always throw-killable; static. Positional desync + `ctx phase_salt` harness-override mirror (component-internal). Fairness envelope `arc_time > ~0.27 + blast/200` (defaults 0.9 s / 48 px ≈ 0.39 s slack). All-off lever is additive-OR — assert zero *spawns* on shallow bands. NO shared-file edit; gloss rows deferred to the orchestrator merge commit.
- Done when: all-off fp unmoved; bijection green (dir-scan net, no hard count); `test_lobber` green (marker precedes impact by authored `arc_time`; centre-in-radius kill gated; geometry-ignoring across a wall; period cycle; throw-killable; def < DeckEntry < rc.param_overrides flow; deterministic); menu section auto-appears; worklog + cost ledger + commit.

### U2b — New opposition #8: Sentry (def + one `LaneWatch` component)
- Milestone: M1.11 (Wave 1)   Assignee: general-purpose (+ character-animator: lane/bolt placeholder)   BlockedBy: none
- Spec: `design/M1_11_Tasks/U2b_sentry.md` (body + §Resolved Decisions incl. A1–A4; D-RAT-4)
- Goal: `sentry.tres` (**credit_cost 2 · per_room_cap 1 · per_band_cap 5** — A4; min_band=4, off by default) + the ONE new `LaneWatch` component: lane **derived** (8 fixed octants, `intersect_ray` vs world, longest-pick fixed tie-break) **on the SECOND tick** (A1 — first-tick latch races the broadphase), latching direction AND effective clear **length** (A2 — strip visual, crossing test, bolt max-travel all use it; dense-cover spawn degrades to a short honest lane); IDLE (lane **always-visible**, D-RAT-4) → WINDUP (authored flash; LOS-gated) → FIRE (component-owned driven bolt + per-frame script-swept `kills`-gated test — the ChargeLane idiom; **wall-blocked, stop-on-first-hit, no pierce**; thrown_item reuse rejected) → COOLDOWN (crossable: `cooldown_s >= (lane_width + 2·PLAYER_R)/200`; defaults 1.2 vs 0.28 bar). **Centre-crossing trigger; permanent throw-disable** (D-RAT-4). Body never contact-lethal. NO shared-file edit.
- Done when: all-off fp unmoved; bijection green (11 defs, dir-scan); `test_sentry` green (second-tick acquisition rider — await ≥2 physics frames; windup lead honored; bolt kills-gated + wall-stopped + travel capped at `_lane_len_eff`; cooldown-gap bar; lane geometry from params; throw-kill disables; deterministic); menu section auto-appears; worklog + cost ledger + commit.

### Wave 2 — Materialisation verify  *(U1 alone — sole `main_game.gd` writer through Wave 2; ledger target 1 line)*

### U1 — Scatter materialisation ride-through + downstream verify
- Milestone: M1.11 (Wave 2)   Assignee: general-purpose   BlockedBy: U0
- Spec: `design/M1_11_Tasks/U1_scatter_materialisation.md` (body + §Resolved Decisions RD-U1-0…8)
- Goal: prove the scatter band rides the EXISTING synthetic-piece path — audit verdict: the free ride holds everywhere except ONE line: flip the gate-snap guard at `main_game.gd:1076` from denylist `backend != "cave"` to allowlist `== "socket"` (byte-identical on socket/null/cave arms — walked at all 3 helper call sites; without it the scatter pinned gate is a latent softlock). The unedited `SocketSealer` wall-caps arena perimeter + every cover footprint identically (no perimeter concept in the loop; ~210 tiles at defaults). Rewrite the helper docstring + 2 stale call-site comments in the same commit (uncounted). Verify downstream end-to-end: DepthGrader anchors, snapped gate, JunkPlacer, EncounterBuilder, camera/collision, tint.
- Done when: scatter-profile dive runs headlessly end-to-end; all FOUR control fps byte-identical (arm-walk + fp suite); existing hub/routing/rg1 suites green UNMODIFIED; `test_scatter_materialise` green (M6 strengthened: every floor cell ∈ 2×2-open T, T == floor set, single component — red routes to U0; exhaustive per-cover-cell point-query closure on seed[0], tile-atlas matrix-wide; fp+floor_fp pre/post byte-equal; gate snapped + reachable; junk/encounters on floor); worklog + **the 1-line ledger** + commit.

### Wave 3 — The band as data  *(U3 — the N=3 scalability measurement; ledger target 0)*

### U3 — New band: `band_four.tres` "The Far Field" (scatter profile + deck + tint)
- Milestone: M1.11 (Wave 3)   Assignee: game-director-designer (+ environment-artist: tint, general-purpose: glue/tests)   BlockedBy: U0, U1, U2a, U2b
- Spec: `design/M1_11_Tasks/U3_band_four.md` (body + §Resolved Decisions; D-RAT-5/6)
- Goal: author The Far Field as data — `backend="scatter"`, `scatter_config_band_four.tres` (RD-4 re-based on U0's canonical schema: **64×64 · cover_density_pct 8 · min_cover_spacing 4 · border_margin 2 · weights 4/1/1/1 · edge_cover_bias_pct 60 · clear_lane_width 3 · chunk_cells 8 · cell 16** — sparse-deadly, chunks_x 8 passes the clamp), `band_depth=4` (→ instability 1.45 → **34-credit** budget), deck pin **`lobber 5 / sentry 5 / charger 4 / bomb 6 = 20 spawns, budget exactly 0`** (D-RAT-6; bombs = remainder sponge; supporting draw = charger — its lanes come alive in the open), `depth_curve_band_four.tres` (value 1.45→**2.9**, tier →**5**, density **1.0→1.2** on ~64 junk-bearing pieces), **cold-indigo `palette_tint Color(0.42, 0.46, 0.62)`** (D-RAT-5), **flavors = [] MANDATORY** (scatter validate() fail-louds). Re-assert `max_depth >= 4` + 2×2 throat + S11(a) lane bar on the authored config.
- Done when: `band_four` deterministic (same seed → same fp ×2; connectivity + lane bar green); deck spawns the pinned 5/5/4/6 outcome at 34 credits spend-to-0; ALL FOUR control fps untouched (absolute golden pins); headless profile-load contract test green (re-based C3 cover-budget bound; C6 = the new pin; C11 row-run == 62); worklog + **headline 0-line cost ledger** + commit.

### Wave 4 — Reachability

### U4 — Fourth hub portal + `band_four` routing
- Milestone: M1.11 (Wave 4)   Assignee: general-purpose   BlockedBy: U3
- Spec: `design/M1_11_Tasks/U4_hub_portal_routing.md` (body + §Resolved Decisions; D-RAT-5/8)
- Goal: fourth `departure_portal.tscn` instance at the reserved mirror slot **(-110, -20)** (`interactable_id=&"portal_band_four"`, route key `&"band_four"`, **saturated-indigo glow `Color(0.15, 0.25, 1.0)`** (gate wash ≈ `(0.55, 0.62, 1.0)`), prompt **"Dive — The Far Field"**); one-line `BAND_ROUTES` add (`&"band_four"` → `band_four`); all three existing portals byte-identical; `band_id == &"band_four"` on run rows (generic stamp — verify). **Hub contract pins plaza-FULL: exact set-equality of the 5 interactable ids** (D-RAT-8 — band 5 deliberately starts red; comment names the band-select forcing function). Always present; no save change.
- Done when: three existing portal paths byte-identical (fp + hub contract unmodified cases); new-portal contract check (H8 set-equality; routes to band_four with its fp; wipe-isolated); `band_id` verified; smoke + routing green; worklog + cost ledger (≈1 line + scene block) + commit.

### Wave 5 — Re-gate  *(standing playtest-gate steps)*

### UG1 — M1.11 playtest build + verify + changelog + itch publish
- Milestone: M1.11 (Wave 5)   Assignee: qa-playtest-coordinator   BlockedBy: U0–U4 all Done
- Spec: breakdown §UG1; template `design/M1_10_Tasks/TG1_playtest_build.md`
- Goal: full verify matrix (fp `e943ac9c8bc1` · knob + 11-def bijection · all FOUR band fps · scatter determinism + connectivity + lane bar · all FOUR portals route · preset parity · suite incl. the U2b A1 second-tick rider + U1's seed[0] closure matrix); `changelog.txt` M1.10→M1.11 feature delta (fourth band + open-field generator + two ranged oppositions); publish to itch (`BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh`, human/network-gated). **UG1 Director-eyeball rider (amendment 12): BOTH transit lanes (spawn→portal-2 AND spawn→shop) + the four-glow plaza read.**
- Done when: verify matrix green; changelog committed; build live on `qusto/the-far-yard:html5`.

### UG2 — M1.11 telemetry / balance analysis
- Milestone: M1.11 (Wave 5)   Assignee: qa-playtest-coordinator   BlockedBy: UG1 + Director playtest
- Goal: four-band comparison off `band_id` (band-total value); Lobber marker + Sentry windup fairness (deaths-per-first-encounter vs Ambusher/Burrower/Wrecker baselines); open field tense-vs-empty (time-to-gate + loiter-vs-sprint vs bands 2/3); lane-as-highway feel (U0 RD-15); sentry throw-disable piñata watch (D-RAT-4); exposed-center loot value watch (M2 candidate); 1.45 budget sanity (5/5/4/6 deterministic — drift = cap/refusal); web perf with cover-collision geometry; `debug_dirty` filtered.
- Done when: analysis doc assembled for UG3.

### UG3 — M1.11 re-gate verdict (Director decides)
- Milestone: M1.11 (Wave 5)   Assignee: qa (assembles) → Director (decides)   BlockedBy: UG2
- Goal: go/iterate/pivot in `design/M1_11_Tasks/G4_findings_M1.11.md`. Watch-items: **the N=3 cost-ledger trend** (backend #3 + oppositions #7/#8 vs M1.10's price — is "content = data" compounding?); open-field fun read; do Lobber/Sentry enter other decks; **plaza FULL — band 5 forces the band-select surface** (design task next version?); pack-hunters (deferred coordination axis) next?; extract-vs-duplicate chunk machinery on a 4th backend (U0 RD-14); four bands ≈ the GDD's "bands 1–4 distinct biomes" — is M1's band spread complete?
- Done when: recorded verdict.

---

## M1.10 — Second Generation Backend + Cave Band + Low-Sightline Oppositions (build DONE + TG1 published; TG2/TG3 Director-pending, non-blocking)

**Build waves T0–T4 all DONE + integrated; TG1 DONE + published** (`m1-20260706-d04bd13`, incl. the
FBM-A1 Ambusher stalker rework + FBM-A2 Director tuning). Breakdown + amendments + ratifications
D-RAT-1…9: `design/M1_10_Tasks/M1.10_Breakdown.md`. **Open (Director-gated, non-blocking M1.11):**
TG2 (telemetry/balance) + TG3 verdict in `design/M1_10_Tasks/G4_findings_M1.10.md` — await the
Director's playtest of the published build. One Wave-5 test-fixture deviation awaits disposition at
the TG3 close-out (rec Reviewed). Build-task specs T0–T4 + TG1 archived → `TASKS_COMPLETED.md` §M1.10.

### TG2 — M1.10 telemetry / balance analysis
- Milestone: M1.10 (Wave 5)   Assignee: qa-playtest-coordinator   BlockedBy: TG1 + Director playtest
- Goal: three-band comparison off `band_id` (band-total **value** not item counts — per-chunk loot rolls); Ambusher tell + Burrower telegraph fairness (deaths-per-first-encounter vs Wrecker/Splitter); does the cave disorient productively vs read as lost (time-to-gate vs band 2); 1.30 budget sanity (deck outcome 6/3/4/1 is deterministic — count drift = cap/refusal); web perf with cave wall-collision geometry; `debug_dirty` filtered.
- Done when: analysis doc assembled for TG3.

### TG3 — M1.10 re-gate verdict (Director decides)
- Milestone: M1.10 (Wave 5)   Assignee: qa (assembles) → Director (decides)   BlockedBy: TG2
- Goal: go/iterate/pivot in `design/M1_10_Tasks/G4_findings_M1.10.md`. Watch-items: **the cost ledgers** (did backend #2 + oppositions #5/#6 hold "content = data"?); cave depth-signposting (lighting/cue next?); do Ambusher/Burrower enter shallower decks; ScatterBackend next?; flavor stages on cave floor; hub portal-row scaling (3 portals — band 5 forces a band-select surface).
- Done when: recorded verdict.

---

## M1.9 — Scalable Opposition + Band Systems (build DONE; SG2/SG3 Director-pending, non-blocking)

**Build waves S0–S9 all DONE + integrated; SG1 DONE + published** (`m1-20260704-55ca78f`, incl.
FBM19/FBM19b feedback fixes). Breakdown + amendments + ratifications: `design/M1_9_Tasks/M1.9_Breakdown.md`.
**Open (Director-gated, non-blocking M1.10):** SG2 (telemetry/balance off `band_id`) + SG3 verdict in
`design/M1_9_Tasks/G4_findings_M1.9.md` — await the Director's playtest of the published build. Build-task
specs S0–S9 archived → `TASKS_COMPLETED.md` §M1.9.

### SG2 — M1.9 telemetry / balance analysis
- Milestone: M1.9 (Wave 6)   Assignee: qa-playtest-coordinator   BlockedBy: SG1 (done) + Director playtest
- Goal: per-band comparison off `band_id`; new-hazard readability + fairness (via `opposition_event`); The Sump's +15% step felt?; `debug_dirty` runs filtered; web perf with the deck live.
- Done when: analysis doc assembled for SG3.

### SG3 — M1.9 re-gate verdict (Director decides)
- Milestone: M1.9 (Wave 6)   Assignee: qa (assembles) → Director (decides)   BlockedBy: SG2
- Goal: go/iterate/pivot in `design/M1_9_Tasks/G4_findings_M1.9.md`. Watch-items: did "content = data" hold; promote charger/splitter to band 1?; legacy-signal retirement; ceiling numeric merge; CaveBackend/ScatterBackend next? *(M1.10 answers the CaveBackend watch-item.)*
- Done when: recorded verdict.

---

## M1.9 — build-task detail (SUPERSEDED — specs archived to `TASKS_COMPLETED.md` §M1.9)

_The full S0–S9 task specs below are retained for provenance only; they are all Done. The active M1.9
surface is the SG2/SG3 block above._

## M1.9 — Scalable Opposition + Band Systems (ACTIVE — Director-directed; design LOCKED 2026-07-02)

Implement the two explored scalable architectures — the **SpawnService/EncounterBuilder** split
(opposition v2) and the **BandProfile/BandPipeline** (bands) — then prove them with **2 new hazards
(Charger "The Wrecker" + Splitter) and 1 new band ("The Sump", `band_two`)** behind a second hub portal.
Breakdown + cross-task amendments + Director ratifications: `design/M1_9_Tasks/M1.9_Breakdown.md`.
Every task doc carries a BINDING `Resolved Decisions (Phase 3)` section. **Contracts:** all-off fp
`e943ac9c8bc1` byte-identical at every wave boundary; bandgen determinism byte-matches through the
pipeline; knob model 89 (frozen legacy) → 91 at S4; no save-schema change; legacy R1/K5 knobs + signals
stay (dual-emit) through the gate; single-writer-per-file per wave (`main_game.gd`: S0 → S3 only;
`run_config.gd` Wave-4 writer = S4); parallel agents in worktrees; no PixelLab (D-RAT-4).

### Wave 1 — Foundations  *(S0 ∥ S1, parallel worktrees)*

### S0 — SpawnService + OppositionDef data layer + EventBus pre-declare
- Milestone: M1.9 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_9_Tasks/S0_spawn_service.md` (body + §Resolved Decisions)
- Goal: extract the mechanism half of `_spawn_new_hazards` into a policy-free per-dive `SpawnService`; author the 4 shipped hazards as `OppositionDef.tres` (`Game/data/oppositions/`); pre-declare `opposition_event` / `opposition_killed_player` (silent until S2) / `debug_run_dirtied` + the `dive_requested` doc-amendment + inert GameState staging seam. Sole writer of `main_game.gd`, `event_bus.gd`, `game_state.gd` this wave.
- Done when: all-off fp `e943ac9c8bc1` byte-identical; every `test_rg1_m1*` + `test_new_hazard_spawn` green UNMODIFIED (forwarding consts + ctx forwarder); preset cohort unchanged; new `test_spawn_service` green (caps/registry/valid_cells/clear_all/staging round-trip); import + smoke green; worklog + commit.

### S1 — BandProfile + BandPipeline + `band_greybox.tres`
- Milestone: M1.9 (Wave 1)   Assignee: general-purpose   BlockedBy: none
- Spec: `design/M1_9_Tasks/S1_band_profile_pipeline.md` (body + §10 Resolved Decisions)
- Goal: `BandProfile` resource (incl. `palette_tint`) + `BandPipeline.generate(profile, seed, rc)` delegating to today's `BandGenerator` (seal stays at materialisation; marked `# STAGE HOOK (S5)` slot) + `data/bands/band_greybox.tres`. Touches ONLY `systems/bandgen/` + `data/bands/` + new tests.
- Done when: `test_band_pipeline_parity` byte-matches fingerprints vs the direct path across the 9-seed matrix (+ grading/rc-pass-through/purity guards); existing bandgen suite green; all-off fp unmoved; worklog + commit.

### Wave 2 — Internals  *(S2 ∥ S5, parallel worktrees)*

### S2 — Opposition component extraction + `param_schema`
- Milestone: M1.9 (Wave 2)   Assignee: general-purpose   BlockedBy: S0
- Spec: `design/M1_9_Tasks/S2_components_param_schema.md` (body + §Resolved Decisions)
- Goal: refactor the 4 shipped entities onto the 9-component set (host-ticked child Nodes, resolved primitives; guards/timers transplant line-for-line into hosts); complete per-def `params`+`param_schema` (incl. `trap_if_neutral`); land the `thrown_item.gd` seam `resolve_throw_death(killer_ctx) -> bool` + the `LethalContact` external-contact seam; dual-emit generic signals from components.
- Done when: all-off fp byte-identical; full hazard suite green; golden frame-trace parity harness green (goldens captured pre-refactor); params↔schema bijection check green; worklog + commit.

### S5 — Band flavor stages: SetPieceInject + WearDecay + connectivity guarantee
- Milestone: M1.9 (Wave 2)   Assignee: general-purpose   BlockedBy: S1
- Spec: `design/M1_9_Tasks/S5_flavor_stages_connectivity.md` (body + §10 Resolved Decisions)
- Goal: the two flavor stages (attach-at-socket set-pieces via `SetPieceEntry` pools; breach-led WearDecay) + the ASSERT/CARVE connectivity stage, in S1's stage hook, per-stage sub-seeds, off by default.
- Done when: empty-flavors control fingerprint unmoved; per-stage double-run determinism green; strand-proof test green at max decay across the seed matrix; `floor_fingerprint()` guardrails in place; worklog + commit.

### Wave 3 — Integration  *(S3 alone — sole `main_game.gd` writer)*

### S3 — EncounterBuilder + RunConfig levers + both call-site integrations
- Milestone: M1.9 (Wave 3)   Assignee: general-purpose   BlockedBy: S0, S1, S2
- Spec: `design/M1_9_Tasks/S3_encounter_builder_integration.md` (body + §7 Resolved Decisions)
- Goal: policy out of `main_game` into `EncounterBuilder.populate(band, deck, I, svc)` (legacy lane = byte-exact parity; deck lane = credit budget, `instability(d)=1.0+0.15*(d-1)`); levers `oppositions_enabled`/`param_overrides` as `@export_storage`; `main_game` → `BandPipeline.generate` + `_resolve_band_profile()` (default `band_greybox`) + `piece_pool_ext` field.
- Done when: all-off fp byte-identical THROUGH the new call sites; byte-exact preset parity (plan-capture vs FakeSpawnService); bandgen determinism green through the pipeline; `test_encounter_builder` (8 cases) green; suite green unmodified; worklog + commit.

### Wave 4 — Surface + content proof  *(S4 ∥ S6a ∥ S6b ∥ S7, parallel worktrees)*

### S4 — Generated debug-menu sections + coverage 91 + sweep hygiene
- Milestone: M1.9 (Wave 4)   Assignee: general-purpose   BlockedBy: S2, S3
- Spec: `design/M1_9_Tasks/S4_generated_config_menu.md` (body + §8 Resolved Decisions)
- Goal: 9th "Oppositions" tab generated from `param_schema` (all authored defs, sorted ids); promote the two levers to `@export` + bound rows (count model 89 frozen legacy + 2 = **91**); per-def bijection assertion; sparse `param_overrides` staging stamped on `run_started`; explicit respawn-with-new-params button emitting `debug_run_dirtied`; Telemetry subscribes to the generic signals. Sole Wave-4 writer of `run_config.gd`.
- Done when: two-part coverage pin green (89 legacy + named levers = 91); per-def bijection green; headless menu matrix (0/4/6 defs) green as scenes; `debug_dirty` lands on run rows; all-off fp unmoved; worklog + commit.

### S6a — New hazard #1: Charger ("The Wrecker")
- Milestone: M1.9 (Wave 4)   Assignee: general-purpose (+ character-animator: placeholder sprite/tell)   BlockedBy: S2, S3
- Spec: `design/M1_9_Tasks/S6a_charger_hazard.md` (body + §Resolved Decisions; D-RAT-2)
- Goal: `charger.tres` (min_band=2) + the ONE new `ChargeLane` component (host-ticked; DORMANT→TELEGRAPH→CHARGE→RECOVER; swept-segment lethal via the LethalContact external seam; `lock_at_telegraph_start=true`; wall-crash stun knob; group-toggle dash-invuln — deck override per D-RAT-2); `ProximityTrigger` wake; greybox directional-wedge tell.
- Done when: all-off fp unmoved; `test_charger` green (telegraph timing, kill gating, wall stop, cap=1/room, events); params↔schema green; deterministic placement; worklog + commit.

### S6b — New hazard #2: Splitter
- Milestone: M1.9 (Wave 4)   Assignee: general-purpose (+ character-animator: placeholder sprites)   BlockedBy: S2, S3
- Spec: `design/M1_9_Tasks/S6b_splitter_hazard.md` (body + §Resolved Decisions; D-RAT-2)
- Goal: `splitter.tres` + `splitter_child.tres` (min_band=2, `cap_group=&"new_hazards"`, per_band_cap=8) + the throw-death split hook (client (b): `svc.spawn` mid-run at adjacent `valid_cells`, deterministic-per-split from parent, ctx carries depth/run_t_ms); slow `ChaseMove` pursuer; children half-scale, pure cost, gen 1; `&"split"`/`&"split_refused"` events.
- Done when: all-off fp unmoved; generation fingerprint unaffected by splits; cap-refusal test green; `test_splitter` green; params↔schema green (both defs); worklog + commit.

### S7 — New band: `band_two.tres` ("The Sump")
- Milestone: M1.9 (Wave 4)   Assignee: game-director-designer (+ environment-artist: tint pass, general-purpose: glue)   BlockedBy: S1, S5, S3
- Spec: `design/M1_9_Tasks/S7_band_two.md` (body + §Resolved Decisions; D-RAT-1/3/4)
- Goal: author The Sump as data — socket/branchy (target 16, branch 0.15), `band_depth=2`, flavors `SetPieceInject` (reused large piece) + `WearDecay(&"flooded")` per S5's real schemas, 6-entry deck (4 legacy + charger/splitter, authored order), `depth_curve_band_two.tres` (1.15→2.1, tier 2→5), sepia-amber `palette_tint` (tint-only).
- Done when: `band_two` deterministic (same seed → same fp ×2; connectivity through decay green); deck spawns within caps via the builder; `band_greybox` control untouched; headless profile-load contract test green; worklog + commit.

### Wave 5 — Reachability

### S8 — Second hub portal + band routing + telemetry stamp
- Milestone: M1.9 (Wave 5)   Assignee: general-purpose   BlockedBy: S3, S7
- Spec: `design/M1_9_Tasks/S8_hub_portal_routing.md` (body + §Resolved Decisions; D-RAT-1)
- Goal: second `departure_portal.tscn` instance at (220,-150) (`interactable_id=&"portal_band_two"`, route key `&"band_two"`, ember-orange glow, Sump prompt); rewrite `_resolve_band_profile()` off `consume_pending_dive_band()`; portal 1 (`&"near"`→band_greybox) byte-identical; `band_id` already stamps run rows (verify).
- Done when: existing portal path byte-identical (fp + `test_hub_contract`); `test_band_routing` green (new portal lands in band_two with its fp); smoke green; no save change; worklog + commit.

### S9 — Deck-entry override wrapper (D-RAT-2 delivery) *(Wave-4 close-out, Director Addressed 2026-07-03)*
- Milestone: M1.9 (Wave 5, ∥ S8)   Assignee: general-purpose   BlockedBy: S3, S6a, S7
- Spec: none (close-out-planned task) — contract in this entry + `DESIGN_DEVIATIONS_HISTORY.md` §M1.9 Wave-4 (ORCH entry). Origin: D-RAT-2's Charger "deck `param_override → false`" had no data mechanism (deck = plain def refs per S7 §RD).
- Goal: a `DeckEntry` Resource (`def: OppositionDef` + `param_overrides: Dictionary`) accepted in `BandProfile.opposition_deck` MIXED with plain defs (back-compat); the EncounterBuilder deck lane merges overrides at ctx time with precedence def params < deck-entry overrides < `rc.param_overrides`; rewrap band_two's charger row with the D-RAT-2 values (`throwable_while_charging=false`, `wall_crash_recover_mult=2.0`); tests (mixed-deck parity: a wrapper with empty overrides ≡ plain ref, byte-identical; precedence; band_two charger receives the D-RAT-2 values).
- Done when: all-off + greybox fps byte-identical; `test_band_two_profile`/`test_encounter_builder`/`test_charger` green (charger def defaults still D-RAT-2-letter — the test pins them); new `test_deck_entry` green; worklog + commit.

### Wave 6 — Re-gate  *(standing playtest-gate steps)*

### SG1 — M1.9 playtest build + verify + changelog + itch publish
- Milestone: M1.9 (Wave 6)   Assignee: qa-playtest-coordinator   BlockedBy: S0–S9 all Done
- Spec: breakdown §SG1; template `design/M1_8_Tasks/HG1_playtest_build.md`
- Goal: full M1.9 verify matrix (fp `e943ac9c8bc1` · 91-knob model · bandgen determinism · preset parity · both portals · suite); `changelog.txt` M1.8→M1.9 feature delta; publish to itch (`BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh`, human/network-gated).
- Done when: verify matrix green; changelog committed; build live on `qusto/the-far-yard:html5`.

### SG2 — M1.9 telemetry / balance analysis
- Milestone: M1.9 (Wave 6)   Assignee: qa-playtest-coordinator   BlockedBy: SG1 + Director playtest
- Goal: per-band comparison off `band_id`; new-hazard readability + fairness (via `opposition_event`); The Sump's +15% step felt?; `debug_dirty` runs filtered; web perf with the deck live.
- Done when: analysis doc assembled for SG3.

### SG3 — M1.9 re-gate verdict (Director decides)
- Milestone: M1.9 (Wave 6)   Assignee: qa (assembles) → Director (decides)   BlockedBy: SG2
- Goal: go/iterate/pivot in `design/M1_9_Tasks/G4_findings_M1.9.md`. Watch-items: did "content = data" hold (true proof cost incl. the LethalContact seam); promote charger/splitter to band 1?; legacy-signal retirement; ceiling numeric merge; CaveBackend/ScatterBackend next?
- Done when: recorded verdict.

---

## M1.8 — Hub Art Dressing — ✓ CLOSED 2026-07-02 (Director)

Build + HG1 published (final `m1-20260702-3faeed0`, 45° iso hub retained; H2 top-down = revert path). HG2
short-circuited by direct Director review; verdict + watch-items: `design/M1_8_Tasks/G4_findings_M1.8.md`.
17 deviations dispositioned (15 Reviewed + 2 Addressed) + archived. Tasks archived → `TASKS_COMPLETED.md`.
H3 (street-threshold prop) carried to the follow-ups section below.

---

## M1.7 — Player Embodiment (build DONE; RG2/RG3 Director-pending, non-blocking)

Replace the greybox player (teal `ColorRect`+`Nose`) with the **first real character sprite** — the
`player_basic_template` (flannel/hoodie, 8-directional: walk · pickup · throw · idle-from-rotations) — in **both** the Hub
and the Dive, driven entirely off the existing `facing`/`aim`/`velocity`/`junk_picked_up`/`item_thrown` seams; plus a
**debug toggle** to disable the art (fall back to greybox). Breakdown + dependency map + wave order + locked decisions:
`design/M1_7_Tasks/M1.7_Breakdown.md`. **Design is LOCKED** — every task doc carries a `Resolved Decisions` + a
`Director Disposition` section. Director calls: art in BOTH hub+dive (one shared `player.tscn`); pickup/throw use a **brief
movement-lock** (lock on **accepted** pickups only; **clip-driven** duration) — **both exposed as `@export` knobs** on the
visual controller (NOT `RunConfig` fields). **Invariants:** all-off `RunConfig` fp stays `e943ac9c8bc1`; **89-knob count
holds** (the debug art toggle is a view-only switch OUTSIDE the `config_menu` MANIFEST/coverage); **art-OFF = M1.6
byte-for-byte** (greybox retained, no lock); collision r=14 + `player_movement.tres` untouched; frames **COPIED** (never
moved) from `art_workshop/` into `Game/`, filter-off, LFS. Sequential single wave: N0 → N1 → N2.

**Build tasks all DONE + archived → `TASKS_COMPLETED.md`** (N0 `07edb77` · N1 `47ab9a8` · N2 `cffb5db` ·
RG1 published `m1-20260628-867410f` + FIXINTERP/FIXEAST/PLAYERTAB/art-default-OFF follow-ups).
Open here: RG2/RG3 (Director-pending, non-blocking).

### RG2 — M1.7 readability / telemetry check
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator   BlockedBy: RG1 + human playtest data
- Spec: template `design/M1_1_Tasks/RG2_telemetry_analysis.md`
- Goal: light pass (visual change) — confirm no perf regression from the sprite on the web build; telemetry comparable to M1.6; surface any readability friction (8-dir snapping, movement-lock feel) the Director flags.
- Done when: a short analysis artifact + the Director's readability notes assembled for RG3.

### RG3 — M1.7 re-gate verdict (Director decides)
- Milestone: M1.7 (Wave 2)   Assignee: qa-playtest-coordinator (assembles) → Director (decides)   BlockedBy: RG2
- Spec: template `design/M1_1_Tasks/RG3_regate_verdict.md`
- Goal: record go/iterate/pivot in `design/M1_7_Tasks/G4_findings_M1.7.md`. Watch-items: movement-lock feel; 8-direction legibility; the dive-gear-vs-surface-look question.
- Done when: a recorded go/iterate/pivot verdict.

---

## M1 follow-ups (deferred tech-debt — non-blocking, backlog)

From the M1 wave-5 close-out (`DESIGN_DEVIATIONS_HISTORY.md` §"M1 wave 5"). Neither blocks M1.2; pick up opportunistically.

### H3 — Street-exit threshold prop (PixelLab) — **DEFERRED (Director-gated, paid credits)** *(carried from M1.8, closed 2026-07-02)*
- Milestone: M1.8 (follow-up)   Assignee: environment-artist   BlockedBy: Director OK
- The one missing Layout-A spec prop (`SS`); not loop-critical (no functional street exit yet). Generate only on explicit Director go. Watch-item context: `design/M1_8_Tasks/G4_findings_M1.8.md`.

### FU5 — Shared Actor-host shell (zero per-def host files) *(post-gate; Wave-4 close-out, Director Addressed 2026-07-03)*
- Milestone: backlog (post-M1.9-gate)   Assignee: general-purpose   BlockedBy: M1.9 SG3 verdict
- Origin: S6a dev 1 (`charger_hazard.gd` host shell was needed beyond "def + one component"). Director directed a shared host scene/script so a new def needs ZERO new host files — the per-entity shell (family guard, run clock, component acquire/tick order, emit sites, seams) becomes one generic parameterized host. Constraint: the def-schema host contract (bare instance reports `get_def_id()==def.id`) must survive, and golden frame-trace parity for all shipped hazards must hold.

### BUG-M13FLAKE — `test_rg1_m13_verify` intermittently misses telemetry rows headless
- Milestone: backlog (QA)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Pre-existing timing flake (confirmed on pre-Wave-2 `main` 9cc00c1, ~40% failure rate across repeated headless runs, 2026-07-03): m13 intermittently reports missing nav/exposure/timeout telemetry rows ("emitted none of […]"), passes on retry. NOT an M1.9 regression. Diagnose the timed-segment race and stabilize (deterministic clock or generous margins). Board item created 2026-07-03.

### FU1 — GdUnit4 `test_jsonl_writer`
- Milestone: M1 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `M1_As_Built.md` §Telemetry + `systems/telemetry/jsonl_writer.gd`
- Goal: add the GdUnit4 `test_jsonl_writer` suite G2 deferred — exercise the writer seam (write rows, read back, assert parseable JSON + envelope fields `v, ts, t_ms, run_id, session_id, type, data`).
- Done when: a GdUnit4 suite under `tests/telemetry/` covers `JsonlWriter` round-trip + envelope fields; green headless; test count rises.

### FU2 — Static `EconomyMath` helper
- Milestone: M1 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `systems/game_state.gd` (`_resolve_pockets`/`_sum_values`/`run_haul_value`)
- Goal: lift the pure economy math out of `GameState` into a static `EconomyMath` helper so it's testable without snapshotting global meta; `GameState` delegates; no behavior change.
- Done when: a static `EconomyMath` owns pockets/sum/haul; `GameState` delegates; G2 economy suites call it directly (no meta snapshot); suite green.

### FU3 — Repair-or-retire `test_rg1_m13_verify` *(M1.6 W2-F1 — Reviewed)*
- Milestone: M1.6 (follow-up)   Assignee: qa-playtest-coordinator   BlockedBy: none
- Spec: `tests/test_rg1_m13_verify.gd` + `design/DESIGN_DEVIATIONS_HISTORY.md` §"M1.6 Wave 2 close-out"
- Goal: the M1.3 RG-verify scene is stale (fails on M5/all-on opposition-telemetry rows + `timeout` end-cause; verified pre-existing at `536c9ba`, not in the CI gate, last green at M1.3). Either align its preset/telemetry expectations to the current build or retire it in favour of the maintained `m14`/`m15` verifies; if kept, wire it into the standing CI set.
- Done when: m13 either passes green deterministically (and is in the CI gate) or is retired with a one-line rationale; no other RG verify regresses.

### FU4 — Keyboard-only aim tracks movement *(M1.5 L6-F1 — Reviewed)*
- Milestone: M1.6 (follow-up)   Assignee: general-purpose   BlockedBy: none
- Spec: `player.gd` `resolve_aim()` + `design/M1_5_Tasks/L6_control_rework.md`
- Goal: when neither mouse (`_mouse_active`) nor right-stick is active, let the pure-keyboard fallback aim track the movement direction instead of holding the DOWN default, without destabilising controller stick-release or letting a stale cursor hijack aim. Mouse + controller (primary) behaviour unchanged.
- Done when: a keyboard-only player's aim follows movement; controller/mouse aim unchanged; throw tests green; all-off fp `e943ac9c8bc1` unmoved.

---

## Backlog (M2+)
Pulled forward when M1.x passes its gate. See TDD §7: M2 (vertical slice: full day loop, recipe repair, first enemy, real art for one band), M3 (bands 1–3, currencies/tracks, exposure crises), M4 (Act 3 + endings), M5 (polish/ship). The **economy workbook** `design/economy_model.xlsx` (game-director-designer) is due **before M3**.
