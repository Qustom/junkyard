# Design Deviations Log

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale
and whether it needs human sign-off. The orchestrator appends here whenever a task is consumed
(`CLAUDE.md` → "Record"). Each subagent's per-task deviations land here too.

Format: `[date] <id/area> — what changed vs. the doc · why · sign-off?`

---

## M1 — first wave (A1, B1, C1), 2026-06-15

- `[2026-06-15] A1/B1/C1 — greybox placeholders stubbed inline` instead of dispatching the asset-role subagents (character-animator / environment-artist) or PixelLab. Player = a `ColorRect`; tiles = two flat-color tiles; junk = `greybox_color`+`greybox_shape` encoded in data. · Why: the specs mandate flat greybox ("ColorRect is fine", "two flat color tiles"), and live generation is human-gated (paid credits). · **Sign-off: not needed** — on-spec.
- `[2026-06-15] A1 — extracted a pure `step_velocity()` helper` not in the spec sketch, so movement is unit-testable headlessly. · Behavior byte-identical; structural only. · **Sign-off: not needed.**
- `[2026-06-15] B1 — fixed the spec's `opposite()` sketch` (`Dir[(int(d)+2)%4]` doesn't compile — the enum is a Dictionary) to `((int(d)+2)%4) as Dir`. Aligned geometry to A1's locked `world`=layer_2 and gave the debug pawn its own `pawn`=layer_6. · Why: spec sketch bug + keep the locked 1–5 layer map intact. · **Sign-off: not needed.**
- `[2026-06-15] C1 — engine_block authored at `slot_size = 6`** (spec sketch showed 4) to sharpen the bulky-ceiling carry choice (pins value/slot at 20). · Tunable in playtest. · **Sign-off: not needed** (a balance placeholder, not a design change).

### ⚠ Open follow-ups surfaced by M1 wave 1 (need a human/Director call)

- **`Item` vs `JunkItem` schema overlap.** `data/item.gd` (`class_name Item`, pre-existing generic content schema) and the new `data/junk/junk_item.gd` (`class_name JunkItem`) overlap heavily (id, display_name, slot_size, base_value/base_sell_value, needs_containment/containment_flags, origin_band). C1 was briefed NOT to touch `Item`. The sample `data/items/sample_junk.tres` is an `Item`, unrelated to the junk catalog. **Decision needed:** does `JunkItem` become canonical (retire/repurpose `Item`) or do the two merge? Saves/telemetry key off ids, so resolve before content volume grows. → Recommend a producer task post-wave-1.
- **Parallel-dispatch tooling.** Running 3 agents in one shared checkout caused `git switch` collisions: agents clobbered each other's untracked files, and C1's commit swept in stale copies of A1's player files (excluded during integration). **Process fix:** dispatch parallel agents with `isolation: worktree` (or serialize same-tree work). Adopted going forward.

## M1 — second wave (B2), 2026-06-15

- `[2026-06-15] B2 — RNG API adaptation` (orchestrator-directed). Spec pseudocode used `RNG.set_seed`/`RNG.weighted_pick`/`RNG.fork`; the real `systems/rng.gd` exposes `seed_from`/`randi`/`randi_range`/`randf`/`pick`. Implemented: one `RNG.seed_from(seed)` per attempt + a self-written INTEGER cumulative-weight pick (`ZonePieceData.weight` scaled ×1000 to ints) rolled against `RNG.randi_range(0,total-1)`. Keeps all branch-affecting decisions on integer math for cross-build determinism. · **Sign-off: not needed** (orchestrator-directed; behavior matches spec intent).
- `[2026-06-15] B2 — flush-edge socket alignment` instead of the spec's raw seam formula `cand_cell == sock_cell + dir`. B1's greybox pieces are solid-walled rects with openings at the EDGE and the socket marker one cell IN, so the raw formula double-counts the inset and overlaps mated pieces by two columns. `_alignment_offset` places the candidate flush against the host footprint edge (facing axis) and aligns socket lanes (perpendicular axis), pure integer-cell. · Adaptation to B1's actual geometry, not a design change. · **Sign-off: not needed.**
- `[2026-06-15] B2 — connectivity = FLOOR-cell adjacency` (TileSet atlas (0,0)), not whole-footprint adjacency, so "connected AND walkable" is a true traversability guarantee (a shared perimeter wall does not count as a link). · **Sign-off: not needed.**
- `[2026-06-15] B2 — acceptance test runs as a headless scene` (`tests/test_bandgen_determinism.tscn`), not a `--script` SceneTree harness, because `--script` mode does not register the `EventBus`/`RNG` autoload globals at compile time and the generator (correctly) uses the global form like `game_state.gd`. · **Sign-off: not needed.**
