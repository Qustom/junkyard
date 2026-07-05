# Worklog — T1 Cave materialisation + backend-agnostic sealing + downstream verify

- **Date:** 2026-07-05
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.10 (Wave 2 — T1 alone, the version's sole `main_game.gd` writer)
- **Branch:** worktree-agent-a8674f391474e6160
- **Commit:** c6f58424b4016fe6cc209c0b789a5f84ef2814be (feature commit; this SHA recorded in the follow-up worklog commit)

## What changed
Made a T0-generated cave *playable*. `_materialise_band` now builds a runtime greybox
instance for each synthetic (cave) piece — a `ZonePiece` host + generated `Geometry`
`TileMapLayer` written with **FLOOR tiles only** — and assigns it to `p.instance`
**before** the seal, so the **unedited `SocketSealer` runs verbatim** and writes the entire
WALL shell (1-tile shell over darkness, D-RAT-8). The pinned/near-spawn gate now
snaps-to-nearest-floor on cave bands (D-RAT-7) at its 3 call sites, guarded on
`backend == "cave"` so the socket path is byte-untouched. Entry spawn reads T0's
`floor_cells[0]` anchor and `palette_tint` rides the container modulate — both free.
Socket bands never enter the new branch (the generator always instantiates a scene, so
`p.instance != null`), so socket materialisation is byte-identical by construction.

## Files touched
- `Game/scenes/game/main_game.gd` — the `_materialise_band` null-branch (build synthetic
  instance); new `_build_synthetic_piece` helper; new `_pinned_gate_pos` helper + 3
  `_place_gate`/`_exit_candidate_cells` call-site swaps; one lazy `GREYBOX_TILESET_PATH`
  const. **The only source file changed.**
- `Game/tests/test_cave_materialise.gd` (+ `.tscn`, `.uid`) — new headless SCENE test,
  M1–M9, cave profile built in-code off `CaveBandConfig.new()` schema defaults (OQ-6).

**NOT touched (per spec):** `systems/bandgen/*` (incl. `socket_sealer.gd` — the whole
point), `band_pipeline.gd`/`band_profile.gd`/`cave_*.gd` (T0's), `data/run_config/*`,
`entities/*`, any committed golden/fixture.

## Bespoke-code ledger (TG3 evidence — non-data, non-test lines added)
All in `main_game.gd`: **39 non-comment/non-blank code lines total** (75 insertions incl.
comments; 4 deletions). Breakdown:
- Synthetic-instance builder `_build_synthetic_piece` (the "materialisation contract
  reused" proof): **~15 lines**.
- Cave-safe gate `_pinned_gate_pos` (snap-to-nearest-floor, deterministic): **~15 lines**.
- `_materialise_band` null-branch (build-then-fall-through): **~3 lines** (1 real new
  statement on the piece walk + 1 defensive guard).
- 3 gate call-site swaps + 1 lazy tileset const: **~4 lines**.

The materialisation contract was genuinely backend-agnostic: **zero** socket-path files
changed, and the whole cave-playable path cost ~39 lines against the spec's ~76-line
estimate (shell-only sealing, §2.3, kept `_build_synthetic_piece` lean). The unedited
`SocketSealer` becomes the single wall-writer for both backends — the b3 "tile-world vs
piece-world" flag closed: the cave stays a piece-world citizen, its pieces born at runtime.

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse/SCRIPT errors; pre-existing
      `*.en.translation` load warnings are unrelated CSV-regeneration noise).
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → **SMOKE OK**.
- [x] `test_cave_materialise` **M1–M9 green** across the 9-seed matrix (~3.2 s): closure
      (`_count_floor_facing_void == 0`), collision truth (WALL atlas + `direct_space_state`
      point query hits wall / misses floor, after a physics-frame await), determinism
      (fp + floor_fp byte-equal pre/post materialise), anchors (spawn=`floor_cells[0]`,
      2×2-open, `max_depth >= 4`, deepest==max_depth), snapped gate on floor + reachable,
      2×2-open spawn→gate throat cert, JunkPlacer+EncounterBuilder land on floor at
      depth>0, tint applied, socket control (0 synthetic hosts, N children).
- [x] **Socket byte-identity + all-off fp:** `test_band_pipeline_parity` →
      `fp=e943ac9c8bc1` (all-off UNMOVED); `test_bandgen_determinism` →
      `fp=e943ac9c8bc1`; `test_band_two_profile` OK; `test_cave_backend` OK;
      `test_hub_contract` OK; `test_band_routing` OK; `test_rg1_m12/13/14/15_verify` all
      exit 0. All suites green **unmodified**.
- [x] Definition of done met: "a cave-profile dive runs headlessly end-to-end (generate →
      materialise → junk + gate + spawns placed on FLOOR); socket-band materialisation
      byte-identical; all-off fp unmoved; `test_cave_materialise` M1–M9 green; import +
      smoke green." All satisfied.

## Design deviations
**none.** Built exactly to the Resolved Decisions (Phase 3): shell-only sealer WALL shell
(D-RAT-8), snap-to-nearest-floor pinned gate (D-RAT-7), runtime `ZonePiece.new()` assembly
(OQ-5), in-code test profile off schema defaults (OQ-6), the settled T0/T1 sealing seam
(T1 writes FLOOR only; the unedited `SocketSealer` writes the WALL shell). `SocketSealer`
NOT edited. `_key_lt` not built — Godot 4 `Vector3i` `<` is lexicographic (Phase-3 minor
correction). No T0 contract gap found: T0's `cave_backend.gd` ships the west-most 2×2-open
front-positioned entry anchor (CT-2), `max_depth >= 4`, and the `carve_width=2` throat
floor — T1's M4/M6 pass on the default config with no T0 follow-up needed.

## Handoffs / follow-ups
- **M6 note (informational, not a red):** the 2×2-open spawn→gate certificate passes on all
  9 seeds at T0's default config — the throat protocol (CT-3) holds; no T0 widening
  follow-up triggered.
- **OQ-7 (deferred, per Phase-3):** `SocketSealer` is now the cave's wall-writer too — the
  "SocketSealer" misnomer is complete. Rename → `PerimeterSealer` + re-docstring is a
  post-TG3 hygiene task (deliberately deferred: this is the version whose bar is
  "socket-path files untouched").
- **OQ-8 (TG2 telemetry-reading note):** cave runs report `corridor_frac = 0` (synthetic
  `cave_<hash>` ids are never in `RunConfig.CORRIDOR_PIECE_IDS`) — definitionally correct;
  TG2's three-band comparison should read the zero as a definition, not a signal.
