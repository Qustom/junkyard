# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.12 (Scaling Debt Paydown — pre-M2 architecture cleanup; Director-directed 2026-07-10, opened ahead of M1.11's UG2/UG3) — **design LOCKED 2026-07-10 (D-RAT-1…7; V3b pursuer-migration design pending). Implements the M1.11 systems-state report's R2–R10 (R1/CSV deferred). Master contract: behavior-preserving (4 control layout fps byte-identical + full suite green); measure = the debt ledger (net LOC removed). ▶ Wave 1 build dispatching (V1 ∥ V5 ∥ V7 ∥ V8 ∥ V9).** *(M1.11 build+UG1 published `m1-20260708-69446d5` — Director playtest → UG2 → UG3 pending, non-blocking. M1.10 TG2/TG3, M1.9 SG2/SG3, M1.7/M1.6 RG2/RG3 Director-pending; M1.8 CLOSED.)*

> **M1.12 design LOCKED (2026-07-10):** breakdown + 10 per-task designs (V1–V9 + V3b), each with a
> binding `Resolved Decisions (Phase 3)` (fresh-eyes pass: contract owners V1/V2/V6 first, then
> consumers V3/V4/V5/V7/V8/V9). Director ratifications **D-RAT-1…7** folded into
> `design/M1_12_Tasks/M1.12_Breakdown.md`. Task→recommendation map (report R#): V1←R2 (by-id spawn
> weights + wire CI catalog check) · V2←R3 (retire 6 dual-emit signals, EventBus 60→54) · V3←R4.1
> (K5 lane→deck) · **V3b←R4.2 (R1 pursuer→deck — Director "fold all four", design pending)** · V4←R5
> (facade-preserving GameState split, verified 0 caller edits) · V5←R6 (InteractionOwner helper) ·
> V6←R7 (RNG.substream + substream_hashed, 2 forms — the .seed vs .seed+.state trap) · V7←R8
> (2 MB telemetry rotation + analyze argv) · V8←R9 (CI wall-clock, sharding deferred) · V9←R10
> (delete all 4 empty folders + run.sav). Two Director calls went against Claude's rec: V3 folds the
> pursuer too (D-RAT-3), and V9 deletes recipes/upgrades too (D-RAT-6). Waves: 1 = V1∥V5∥V7∥V8∥V9,
> 2 = V2∥V6, 3 = V4, 4 = V3→V3b, 5 = VG1→VG2→VG3 (regression gate per D-RAT-1). TASKS.md §M1.12 +
> board items V1…VG3 wired (Wave-1 In Progress).

> **M1.11 design LOCKED (2026-07-06):** breakdown + 6 per-task designs each with a BINDING
> `Resolved Decisions (Phase 3)` section (fresh-eyes pass run in two waves — contract owners
> U0/U2a/U2b, then consumers U1/U3/U4); 13 cross-task amendments + Director ratifications
> **D-RAT-1…8** folded into `design/M1_11_Tasks/M1.11_Breakdown.md`. Headlines: backend #3 =
> **ScatterBackend** (open-field arena + order-stable poisson cover; connectivity + 2×2
> passability BY CONSTRUCTION — `min_cover_spacing >= 3` + `chunks_x >= 5` validate() clamps,
> no carve); oppositions #7/#8 = **Lobber "The Mortar"** (no lead, single shell,
> centre-in-radius, marker locked at fire) + **Sentry** (always-visible derived lane latched
> on the 2nd tick, permanent throw-disable) — both band-4-exclusive, `credit_cost 2 ·
> per_band_cap 5` each; band 4 = **"The Far Field"** (scatter, cold-indigo tint, indigo
> portal glow `(0.15,0.25,1.0)`, deck **5/5/4/6 = 20 @ 1.45/34-credit spend-to-0**, reward
> 2.9/tier 5/density 1.2); portal 4 @ the mirror slot **(-110,-20)** + the hub contract pins
> **plaza-FULL (5-id set equality)** — band 5 deliberately starts red (band-select forcing
> function). Version cost targets: U1 = **1 line** (gate-snap allowlist flip), U3 = **0
> lines**. FOUR byte-identical controls (all-off fp `e943ac9c8bc1` + greybox/two/three fps).
> TASKS.md §M1.11 + board items U0–UG3 wired (U0/U2a/U2b In Progress).

**Last updated:** 2026-07-10 (M1.12 opened + design LOCKED — four-phase authoring complete: breakdown + 10 designs + fresh-eyes resolve; Director dispositioned D-RAT-1…7. Phase-4 wire-up done: TASKS.md §M1.12 + 13 board items (Wave-1 In Progress). **▶ Wave 1 build dispatching (V1∥V5∥V7∥V8∥V9); V3b pursuer-migration design authoring in parallel.** M1.11 UG1 build `#1781007` @ `m1-20260708-69446d5` still the live itch build; its Director playtest → UG2/UG3 pending, non-blocking.)

## M1.11 Wave 1 — Done + integrated on `main` (2026-07-06)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| U0 — ScatterBackend + `ScatterBandConfig` + pipeline dispatch | general-purpose | `bd24204` (br feature `bbed6fb` + RD-16 `d2a8a34`) | `test_scatter_backend` S1–S11 OK (9 seeds; sample 12345 → 35 pieces, max_depth 9, fp `44a9a9b3756f`; S11(b) calibrated 90/75 floors vs 99/95 measured); ALL FOUR controls byte-identical (all-off `e943ac9c8bc1` · greybox · band_two · band_three; cave fp `d984fd8913bf` unchanged); P7/C8 fail-louds survive; **ledger 327 lines vs the cave's ~466 — backend #3 ~30% cheaper (the N=3 headline)**; RD-12 sanity of U3's 64×64 config recorded. Worklog `…-U0-general-purpose.md`. **4 deviations (all rec Reviewed).** |
| U2a — Lobber "The Mortar" (def + `MortarCycle`) | general-purpose (animator scope folded) | `7cbe50f` (br `364ffea`) | `test_lobber` OK (12 cases: locked marker + arc_time dodge; centre-in-radius kills-gated BUG6-once; geometry-ignoring; throw-kill stops the rain; additive-OR lever = zero spawns bands 1–3; def<DeckEntry<rc; cap 5/min_band 4 enforced; positional desync + ctx override; RNG-free); all-off fp pinned; card `2/1/5`. Ledger: component ~110 eff. lines, **0 shared-file edits**. Worklog `…-U2a-general-purpose.md`. Deviations: none. |
| U2b — Sentry (def + `LaneWatch`) | general-purpose (animator scope folded) | `4ff5c49` (br `dc1c124`) | `test_sentry` OK (12 cases: A1 second-tick lane + A2 latched `_lane_len_eff` + short-lane honesty; windup fairness — zero pre-flash contact; wall stops bolt + LOS suppression; cooldown bar 1.2 ≥ 0.28; permanent throw-disable; body never lethal; cap 5/min_band 4; RNG-free); all-off fp pinned; card `2/1/5`. Ledger: component ~191 code lines (over ~120–150 prediction — the A1/A2 hardening, itemised), **0 shared-file edits**. Worklog `…-U2b-general-purpose.md`. Deviations: none. |

> **Integration (`fb3435d`):** three file-disjoint worktree branches merged (topology verified); both
> defs' `CFG_FIELD_*` gloss rows (7 lobber + 11 sentry) applied in ONE commit (amendment-6 protocol).
> Integrated verify ALL GREEN: import · scatter · lobber · sentry · **11-def bijection** · def-menu
> coverage · config 91/91 · parity fp `e943ac9c8bc1` · determinism · cave · band_three profile (greybox
> + band_two golden pins) · cave materialise · routing · hub contract · smoke. Board U0/U2a/U2b = Done.
>
> **✓ Wave-1 close-out COMPLETE (2026-07-07):** the Director dispositioned all 4 U0 deviations
> (entry-anchor lane tie-break · no-carve election · S10 strong form · RD-16 comment edits) **Reviewed**;
> U2a/U2b none. Reapply: one clarifying line in `M1.11_Breakdown.md` §entry-anchor contract ("unchanged"
> binds the bars; tie-break is per-backend). All 4 archived → `DESIGN_DEVIATIONS_HISTORY.md` (`218d808`).

## M1.11 Wave 2 — Done + integrated on `main` (2026-07-07)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| U1 — Scatter materialisation ride-through + downstream verify | general-purpose | merge of br `1381aca` (worklog `40e0521`) | **Cost ledger: EXACTLY 1 changed line** (RD-U1-8 — the `:1076` `_pinned_gate_pos` guard `!= "cave"` → `== "socket"`; docstring + 2 call-site comments rewritten, uncounted; RD-U1-0(b) `:1170` fallback untouched). `test_scatter_materialise` M1–M9 GREEN 9 seeds (M6 strengthened: every floor cell ∈ T, `|T| == |floor|`, single component; M2 exhaustive cover-cell point queries seed[0]; M9 socket zero-synthetic + raw-offset pin + cave guard-arm still snaps). C1–C6 re-verified vs landed U0 — no drift. Integrated verify on `main` ALL GREEN: import · scatter-materialise · scatter-backend (fp `44a9a9b3756f`) · cave-materialise · parity fp **`e943ac9c8bc1`** · band_two · band_three (greybox+band_two pins) · band_routing · hub contract · app router · smoke. Worklog `…-U1-general-purpose.md`. **3 deviations (all rec Reviewed).** |

> **✓ Wave-2 close-out COMPLETE (2026-07-08):** the Director dispositioned all 3 U1 deviations
> (M6 `|T|==|floor|` size-belt · M9 socket raw-offset in-suite pin · `_exit_candidate_cells` comment
> deferred per RD-U1-4 scoping) **Reviewed**. No design reapply (test-only/hygiene; the comment is
> already on the post-UG3 hygiene-pass list). Archived → `DESIGN_DEVIATIONS_HISTORY.md`.
>
## M1.11 Wave 3 — Done + integrated on `main` (2026-07-08)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| U3 — `band_four.tres` "The Far Field" (scatter profile + deck + tint) | game-director-designer | merge of br `2e43902` (worklog `1787121`) + integration `72cf997` | **Cost ledger: 0 production lines** (RD-15 — 3 `.tres` + `test_band_four_profile`; N=3 trend: band 2 = 1 line → band 3 = 0 → band 4 = 0). `BAND_FOUR OK` C0–C11, 9 seeds: deck pin **lobber 5 / sentry 5 / charger 4 / bomb 6 = 20 @ 34 credits spend-to-0** (shipped native cards matched RD-1, no re-derivation); measured junk band-total **71.1 mean** (68–75) on RD-11's ~70 target; greybox+band_two+band_three byte-identity pins in-suite. Integrated verify ALL GREEN: import · band_four · def-menu coverage (post-golden) · parity fp **`e943ac9c8bc1`** · band_two/band_three profiles · scatter backend (`44a9a9b3756f`) + materialise · cave materialise · routing · hub contract · 11-def bijection · lobber · sentry · smoke. Worklog `…-U3-game-director-designer.md`. **1 deviation (def-menu golden — U3 flagged, orchestrator applied `72cf997`; rec Reviewed).** |

> **✓ Wave-3 close-out COMPLETE (2026-07-08):** the Director dispositioned the U3 def-menu-golden
> deviation **Reviewed** (test caught up to product; orchestrator-applied at integration `72cf997`).
> Archived → `DESIGN_DEVIATIONS_HISTORY.md`.
>
## M1.11 Wave 4 — Done + integrated on `main` (2026-07-08)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| U4 — Fourth hub portal + `band_four` routing (plaza-full pin) | general-purpose | merge of br `0a12c25` (worklog `721f267`) | **Cost ledger: 1 production line** (the `BAND_ROUTES` row; scene data 9 lines; tests +157). Portal 4 @ `(-110, -20)`, "Dive — The Far Field", indigo `(0.15, 0.25, 1.0)` / gate `(0.55, 0.62, 1.0)`. H8 green (glow pin + pairwise distinctness + **plaza-FULL 5-id set-equality**, forcing-function comment verbatim); C8 + FOURTH C5 drive green (dive lands in the open field, `band_id == "band_four"` at the signal + JSONL spot-check, unchanged auto-return); C6 band-4 wipe round. `departure_portal.tscn` zero-byte diff; portals 1/2/3 byte-untouched. Integrated verify ALL GREEN: hub contract (5 interactables) · routing (all four routes, distinct fps) · app router · parity fp **`e943ac9c8bc1`** · band_two/three/four profiles · scatter+cave materialise · def-menu · 11-def bijection · smoke. Worklog `…-U4-general-purpose.md`. **Deviations: none.** UG3 flags recorded: plaza-full/band-5-forces-band-select + D-U4-2 UG1 eyeball (both transit lanes + four-glow plaza read). |

> **✓ Wave-4 close-out (2026-07-08): 0 deviations — nothing to disposition.** Build phase U0–U4 CLOSED.
> Cumulative M1.11 bespoke-code ledger: **backend #3 ~327 lines (U0) · materialisation 1 line (U1) ·
> band 0 lines (U3) · portal/routing 1 line (U4) · oppositions ~110 + ~191 component lines (U2a/U2b)** —
> the N=3 declining-cost evidence UG3 judges.
>
> **✓ Wave 5 (UG1) DONE + PUBLISHED (2026-07-08):** verify matrix ALL GREEN (four controls byte-identical
> `e943ac9c8bc1` + greybox/two/three · scatter `44a9a9b3756f` · 91/91 · 11-def bijection · deck pin
> `5/5/4/6 = 20 @ 34` · save v4 unchanged; `test_rg1_m13_verify` PASS on attempt 1 — re-run flake =
> pre-existing BUG-M13FLAKE, not a regression). Build-verify doc `design/M1_11_Tasks/UG1_playtest_build.md`
> + M1.11 changelog block committed (br `90db6cc`, merge `69446d5`). **Published (orchestrator, from
> `main`): `qusto/the-far-yard:html5 @ m1-20260708-69446d5`, butler build `#1781007`** ✓. UG1
> deviations: none. Worklog `…-UG1-qa-playtest-coordinator.md`. Board UG1 = Done.

## ▶ DIRECTOR PLAYTEST — M1.11 build (human-gated; UG2 is BlockedBy this)

> Play **https://qusto.itch.io/the-far-yard** (Chrome/Edge only, password-gated), build
> **`m1-20260708-69446d5`** (itch build `#1781007`; supersedes M1.10's `d04bd13`). Full checklist:
> `design/M1_11_Tasks/UG1_playtest_build.md` §5. Key reads:
> - **The fourth portal "Dive — The Far Field"** (indigo glow, WEST at `(-110, -20)` — mirror of
>   The Warren's slot) → the **open-field band**: one vast flat arena, sparse rim-biased cover, long
>   sightlines, a full-width clear-lane "highway" — a *third* generator (not rooms, not caves).
> - **Lobber "The Mortar"** — static sheller; ground-ring marker locks at fire, shell arcs over
>   EVERYTHING (cover does not protect — keep moving); throw-kill silences the rain.
> - **Sentry** — always-visible lane down a long sightline; windup flash → wall-blocked bolt (cover
>   DOES protect); crossable cooldown; throw-kill disables it permanently.
> - **The charger** ("The Wrecker") — cut from the cave for lack of lanes — comes alive in the open
>   field; 6 mines punctuate the exposed crossing. Deck: lobber 5 / sentry 5 / charger 4 / bomb 6.
> - **D-U4-2 eyeball rider (binding):** (a) BOTH transit lanes — spawn→portal-2 (over portal 3) AND
>   spawn→shop (over portal 4, the most-walked lane) — any mis-dive pressure? (b) the FOUR-glow plaza
>   read (violet · ember · teal · indigo) — distinct at a glance? (c) bands 1–3 unchanged (controls).
> - Watch-items: open field *tense* vs *empty*; the 1.45 step felt vs band 3; lane-as-highway;
>   sentry piñata (throw-disable); exposed-center loot. **Export telemetry** (P → Meta tab) → UG2.
>
> Then **UG2** (qa four-band telemetry/balance) → **UG3** verdict (go/iterate/pivot) in
> `design/M1_11_Tasks/G4_findings_M1.11.md` — where the N=3 cost-ledger trend + the plaza-full
> band-5 forcing function get judged. Do NOT dispatch UG2 until the Director has played.

> **⚙ Repo layout (since 2026-06-27):** the **Godot project is under `Game/`**; repo root holds only design/docs/meta
> (`design/`, `worklogs/`, `*.md`, `changelog.txt`, `.github/`, dotfiles). Run godot with **`--path Game`** (or `cd Game`);
> `res://…` paths are unchanged. Publish: `bash Game/tools/push_itch.sh` (self-locates). CI uses `working-directory: Game`.
> Design-doc/worklog filesystem paths written before this date gain a `Game/` prefix (e.g. `systems/…` → `Game/systems/…`);
> their `res://…` references are still valid as-is.

---

## ✓ FBM-A1 DONE + REPUBLISHED — Ambusher rework to a hide-pursue-pounce stalker (2026-07-05/06)

> Director feedback on `m1-20260705-3c9644e` fixed on `main`@`8e3a888` (merge `8e3a888`): **(bug)** the
> orange tell was visible at rest — `Concealment` now gates `$Tell` alpha too (0 hidden / 1 revealed);
> **(root cause of "junk just stops")** it was the one-shot **husk** — solid (layer 16) but out of the
> "hazard" group = unkillable, so throws bounced and re-dropped; removing the husk eliminates the state;
> **(rework)** dropped `_spent` — after the first pounce it STALKS: re-hides (invisible, un-hittable,
> floor-smudge still tracking) + pursues via the reused `ChaseMove` (`track_speed` **130 px/s**, tunable)
> → re-pounces toward the player → loops until killed in a revealed window. New `track_speed` knob
> (params↔schema bijection green at 9 defs); `re_hide_s` default 0→0.6 s inter-pounce breath. Off-by-
> default fp `e943ac9c8bc1` unmoved; `test_ambusher`/`test_opposition_def_schema`/smoke green. Changelog
> Ambusher description updated in place. **Republished:** `qusto/the-far-yard:html5 @ m1-20260706-8e3a888`
> (build `#1775586`). **Design watch-item (surfaced, Director-directed):** now a mechanical cousin of the
> Burrower (both hide-track-strike) — flag at TG2/TG3.
>
> **✓ FBM-A2 (2026-07-06, `main`@`d04bd13`) — Director Lurker tuning:** pounce dist 140→**250**, speed
> 600→**900**, exposed window 1.5→**0.6 s**, stalk speed 130→**232** px/s. Pure data (params + schema
> defaults + host DEFAULTS mirror synced; all within schema ranges); bijection/mirror green, all-off fp
> `e943ac9c8bc1` unmoved. **Note: stalk 232 > player ~200 → un-outrunnable** (juke/kill only). Republished
> `qusto/the-far-yard:html5 @ m1-20260706-d04bd13` (build `#1775901`).

## ▶ DIRECTOR PLAYTEST — M1.10 build (human-gated; still PENDING, non-blocking for the M1.11 build waves)

> Play **https://qusto.itch.io/the-far-yard** (Chrome/Edge only, password-gated), build **`m1-20260706-d04bd13`**
> (itch build `#1775901`; supersedes `8e3a888`/`3c9644e` — FBM-A1 stalker rework + FBM-A2 Director tuning). Full
> checklist: `design/M1_10_Tasks/TG1_playtest_build.md` §5. **Re-check the Ambusher "The Lurker":** invisible at
> rest · springs when you approach loot · then STALKS — vanishes, chases, re-pounces. **FBM-A2 tuning (2026-07-06):
> pounce dist 250 / speed 900 / exposed 0.6 s / stalk 232 px/s — stalk now > player ~200, so it is
> un-outrunnable (juke the pounce or kill it in the short exposed beat).** All live-tunable in the Oppositions tab.
> Other key reads:
> - **The two old portals are unchanged** (band 1 + The Sump play exactly as M1.9 — the control).
> - **The third portal "Dive — The Warren"** (cave-teal glow, forward of the other two) → a **cave band**:
>   blobby chambers, bad sightlines, nook-rich — a *different generator*, not rooms-and-corridors.
> - **Ambusher** — hides in the floor near loot, springs when you get close (readable tell → dodge → punish).
> - **Burrower "Sinkmaw"** — tracks you underground, surfaces on a rhythm to strike (static pop, locked decal
>   = the dodge frame); un-hittable while buried. Both are Warren-exclusive.
> - Watch-items to eyeball: the third portal's plaza composition + the spawn→portal-2 transit prompt; the
>   cave-teal glow currently reads deep cyan-blue (violet-multiply — a retone is Director-gated); is the cave
>   *disorienting-tense* or *lost-annoying*? does the +15% (1.30) difficulty step feel like a band apart?
> - **Export telemetry** (in-game button) when done → feeds TG2.
>
> Then **TG2** (qa telemetry/balance — three-band comparison, hazard fairness, cave time-to-gate, 1.30 budget,
> web perf) → **TG3** verdict (go/iterate/pivot) in `design/M1_10_Tasks/G4_findings_M1.10.md`. TG2 is BlockedBy
> the Director playtest — do NOT dispatch it until the Director has played. Also pending: disposition the one
> Wave-5 test-fixture deviation (rec Reviewed) at the TG3 close-out.

## ▶ Next action (start here on a cold restart) — **M1.12 Wave 1 build** (V1∥V5∥V7∥V8∥V9, file-disjoint worktrees) is dispatching; each is design-LOCKED (`design/M1_12_Tasks/V<n>_*.md` + its `Resolved Decisions (Phase 3)`). In parallel, **V3b (pursuer migration) design is authoring** (Phase-2 → Phase-3 resolve) — it must lock before Wave 4. After each wave lands + integrates on `main`: run the wave close-out deviation sweep (Director dispositions), then dispatch the next (Wave 2 = V2∥V6, Wave 3 = V4, Wave 4 = V3→V3b, Wave 5 = VG1→VG2→VG3). Master contract every wave: 4 control layout fps (`e943ac9c8bc1` + band_greybox/two/three) byte-identical + full suite green. Breakdown + D-RAT-1…7: `design/M1_12_Tasks/M1.12_Breakdown.md`; queue: `TASKS.md` §M1.12; board ids: `design/M1_12_Tasks/.board_item_ids.txt`.
>
> **Non-blocking, still open:** M1.11 Director playtest → UG2/UG3 (`design/M1_11_Tasks/UG1_playtest_build.md` §5); M1.10 TG2/TG3 + its one TG1 deviation; M1.9 SG2/SG3; M1.7/M1.6 RG2/RG3.

## (archived) ▶ prior next-action — M1.11 build + UG1 DONE + PUBLISHED (`m1-20260708-69446d5`, build `#1781007`); Director playtest → UG2 → UG3 pending (checklist `design/M1_11_Tasks/UG1_playtest_build.md` §5).

> **M1.11 = the N=3 declining-cost proof** (Director-directed 2026-07-06; design LOCKED same day):
> a **ScatterBackend** (open-field arena + order-stable poisson cover — no pieces, no CA) behind the same
> `BandPipeline`, proven by **band 4 "The Far Field"** + two ranged oppositions (**Lobber "The Mortar"** +
> **Sentry** — the at-range axis; all 9 shipped defs are contact-lethal) behind a fourth hub portal at the
> reserved mirror slot. Every build worklog carries the **cost ledger** (UG3 judges the N=3 trend; targets:
> materialisation **1 line**, band 4 **0 lines**). Breakdown + 13 amendments + **D-RAT-1…8**:
> `design/M1_11_Tasks/M1.11_Breakdown.md`. Task queue + DoD: `TASKS.md` §M1.11; board items U0–UG3 created
> (U0/U2a/U2b In Progress). Key contracts: FOUR controls byte-identical at every boundary (all-off fp
> `e943ac9c8bc1` + `band_greybox` + `band_two` + `band_three` fps); order-stable scatter determinism +
> passability by construction; 11-def bijection; knob model frozen; no save change; single-writer-per-file
> per wave; PixelLab Director-gated (tint-only).
>
> **M1.10 surface still open (Director-gated, non-blocking):** playtest `m1-20260706-d04bd13` (block above)
> → TG2 → TG3 + the one Wave-5 deviation disposition. M1.9 SG2/SG3 likewise pending (`TASKS.md` §M1.9).
> `DESIGN_DEVIATIONS.md` holds only the M1.10 Wave-5 test-fixture entry (rec Reviewed).

---

## ✓ M1.8 — Hub Art Dressing — CLOSED 2026-07-02 (Director)

> Build + HG1 done + published (final build `m1-20260702-3faeed0`, iso hub). The formal HG2 was
> short-circuited by direct Director review; verdict + watch-items (iso prop re-dress · bounds/street
> cue · H3 deferred) recorded in **`design/M1_8_Tasks/G4_findings_M1.8.md`**. 17 deviations
> dispositioned (15 Reviewed + 2 Addressed), reapplied + archived → `DESIGN_DEVIATIONS_HISTORY.md`.
> Tasks archived → `TASKS_COMPLETED.md` §M1.8. H2 top-down dressing stays the one-swap revert path.

---

## (M1.7 — build+RG1 done + published; RG2/RG3 Director-pending, non-blocking) DIRECTOR PLAYTEST → RG2 → RG3

> **✓ RG1 DONE + PUBLISHED (2026-06-28).** Build-verify doc `design/M1_7_Tasks/RG1_playtest_build.md` + M1.7 changelog block
> (`changelog.txt`); full M1.7 verify matrix green (import · smoke · fp **`e943ac9c8bc1`** · config **89/89** · `PLAYER_VISUAL OK`
> · `MOVE OK` · junk/drop/loop · no save-schema change). No new `test_rg1_m17_verify` (QA call — the gate is visual/tooling; the
> existing suite + `test_player_visual` cover the non-rendered surface). **Published to itch:** `qusto/the-far-yard:html5 @
> m1-20260628-867410f` (build #1758386 ✓; Chrome/Edge, password-gated: https://qusto.itch.io/the-far-yard). Fixed a publish
> blocker en route: `push_itch.sh` looked for `APIKEYS.md` in `Game/` post-restructure → now resolves it at the real repo root
> (`867410f`-chain). Worklog `…-RG1M17-qa-playtest-coordinator.md`. RG1 board=Done.
>
> **▶ DIRECTOR PLAYTEST (human-gated).** Play the published build. **The animated character is OFF by default** (boots to greybox
> = M1.6 parity) — press **P → the new "Player" tab → tick "Player art (debug)"** to turn it on. Then check: 8-dir idle/walk reads
> as you aim/move (mouse + controller) · pickup + throw animations in hub AND dive · **throw RIGHT/east is a clean single
> character** (the regenerated frames) · the one-frame spawn "jump" is gone (thrown/re-dropped junk, dive-start, hazards) · the
> Player-tab **Pickup lock (s)** / **Throw lock (s)** + lock-mode change the feel (try Fixed + shorter if sluggish) · toggling art
> OFF restores greybox. Export telemetry (in-game button on web). Full checklist: `RG1_playtest_build.md` §4.5.
>
> Then **RG2** (qa telemetry/readability) → **RG3** verdict (go → next / iterate → M1.8 / pivot) in
> `design/M1_7_Tasks/G4_findings_M1.7.md`. Claude assembles + recommends; the Director plays + decides.
>
> **As-built note to fold at close-out:** `event_bus.gd` comment corrected (art default OFF) — `867410f`.

---

## (Director-pending, non-blocking) M1.6 re-gate — RG2 → RG3

> **RG1 feedback fixes (2026-06-27, applied direct — gate green, re-published `m1-20260627-a1097fd`):** Director playtest
> surfaced 3 items → fixed on `main`@`a1097fd`. **FB1** the "[F] extract" prompt was hidden behind the gate door — lifted the
> world `InteractionPrompt` above geometry (`z_index=100`, `z_as_relative=false`) + made the HUD `ExtractPrompt` derive its
> glyph from the real `interact` binding (stale "E"→"F"). **FB2** quota always MISSED — the `cumulative_money` basis read
> `money` only, but M1.6 holds the haul unsold until the Shop and `evaluate_quota_on_return()` fires pre-sale → `achieved=0`;
> fix: cumulative basis = `money + _held_haul_value()` (0 on the sell path, unchanged there) + new quota Case 7 regression.
> **FB3** current quota not visible — the K2 `QuotaLabel` was anchored bottom-right with `have=money` only; moved it top-right
> **under the Holding label** and made `have = money + run_haul_value()` (live, matches what banks toward the quota).
> **FB4** added an on-screen **controls list** to the hub HUD (move/aim/throw/cycle/interact-extract/pause/debug-menu,
> kb+mouse+controller) + **updated `changelog.txt`** (THE HUB: controls list + HUD quota readout note). Latest build
> `m1-20260627-41106de`. Gate green: fp `e943ac9c8bc1` · 89/89 · router/loop/save-v4/shop/m15/quota/smoke. Worklog
> `…-RG1FB-claude.md`. **Re-test the new build.**

> **✓ RG1 DONE + PUBLISHED (2026-06-26)** — `main`@`aea0bb7`, board=Done. Build-verify doc
> `design/M1_6_Tasks/RG1_playtest_build.md` + M1.6 changelog block; full verify matrix green (router · shop · save v1/v2/v3→**v4**
> · m15 preset fp `e943ac9c8bc1` · 89/89 · loop). No new test (existing suite covers the gate — QA call). **Published to itch:**
> `qusto/the-far-yard:html5 @ m1-20260626-aea0bb7` (Chrome/Edge, password-gated: https://qusto.itch.io/the-far-yard).
>
> **▶ DIRECTOR PLAYTEST (human-gated — headless can't drive mouse/keyboard/the felt loop).** Play the published build:
> Main Menu (New wipe-confirm / Continue gated / Settings placeholder / first-run consent) · walk the Hub (no clock) ·
> portal→dive→auto-return · quota-miss wipe-on-return notice · Shop SELL tally + BUY spend + owned/can't-afford + **persistence
> across quit/relaunch** · P-overlay in all 3 states + in-dive pause + 7 tabs + Vision split + Meta-tab Export-telemetry · and
> the gate question: **does it read as a game now?** Export telemetry (in-game button on web). Watch-items: shop upgrade effects
> are stubs (do testers buy with no visible effect?); Settings is a placeholder. Full checklist: `RG1_playtest_build.md` §4.5.
>
> Then **RG2** (qa telemetry/flow analysis vs M1.0–M1.5) → **RG3** verdict (go → M2 milestone / iterate → M1.7 / pivot) in
> `design/M1_6_Tasks/G4_findings_M1.6.md`. Claude assembles + recommends; the Director plays + decides.

> **✓ M1.6 BUILD COMPLETE (2026-06-26)** — all 5 build tasks (M0·M1·M2·M4·M3) integrated on `main`@`f47d8fc`, pushed,
> board=Done. The full surface loop runs: **boot → Main Menu (New/Continue/Quit/Settings) → walkable Hub → Shop (sell+buy)
> + departure portal → Dive → auto-return to Hub**; clock dive-only; P-key 7-tab debug menu (Vision split out); persistent
> upgrades (META **v4**). Integrated gate green: import · smoke · router · config_menu **89/89** · run_config 89 · fp
> **`e943ac9c8bc1`** byte-match · save-migration **v1/v2/v3→v4** (`owned_items` round-trips) · shop_economy · quota · loop ·
> 4 RG verifies. **Wave-3 (M3) close-out: 0 deviations.** Watch-items (non-blocking): shop upgrade effects are stubs
> (`effect_kind=&"none"` — RG2 watch DR-M3-2: do testers buy with no visible effect?); orphan `ui/sell/sell_strings` locale
> entry left in `project.godot` (CSV kept; harmless; minor tech-debt). Follow-ups filed: **FU3** (repair/retire m13),
> **FU4** (keyboard-only aim).

> **▶ Wave 4 = RE-GATE.** **RG1** (qa): author `design/M1_6_Tasks/RG1_playtest_build.md` from the M1.5 template; update
> `changelog.txt` (M1.5→M1.6 delta: main menu, walkable hub, sell+buy shop, P-tab debug menu); run the full M1.6 verify
> matrix; **publish to itch** `BUTLER=/mnt/c/wsl-libraries/butler/butler bash tools/push_itch.sh` (Chrome/Edge, password-gated;
> network/human-gated). Then **Director playtest** the surface loop → **RG2** telemetry/flow analysis → **RG3** verdict
> (go → M2 milestone / iterate → M1.7 / pivot) in `design/M1_6_Tasks/G4_findings_M1.6.md`.

---

## Blocked
| Task | Blocked by | Note |
|---|---|---|
| ElevenLabs/PixelLab live generation | human | Connected; calling them spends paid credits — get human OK before a generation run. |

---

## History (not here — see)
- **Completed tasks** (M0, M1, M1.1, with proof/commits): `TASKS_COMPLETED.md`.
- **Superseded status sections** (M1/M1.1 Done tables, prior next-actions, playtest-gate notes): `STATUS_ARCHIVE.md`.
- **Design history**: `design/` (per-version `M<n>_*_Tasks/`), `DESIGN_DEVIATIONS_HISTORY.md`, `design/M1_Tasks/M1_As_Built.md`.

## Legend
`Backlog → In progress → (Verify) → Done` · or `→ Blocked`. A task is **Done** only with a worklog naming a real commit and its definition of done met.
