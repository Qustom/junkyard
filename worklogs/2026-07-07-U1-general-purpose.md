# Worklog — U1 Scatter materialisation ride-through + downstream verify

- **Date:** 2026-07-07
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.11 (Wave 2)
- **Branch:** `general-purpose/U1` (isolated worktree; left unmerged for the orchestrator's verified merge)
- **Commit:** `1381acae5e2a78c5a455d5f65458f10dad63bc66`

## Bespoke-code COST LEDGER (the headline — the N=3 datum UG3 judges)

**EXACTLY 1 changed line of non-data, non-test code** (RD-U1-8's audited expectation, met):

| # | File:line | Change |
|---|---|---|
| 1 | `Game/scenes/game/main_game.gd:1081` (was `:1076`) | `_pinned_gate_pos` snap guard: `_band_profile.backend != "cave"` → `_band_profile.backend == "socket"` (denylist → allowlist; null-check clause unchanged) |

Recorded but **uncounted** per RD-U1-4 (the ledger measures code): the `_pinned_gate_pos`
docstring rewritten (its "Socket bands (and every non-cave harness path)" description became
false with the flip) + the two stale `# cave: snap-to-floor … socket: today's value` call-site
comments at the all-off pin and keep-one sites, renamed to "synthetic backends: …". The
`_materialise_band`/`_build_synthetic_piece` "cave-backend" wording left untouched (deferred to
the post-UG3 hygiene pass, RD-U1-4). `:1170`'s raw-offset degenerate fallback is NOT a
`_pinned_gate_pos` call site and is untouched (RD-U1-0(b) footnote). Test files
(`test_scatter_materialise.gd`/`.tscn`) are outside the ledger by definition.

**T1 paid for the generality; U1's ride-through cost 1 line — the audit's predicted gap
(scatter took the unsnapped socket gate arm), nothing else.** Every other step of the cave
materialisation path (synthetic-piece build, perimeter-blind sealer capping ring AND cover
blobs, entry spawn, depth/junk/encounter placement, tint, collision) hosted scatter output
with **zero** edits, proven by the new suite below.

## What changed
1. **`main_game.gd`** — the §3.1/RD-U1-1 guard flip: the D-RAT-7 snap-to-nearest-floor now
   arms for every synthetic backend (cave + scatter + future); only socket bands and the
   null-profile harness paths keep the raw `spawn_pos + GATE_SPAWN_OFFSET`. Byte-identical
   on the null/socket/cave arms (RD-U1-0(b) arm walk); all three call sites (`_place_gate`
   all-off pin, keep-one pin, `_exit_candidate_cells` exclusion) inherit through the one
   shared helper. Fixes the seed/config-dependent unreachable-gate softlock on scatter
   (latent at RD-11 defaults, real at legal schema corners per RD-U1-1(ii)).
2. **`tests/test_scatter_materialise.gd` + `.tscn`** — NEW headless SCENE suite, M1–M9 per
   spec §3.2 as amended by the Phase-3 RDs (harness cloned from `test_cave_materialise`;
   profile built in code off `ScatterBandConfig.new()` schema defaults, no fixture `.tres`;
   9-seed matrix).

## §2.7 C-contract re-verification against LANDED U0 (done before writing code)
C1–C6 all hold — **no drift**: chunked `scat_` content-hashed pieces, entry chunk first,
floorless chunks skipped, `max_depth >= 4` via the corrected `chunks_x >= 5` clamp (C1);
entry anchor front-positioned as `floor_cells[0]`, lane-aligned tie-break per RD-2 as briefed,
`deepest_piece` set by `_pick_deepest_piece` (C2); all piece fields per contract —
`instance == null`, `offset_cell`, chunk-rect `footprint_cells`, `open_sockets == []`,
`mated_socket_index == -1` (C3); `min_cover_spacing >= 3` Chebyshev hard `validate()` clamp +
`border_margin >= 2` + full-width clear lane (C4); `BandPipeline` scatter dispatch + widened
connectivity ASSERT + `BandProfile.validate()` scatter branch (C5); component-driven proof
only, no `BAND_ROUTES` key (C6).

## Files touched
- `Game/scenes/game/main_game.gd` — the 1-line guard flip + RD-U1-4 docstring/comment rewrites (nothing else).
- `Game/tests/test_scatter_materialise.gd` (+`.uid`) — NEW: the M1–M9 acceptance harness.
- `Game/tests/test_scatter_materialise.tscn` — NEW: scene wrapper (tests run as SCENES).
- NOT touched: `systems/bandgen/*` (incl. `socket_sealer.gd` + U0's scatter files), `band_pipeline.gd`, `band_profile.gd`, `data/**`, `entities/**`, every existing test, every golden/fixture.

## Checks run
All via `godot` 4.6.3 headless, serially (never concurrent — import-lock):
- [x] `godot --headless --path Game --import` clean (no parse errors).
- [x] **`res://tests/test_scatter_materialise.tscn` → SCATTER MATERIALISE OK** — M1–M9 across the 9-seed matrix:
  - M1 closure: every floor cell's non-floor 4-neighbour WALL-capped (ring AND cover blobs, perimeter-blind), every seed.
  - M2 collision truth (RD-U1-3): exhaustive `direct_space_state` point queries (mask 2) on seed[0] — **every** cover cell HIT, sampled ring cells HIT, sampled floor cells MISS, after one physics-frame await; tile-atlas closure matrix-wide via M1.
  - M3 `fingerprint()` + `floor_fingerprint()` byte-equal pre/post materialise, every seed.
  - M4 anchors: spawn == `entry_piece.floor_cells[0]`, floor, 2×2-open; `max_depth >= 4`; `deepest_piece.depth_index == max_depth`, every seed.
  - M5 gate: all-off → exactly 1 gate on floor (the snap armed for scatter), floor-reachable from spawn; play preset → every gate on floor, every seed.
  - M6 STRENGTHENED (RD-U1-2): every floor cell ∈ T; T single component with |T| == |floor|; spawn ∈ T; all-off gate in T's flood (or 4-adjacent), every seed. GREEN — no U0 contract breach.
  - M7 `JunkPlacer.plan` all on floor; play-preset hazards ≥ 1, all on floor at `depth_index > 0`, every seed.
  - M8 tint: container modulate == non-white `palette_tint`.
  - M9 backend controls: socket band → exactly `pieces.size()` children, zero synthetic hosts, `_pinned_gate_pos` == raw fixed offset (allowlist arm pinned in-suite); cave-profile `_pinned_gate_pos` still snaps to floor (cave arm pinned in-suite).
- [x] **All FOUR control fingerprints byte-identical**, suites green UNMODIFIED:
  - all-off RunConfig fp **`e943ac9c8bc1`** — `test_bandgen_determinism` OK, `test_band_pipeline_parity` OK, `test_rg1_m12_verify`/`m13`/`m14`/`m15` all OK ("byte-identical to the locked baseline (fp=e943ac9c8bc1)").
  - `band_greybox` — parity suite byte-match + `test_band_routing` OK.
  - `band_two` — `test_band_two_profile` OK + `test_band_three_profile` C5 golden pin OK.
  - `band_three` — `test_band_three_profile` OK + `test_cave_backend` OK (sample fp `d984fd8913bf` unchanged).
- [x] `test_scatter_backend` OK unmodified (U0 control: seed 12345 → 35 pieces, max_depth=9, fp=`44a9a9b3756f` — matches U0's worklog exactly).
- [x] `test_cave_materialise` OK unmodified (the cave-arm equivalence proof, doubles as U1's cave control).
- [x] Gate/exit regression: `test_exit_placement` OK + `test_exit_placement_count` OK (both exercise `_pinned_gate_pos` on the socket/null arms — raw-offset behaviour byte-identical).
- [x] Adjacent suites: `test_band_depth`, `test_band_flavors`, `test_hub_contract`, `test_band_routing`, `test_app_router`, `test_rg1_loop_verify` — all OK.
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] Definition of done met: "test_scatter_materialise green (M1–M9) across the seed matrix; all FOUR control fingerprints byte-identical; every existing suite green unmodified; import + smoke green; component-driven scatter dive proven headlessly by M5+M7; worklog with the headline cost ledger naming commit SHA(s) + deviations" — all bullets above.

## Design deviations
1. **Minor, in M6's spirit-strengthening direction:** M6(b) additionally asserts
   `|T| == |floor|` alongside single-component — the explicit belt on RD-U1-2's "T == the
   floor set" claim (T ⊆ floor holds by construction; (a) gives the other inclusion; the size
   check makes the equality a direct assertion). Zero flakiness cost, tightens the tripwire.
2. **Minor, in M9's spirit:** M9(a) also pins the socket arm's RAW-offset return value from
   inside this suite (`_pinned_gate_pos == spawn_pos + GATE_SPAWN_OFFSET` on a greybox
   profile) in addition to the spec's cave guard-arm check — a 3-line byte-identity pin on
   the flipped guard's socket arm, complementing the external `test_exit_placement` proof.
3. **Noted, not changed (RD-U1-4 scoping):** the `_exit_candidate_cells` comment ("Exclude
   the SNAPPED pinned cell on caves…") also names the old arms but is NOT one of RD-U1-4's
   two listed call-site comments — left for the post-UG3 hygiene pass holding the other
   wording cleanups (still literally true, just cave-only in phrasing).
Otherwise none — RD-U1-0…RD-U1-8 followed as written; ledger = 1 exactly as ratified.

## Handoffs / follow-ups
- **U3 (band_four authoring):** the materialisation path is certified end-to-end at schema
  defaults; author `band_four.tres` against `ScatterBandConfig` (RD-12 sanity numbers in
  U0's worklog). No fixture `.tres` was created here — no collision.
- **UG2:** telemetry reading notes stand as ratified (RD-U1-6): `corridor_frac = 0` +
  R4 junction-degree inflation on scatter are definitionally correct; one bundled
  analysis-plan line covers all four bands.
- **Post-UG3 hygiene pass:** `_materialise_band`/`_build_synthetic_piece` "cave-backend"
  wording + the `_exit_candidate_cells` comment (deviation 3) + the SocketSealer rename
  (T1 OQ-7) — all deferred there per RD-U1-4.
