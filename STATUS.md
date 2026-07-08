# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.11 (Third generation backend + open-field band + ranged oppositions — Director-directed 2026-07-06, opened ahead of M1.10's TG2/TG3) — **design LOCKED 2026-07-06 (D-RAT-1…8). Waves 1–2 DONE + swept (Wave-2's 3 U1 deviations Director-Reviewed 2026-07-08, archived). ▶ Wave 3 DISPATCHED (U3 — `band_four.tres` "The Far Field", ledger target 0).** *(M1.10 build DONE + TG1 published `m1-20260706-d04bd13` — Director playtest → TG2 → TG3 pending, non-blocking, one Wave-5 deviation rec Reviewed at TG3 close-out; M1.9 SG2/SG3, M1.7/M1.6 RG2/RG3 Director-pending; M1.8 CLOSED.)*

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

**Last updated:** 2026-07-08 (M1.11 Wave-2 close-out COMPLETE — Director dispositioned all 3 U1 deviations **Reviewed**; no design reapply needed (test-only/hygiene); archived. **Wave 3 (U3) dispatched** — game-director-designer, worktree, board In Progress.)

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
> **▶ Wave 3 (U3) DISPATCHED (2026-07-08):** game-director-designer in a worktree on
> `design/M1_11_Tasks/U3_band_four.md` (§Resolved Decisions RD-1…15 BINDING; D1–D5 already
> Director-ratified as D-RAT-5/6 at design lock) — 3 `.tres` (`band_four` + `scatter_config_band_four`
> + `depth_curve_band_four`) + the mirrored contract test; ledger target **0 lines**.

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

## ▶ Next action (start here on a cold restart) — M1.11 Wave 3 (U3) is DISPATCHED (worktree; 3 `.tres` + mirrored contract test `test_band_four_profile`; ledger target 0 lines — the N=3 headline measurement). On return: verify the DoD (four control fps byte-identical; `5/5/4/6 = 20` spend-to-0 deck pin; 11-def bijection unchanged — U3 adds no def; ledger = 0), merge, Wave-3 deviation sweep → Wave 4 **U4** (portal 4 + plaza-full pin; one `BAND_ROUTES` row) → Wave 5 (UG1 publish → Director playtest → UG2 → UG3).

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
