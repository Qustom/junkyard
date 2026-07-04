# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.9 (Scalable Opposition + Band systems — Director-directed 2026-07-02) — **SG1 DONE + PUBLISHED (`m1-20260704-8412732`). ▶ Next: DIRECTOR PLAYTEST (human-gated) → SG2 → SG3.** *(M1.8 CLOSED; M1.7/M1.6 RG2/RG3 Director-pending, non-blocking.)*
**Last updated:** 2026-07-03 (SG1: full M1.9 verify matrix ALL GREEN — fp `e943ac9c8bc1` · 91/91 + per-def bijection · both portals · 7-def schema · m13 first-run · save schema UNCHANGED (meta v4/run v1). Changelog "The Sump" block written. Published to itch: `qusto/the-far-yard:html5 @ m1-20260704-8412732`. Docs: `design/M1_9_Tasks/SG1_playtest_build.md` (§5 = the playtest checklist).)

> **✓ FBM19 feedback fixes LANDED + REPUBLISHED (2026-07-03/04, build `m1-20260704-72fd565`).** Director's 3 playtest
> reports fixed on `main`@`5dec90c`: **FB1** split reliability — shards now bypass the BUG7 entry-safe refusal + per-room
> cap via explicit ctx escapes (`ignore_entry_safety` new on SpawnService; per_band 8 + group 48 ceilings unchanged);
> **FB2** deck lane is def-major with J2-style even-spread over eligible pieces — charger/splitter now reach the deepest
> third (test-proven); **FB3** splitter `aggro_radius=160` latch param (0=legacy; child 0; Oppositions-tab tunable, gloss
> added). Full matrix green; changelog descriptions updated in place. Worklog `…-FBM19-general-purpose.md`. Deviations: none.

## In progress
| Task | Since | Agent(s) | Milestone | Note |
|---|---|---|---|---|
| FBM19b — Oppositions tab: surface deck-spawned hazards' knobs | 2026-07-04 | general-purpose | M1.9 (post-SG1 FB) | Branch `general-purpose/FBM19b`. Deck-membership chip (no more misleading OFF), auto-expand charger/splitter sections, end-to-end staged-override test (aggro/speed → band_two spawns). All 4 knobs already exist + work. |

## ▶ DIRECTOR PLAYTEST (human-gated — the felt loop can't be verified headless)

> Play **https://qusto.itch.io/the-far-yard** (Chrome/Edge only, password-gated), build **`m1-20260704-72fd565`** (FBM19 re-test build; supersedes `m1-20260704-8412732`). Re-check the 3 fixed items: splitter always splits on throw-kill (even at the band entrance / two in one room) · Wrecker+Splitter present deep into The Sump · splitter lurks until ~on-screen range then latches (tune `aggro_radius` in the Oppositions tab if 160 feels wrong).
> Checklist (full version: `SG1_playtest_build.md` §5): both portals from the hub · band 1 = control feel
> (unchanged M1.8) · **The Sump reads as a band apart** (branchy/flooded/vault/sepia tint/denser opposition) ·
> **The Wrecker**: bait → dodge → punish; throws MISS mid-dash (intended); wall-crash = longer stun ·
> **Splitter**: throw-kill splits into 2 (children terminal); non-throw kill doesn't · P-menu **Oppositions tab**:
> tune + respawn (marks the run debug-dirty) · **Export telemetry** (in-game button) when done.
> Then **SG2** (qa telemetry/balance analysis) → **SG3** verdict (go/iterate/pivot) in `G4_findings_M1.9.md`.
> Watch-items for SG3: content=data proof cost (host shell, LethalContact seam) · promote charger/splitter to band 1? ·
> legacy-signal retirement · ceiling numeric merge · CaveBackend/ScatterBackend next? · hub iso prop re-dress.

## In progress
| Task | Since | Agent(s) | Milestone | Note |
|---|---|---|---|---|
| ~~S8 — Second hub portal + band routing + telemetry band-stamp~~ | 2026-07-03 | general-purpose | M1.9 (W5) | **DONE 2026-07-03** — merged (`a357e47`). Portal 2 "Dive — The Sump" ember-orange at (220,-150); `BAND_ROUTES` mapping live; portal 1 `departure_portal.tscn` zero-byte diff; `band_id` stamp verified both routes; new `test_band_routing` + `test_hub_contract` green. 1 deviation logged (route-key member vs Dict helper). |
| ~~S9 — DeckEntry override wrapper (D-RAT-2 delivery)~~ | 2026-07-03 | general-purpose | M1.9 (W5) | **DONE 2026-07-03** — merged (`ac289db`). `test_deck_entry` green (empty-wrapper ≡ plain ref byte-identical; precedence def < deck-entry < rc; band_two charger gets the D-RAT-2 values); charger def-default pin intact; fps unmoved. Deviations: none. |

## In progress
| Task | Since | Agent(s) | Milestone | Note |
|---|---|---|---|---|
| ~~S4 — Generated debug-menu sections + coverage 91 + sweep hygiene~~ | 2026-07-03 | general-purpose | M1.9 (W4) | **DONE 2026-07-03** — merged (`e95a892`). 91/91 + per-def bijection; generated Oppositions tab (count-agnostic, proven at 6 defs post-merge); dotted stamp asserted; neutral-card trap YES; `debug_dirty` hygiene; tier-v1 respawn. 5 deviations logged. |
| ~~S6a — Charger "The Wrecker"~~ | 2026-07-03 | general-purpose | M1.9 (W4) | **DONE 2026-07-03** — merged (`250cee1`). ChargeLane (the ONE new behavior script); `charger.tres` D-RAT-2 letter defaults (pinned by test); `test_charger` 11 groups green; goldens intact. 4 deviations logged. |
| ~~S6b — Splitter~~ | 2026-07-03 | general-purpose | M1.9 (W4) | **DONE 2026-07-03** — merged (`5ac1fa7`). `test_splitter` green (throw-death-only split, cap refusal, freed-parent headroom per live-registry canon, fp byte-identical across a forced split); 6-def bijection green; goldens intact. 6 deviations logged. **Integration note: 10 `CFG_GLOSS_SPLITTER_*` CSV rows deferred to S4 merge.** |
| ~~S7 — band_two "The Sump"~~ | 2026-07-03 | game-director-designer | M1.9 (W4) | **DONE 2026-07-03** — merged (`025d37a`). `test_band_two_profile` C0–C6 green 9 seeds; greybox fp untouched; tint `Color(0.82,0.66,0.42)`. **⚠ ORCHESTRATOR INTEGRATION STEP after S6a+S6b merge: complete the deck 4→6** (add charger/splitter ExtResources to `band_two.tres`, order `[pursuer,pingpong,bomb,spike,charger,splitter]`; confirm `min_band=2` on both). 2 deviations logged. |

## Wave 3 — Done (2026-07-03)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S3 — EncounterBuilder + RunConfig generic levers + both call-site integrations | general-purpose | `d9f5377` (branch `general-purpose/S3`) | Worklog `worklogs/2026-07-03-S3-general-purpose.md`; integrated matrix 23 tests + smoke ALL green (incl. m13 first-run); fp `e943ac9c8bc1` through the new call sites; preset cohort byte-parity; 89/89 held (`@export_storage` levers invisible); 91 knobs stamped. 5 deviations logged — sweep next. |

## Wave 2 — Done (2026-07-03)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S2 — Opposition component extraction + `param_schema` | general-purpose | `e851a8c` (branch `general-purpose/S2`) | Worklog `worklogs/2026-07-02-S2-general-purpose.md`; golden frame-trace parity byte-identical (5 traces, goldens captured pre-refactor); dual-emit twins 1:1; defs completed + bijection test; throw seam + LethalContact external seam landed. 4 deviations logged. |
| S5 — Band flavor stages + connectivity guarantee | general-purpose | `0aa085c` (branch `general-purpose/S5`) | Worklog `worklogs/2026-07-02-S5-general-purpose.md`; `test_band_flavors` F1–F8 green 9 seeds; parity UNMODIFIED green; strand-proof at max decay. 4 deviations logged (WearDecay breach-led headline flagged for Director). |

## Wave 1 — Done (2026-07-02)
| Task | Agent | Merged | Proof |
|---|---|---|---|
| S0 — SpawnService + OppositionDef data layer + EventBus pre-declare | general-purpose | `84785cf` (branch `general-purpose/S0`) | Worklog `worklogs/2026-07-02-S0-general-purpose.md`; full matrix green incl. golden `test_new_hazard_spawn` unmodified + new `test_spawn_service`; 2 deviations logged (cap accounting registry-derived; untyped sweep locals) — awaiting Director. |
| S1 — BandProfile + BandPipeline + `band_greybox.tres` | general-purpose | `9a8c6fb` (branch `general-purpose/S1`) | Worklog `worklogs/2026-07-02-S1-general-purpose.md`; parity byte-match 9 seeds, purely additive. Deviations: none. |

> **⚙ Repo layout (since 2026-06-27):** the **Godot project is under `Game/`**; repo root holds only design/docs/meta
> (`design/`, `worklogs/`, `*.md`, `changelog.txt`, `.github/`, dotfiles). Run godot with **`--path Game`** (or `cd Game`);
> `res://…` paths are unchanged. Publish: `bash Game/tools/push_itch.sh` (self-locates). CI uses `working-directory: Game`.
> Design-doc/worklog filesystem paths written before this date gain a `Game/` prefix (e.g. `systems/…` → `Game/systems/…`);
> their `res://…` references are still valid as-is.

---

## ▶ Next action (start here on a cold restart) — M1.9 build Wave 1: dispatch S0 ∥ S1

> **M1.9 = the two scalable architectures + the content that proves them** (Director-directed 2026-07-02):
> SpawnService/EncounterBuilder (opposition v2) + BandProfile/BandPipeline (bands), proven by **Charger "The
> Wrecker" + Splitter** and **band 2 "The Sump"** behind a second hub portal. **Design LOCKED** (four-phase process
> complete): breakdown + 10 per-task designs each with a BINDING `Resolved Decisions (Phase 3)` section +
> cross-task amendments + Director ratifications **D-RAT-1..4** — all in `design/M1_9_Tasks/M1.9_Breakdown.md`.
> Task queue + DoD: `TASKS.md` §M1.9; board items S0–SG3 created (Todo).
>
> **▶ Dispatch Wave 1 now:** **S0** (SpawnService + defs + EventBus pre-declare; sole writer `main_game.gd` +
> `event_bus.gd` + `game_state.gd`) ∥ **S1** (BandProfile + BandPipeline + `band_greybox.tres`; only
> `systems/bandgen/` + `data/bands/` + tests) — parallel worktrees, file-disjoint. Then Wave 2 (S2 ∥ S5) → Wave 3
> (S3, sole `main_game.gd` writer) → Wave 4 (S4 ∥ S6a ∥ S6b ∥ S7) → Wave 5 (S8) → Wave 6 (SG1 → playtest → SG2 →
> SG3). **Wave close-out deviation sweep after every wave.** Key contracts: all-off fp `e943ac9c8bc1` byte-identical
> at every boundary; bandgen determinism through the pipeline; 89→91 knob model at S4; no save change; no PixelLab.
>
> **✓ M1.8 CLOSED (2026-07-02)** — nothing carried into the build waves; `DESIGN_DEVIATIONS.md` is empty.

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
