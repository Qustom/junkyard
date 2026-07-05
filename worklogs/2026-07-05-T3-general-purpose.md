# Worklog — T3 New band: `band_three.tres` "The Warren" (cave profile + deck + tint)

- **Date:** 2026-07-05
- **Subagent:** general-purpose (programmer) — profile/deck/curve values per game-director-designer T3 spec; palette tint per environment-artist D-RAT-5 ratification
- **Milestone:** M1.10 (Wave 3 — the scalability measurement)
- **Branch:** worktree-agent-ac7af44f8860ba823
- **Commit:** <filled at commit>

## What changed
Authored the third dive band **entirely as data**, riding the now-merged cave stack
(T0 CaveBackend + `CaveBandConfig`, T1 materialisation, T2a Ambusher, T2b Burrower)
with **zero new production code**. Added `band_three.tres` ("The Warren", `backend =
"cave"`, `band_depth = 3`, blue-violet `palette_tint`, `flavors = []`), its tuned
`CaveBandConfig` (`cave_config_band_three.tres`), a reward-lifted `DepthCurve`
(`depth_curve_band_three.tres`), the D-RAT-6 natives-first deck
`[ambusher · burrower · splitter · DeckEntry{bomb, base_count:1}]`, and a contract
test that mirrors `test_band_two_profile.gd` extended to pin **both** socket controls.

## Files touched (all NEW — no existing file modified; `git diff --stat` empty)
- `Game/data/bands/band_three.tres` — the `BandProfile` (cave, depth 3, deck, tint, empty flavors).
- `Game/data/bands/cave_config_band_three.tres` — tuned `CaveBandConfig` (56×56 · fill 45 · smooth 4 · wall_threshold 5 · min_region 24 + T0 defaults, per Phase-3 amendment #4; integer-only, no float `nook_roughness`).
- `Game/systems/depth/depth_curve_band_three.tres` — reward-lifted curve (value 1.30→2.5; tier floor 3 / ceiling 5; density re-based ~1.0→1.3 per chunk-piece, per D-RAT-6 / Phase-3 amendment #9).
- `Game/tests/test_band_three_profile.gd` (+ `.tscn`, `.gd.uid`) — C0–C6 + C10 contract test.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] `res://tests/test_band_three_profile.tscn` → **BAND_THREE OK** (all seeds):
  - C0 profile contract (cave backend, empty flavors, null piece_pool, `CaveBandConfig` values, curve floors, deck ids, bomb `DeckEntry{base_count:1}`).
  - C1 determinism (fingerprint + floor_fingerprint stable per seed; seed variety).
  - C2 connectivity (cell + piece level, every seed).
  - C3 soft floor (floor cells ≥ 300; pieces ≥ 2).
  - C4 depth axis (`max_depth ≥ 4` on the **authored** config; deepest graded + reachable).
  - C5 **both controls byte-identical**: `band_greybox` direct-vs-pipeline fp; `band_two` absolute golden fps (9 pinned constants captured pre-change).
  - C6 deck: `instability(3)=1.30`, `floor(24·1.30)=31`, min_band gate, and the deterministic **6/3/4/1 = 14** spawn outcome through the real `EncounterBuilder` deck lane (budget spends exactly to 0), every seed.
  - C10 2×2-open throat certificate on the authored config, every seed.
- [x] Regression controls green: `test_cave_backend` (C9 socket controls + player-scale), `test_band_two_profile`, `test_deck_entry` (all-off fp **e943ac9c8bc1** pinned).
- [x] **Definition of done met:** "`band_three` deterministic + connectivity green; deck spawns 6/3/4/1 within caps at 31 credits; both socket controls untouched (absolute golden pins); `test_band_three_profile` green (C0–C6 + both controls + the 2×2 throat cert on the authored config); import clean + smoke green." — all satisfied.

## Bespoke-code ledger (the M1.10 headline scalability measurement)

**Marginal cost of adding band 3 (a whole new, differently-generated band):**

| Category | Count | Detail |
|---|---|---|
| **Production (non-data, non-test) code lines** | **0** | `git diff --stat` is EMPTY — not one existing `.gd`/`.tres` was edited. Every seam band 3 needs already existed: the cave backend dispatch (T0), the `validate()` cave branch (T0), `palette_tint` field + cave materialisation consuming it (T1), the `DeckEntry base_count` lever (S9), the count-agnostic generated menu (S4). |
| **Data `.tres`** | **3 files, 77 lines** | `band_three.tres` (36) + `cave_config_band_three.tres` (17) + `depth_curve_band_three.tres` (24). |
| **Test** | **1 test, 528 lines** (+ `.tscn`) | a retargeted clone of `test_band_two_profile.gd`, extended to pin the second socket control. |

**Comparison to band_two (M1.9 S7):** band_two's marginal cost was **1 production glue
line** (`geo.tile_set = profile.tileset`) **+ a new `palette_tint` schema field** on
`BandProfile`. **Band 3 is cheaper still — 0 production lines, 0 schema changes** —
because the tint field, the cave dispatch, and the `DeckEntry` lever all already shipped
in T0/T1/T2a/T2b. **The M1.10 thesis holds on evidence: once the second backend exists,
adding a cave band costs exactly what adding a socket band did — data only (in fact,
strictly less: zero glue vs band_two's one line).** The fixed cost (the CaveBackend,
materialisation, and the two components) is paid once by T0/T1/T2a/T2b and amortizes over
every future cave band.

## Design deviations
**none.** Every value is per the T3 spec's binding `Resolved Decisions (Phase 3)` +
the breakdown's Phase-3 amendments (#4 integer-only `CaveBandConfig` — no float
`nook_roughness`; #9 deck 6/3/4/1 + density re-base ~1.0→1.3, value 1.30→2.5, tier 3→5)
+ Director ratifications D-RAT-5 (identity "The Warren", blue-violet
`Color(0.62, 0.60, 0.78)` tint) and D-RAT-6 (deck + budget). Portal glow (cave-teal) is
T4's, not authored here. No code change was needed — the "band 3 = pure data" prediction
held exactly, so nothing was escalated for orchestrator adjudication.

## Handoffs / follow-ups
- **T4 (Wave 4):** D-RAT-5 hands T4 `display_name` "The Warren" + band `palette_tint`
  only; portal-3 `glow_tint` is T4's, constrained to green–teal (cave-teal
  `Color(0.30, 0.90, 0.65)` recommended). Route key `&"band_three"` → `band_three` still
  to be added to `BAND_ROUTES`.
- **TG2:** band-3 junk counts are per-chunk-piece rolls (~40+ pieces) — compare
  **band-total value**, not item counts. The deck outcome is deterministic 6/3/4/1 = 14;
  any observed deviation indicates cap/refusal behavior in the live service (per_room_cap
  ambusher 2 / burrower 1 / splitter 2), not tuning drift. The contract test proves the
  builder's *plan* (budget + per_band_cap); live per_room refusals are a TG1/TG2 check.
- **M2 content:** tier-6 "anomalous/paradox parts" JunkItems (the GDD's literal Band-3
  loot) remain deferred — the shared junk pool tops at tier 5, so band 3's ceiling is 5
  with a raised floor of 3 (D5 confirm).
