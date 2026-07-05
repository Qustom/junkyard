# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.10 (Second generation backend + cave band + low-sightline oppositions — Director-directed 2026-07-04, opened ahead of M1.9's SG2/SG3) — **Build Wave 1 LANDED + integrated on `main` (`57f2a81`): T0 CaveBackend + T2a Ambusher + T2b Burrower all merged, verified, board=Done. ▶ HOLD: Wave-1 close-out deviation sweep — 3 T0 entries await Director disposition (all rec Reviewed) BEFORE T1 dispatches (CLAUDE.md hard gate).** *(M1.9 SG1 published `m1-20260704-55ca78f` — Director playtest → SG2 → SG3 pending, non-blocking; M1.8 CLOSED; M1.7/M1.6 RG2/RG3 Director-pending, non-blocking.)*

> **M1.10 design LOCKED (2026-07-05):** breakdown + 6 per-task designs each with a BINDING
> `Resolved Decisions (Phase 3)` section; 13 cross-task amendments + Director ratifications
> **D-RAT-1…9** folded into `design/M1_10_Tasks/M1.10_Breakdown.md`. Headlines: Ambusher +
> Burrower "Sinkmaw" (band-3-exclusive, fatal `kills`-gated); band 3 = **"The Warren"**
> (cave/CA backend, blue-violet tint, cave-teal portal glow, deck 6/3/4/1 @ 1.30/31-credit);
> cave gate snaps-to-floor; cave walls = 1-tile sealer shell; portal 3 @ (110,-20). TASKS.md
> §M1.10 + board items T0–TG3 wired (T0/T2a/T2b In Progress).

**Last updated:** 2026-07-05 (SG1: full M1.9 verify matrix ALL GREEN — fp `e943ac9c8bc1` · 91/91 + per-def bijection · both portals · 7-def schema · m13 first-run · save schema UNCHANGED (meta v4/run v1). Changelog "The Sump" block written. Published to itch: `qusto/the-far-yard:html5 @ m1-20260704-8412732`. Docs: `design/M1_9_Tasks/SG1_playtest_build.md` (§5 = the playtest checklist).)

> **✓ FBM19 feedback fixes LANDED + REPUBLISHED (2026-07-03/04, build `m1-20260704-72fd565`).** Director's 3 playtest
> reports fixed on `main`@`5dec90c`: **FB1** split reliability — shards now bypass the BUG7 entry-safe refusal + per-room
> cap via explicit ctx escapes (`ignore_entry_safety` new on SpawnService; per_band 8 + group 48 ceilings unchanged);
> **FB2** deck lane is def-major with J2-style even-spread over eligible pieces — charger/splitter now reach the deepest
> third (test-proven); **FB3** splitter `aggro_radius=160` latch param (0=legacy; child 0; Oppositions-tab tunable, gloss
> added). Full matrix green; changelog descriptions updated in place. Worklog `…-FBM19-general-purpose.md`. Deviations: none.

> **✓ FBM19b LANDED + REPUBLISHED (2026-07-04, build `m1-20260704-55ca78f`).** Oppositions tab now surfaces
> deck-spawned hazards: charger/splitter chips read "IN DECK: band_two · n tuned" (tooltip names the band; OFF only
> for truly nowhere-spawning defs), their sections open PRE-EXPANDED, and a new end-to-end case stages the Director's
> 4 knobs (aggro_range/charge_speed/aggro_radius/move_speed) through the menu path and proves band_two spawns receive
> them on top of the D-RAT-2 deck layer. 91/91 + fps intact. Worklog `…-FBM19b-general-purpose.md`. Deviations: none.
> Director-flag (worklog): section bodies stay dimmed for not-enabled deck defs (redundant-cue rule) — say the word to undim.

## ▶ DIRECTOR PLAYTEST (human-gated — the felt loop can't be verified headless)

> Play **https://qusto.itch.io/the-far-yard** (Chrome/Edge only, password-gated), build **`m1-20260704-55ca78f`** (FBM19b tab-surfacing build; supersedes `72fd565`/`8412732`). Re-check the 3 fixed items: splitter always splits on throw-kill (even at the band entrance / two in one room) · Wrecker+Splitter present deep into The Sump · splitter lurks until ~on-screen range then latches (tune `aggro_radius` in the Oppositions tab if 160 feels wrong).
> Checklist (full version: `SG1_playtest_build.md` §5): both portals from the hub · band 1 = control feel
> (unchanged M1.8) · **The Sump reads as a band apart** (branchy/flooded/vault/sepia tint/denser opposition) ·
> **The Wrecker**: bait → dodge → punish; throws MISS mid-dash (intended); wall-crash = longer stun ·
> **Splitter**: throw-kill splits into 2 (children terminal); non-throw kill doesn't · P-menu **Oppositions tab**:
> tune + respawn (marks the run debug-dirty) · **Export telemetry** (in-game button) when done.
> Then **SG2** (qa telemetry/balance analysis) → **SG3** verdict (go/iterate/pivot) in `G4_findings_M1.9.md`.
> Watch-items for SG3: content=data proof cost (host shell, LethalContact seam) · promote charger/splitter to band 1? ·
> legacy-signal retirement · ceiling numeric merge · CaveBackend/ScatterBackend next? · hub iso prop re-dress.

## Wave 1 — Done + integrated on `main` (2026-07-05)
| Task | Agent(s) | Merged | Proof |
|---|---|---|---|
| T0 — CaveBackend + `CaveBandConfig` + pipeline dispatch | general-purpose | `cfef9f7` (br `…a8c1cc4`) | `test_cave_backend` OK (C1–C10, 9 seeds; sample seed 12345 → 49 pieces, max_depth 12, cave fp `d984fd8913bf`); `test_band_pipeline_parity` + `test_bandgen_determinism` OK, socket-path fp **`e943ac9c8bc1`** byte-identical (greybox + band_two); ~475-line cost ledger, **0 new downstream lines**. Worklog `…-T0-general-purpose.md`. **3 deviations (all rec Reviewed).** |
| T2a — Ambusher (def + `Concealment` component) | general-purpose (+ character-animator) | `3d17bf0` (br `…a19da54`) | `test_ambusher` OK (all cases: HIDDEN pass-through layer 0, arm/tell/pounce, `kills`-gate + BUG6 once, EXPOSED throw-kill, one-shot); all-off fp unmoved; 39-line `Concealment`, **0 shared-file edits**. Worklog `…-T2a-general-purpose.md`. Deviations: none. |
| T2b — Burrower "Sinkmaw" (def + `BurrowCycle` component) | general-purpose (+ character-animator) | `26ef5e9` (br `…a6048d5`) | `test_burrower` OK (11 cases: buried pass-through, dodge frame, wall-clear surface, `kill_radius=34` surfacing-frame kill, positional desync); all-off fp unmoved; 212-line ledger, **0 shared-file edits**. Worklog `…-T2b-general-purpose.md`. Deviations: none. |

> **Integration done (`57f2a81`):** three worktree branches merged (file-disjoint, verified); both
> T2a (12) + T2b (9) `CFG_FIELD_*` gloss rows applied to `config_strings.csv` in one commit (`57f2a81`);
> the def schemas reference those exact keys (verified). Integrated verify ALL GREEN: import · cave ·
> parity · bandgen · ambusher · burrower · **9-def bijection** · socket-path fp `e943ac9c8bc1` · smoke.
> Board T0/T2a/T2b = Done.

> **▶ HOLD — Wave-1 close-out deviation sweep (CLAUDE.md hard gate; the Director dispositions, Claude only
> recommends).** `DESIGN_DEVIATIONS.md` holds **3 T0 entries, all recommended Reviewed**: (1) grid-level
> carve = deterministic *mirror* of the CARVE-mode concept (Phase-3 Q4 already ratified this reading);
> (2) `cave_backend.gd` ~404 code lines vs the ~255 estimate (Q8 throat pass + deepest-piece BFS — cost-
> ledger magnitude note, no design change); (3) `deepest_piece` chosen by chunk-graph BFS (makes C4's
> `depth_index == max_depth` bar hold by construction; spec §3.5 was self-contradictory). T2a/T2b: none.
> **T1 (Wave 2, sole `main_game.gd` writer) does NOT dispatch until the Director dispositions these** —
> #3 in particular touches the depth contract T1 builds on.

> **M1.9 build-wave Done tables** (S0–S9, all merged 2026-07-02/03) archived → `STATUS_ARCHIVE.md`
> §"M1.9 build waves". SG2/SG3 remain the only open M1.9 surface (pointer above + `TASKS.md` §M1.9).

> **⚙ Repo layout (since 2026-06-27):** the **Godot project is under `Game/`**; repo root holds only design/docs/meta
> (`design/`, `worklogs/`, `*.md`, `changelog.txt`, `.github/`, dotfiles). Run godot with **`--path Game`** (or `cd Game`);
> `res://…` paths are unchanged. Publish: `bash Game/tools/push_itch.sh` (self-locates). CI uses `working-directory: Game`.
> Design-doc/worklog filesystem paths written before this date gain a `Game/` prefix (e.g. `systems/…` → `Game/systems/…`);
> their `res://…` references are still valid as-is.

---

## ▶ Next action (start here on a cold restart) — M1.10 Wave 1 LANDED; HELD at the Wave-1 deviation-sweep gate. On Director disposition of the 3 T0 entries → reapply+archive per verdict → dispatch Wave 2 (T1, sole `main_game.gd` writer)

> **M1.10 = the second architectural axis** (Director-directed 2026-07-04; design LOCKED 2026-07-05):
> a **CaveBackend** (cellular-automata caverns — no pieces/sockets) behind the same `BandPipeline`, proven by
> **band 3 "The Warren"** + two low-sightline oppositions (**Ambusher** + **Burrower "Sinkmaw"**) behind a third
> hub portal. Every build worklog carries a **cost ledger** (bespoke lines beyond the promised backend/component
> = TG3's scalability evidence). Breakdown + 13 cross-task amendments + ratifications **D-RAT-1…9**:
> `design/M1_10_Tasks/M1.10_Breakdown.md`. Task queue + DoD: `TASKS.md` §M1.10; board items T0–TG3 created
> (T0/T2a/T2b In Progress).
>
> **▶ Wave 1 DISPATCHED (parallel worktrees, file-disjoint):** **T0** (CaveBackend + `CaveBandConfig` + dispatch;
> sole writer `systems/bandgen/` + `band_profile.gd`/`band_pipeline.gd`) ∥ **T2a** (Ambusher: `ambusher.tres` +
> `Concealment`) ∥ **T2b** (Burrower: `burrower.tres` + `BurrowCycle`). **On return:** verify each DoD, apply the
> shared-CSV gloss rows in one merge commit (`CFG_FIELD_*`), Wave-1 close-out deviation sweep → then Wave 2
> **T1** (cave materialisation, sole `main_game.gd` writer) → Wave 3 **T3** (band_three) → Wave 4 **T4** (portal) →
> Wave 5 (TG1 → Director playtest → TG2 → TG3). Key contracts: THREE controls byte-identical at every boundary
> (all-off fp `e943ac9c8bc1` + `band_greybox` + `band_two` through the untouched socket path); order-stable cave
> determinism; 9-def bijection; 91-knob model frozen; no save change; PixelLab Director-gated (tint-only).
>
> **✓ M1.9 build DONE + SG1 published** (`m1-20260704-55ca78f`); SG2/SG3 Director-pending, non-blocking (§M1.9
> pointer above). **✓ M1.8 CLOSED (2026-07-02).** `DESIGN_DEVIATIONS.md` is empty (M1.9 fully swept).

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
