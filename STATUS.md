# STATUS — THE FAR YARD

**Resume point — read this first.** Where the orchestrator picks up after any interruption, with no other
context. Holds only *current* work: what's in progress (and how to continue it), what's blocked, the immediate
next action. Full task queue → `TASKS.md`; board mirror → GitHub Projects; completed tasks → `TASKS_COMPLETED.md`;
superseded status history → `STATUS_ARCHIVE.md`. Update this every time a task is claimed, blocked, or finished.
See `CLAUDE.md` → "The orchestrator loop".

**Current milestone:** M1.8 (Hub Art Dressing — Layout A vertical spine) — **Wave 1 + HG1 done; H2 re-dress iteration DONE (2026-07-01).** The Director flagged the Wave-1 look (per-tile black borders, misaligned tiles, wrong object angles); H2 re-authored the ground as seamless PixelLab corner-Wang tilesets painted by a vertex-map `hub_ground.gd` (720 cells, fills the camera), regenerated 6 props angle-consistent (+ NEW front-facade shack, south fence line), y-sort re-anchored to sprite base. Contracts invariant; full suite green. **Next = publish H4 to itch → DIRECTOR PLAYTEST → HG2 (readability) → HG3 (verdict: 45° iso vs top-down).** *(M1.7 build+RG1 done + published; its RG2/RG3 Director-pending, non-blocking.)*
**Last updated:** 2026-07-02 (M1.8 H4 45° iso re-dress integrated — iso ground + props removed, shop/portal kept; H2 top-down kept in-repo as revert path. Earlier: H2 hub re-dress integrated: fp `e943ac9c8bc1` + 89/89 unmoved, hub contract 720 cells OK; changelog M1.8 block updated in place; 7 new deviations (2 supersede Wave-1 entries) await the HG3 close-out. Worklog `…-H2-hub-redress-orchestrator.md`.)

> **⚙ Repo layout (since 2026-06-27):** the **Godot project is under `Game/`**; repo root holds only design/docs/meta
> (`design/`, `worklogs/`, `*.md`, `changelog.txt`, `.github/`, dotfiles). Run godot with **`--path Game`** (or `cd Game`);
> `res://…` paths are unchanged. Publish: `bash Game/tools/push_itch.sh` (self-locates). CI uses `working-directory: Game`.
> Design-doc/worklog filesystem paths written before this date gain a `Game/` prefix (e.g. `systems/…` → `Game/systems/…`);
> their `res://…` references are still valid as-is.

---

## ▶ Next action (start here on a cold restart) — republish H2 → DIRECTOR PLAYTEST → HG2 → HG3

> **✓ H2 HUB RE-DRESS DONE (2026-07-01, Director-directed `/goal`).** Ground re-authored as 3 chained PixelLab
> corner-Wang tilesets (asphalt↔dirt↔litter↔scrap, gradient-map retoned to Band-0) painted by a **vertex-map**
> `hub_ground.gd` (RNG-free, 36×20 = 720 cells — fills the camera view, no black backdrop); 6 props regenerated
> angle-consistent (gate front-on INTO the north wall, cars side-view, + NEW 176×144 front-facade shack, NEW south
> fence line); all props y-sort by BASE now (position=feet + offset). Contracts invariant (ids · collision · node
> paths · spawn · zoom). Gate green: import · smoke · fp **`e943ac9c8bc1`** · **89/89** · hub contract (720 cells).
> Preview: `hub_after2.png` (sent to Director). Worklog `…-H2-hub-redress-orchestrator.md`.
>
> **✓ REPUBLISHED to itch:** `qusto/the-far-yard:html5 @ m1-20260702-2457bc2` (Chrome/Edge, password-gated:
> https://qusto.itch.io/the-far-yard). Changelog M1.8 block updated in place. `main`@`2457bc2`.
>
> **▶ DIRECTOR PLAYTEST (human-gated).** Play the republished build. Check (HG1 §5 + H2): the ground reads as
> seamless materials (no tile grid/borders); the spine reads S→N (paved+fenced street → dirt yard → litter patches →
> scrap wall); the central spawn→shop→gate lane stays clear; the office-shack + gate-in-wall read as functional vs.
> dressing; **object angles feel consistent with the player**; golden-hour holds; **the loop plays identically**
> (walk → shop sell/buy → dive → return); toggling the M1.7 **player art ON** (P → Player tab) still y-sorts among
> props. Export telemetry (in-game button on web).
>
> Then **HG2** (qa readability/telemetry) → **HG3** verdict (go → next milestone / iterate → M1.9 / pivot) in
> `design/M1_8_Tasks/G4_findings_M1.8.md`. Claude assembles + recommends; the Director plays + decides.
>
> **⚠ Close-out still open:** 13 deviations in `design/DESIGN_DEVIATIONS.md` — 5 Wave-1 (all recommend Reviewed; the
> "walls kept as ColorRects" + "doorway-only shack" entries are now SUPERSEDED by H2) + carried PLAYERTAB (→ Addressed)
> + 7 new H2 entries (6 recommend Reviewed, shack → Addressed) — all await Director disposition at the HG3 close-out.

---

## (archived — M1.8 Wave 1 build, on `main`, pushed) H0 + H1

> **M1.8 = Hub Art Dressing** (Director-directed, art-only iteration). Breakdown:
> `design/M1_8_Tasks/M1.8_Breakdown.md`. Source: `art_workshop/map_layouts/staging_area_layout_a_dressed.md`
> + `layout_a_assets/` (16 ground tiles + 24 props; gap analysis = nothing loop-critical missing →
> **no PixelLab run**; the one missing prop, the street threshold `SS`, is deferred (H3, paid/Director-gated)).
> **Contracts:** all-off fp **`e943ac9c8bc1`** + **89/89** held (no knob); **no save change**; portal/shop
> `Interactable` ids + collision + `hub.gd` node paths + wall-bounding are invariant (H1 is a re-skin).
> **Copy, never move** from `art_workshop/`.
>
> **✓ Wave 1 DONE (`main`@`11b8ff4`).** **H0** (`33f67d5`) copied 16 ground tiles + 20 props → `Game/art/hub/`,
> built `Game/data/tilesets/hub_ground.tres`; **H1** (`81a3c13`) re-skinned `hub.tscn` — `HubGround` TileMapLayer
> spine (asphalt S → dirt mid → litter N, scrap-wall border, central lane clean), `dive_gate`+`portal_glow` on
> `DeparturePortal`, `shack_door`+`workbench`+`sort_table` on `HubShop`, 15 dressing props y-sorted, camera 1.2→1.05.
> Visual-only re-skin: portal/shop `Interactable` ids + collision + `hub.gd` node paths + wall-bounding all invariant.
> Gate green: import · smoke · fp **`e943ac9c8bc1`** · **89/89**. Worklog `…-H0H1-hub-dressing-general-purpose.md`.
> Originals intact in `art_workshop/` (copy-not-move verified). **Asset gap:** street-threshold `SS` deferred (H3,
> PixelLab/paid/Director-gated) — not loop-critical.
>
> **▶ Wave 1 close-out (Director dispositions — 5 deviations in `design/DESIGN_DEVIATIONS.md`, all recommend Reviewed):**
> doorway-only shack (vs open-roof) · camera 1.05 · walls kept as re-tinted ColorRects · 15 props (vs ~10–12) · stale
> "24 objects" doc count (actual 20). + the carried PLAYERTAB (M1.7) entry recommends Addressed.
>
> **▶ Wave 2 = re-gate:** **HG1** (qa) verify matrix + `changelog.txt` (M1.7→M1.8: art-dressed hub) + publish to itch →
> **Director playtest** → **HG2** readability → **HG3** verdict in `design/M1_8_Tasks/G4_findings_M1.8.md`.
>
> **⚠ MANUAL (headless can't render here — Godot has no display server in WSL2):** the on-screen read — spine flows
> S→N, central lane clear, functional props (gate/shack) distinguishable from dressing, prop scale/busyness vs the
> player, golden-hour holds — is the core Director item. A compositing preview (`m1_8_hub_preview.png`, faithful coords +
> real assets, not an engine render) approximates it; the true render comes from the HG1 itch build or the editor.

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

## (archived — M1.7 build + fixes, all on `main`, pushed) Wave 1 build + post-build tweaks

> **✓ M1.7 WAVE 1 (BUILD) COMPLETE + VERIFIED ON `main`@`cffb5db` (2026-06-28), pushed.** The greybox player is replaced by
> the animated `player_basic_template` character (8-dir idle/walk + pickup/throw) in **both** Hub and Dive, plus a Meta-tab
> "Player art (debug)" toggle that swaps back to greybox. **Wave-1 close-out: 0 deviations** (`DESIGN_DEVIATIONS.md` empty).
> Integrated gate green: import · smoke · fp **`e943ac9c8bc1`** byte-identical · config **89/89** · `PLAYER_VISUAL OK` ·
> `MOVE OK`. Tasks N0 (`07edb77`) · N1 (`47ab9a8`) · N2 (`cffb5db`) — board=Done. Worklogs `…-N{0,1,2}-general-purpose.md`.
>
> **✓ Two Director-reported visual bugs FIXED + INTEGRATED (2026-06-28), pushed:**
> - **FIXINTERP** (`9e134fd`) — junk/player/hazard "jumps somewhere else for one frame" = `physics_interpolation=true`
>   teleport ghost with no `reset_physics_interpolation()`. Added the reset at 8 world-entity spawn-teleport sites
>   (junk_spawner.spawn_one, thrown-item, player+camera dive-start, hazard spawns, extract-gate). Render-only; fp unmoved;
>   junk/throw/loop tests green. Left the K6 per-tick camera smoothing alone. Worklog `…-FIXINTERP-general-purpose.md`.
> - **FIXEAST** (`a37d106`) — "throw-right character cut in half" = corrupt `throw/east` source (PixelLab neighbor-bleed in
>   all 7 frames; only east). **Regenerated east via PixelLab** (Director-authorized; char `3cb56375`, new anim `b03f703e`,
>   clean 7f), replaced in `Game/` + `art_workshop` source (corrupt originals preserved in git history + GENERATION.md note).
>   Bundled the recurring SpriteFrames uid-drift cleanup (godot-normalized `uid://bd2h7mfhen6uo` + player.tscn hint). Asset-only;
>   fp unmoved; player_visual/config 89 green. Worklog `…-FIXEAST-claude.md`.
> Both still need on-screen confirmation in RG1 (headless can't render the ghost-gone / the clean east throw).
>
> **✓ PLAYERTAB (`bb1976a`, 2026-06-28) — debug menu "Player" tab added, integrated, pushed.** New `CFG_TAB_PLAYER` tab holds
> the **Player art (debug)** toggle (MOVED off Meta) + live pickup/throw animation-lock controls: lock-on-pickup, animate-on-reject,
> lock-mode (Clip-driven/Fixed), and **separate `Pickup lock (s)` / `Throw lock (s)`** (per-action timing — replaced N1's shared
> cap/fixed; see `DESIGN_DEVIATIONS.md`, recommend Addressed). Live via new EventBus `debug_player_anim_config_changed`. Debug-only
> (outside MANIFEST): fp `e943ac9c8bc1` unmoved · **89/89** held · CLIP_DRIVEN default byte-preserved. Worklog `…-PLAYERTAB-general-purpose.md`.
>
> **✓ ART DEFAULT FLIPPED TO OFF (2026-06-28, Director-directed).** The shipped default is now **greybox (art OFF)** — the
> animated character is **opt-in** via the Player-tab toggle; with art off the pickup/throw movement-lock is also off (gated by
> `_art_on`). Changed: `player_visual._art_on=false`, `player.tscn` (AnimatedSprite2D hidden / greybox `Visual`+`Nose` shown),
> the Player-tab art `CheckButton` default unchecked, + the `test_config_menu` assertion. So the **default build == M1.6 look &
> feel**; turning art ON in the Player tab previews the new character. fp `e943ac9c8bc1` unmoved · 89/89 · smoke · player_visual OK.
>
> **▶ Wave 2 = RE-GATE.** **RG1** (qa): author `design/M1_7_Tasks/RG1_playtest_build.md` from the M1.6 template; run the M1.7
> verify matrix (8-way anim + toggle swap headless-provable parts; fp/89/smoke); **update `changelog.txt`** (M1.6→M1.7 delta:
> the player is now an animated character + a debug art toggle); **publish to itch** `BUTLER=/mnt/c/wsl-libraries/butler/butler
> bash Game/tools/push_itch.sh` (Chrome/Edge, password-gated; **network/human-gated**). Then **Director playtest** → **RG2**
> readability/telemetry → **RG3** verdict in `design/M1_7_Tasks/G4_findings_M1.7.md`.
>
> **⚠ MANUAL (headless can't render):** the on-screen confirmation — that idle/walk/pickup/throw read correctly in BOTH Hub
> and Dive, the scale 0.45 / y=-18 seats the character on the r=14 body, the toggle swaps art↔greybox live, and the
> movement-lock doesn't feel sluggish (flip `PlayerVisual.lock_mode=FIXED` in-editor if it does) — is the core RG1 item.

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

## (archived) M1.6 build waves — done (full detail in worklogs + `DESIGN_DEVIATIONS_HISTORY.md`)

- **Wave 1 (M0, `52d6e17`)** — persistent root `App` router (new `run/main_scene`) + 8 EventBus signals + neutral `GameState`
  economy surface + quota-decouple + staged-config accessor + `debug_menu_toggle`=P + greybox stubs. 0 deviations.
- **Wave 2 (M1 ∥ M2 ∥ M4, `40d328d`)** — Main Menu (`bbc61ff`) · walkable Hub + `main_game` dive-only refactor + hub-return
  quota/wipe (`7c5391e`) · P-tab debug menu + Vision split, 89-coverage byte-identical (`1d0c0dc`). Parallel worktrees,
  file-disjoint, conflict-free. Close-out: 3 items all **Reviewed** (W2-F1 m13 stale→FU3, W2-F2 quota banner→M3, L6-F1→FU4).
- **Wave 3 (M3, `f47d8fc`)** — Hub Shop sell+buy + 3-item persistent catalog + META **v3→v4** (migration + `meta_v3.sav`
  fixture) + SellScreen retired + quota-MISS notice. Close-out: 0 deviations.

---

> **Standing contracts (M1.6):** all-off `RunConfig` default = permanent baseline (fp `e943ac9c8bc1`); **89-knob count holds**
> (M1.6 adds no lever knob; M4 regroups only); Money/owned purchases are meta, in-dive haul is run-state; save bump v3→v4 lands
> in M3 (migration + `meta_v3.sav` fixture); `run_ended` arity locked (the router observes it, never changes it); M0 is the sole
> writer of `game_state.gd`/`event_bus.gd`/`project.godot`/`app.*`; clock is dive-only; verify branch topology before every merge
> (qa git-switch leak); push + board mirror after every merge; wave close-out deviation sweep.

## ✓ M1.5 — Agency & Legibility — DONE 2026-06-24..26 (re-gated → ITERATE → M1.6)

All waves built + re-gated (L0–L6 + RG1 + post-RG3 tuning): agency-throw + room-bound pursuer + legibility fixes + the L6
mouse-aim/twin-stick control rework. Director re-test → **RG3 ITERATE → M1.6**. Detailed in-progress notes archived →
`STATUS_ARCHIVE.md`; tasks → `TASKS_COMPLETED.md`; re-gate provenance → `design/M1_5_Tasks/G4_findings_M1.5.md`. **L6-F1**
(keyboard-only-no-mouse aims DOWN) carried to the M1.6 backlog (mouse + controller unaffected; non-blocking).

---

## ✓ Wave 2 (Oppositions retuned to the new canvas) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. Determinism unmoved (fp=e943ac9c8bc1); none touched `main_game.gd`.
- **I2** hazard refuge fix (shrink body r10 + anti-wall-stick + depth-scaled catch + `r1_catch_radius_per_depth` knob, CFG 36/36) — merge `1966145`.
- **I3** R2/R3 cues (exposure ramp+ticks+penalty banner; return-cost pulse+floating −N; optional shake; all-off=M1.0 HUD) — merge `9b5d75d`.
- **I4** vision/fog rework (radial-dark occlusion ~0.94 + 3-state fog + lost edge-pulse/"DISORIENTED"; R4-off=M1.0) — merge `d56674d`.

Close-out: 0 formal deviations; 1 finding (W2.2-F1: R2 `exposure` toll fired its cue but didn't charge R3's meter — no `add()` on `exposure_meter.gd`) → Director: **fix now** → **BUG5** filed + dispatched.

---

## ✓ M1.2 DONE — re-gated, verdict ITERATE (2026-06-19)

Director playtested the RG1 build (33 runs, `ba745e1`). RG2 (`design/M1_2_Tasks/G4_findings_M1.2.md`): run-length ~2×
M1.1 (26.4s median), depth to 17, three-way end-causes (real hazard deaths), `duration_s` clean (I5 works). RG3 verdict:
**ITERATE → M1.3.** Director decisions + new issues (BUG6 hazard-spam, R3/R4 config traps) recorded in §5 of that doc.

## ✓ M1.3 Wave 1 (Foundation & correctness) — DONE (2026-06-19)

All 5 on `main`, verified, pushed, board=Done; all-off fp byte-identical (e943ac9c8bc1). Close-out: 2 Reviewed + 1 Addressed (history).
- **J5** depth counter → `Depth {depth_index} / {max}` via `depth_changed` — `50d8faf`.
- **BUG6** `hazard_caught` one-shot latch + `inert_enabled_oppositions()` warn-only traps — `ed176bf`; refined to maze-aware `r4_no_effect` (`25072f6`).
- **DLV2** in-game `JavaScriptBridge` telemetry-export button on the sell screen (web-guarded) — `2b00a09`.
- **DLV1** itch HTML5 delivery (Web preset + `push_itch.sh` + web templates + nightly slugs) — `02ad951`. ⚠ **real butler push human-gated** (sandbox can't reach `broth.itch.ovh`; run `tools/push_itch.sh` per SETUP §1a).
- **J1** `make_default_play_preset()` (19 rooms, size 4.0, R1 on, **R4 maze-only / occlusion OFF = match-played**, R2/R3 off) + `RANGE_MULT=[4.0,40.0]` — `3159aac` (+ `25072f6`).

## ✓ M1.4 Wave 1 — DONE (2026-06-21)

K0 + K3/K6 + K4 all on `main`, pushed, board=Done; all-off fp byte-identical (`e943ac9c8bc1`); 81 knobs.
- **K0** foundation (`74034bc`+`02b8a00`): 35 new knobs off/neutral + `to_flat_dict()` + 7 new signals + removed dead `light_low()` + CFG rows (46→81) + K1 retune (`r1_speed_per_depth→3.0`, `r1_catch_radius_per_depth→1.0`). Worklog `worklogs/2026-06-21-K0-general-purpose.md`. **Deviation for close-out:** K0 doc RD-1/RD-6 dropped the two quota enums (would be 79) but the Phase-4 Lock KEPT them → 81 as-built (reconcile the doc).
- **K3+K6** camera + jitter (`f3147d2`): `[display]` (canvas_items/integer/expand, base 1152×648) + `[physics]` `physics_interpolation=true`; camera reparented off the player to a level-owned `CameraRig`/`CameraView` (`entities/dive/camera_view.gd`) driving fixed visible-world-width from `cam_*`. Default-off = today's framing byte-for-byte. **Deferred check:** jitter-gone + fixed-FOV *look* are render-time, confirm in RG1 playtest on >60Hz hardware.
- **K4** timer + warning (`878fe1f`): `timer_length_s` override + one-shot `dive_clock_warning` latch + HUD visual cue + gated audio stub. All-off = today's clock.

## ✓ M1.4 Wave 2 (Stakes & spatial) — DONE (2026-06-21)

K2 + K7 both on `main`, pushed, board=Done; all-off fp byte-identical (**e943ac9c8bc1**); 81 knobs (0 new RunConfig fields — K0 pre-declared both groups). Wave-2 close-out: **0 deviations** (swept → `DESIGN_DEVIATIONS.md` empty).
- **K2** quota + roguelite wipe (merge `65a6cdf`): per-run quota (preset $50 +$50/run, every-run-end × cumulative-money, both swept knobs), miss = full **9-field meta wipe**; save META **v2→v3** + migration + `meta_v2.sav` fixture; HUD quota readout + SellScreen "QUOTA MISSED" + MainGame Continue→`wipe_meta()`→fresh start; Q8 `run_started` quota stamp. Verified: v1→v3 & v2→v3 migrations green, `test_quota_system` green. Worklog `worklogs/2026-06-21-K2-general-purpose.md`.
- **K7** exit placement (merge `8d9c884`): single fixed gate → 1..N gates, depth-scaled count, Strategy-A local-sub-stream random placement (`run_seed ^ EXITS_RNG_SALT`), `exit_keep_one_at_spawn` pin. Pure run-state — **no save/schema change**. Default/preset = today's single fixed gate (exits OFF). `test_exit_placement` green. Worklog `worklogs/2026-06-21-K7-general-purpose.md`.
- *qa git-switch leak recurred on BOTH builds; agents self-cleaned; topology verified clean before each merge (qa-agent-git-switch-leak memory holds).* 

## ✓ M1.4 Wave 3 (Danger variety) — DONE (2026-06-21)

K5a + K5b + K5c (parallel) + K5i (integration) all on `main`, pushed, board=Done; all-off fp byte-identical (**e943ac9c8bc1**); each entity RNG-free; node counts bounded by `NEW_HAZARD_BAND_CEILING=48`. All three ran as clean parallel worktrees (zero file overlap). qa git-switch leak recurred on each; agents self-cleaned; topology verified clean before every merge.
- **K5a** ping-pong bouncer (merge in `50ba1a7` chain): `CharacterBody2D`, straight travel + wall-reflect within `room_bounds`, distance kill, amber tell. `res://scenes/hazards/pingpong_hazard.tscn`. Worklog `2026-06-21-K5a-general-purpose.md`.
- **K5b** committed proximity bomb: proximity-arm (no-defuse) → pulse → detonate within `hbomb_blast_radius`; idle/amber/orange-red tells. `res://scenes/hazards/bomb_hazard.tscn`. Worklog `2026-06-21-K5b-general-purpose.md`. *(test emits harmless `queue_free`-on-freed stderr → **W3-F1**, awaiting Director disposition.)*
- **K5c** anchored rotating spikes: 3 arms (const), analytic point-to-segment kill (no CollisionShape2D), deterministic phase from `spawn_ctx.phase_salt`, steel/cyan tell. `res://scenes/hazards/spike_hazard.tscn`. Worklog `2026-06-21-K5c-general-purpose.md`.
- **K5i** spawn-seam integration (merge `91be51f`): `_spawn_new_hazards` sibling of `_spawn_r1_hazards`, descriptor table (pingpong→bomb→spike starvation order), per-room count `base+floor(per_depth*depth)` capped per-room + shared 48 ceiling, per-kind `spawn_ctx`, pure-deterministic; R1's `_density_spawn_positions` untouched (golden-guard added). `test_new_hazard_spawn` green. Worklog `2026-06-21-K5i-general-purpose.md`.

## ✓ M1.4 Wave 4 — RG1 build+verify — DONE (2026-06-21)

RG1 on `main` (merge `0da631f`; build commits `183d19f`/`aa58a99`), pushed, board=Done. **Director lifted the Wave-4 hold → RG1 built + verified + published to itch.**
- **Preset = M1.4 fun stack:** `make_default_play_preset()` now layers **K4** timer (60s dive / 10s near-end warning / visual-only) + **all three K5 hazards** (hpp/hbomb/hspike ON at RG1 sweep-START magnitudes, each with a mandatory `per_room_cap=2`, balanced ~9/9/9 under the 48 ceiling so all three spawn) on top of the M1.3 base + K2 quota + K3 camera. **K7 exits ship OFF** (Phase-3 lock). All-off code defaults untouched.
- **Headless `test_rg1_m14_verify`** (run as a SCENE: `godot --headless res://tests/test_rg1_m14_verify.tscn`) → **`RG1 M1.4 VERIFY OK`, exit 0**: preset shape, all-off fp byte-identical **`e943ac9c8bc1`**, no-leak into the control, `to_flat_dict()` carries all 81 knobs incl. K4/K5/K7, K5i spawn helper spawns ≥1 of each kind bounded by cap + 48 ceiling, extract/timeout end-causes reachable. 11 rows headless / 7 human-deferred.
- Gates re-run by orchestrator: import clean · smoke OK · run_config 81 · config_menu 81/81.
- Verify doc `design/M1_4_Tasks/RG1_playtest_build.md`; `loop_smoke_checklist.md` + `tester_readme.md` updated. Worklog `worklogs/2026-06-21-RG1-general-purpose.md`.
- **itch published:** `qusto/the-far-yard:html5 @ m1-20260621-...` (Chromium-only, password-gated). *(Re-published post-merge so the live build matches final `main`.)*

> **Board drift flagged (2026-06-21):** the GitHub Project only carries items through M1.1 (R0/CFG); the M1.2/M1.3/M1.4 `J*`/`K*` tasks were never added despite STATUS marking them "board=Done." RG1 item created + set Done (`PVTI_lAHOAAXnOs4BasyMzgwZAFk`); back-filling the ~20 missing items is a Director call (surfaced, not silently done).

> **Wave-4 RG1 close-out (2026-06-21):** 1 deviation flagged by the build agent → **RG1-F1** (the K5 sweep-start magnitudes — chose modest base 0 / per_depth 0.15 / cap 2 so all three hazards spawn rather than pingpong starving spikes at the shared 48 ceiling; the load-bearing constraint "every type must spawn in the default" was held; values are an explicit RG1 sweep the Director delegated). **Awaiting Director disposition** (recommend **Reviewed**). `DESIGN_DEVIATIONS.md` carries it.

## ✓ M1.4 Wave 5 (RG1-feedback bug-fixes) — DONE (2026-06-21)

Director playtested the RG1 itch/desktop build → **RG3 verdict = ITERATE, packaged as an M1.4 bug-wave + re-gate**
(not a full M1.5). RG2 telemetry analysis + 6-item triage in `design/M1_4_Tasks/G4_findings_M1.4.md`. Four file-disjoint
tasks ran as parallel worktrees; all merged to `main`, all-off fp **byte-identical e943ac9c8bc1**, board=Done. Full
suite green (import · smoke · run_config 81 · config_menu 81/81 · rg1_m14_verify · new_hazard_spawn · pingpong · spike ·
exit_placement(_count)).
- **BUG7** (`main_game.gd`, merge `5bcc89b`; fix `a5b1b57`) — **feedback #7 (CRITICAL)**: `_spawn_new_hazards` skips the
  depth-0 entry piece + filters cells within `NEW_HAZARD_SPAWN_SAFE_CELLS=2.5` of the entry-spawn (mirrors
  `_exit_candidate_cells`). `base_count ≥ 1` no longer spawn-kills at frame 0. Telemetry root-cause: `s_384be7` runs 19–47.
- **BUG8** (`pingpong_hazard.gd`, merge `8c2f283`; fix `b11571c`) — **feedback #2**: tracks intended heading `_dir` and
  reflects IT (summed normals at corners), so `move_and_slide`'s tangential mutation never feeds the bounce → no wall-stick.
- **TUNE2** (`run_config.gd` preset + `test_rg1_m14_verify.gd`, merge `17b0e72`; fix `7854ddd`) — **#1** cam 576→**1000**;
  **#3** spikes `base 0→1` / `cap 2→1` so a spike reliably spawns at shallow depth (≈37 hazards combined < 48 ceiling, spikes
  not starved). Added `_driven_default_preset()` (K5 off for the driven end-cause matrix only; full preset still shape-checked).
- **FB5** (new `test_exit_placement_count`, merge `73530d5`; `3e1c95b`) — **#5 VERDICT: NOT a bug.** Multi-exit placement is
  correct (depth-scaled distinct gates scattered across pieces); the Director saw it during the #7 instant-death runs that never
  left depth 1. Regression test added. *Note for Director: exits are placed once per band at build time across its pieces — no
  NEW gates appear as you walk deeper within one band (that'd be a net-new "progressive spawn" feature, K7 DR-7 deferred).*

**#6** (spawn-room-only pursuer) is **deferred to M1.5**, semantics LOCKED by the Director: **slow patrol** — the pursuer
keeps patrolling within its spawn room but never chases the player outside it; chases only while the player is in that room.

### ▶ Next action (start here on a cold restart) — re-publish RG1 to itch, then re-gate

1. **Re-publish the fixed build to itch** (standing playtest-gate step): `bash tools/push_itch.sh` with
   `BUTLER=/mnt/c/wsl-libraries/butler/butler` (Chromium-only, password-gated; SETUP §1a). Human-gated on a real network.
2. **Director re-gate playtest** of the Wave-5 build (camera 1000, spikes now visible, no auto-end, ping-pong unsticks);
   export telemetry; record **go → M2 / iterate → M1.5** in `design/M1_4_Tasks/G4_findings_M1.4.md`.
3. **Wave-5 close-out deviation sweep** (below) — Director dispositions before any M1.5 work.

> **Wave-5 close-out — for Director disposition:** (a) **TUNE2 `_driven_default_preset()`** — the verify driver now
> disables the three K5 hazards for its scripted end-cause matrix because shallow spikes kill the driven player (no
> per-hazard `kills` toggle like R1's `r1_catch_kills`); shape-checks + spawn-checks still run the full preset. Recommend
> **Reviewed** (test-harness accommodation, not a design change) — or Addressed if a `*_kills` toggle is wanted on the K5
> family. (b) **Stale `.tscn` UID drift** — 11 scene files showed pre-existing local UID-regen at session start; current
> `--import` does NOT reproduce them and HEAD builds/tests clean, so they were set aside in `git stash@{0}` (not reapplied,
> not dropped). Recommend dropping the stash unless the Director wants those UIDs investigated.

---

## (superseded) ▶ M1.4 RG2/RG3 re-gate — Director played → ITERATE (see Wave 5 above)

RG1 is done + published. The re-gate now hands off to the **Director**:
1. **Director playtest** — play the itch build (and/or a desktop config sweep) across the M1.4 fun stack + variants; export telemetry (in-game "Export telemetry" button on web; `user://telemetry/run_log.jsonl` on desktop).
2. **RG2 (`qa`)** — analyse the returned telemetry: per-config distributions side-by-side across **M1.0/M1.1/M1.2/M1.3/M1.4**; did stakes (quota+wipe), variety (3 new hazards), and the legibility fixes (camera/timer/jitter) land? **OQ-3 carry-forward:** confirm worst-case ~112-body (R1 64 + new 48) tick-time on the web build is acceptable.
3. **RG3 (Director)** — record **go → M2 / iterate → M1.5 / pivot** in `design/M1_4_Tasks/G4_findings_M1.4.md`. Claude assembles + recommends; the human plays + decides.

Also pending the Director: **RG1-F1 disposition** (above) and the **board back-fill** call.

> **Standing contracts (M1.4):** all-off `RunConfig` default = permanent baseline (fp e943ac9c8bc1); fun values only in `make_default_play_preset()`; config-marked telemetry; `run_ended` arity locked; single-writer-per-`.gd`-file per wave; parallel agents `isolation: worktree`; verify branch topology before every merge (qa git-switch leak — memory); push + board mirror after every merge; wave close-out deviation sweep.

> **Wave-1 close-out sweep DONE (2026-06-21).** 3 deviations dispositioned → archived to `DESIGN_DEVIATIONS_HISTORY.md`:
> K0 count (Reviewed, as-built 81 per Lock) · K3/K6 render-time deferred-checks (Reviewed → RG1 matrix) · **camera now
> ENABLED in the preset** (Addressed: `make_default_play_preset()` → `cam_enabled=true`, `cam_visible_world_width=576`,
> `cam_zoom_policy=fit_width`; smoke OK, all-off fp `e943ac9c8bc1` unchanged).

> ⏸ **BUILD PAUSED after Wave 1 at the Director's request (2026-06-21).** Resume by dispatching **K2** (the first Wave-2
> task) per the step above. Design is locked, Wave 1 is integrated + pushed; nothing is mid-flight.

> **Contracts (M1.4):** all-off `RunConfig` default = permanent baseline (fp=e943ac9c8bc1); fun values ship in
> `make_default_play_preset()`; quota = every-run-end × cumulative-money, miss = full wipe (Director FINAL); config-marked
> telemetry (every knob → `to_flat_dict()` + test counts); `run_ended` arity locked; K0 pre-declares ALL new signals up front;
> single-writer-per-`.gd`-file per wave; parallel agents `isolation: worktree`; **verify branch topology before every merge**
> (qa-agent `git switch` leak — memory); push after every merge; board mirror; wave close-out deviation sweep.

> **Carry-over (non-blocking):** wire `tests/test_rg1_m13_verify.tscn` into the CI test set when convenient; butler push
> stays human-gated on a real network (SETUP §1a, Chromium-only) — relevant again at M1.4 RG1.

---

## ✓ M1.3 — Legibility & Density — DONE 2026-06-21 (re-gated → ITERATE → M1.4)

Waves 1/2 (J1·J2·J3·J4·J5·BUG6·DLV1·DLV2) + RG1 all on `main`; all-off fp byte-identical (e943ac9c8bc1). RG1 (`d9138c7`)
verified (`test_rg1_m13_verify` → **RG1 M1.3 VERIFY OK**), published-gate human. Director playtested → **RG3 verdict ITERATE**;
feedback work-order → M1.4 (`design/M1_3_Tasks/G4_findings_M1.3.md`). Detailed Wave-1/2 in-progress notes archived → `STATUS_ARCHIVE.md`.

---

## ✓ Wave 1 (Spatial & data foundation) — DONE (2026-06-19)

All three integrated on `main`, verified, pushed, board = Done. All-off default still byte-matches the M1.1 baseline (fp=e943ac9c8bc1).
- **I1** configurable level scale (count override + size mult + 4 new larger greybox pieces behind a config-dependent ext catalog) — merge `e67532c`. Worklog `worklogs/2026-06-19-I1-general-purpose.md`. *Empirical: linear spine reached requested count up to 60 — no count ceiling in the realistic range; run-time is the binding constraint (RG1/RG2 tuning).*
- **BUG4** geometry-keyed branch-rate-independent seal — merge `eee4418`. 508 void cells → 0 across 36 high-branch bands; fingerprint byte-identical. Worklog `worklogs/2026-06-19-BUG4-general-purpose.md`.
- **I5** telemetry hygiene (duration loop-re-entry regression-lock + real HEAD-SHA bake, `+dirty`) — merge `1fd657e`. Worklog `worklogs/2026-06-19-I5-qa-playtest-coordinator.md`.

Close-out: 4 deviations (I1-1, I1-2, + 2 lingering M1.1 RG1 entries), **all Director-Reviewed**, reapplied (`M1_As_Built.md` socket-width rule; `RG1`/`CFG` magic-count prose) + archived → `DESIGN_DEVIATIONS_HISTORY.md`. `DESIGN_DEVIATIONS.md` empty between waves.

---

## ▶ Next action (start here on a cold restart) — **finish BUG5, then dispatch Wave 3 (RG1)**

Waves 1 & 2 are on `main` (new spatial canvas + clean telemetry + retuned/legible oppositions). **BUG5 is in flight** (the
last build fix before the re-gate — makes R2's `exposure` toll actually charge R3). When BUG5 returns:
1. **Verify + integrate BUG5** (verify topology first — the Wave-1 stray-`git switch` lesson), push, board=Done, run its mini close-out.
2. **Dispatch Wave 3 — RG1** (`general-purpose` + `qa-playtest-coordinator`): author the M1.2 RG1 build+verify doc from the
   `design/M1_1_Tasks/RG1_playtest_build.md` template; assemble the runnable M1.2 loop; verify each fix individually + stacked;
   confirm config-marked telemetry writes; multiple runs/session. **BlockedBy: I1, BUG4, I5, I2, I4, I3 (all done) + BUG5.**
3. **RG2/RG3 are HUMAN-GATED** — RG1 hands off to a **Director playtest** (sweep configs on a dev machine), then `qa` analyses
   the telemetry vs the M1.0 (all-off) + M1.1 baselines (RG2), and the Director records the go/iterate/pivot verdict in
   `design/M1_2_Tasks/G4_findings_M1.2.md` (RG3). Claude assembles + recommends; the human plays + decides.

> **Collision note for Wave 3:** RG1 is largely additive scene-assembly + a verify test; it touches `main_game.gd` (loop
> wiring) + a new RG1 verify test. It's sequential (single task), so no parallel-collision management needed. Confirm no new
> `event_bus.gd` signal is required (the M1.1 RG1 needed none).

> **Standing process (locked):** parallel agents in `isolation: worktree`; pre-declare any new `event_bus.gd` signal on `main` before a parallel wave; single-writer-per-`.gd`-file; push `main` after every merge; mirror task status to the board; run the **wave close-out deviation sweep** after each wave (Director dispositions). See `CLAUDE.md` orchestrator loop.

**Also open (independent, Todo, non-blocking):** FU1 `test_jsonl_writer` · FU2 `EconomyMath`.

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
