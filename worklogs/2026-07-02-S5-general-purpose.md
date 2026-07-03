# Worklog — S5 Band flavor stages: SetPieceInject + WearDecay + Stage-5 connectivity guarantee

- **Date:** 2026-07-02
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.9 (Wave 2, band migration Phase B — parallel worktree, ∥ S2)
- **Branch:** general-purpose/S5
- **Commit:** 0aa085c (implementation; this worklog follows in a docs commit on the same branch)

## What changed
Built per `design/M1_9_Tasks/S5_flavor_stages_connectivity.md` (§10 Resolved Decisions binding).
The two flavor stages + the connectivity invariant land as small `RefCounted` stages operating on
the post-assembly `Band` (§10 Q1), wired into S1's marked `# STAGE HOOK (S5)` slot in
`BandPipeline.generate` — replacing the pre-S5 stage-bearing guard with the real loop.
**Empty `flavors` runs zero flavor code**: the control path is literally the S1 parity path
(all-off fp `e943ac9c8bc1` unmoved, verified). Per-stage sub-seeds =
`hash_combine(hash_combine(resolved_seed, cfg.salt), array_index)` on LOCAL
`RandomNumberGenerator`s (the JunkPlacer pattern) — no stage touches the RNG autoload.
- **SetPieceInjectStage** (`mutates_pieces`): ATTACH at a depth-gated retained open socket via the
  untouched grow-loop helpers (`_read_piece`/`_find_mate_socket`/`_alignment_offset`/`band.fits`/
  `_make_placed`) — §10 Q3. Pool = `SetPieceEntry`/`SetPieceInjectConfig` resources (never the base
  catalog — §10 Q2, control-safe by construction). Layout-affecting: moves `fingerprint()`
  deterministically; the control layout stays a strict prefix (tested). Caps/unique/depth-gate per
  e4; graceful skip-and-log; anchors (`entry_piece`/`deepest_piece`) never reassigned. Tests use
  `piece_box_large` as the vault (D-RAT-3: reuse an existing large piece, no new art).
- **WearDecayStage** (`reshapes_floor`): breach pass hardcoded BEFORE block pass (§4.2 — the tree
  bands make every doorway a bridge; breach-led decay). Breaches = `breach_width` (default 2, §10
  Q9) colinear wall-cell pairs across the 2-thick seam → FLOOR; blocks = every i-side doorway seam
  cell → WALL, tentative with inline reject-on-disconnect. Every committed op journaled
  (`{kind, writes:[{piece, cell, prior}]}`). `state` param (`&"collapsed"`/`&"flooded"` — D-RAT-1)
  keys the greybox modulate tint on decay-touched pieces (§10 Q5). Tree-gated `push_warning` for
  block-only configs (§10 C2).
- **ConnectivityGuarantee**: cell-level flood-fill from the entry's (y,x)-first floor cell (§10
  Q8), run by the pipeline after EVERY stage off the traits (§10 Q7): ASSERT after pure-socket
  stages (push_error, never crash), CARVE after floor-reshaping ones (deterministic LIFO journal
  revert until coverage restores).
- **`Band.floor_fingerprint()`** (additive, §6.1): the wear-aware supplementary determinism bar,
  with the §10 A1 guardrail docstring (NOT the control bar; computed from pre-seal `floor_cells`;
  asserted only in the flavor test). `fingerprint()` untouched.

## Files touched
- `Game/systems/bandgen/stages/band_flavor_stage.gd` (+`.uid`) — stage contract base (traits as methods).
- `Game/systems/bandgen/stages/set_piece_inject.gd` (+`.uid`) — attach-at-socket injection (spec §3).
- `Game/systems/bandgen/stages/wear_decay.gd` (+`.uid`) — breach/block decay + journal + tint (spec §4).
- `Game/systems/bandgen/stages/connectivity_guarantee.gd` (+`.uid`) — Stage-5 invariant (spec §5).
- `Game/data/bands/flavors/set_piece_entry.gd`, `set_piece_inject_config.gd`, `wear_decay_config.gd`
  (+`.uid`s) — the authored config Resource surface (spec §2.2/§3.1/§4.1).
- `Game/systems/bandgen/band_pipeline.gd` — stage hook replaced with the flavor loop + provisional
  grade + connectivity interleave + `_stage_seed` mix; principles / unknown-flavor-config fail-loud
  guards (S5 = sole Wave-2 writer of this file).
- `Game/systems/bandgen/band.gd` — additive `floor_fingerprint()` only.
- `Game/tests/test_band_flavors.gd` / `.tscn` (+`.uid`) — F1–F8 per spec §6.2.
- `design/DESIGN_DEVIATIONS.md` — 4 entries (below).

## Checks run
- [x] `godot --headless --path Game --import` clean (no parse errors)
- [x] `godot --headless --path Game --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [x] `res://tests/test_band_flavors.tscn` → exit 0 — "BAND FLAVORS OK … across 9 seeds".
      F1 control unmoved (empty-flavors pipeline fp == direct fp per seed, flavor plumbing present);
      F2 inject double-run determinism + strict-prefix + cap ≤ max_total + injected id + host depth
      gate + `min_depth_norm = 1.1` injects nothing + non-vacuous (injections occurred);
      F3 decay `floor_fingerprint()` deterministic twice + `fingerprint()` byte-equals control
      (off-fingerprint asserted, not assumed) + floor-fp variation across seeds;
      F4 strand-proof: `decay_level = 1.0`, budgets 8/8 across the full seed matrix → cell-level
      fully connected, no unreachable-depth sentinel, deepest_piece reachable, non-vacuous;
      F5 tree fact pinned behind its explicit precondition (edges == n−1, §10 C2) → zero committed
      block ops + floor-fp == control on block-only decay;
      F6 CARVE unit test: hand-blocked doorway (bypassing the inline reject) disconnects →
      `enforce(CARVE, journal)` reconnects, tiles + floor_cells restored, journal drained;
      F7 `[SetPieceInject, WearDecay]` composition deterministic (fp + floor-fp twice), injected,
      connected; F8 two WearDecay entries → index-mixed sub-streams provably distinct.
- [x] `res://tests/test_band_pipeline_parity.tscn` → exit 0 **UNMODIFIED** — "PIPELINE PARITY OK …
      (sample seed 12345 -> 12 pieces, fp=e943ac9c8bc1)" — P7's stage-bearing-profile guard still
      green against the new fail-loud validation.
- [x] `res://tests/test_bandgen_determinism.tscn` → exit 0 (BANDGEN OK / BUG3 / R4 / BUG4 all OK;
      file untouched). All-off fingerprint **e943ac9c8bc1 unmoved**.
- [x] `res://tests/test_band_depth.tscn` → exit 0 (BAND DEPTH OK).
- [x] `res://tests/test_level_scale_determinism.tscn` → exit 0 (LVL OK).
- [x] `res://tests/test_corridor_lever.tscn` → exit 0 (J4 OK). `res://tests/test_exit_placement.tscn`
      → exit 0 (K7 OK).
- [x] Scope audit: `git status` shows only `Game/systems/bandgen/` (pipeline + band.gd + new
      `stages/`), `Game/data/bands/flavors/`, `Game/tests/test_band_flavors.*`, this worklog and
      `design/DESIGN_DEVIATIONS.md`. `main_game.gd` / `event_bus.gd` / `game_state.gd` /
      `run_config.gd` / `band_generator.gd` / `socket_sealer.gd` / `depth_grader.gd` /
      `junk_placer.gd` / `systems/spawning/` / `data/oppositions/` all untouched.
- [x] Definition of done met (spec §8): control intact (fp `e943ac9c8bc1` + parity green
      unmodified); each stage deterministic on local sub-streams (zero RNG-autoload calls in any
      stage — code-audited + F1 proves it behaviorally); WearDecay cannot strand (F4 + F6);
      SetPieceInject proves the socket ride with an existing greybox piece, skip path exercised;
      worklog + deviations recorded.

## Design deviations
(All four also appended to `design/DESIGN_DEVIATIONS.md` with recommendations.)
1. **Attach-at-open-socket, not e4's swap lean** — pre-ratified §10 Q3, recorded per DoD §8.6.
   Set-pieces are dead-end detours appended at retained open sockets; swap deferred unless S7's
   playtest says detour-vaults read as skippable. Recommend **Reviewed**.
2. **Breach-led decay headline (§4.2/§10 Q4)** — on the as-built tree bands blocks only land behind
   breaches; M1.9 decay is shortcut-led. Pinned by test F5 behind its explicit tree precondition.
   **Director must see this at close-out (non-blocking)**. Recommend **Reviewed** (do not pull
   `loop_back_count` forward — out of the §0 guardrails).
3. **Unknown flavor config = fail-loud `null`, not spec §2.2's "skip and still generate"** — §2.2
   is unsatisfiable alongside S1's P7 parity assertion (`flavors = [Resource.new()]` → null) and
   the "parity green UNMODIFIED" DoD; fail-loud is also the stricter control-safety posture.
   Recommend **Reviewed** + amend §2.2 at reapply.
4. **Stage traits as overridable methods, not consts** — GDScript cannot shadow a base-class const;
   `mutates_pieces()`/`reshapes_floor()`/`journal()` carry the identical pipeline-enforced
   contract. Mechanical translation. Recommend **Reviewed**.

## Handoffs / follow-ups
- **S3 (Wave 3):** nothing to rewire for S5 — the flavor loop is inside `BandPipeline.generate`,
  upstream of the S3 call-site switch; materialisation seal stays where it is (§10 C1).
- **S7 (Wave 4):** authors `band_two`'s `SetPieceInjectConfig`/`WearDecayConfig` `.tres` against
  the canonical §3.1/§4.1 schema (A2 mapping table): one `SetPieceEntry` wrapping the chosen
  existing large piece, `min_depth_norm 0.6`, `decay_level 0.25`, `state = &"flooded"` (D-RAT-1),
  budgets/width/salts at defaults. `Band.floor_fingerprint()` is S7's "connectivity green through
  WearDecay" handle. Note: width-2 breach runs are scarce on greybox bands (≈0–2 per band; they
  exist only on room-room seams with interior floor in-line on both sides) — at `decay_level 0.25`
  × `breach_budget 2` expect ≤1 breach per band; tune budgets, not width, if The Sump needs more
  ruin.
- **SG2 watch-item (Q5):** breach legibility — does a modulate-tinted breach read as passable
  without a dedicated tile? S7's Tier-2 accent tile is the follow-up if the playtest flags it.
