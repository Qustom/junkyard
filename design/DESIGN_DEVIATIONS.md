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

## M1 — second wave (D1), 2026-06-15

- `[2026-06-15] D1 — integrated with the REAL GameState`, not the spec's idealized `banked_money`/`cash_out`/`start_run()` excerpt. Added only `run_inventory` (run-state) + its fresh-on-`start_run` / clear-on-`end_run`+death lifecycle; left `money`/`unbanked_value`/`bank_haul`/pockets untouched. Junk→value reconciliation is C2/E1/F1's. · Why: the excerpt was illustrative; the real autoload already enforces the run/meta boundary. · **Sign-off: not needed** (orchestrator-directed).
- `[2026-06-15] D1 — `max_slots` from an authored `InventoryConfig.tres`** (`base_max_slots = 12`), read once in `start_run()`. · Adopts the spec's own Open-question recommendation; keeps bag size designer-tunable. · **Sign-off: not needed.**
- `[2026-06-15] D1 — RunInventory emits via a SceneTree-resolved EventBus lookup` (`_emit_changed()` → `Engine.get_main_loop().root.get_node("EventBus")`) instead of the compile-time `EventBus` global. · Why: a `class_name` script loaded standalone in a `--script` test harness can't resolve autoload *names* as globals (the Node still exists in the tree), so a direct `EventBus.…emit()` fails to compile there though it's fine in the booted project. Same node at runtime; keeps the model unit-testable. Still signal-driven, no hard refs. Did NOT edit `event_bus.gd` (signal already on main). · **Sign-off: not needed** (implementation detail, on-spec behaviorally).
- `[2026-06-15] D1 — added `remove_at(index)` alongside `remove(item)`** and made `remove()` instance-identity-based. · Adopts the spec's Open-question recommendation (index-safe removal is D2's preferred path; `find()`-by-value alone was rejected). · **Sign-off: not needed.**
