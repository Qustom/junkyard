# HG1 — M1.8 Playtest Build (Hub Art Dressing — the box becomes a yard)

**Task id:** HG1 · **Milestone:** M1.8 (Hub Art Dressing) · **Workstream:** the re-gate · **Wave:** 2 (after Wave-1 H0+H1 integrate)
**Assignee:** `qa-playtest-coordinator` (build assembly verification — integrated across H0+H1) + the verify matrix
**dependsOn:** **H0** (asset import → `hub_ground.tres` TileSet) + **H1** (dress `hub.tscn` — Layout-A vertical spine) both integrated on `main` (`11b8ff4`, bookkeeping `7df074c`)
**Companion docs:** `M1.8_Breakdown.md` (the one thing this version must prove + the cross-cutting contracts), `M1_7_Tasks/RG1_playtest_build.md` (the template this mirrors), the M1.7 changelog block (the previous shipped version, for the changelog delta), `M1_Tasks/M1_As_Built.md` (canonical APIs), `worklogs/2026-06-28-H0H1-hub-dressing-general-purpose.md` (the Wave-1 build worklog), `systems/save_manager.gd` (`META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **unchanged in M1.8**).

> **This is the VERIFY + DOCUMENT task, not new gameplay.** M1.8 is an **art-only iteration**: H1 re-skinned the greybox surface Hub with the Layout-A vertical-spine placeholder art (tiled ground spine, `dive_gate`+`portal_glow` on the portal, `shack_door`+benches on the shop, 15 y-sorted dressing props) — a **pure visual re-skin** with no gameplay / save / `RunConfig`-knob change. HG1 (a) confirms the dressed `hub.tscn` still **loads and resolves every functional contract** the loop reads, (b) confirms the **loop is byte-identical** — the all-off control still reproduces the locked baseline (fp `e943ac9c8bc1`), (c) confirms the **89-knob count holds** (M1.8 adds no lever), (d) confirms **no save-schema change** (META v4 / RUN v1 unchanged; nothing about hub art persists), and then (e) hands the Director a playable build (published to itch by the orchestrator) + the changelog for the re-gate (HG2/HG3).

---

## 1. Goal & design intent

**Goal:** verify **one runnable M1.8 build** that proves the surface Hub can shed its greybox skin and read as a *place* — a lived-in, golden-hour salvage yard — using the placeholder Layout-A art, **without touching the loop's behaviour**. The portal still dives, the shop still sells/buys, the quota still fires on return, the room is still wall-bounded, and the all-off dive is still byte-for-byte the locked baseline. Only the *look* changed.

**Design intent (one line):** *HG1 is the M1.8 integration + verification + publish capstone, not a new system* — it confirms the H0/H1 re-skin composes onto the existing scene without disturbing the loop, the dive, the band generation, or the save format: the all-off `RunConfig` band fingerprint stays `e943ac9c8bc1`, the 89-knob count holds, the save schema does not bump, and **every functional node contract `hub.gd` and the interaction system read is intact** after the re-skin. The dressed-yard *look* read (does the spine read, is the lane clear, do functional props distinguish from dressing, does golden-hour hold, framerate with ~15 props) is HG2/HG3 (Director) — headless cannot render any of it.

---

## 2. What's already wired (the M1.8 H0/H1 work — do NOT rebuild)

HG1 inherits the integrated H0/H1 work (one shared branch, one worklog — `2026-06-28-H0H1-hub-dressing-general-purpose.md`). Key seams (verified present by §4):

- **H0 — asset import + ground TileSet.** 16 Layout-A ground tiles (32×32; 5 materials: asphalt / dirt / dirt-litter / scrap-wall / plank-floor) + 20 object PNGs **copied** (not moved) from `art_workshop/map_layouts/layout_a_assets/` into `Game/art/hub/{ground,objects}/`, imported with texture-filter OFF (inherited from the project default). `Game/data/tilesets/hub_ground.tres` is a 32px-cell `TileSet` with the 16 ground tiles as atlas sources (no physics layers — walls own collision separately).
- **H1 — dressed `hub.tscn`.** The `Room/Floor` `ColorRect` is now a `TileMapLayer` painted by a new **RNG-free** `hub_ground.gd` (the 3-band south→north spine: asphalt street edge → packed-dirt yard with the central spawn→shack→gate lane kept cleanest → dirt-litter north fringe, framed by a scrap-wall border ring). The four `Room/Walls` `StaticBody2D` colliders are **unchanged** (their visual `ColorRect`s re-tinted deep-rust, sitting on the scrap-wall ground border). The `DeparturePortal`'s greybox `Body`/`BodyInner` `ColorRect`s → `dive_gate` + `portal_glow` `Sprite2D`s; the `HubShop`'s greybox `Body` → `shack_door` + `workbench` + `sort_table` `Sprite2D`s. 15 `o`-pool dressing sprites scatter under a y-sorted `Props` node; the root `y_sort_enabled` lets the Player sort correctly among props/portal/shop. `HubCamera.zoom` tightened 1.2 → 1.05 to frame the full spine.

**The run/meta boundary stays intact:** the hub reads META only and holds no run-state — the re-skin is **pure presentation**. **No `RunConfig` lever added in M1.8** → the 89-knob count holds and the all-off fp stays `e943ac9c8bc1`. **No save-schema change** (META v4 / RUN v1). The functional-node contracts (portal/shop `Interactable` ids + collision, `hub.gd` node paths, wall-bounding) are invariant — H1 is a re-skin, behaviour-identical.

**Shack open-question (carried from the layout doc) resolved to DOORWAY-ONLY** for this pass (`shack_door` + `workbench`/`sort_table` props beside it, no visible plank-floor interior). The plank-floor tiles are imported and in `hub_ground.tres`, so an open-roof follow-up is cheap if the Director wants it. *Director-confirm at HG3.*

---

## 3. HG1 deliverable: greybox → dressed yard, loop unchanged

M1.8 is a **visual** iteration. The loop — `make_default_play_preset()`, the dive, the shop, the quota, the 300s clock — and the rest of the surface (Main Menu / Shop UI / P-tabbed debug / the M1.7 opt-in player art) are **identical to M1.7**. HG1 ships the **dressed surface** around that unchanged loop:

| System | What ships | Source |
|---|---|---|
| **Dressed Hub ground (H0+H1)** | tiled `TileMapLayer` floor reading as a south→north spine: paved street at the entrance → packed-dirt yard → grubbier dirt-litter toward the back; central spawn→shack→gate lane kept clearest; scrap-wall border ring | Director-directed Layout-A vertical-spine blockout (`art_workshop/map_layouts/staging_area_layout_a_dressed.md`). |
| **Dressed dive gate (H1)** | the north-center portal is now a fenced, padlocked `dive_gate` with a cold-violet `portal_glow` behind it, where the purple greybox box was | visual swap only — `Interactable` id `&"portal"` + collision unchanged. |
| **Dressed shop (H1)** | the shop is now a salvage-shed `shack_door` with a `workbench`/`sort_table` beside it (doorway-only, no walk-in interior), where the green greybox box was | visual swap only — `Interactable` id `&"shop"` + `ShopUI` unchanged. |
| **Dressing scatter (H1)** | 15 junkyard props (car on blocks, truck cab, tire stacks, oil drums, freezer, bathtub, cable spool, pallet of cans, propane tank, signpost, wheelbarrow, potted plant, folding chair, chalkboard, dog bowl) framing the yard, y-sorted so the player walks behind/in-front correctly; bigger silhouettes near the border, litter thickening north, central lane clear | pure visual — no collision (the wall border owns bounding). |
| (M1.7 loop + surface) | UNCHANGED — Main Menu / Shop / P-tabbed debug; the M1.7 opt-in animated player art (default OFF); the M1.5 fun-stack dive; 300s clock | unchanged from the M1.7 shipped build. |

**Invariants held:** the all-off `RunConfig.new()` band fingerprint stays `e943ac9c8bc1`; the 89-knob count holds (M1.8 adds no knob); `make_default_play_preset()` is the same fun stack; the save schema is **unchanged** (META v4 / RUN v1 — nothing about hub art persists); every functional node contract the loop reads is intact after the re-skin.

---

## 4. Verify matrix (M1.8)

HG1 is **done** only when this matrix passes. It separates **objective build checks** (headless-automatable, each row naming the exact test/command) from **subjective look read** (HG2/HG3 + human — the *rendered* dressed-yard experience). All commands run with `export PATH="$HOME/.local/bin:$PATH"`, **one godot instance at a time** (import-lock deadlock if concurrent), as a SCENE (`godot --headless --path Game res://tests/<x>.tscn`) — except the SceneTree movement/smoke checks, which run via `--script`.

> **Headless cannot render or drive any on-screen pixel.** This environment has **no display server** — so every row about *how the dressed hub looks* (the spine read, the clear lane, golden-hour, prop scale/busyness, the framerate-with-props) is **Director-manual / render-time** and is correctly deferred to §4.4 + HG2/HG3. The objective rows below prove the build *boots, loads the dressed scene, keeps every contract, and doesn't move the loop*.

### 4.1 Build integrity + determinism + loop-unchanged (HEADLESS)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Clean import** | All scripts compile, no parse errors; `.godot` builds (incl. H0 hub art + `hub_ground.tres` TileSet, H1 `hub_ground.gd` paint) | `godot --headless --path Game --import` → exit 0 | **PASS** (exit 0) |
| **CI smoke** | M0 architecture spike healthy (autoloads, EventBus, seeded RNG, save stub) boots headless | `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → "SMOKE OK", exit 0 | **PASS** ("SMOKE OK — M0 architecture spike healthy", exit 0) |
| **All-off baseline (R0)** | All-off `RunConfig` default verified (M1.0 baseline): 89 knobs, staged/cleared on the run boundary, trap-free, default play-preset is the F1 fun stack and does not leak | `godot --headless --path Game res://tests/test_run_config.tscn` → "R0 OK" | **PASS** ("R0 OK — RunConfig all-off default verified … all 89 knobs … J1 make_default_play_preset() is the F1 stack …", exit 0) |
| **Determinism fp (loop unchanged)** | All-off control band fp == `e943ac9c8bc1` (byte-identical to the locked M1.0–M1.7 baseline); the M1.8 art-only change **must not move the fp** (the hub is meta-only; it touched no generation/RNG/RunConfig/economy) | `godot --headless --path Game res://tests/test_rg1_m15_verify.tscn` → "RG1 M1.5 VERIFY OK" (the canonical fp guard — fails loudly if the all-off control drifts) | **PASS** (fp=`e943ac9c8bc1`; "RG1 M1.5 VERIFY OK"; 12 rows headless-verified, 7 deferred; exit 0) |
| **Bandgen determinism** | proc-gen reproducible across 9 seeds; sample seed 12345 → 12 pieces, fp `e943ac9c8bc1` | `godot --headless --path Game res://tests/test_bandgen_determinism.tscn` → "BANDGEN OK" | **PASS** ("BANDGEN OK — determinism + connectivity verified across 9 seeds (sample seed 12345 → 12 pieces, fp=e943ac9c8bc1)", exit 0) |
| **Level-scale determinism** | count + size + per-catalog determinism across 9 seeds | `godot --headless --path Game res://tests/test_level_scale_determinism.tscn` → "LVL OK" | **PASS** ("LVL OK — count + size + per-catalog determinism verified across 9 seeds", exit 0) |

### 4.2 Loop / dive / shop unaffected by the re-skin (HEADLESS)

The H0/H1 visual layer must not regress the loop's pickup/throw/extract/economy/quota logic.

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Main game loop** | dive-only scene builds a band (pieces+pickups+gate), pickup + gate-extract drives `run_ended(extract)` haul held-banked, a second run restarts clean | `godot --headless --path Game res://tests/test_main_game_loop.tscn` → "MAIN GAME OK" | **PASS** ("MAIN GAME OK — assembled dive-only scene … haul held-banked (not sold) … second run restarted clean", exit 0) |
| **Junk pickup** | populate-from-plan, accept adds + frees the item, full-bag reject leaves junk in-world, drop re-spawns | `godot --headless --path Game res://tests/test_junk_pickup.tscn` → "JUNK PICKUP OK" | **PASS** ("JUNK PICKUP OK — populated 24 pickups … accept added 'junk_scrap_bolt' … full-bag reject left junk in-world; drop re-spawned", exit 0) |
| **Drop / swap** | drop gesture removes from bag, emits `junk_dropped`, live spawner re-instantiates the grabbable | `godot --headless --path Game res://tests/test_drop_swap.tscn` → "DROP SWAP OK" | **PASS** ("DROP SWAP OK — drop gesture removed the item … emitted junk_dropped … re-instantiated one grabbable JunkPickup", exit 0) |
| **Throw mechanic** | throw projectile kills a hazard + consumes the item; miss re-drops; one-shot guard; throw flies along aim | `godot --headless --path Game res://tests/test_throw_mechanic.tscn` → "L1+L6 OK" | **PASS** ("L1+L6 OK — throw projectile verified: hazard-hit kills + consumes … miss re-drops … flies along player.aim", exit 0) |
| **Shop economy** | persistent catalog, purchase debits+records+persists, reject paths inert, wipe clears owned, SELL-tab credits the held haul | `godot --headless --path Game res://tests/test_shop_economy.tscn` → "SHOP ECONOMY OK" | **PASS** ("SHOP ECONOMY OK — 3-item persistent catalog … purchase() debits+records+persists … SELL-tab sell_banked_junk(&shop) credits the held haul", exit 0) |
| **Quota system** | met advances+persists; miss → wipe (9-field reset); eval idempotent; Hub-return cumulative basis counts the held unsold haul | `godot --headless --path Game res://tests/test_quota_system.tscn` → "QUOTA OK" | **PASS** ("QUOTA OK — met advances+persists … miss defers to wipe_meta (9-field reset) … M1.6 Hub-return cumulative basis counts the held unsold haul", exit 0) |
| **App router** | boots menu → hub → dive → hub; `current_state` correct (the hub is the dressed scene now) | `godot --headless --path Game res://tests/test_app_router.tscn` → "ROUTER OK" | **PASS** ("ROUTER OK — App router boots → menu → hub → dive → hub; current_state correct", exit 0) |
| **Hazards (4 types)** | pursuing / bomb / pingpong / spike hazard logic unchanged | `…/test_pursuing_hazard.tscn` · `…/test_bomb_hazard.tscn` · `…/test_pingpong_hazard.tscn` · `…/test_spike_hazard.tscn` | **PASS** (each exit 0; e.g. "PURSUING HAZARD OK — awakens at depth threshold … room-bound chase … all-off spawns no hazard") |
| **Player visual FSM** | the M1.7 opt-in player-art FSM (8-sector quantize + walk/idle select) still passes (it renders in the dressed hub too) | `godot --headless --path Game res://tests/test_player_visual.tscn` → "PLAYER_VISUAL OK" | **PASS** ("PLAYER_VISUAL OK — quantize_dir … select_state … verified", exit 0) |

### 4.3 Knob coverage + save schema + hub contract (HEADLESS / inspection)

| # | What's asserted | Test / command | Result |
|---|---|---|---|
| **Config menu 89/89** | All 89 `RunConfig` knobs still bound + reachable; Reset returns the all-off baseline. M1.8 (art-only) adds no knob → count unchanged. | `godot --headless --path Game res://tests/test_config_menu.tscn` → "CONFIG MENU OK" | **PASS** ("CONFIG MENU OK — CFG verified (89/89 knobs bound + reachable … Reset returns the all-off baseline)", exit 0) |
| **Hub contract spot-check** | the **dressed** `hub.tscn` still resolves `$Player`, `$PlayerSpawn`, `$HudLayer/QuotaNotice`; `DeparturePortal` child `Interactable` id `&"portal"`; `HubShop` child `Interactable` id `&"shop"`; the **4 wall colliders** intact; the ground `TileMapLayer` present | throwaway SCENE load check (`_tmp_hub_contract.tscn`, run in the real tree so autoloads load, then removed) → "HG1 HUB CONTRACT OK" | **PASS** ("HG1 HUB CONTRACT OK — $Player / $PlayerSpawn / $HudLayer/QuotaNotice resolve; DeparturePortal Interactable id=&\"portal\"; HubShop Interactable id=&\"shop\"; 4 wall colliders intact; ground TileMapLayer present.", exit 0) |
| **Save schema unchanged** | `META_SCHEMA_VERSION == 4`, `RUN_SCHEMA_VERSION == 1` — **no M1.8 bump** (hub art persists nothing). No new migration / fixture. Existing v1/v2/v3→v4 migrations + fixtures stand. | inspect `systems/save_manager.gd` + `git diff` since the M1.7 ship | **PASS** (`META_SCHEMA_VERSION := 4`, `RUN_SCHEMA_VERSION := 1`; `git diff 50fb401..7df074c` shows **no** change to `save_manager.gd` / `tests/fixtures/` / `test_save_migration.gd`) |
| **Save migration still green** | the existing v1→v4 migration chain still works (no M1.8 fixture needed, but the chain must not have regressed) | `godot --headless --path Game res://tests/test_save_migration.tscn` → "SAVE MIGRATION OK" | **PASS** ("SAVE MIGRATION OK — v1 meta fixture migrates to v4 … existing fields intact … .bak preserved", exit 0) |

### 4.4 Did HG1 add a new `test_hg1_m18_verify`?

**No — and this is a deliberate QA call.** M1.8 is an **art-only / presentation** claim. The only *non-rendered* surface the re-skin introduces is **"the dressed `hub.tscn` still loads and keeps every functional contract"**, which the **Hub contract spot-check** (§4.3) asserts directly (node paths, the two `Interactable` ids, the 4 wall colliders, the ground TileMapLayer). The "loop didn't move" claim is covered byte-for-byte by the existing fp guard (`test_rg1_m15_verify` → `e943ac9c8bc1`), the bandgen/level-scale determinism tests, and the full loop/dive/shop/quota/hazard suite — all of which re-run green here. A consolidated `test_hg1_m18_verify` would only re-instance the same hub/loop scenes and re-assert the same contract/fp/loop facts those tests already cover — pure duplication with no new headless-observable coverage, plus a concurrent-instance risk. **The entire remaining M1.8 surface is rendered** — whether the spine *reads* south→north, whether the central lane *looks* clear, whether the props *read* as dressing vs. the functional gate/shack, whether golden-hour *holds*, whether ~15 props *cost* any framerate — and a headless test **cannot render** any of it. The existing suite + the hub-contract check + the fp/89 guards **are** the M1.8 objective gate; the visual surface is correctly **human-deferred** to §4.5. **No new test committed.** (The contract check was run as a throwaway and removed; it asserts nothing the loop's other tests don't already guarantee structurally, and there is no persistent value in a hub-load test that re-checks node paths H1 already locked.)

### 4.5 Subjective / render-time — HUMAN-DEFERRED to the Director (the playtest checklist)

See §5. These are the *look* of the dressed yard — headless cannot render or input-drive any of them. The look read is HG3 (Director), backed by HG2's readability/perf check.

---

## 5. Director playtest checklist (the dressed hub — render-time, human only)

Open the published build (Chrome/Edge), boot to the Main Menu, NEW GAME, and stand in the dressed Hub. Then:

- **Spine reads S→N.** Walking from the south spawn toward the north gate, does the ground read as a *spine* — paved street/apron at the entrance → packed-dirt yard → grubbier scrap-litter toward the back? Does it tell you "the dive is *that way* (north)"?
- **Central lane clear.** Is the spawn → shack → dive-gate central lane visually the **cleanest** path (least litter, fewest props), so the eye is pulled along it? Or do props/litter clutter the route you actually walk?
- **Functional props distinguishable from dressing.** Do the **dive gate** (`dive_gate` + cold-violet `portal_glow`) and the **shack/shop** (`shack_door` + benches) read as the two things you can *interact with* — distinct from the 15 purely-decorative junkyard props? Could a first-time player find the gate and the shop without a label?
- **Prop scale & busyness vs. the player.** Do the props sit at a believable scale next to the player character? Is ~15 props the right amount of "lived-in" — or is the yard too busy / too empty? (The breakdown noted ~15 vs. the spec's ~10–12 — trim candidates if busy.)
- **Golden-hour read.** Does the whole yard read as a *golden-hour salvage yard* — the warm, lived-in mood the dressing is going for? Does the placeholder palette hold together, or does any one prop/tile clash?
- **Loop still plays identically.** Walk into the **dive gate** → you dive (same as M1.7). Walk into the **shack/shop** → the Shop UI opens; sell + buy work as before. Miss a quota → the "QUOTA MISSED — progress wiped" banner fires on Hub return. The room is still **wall-bounded** (you cannot walk off the yard). Nothing about the loop should feel different — **only the look.**
- **Framerate with ~15 props.** Watch for any frame-rate dip standing in / panning across the dressed yard (the per-band node-cap / 60 FPS · ~16 ms budget). 15 static `Sprite2D`s + one `TileMapLayer` should be free, but confirm on the web build.
- **M1.7 player art still works in the dressed hub.** Press **P → Player tab → tick "Player art (debug)"** → confirm the animated character renders and y-sorts correctly **among the dressed props** (walks behind the truck cab / freezer, in front of low litter). Un-tick → greybox restores cleanly. The dressing must not break the opt-in player art.
- **Placeholder caveat.** Remember the art is **PixelLab placeholder**, not final — judge the *layout / readability / mood*, not the pixel-craft. A human pixel artist still owns the final art.

**Deferred (not in this build):** the **street-exit threshold** (`SS` prop — the H3 PixelLab task) is **deferred** — the south edge currently uses asphalt tiles + a `signpost`; there is no functional street exit yet. The shack is a **doorway**, not a walk-in interior (the open-roof option is a cheap follow-up — tiles are imported). The **dive interiors are still greybox** — only the surface hub is dressed.

---

## 6. Publish + changelog (orchestrator-owned network step)

- **changelog.txt** — updated by HG1 with an **M1.8 — "The Yard Takes Shape"** block documenting the delta from M1.7 (the previous shipped version) as a clean **feature list**: the art-dressed Hub (tiled-spine ground, the salvage-shed shop, the fenced dive gate with portal glow, the scattered junkyard props), the placeholder caveat, and that the loop plays exactly as before (only the look changed; the M1.7 player-art toggle still works). Per the changelog scope rule, intra-M1.8 tweaks (the doorway-only shack call, camera-zoom tune, the 15-vs-12 prop count) are folded into the feature's final-state description, not listed separately. A short "NOT YET IN THIS BUILD" note flags the greybox dive interiors, the missing street exit, and the doorway-not-interior shack.
- **Publish to itch** — the orchestrator runs `BUTLER=/mnt/c/wsl-libraries/butler/butler bash Game/tools/push_itch.sh` (stamp → export the Web preset → `butler push qusto/the-far-yard:html5`). HG1 (this task, in an isolated branch) does **NOT** perform the network-gated push — it produces the verify doc + the changelog; the orchestrator publishes. Live page: `https://qusto.itch.io/the-far-yard` (Chrome/Edge only — SharedArrayBuffer/COEP). Web telemetry returns via the in-game "Export telemetry" button (P-debug Meta tab).

---

## 7. Re-gate guidance for the Director (HG3)

The re-gate question (HG3): **now that the surface Hub is a dressed golden-hour salvage yard, does it read as a *place* — does the spine pull you north toward the dive, are the functional props (gate / shack) legible against the dressing, does the placeholder fidelity HELP or DISTRACT vs. the greybox, and is the loop unmistakably unchanged?** The change is purely visual, so the M1.8 evaluation is **the Director's eyes**, not dive-config sweeping. Suggested playtest:

1. **Boot the dressed hub.** Stand at spawn, walk the spine S→N. Does it read? Find the gate + shop without labels.
2. **Compare to greybox (memory / the M1.7 build).** Does the dressed art *help* you orient (spine → gate) and feel the place — or does the placeholder fidelity *distract* from the loop vs. the clean greybox? (The core HG3 watch-item from the breakdown's open question #4.)
3. **Run the loop.** Dive via the gate, extract, return, sell at the shack, buy, miss/clear a quota — confirm it's behaviour-identical to M1.7.
4. **Player art ON.** P → Player → tick — confirm the character y-sorts cleanly among the props.
5. **Watch-items:** is the doorway-only shack enough, or worth an open-roof interior follow-up (assets imported)? Is the street-threshold (H3) worth generating (paid PixelLab)? Is ~15 props the right busyness?

**Telemetry HG2 should read:** M1.8 adds **no new gameplay metric** — telemetry stays comparable to M1.7 (the 89-knob `run_config` snapshot on every `run_started` row is still ground truth; flow signals unchanged). HG2's job is (a) confirm **no perf regression** from the ~15 hub sprites + TileMapLayer on the web build (60 FPS / ~16 ms budget), and (b) the Director's readability read. `build_tag` (prefix `m18-`) is the human-readable handle HG2 groups on.

---

## 8. Acceptance criteria (M1.8)

1. **A fresh build boots, reaches the dressed Hub, and the complete M1.7 surface loop + M1.5 dive still run end-to-end**, no blockers — the dressed `hub.tscn` loads and every functional contract resolves (Hub contract spot-check green).
2. **The loop is UNCHANGED and the all-off control reproduces the M1.0–M1.7 baseline exactly** (fp `e943ac9c8bc1` unmoved; the fun stack still ships; M1.8 touched no generation/RNG/RunConfig/economy — only hub art).
3. **The 89-knob count holds** (M1.8 art-only adds no knob; the count test stays 89/89).
4. **No save-schema change** (META v4 / RUN v1 unchanged; hub art persists nothing; existing migrations + fixtures stand, no new fixture).
5. **Pickup / throw / extract / shop / quota / hazards are unaffected** by the re-skin (loop/dive/shop/quota/hazard suite green).
6. The build + this doc + the updated changelog are **ready for the Director's playtest** (published to itch by the orchestrator; HG2/HG3 follow), with the dressed-yard *look* read correctly human-deferred (§4.5 + §5).

A build that passes the §4 matrix (all §4.1–4.3 rows green + the §5 human checklist handed off) and ships the updated changelog satisfies HG1. Done means: the matrix is filled, the worklog names the commit SHA, the build boots to a dressed hub whose functional contracts all resolve, the loop is byte-identically the M1.7 loop, the save schema is unchanged, and the 89-knob/fp invariants hold.

---

## 9. Resolved Decisions (pointer)

The Director's dispositions for M1.8 live in `M1.8_Breakdown.md` (the locked scope + cross-cutting contracts) and will be finalized at the HG3 re-gate. HG1 honours the breakdown verbatim: M1.8 is **art-only** (no gameplay/save/knob change); the all-off fp `e943ac9c8bc1` is unmoved; the 89-knob count holds; no save-schema bump; every functional node contract is invariant (the portal/shop `Interactable` ids + collision, `hub.gd` node paths, wall-bounding); assets were **copied** (not moved) from `art_workshop/`; the layout is **RNG-free / static**; the art is **PixelLab placeholder** (a human artist owns the final). The Wave-1 deviations the Director will disposition at close-out (logged in `DESIGN_DEVIATIONS.md` by the H0/H1 worklog): the **doorway-only shack** (vs. open-roof interior), the **camera-zoom 1.2 → 1.05** framing, the **wall-visual ColorRects kept** (re-tinted, not replaced by scrap-wall sprites), and **15 props placed** (vs. the spec's ~10–12). The **street-exit threshold (H3)** stays Director-gated / deferred (no functional street exit exists yet).
