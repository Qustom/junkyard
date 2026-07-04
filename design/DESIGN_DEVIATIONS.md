# Design Deviations Log (active working set)

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale.
The orchestrator and each dispatched subagent append here whenever a task departs from spec.

**Lifecycle (`CLAUDE.md` → "Wave close-out — deviation assessment"):** this file holds
deviations **awaiting the Director's evaluation**. After each wave, the Director dispositions every
entry **Reviewed** or **Addressed** (Claude only recommends — it never self-dispositions). Per the
verdict, Claude reapplies to the design (usually `design/M1_Tasks/M1_As_Built.md` or
`M1_Design_Decisions.md`), then **moves the entry to `DESIGN_DEVIATIONS_HISTORY.md`**. Between
fully-evaluated waves this file is ideally empty.

Format: `[date] <id/area> — what changed vs. the doc · why · Claude's recommendation`

---

*Last close-out: **M1.9 Wave 2** (2026-07-03) — 8 entries (S2×4 + S5×4): **7 Reviewed + 1 Addressed**
(run-clock seam → typed injected Callable, fixed at close-out) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.9 Wave 1** (2026-07-02) — 2 entries: 1 Reviewed + 1 Addressed. **M1.8** (2026-07-02) — 17 entries:
15 Reviewed + 2 Addressed (verdict record `design/M1_8_Tasks/G4_findings_M1.8.md`).*
*Prior close-outs: M1.6 Wave 2 (3 Reviewed), M1.5 (2), M1.4 Wave 5 (3), Wave 3 (1 Addressed), Wave 1 (2+1) — all in
`DESIGN_DEVIATIONS_HISTORY.md`.*

---

*Last close-out: **M1.9 Wave 3** (2026-07-03) — 5 entries (S3): **4 Reviewed + 1 Addressed**
(param_overrides stamp → flat dotted rows, fixed at close-out) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.9 Wave 2** (2026-07-03) — 8 entries: 7 Reviewed + 1 Addressed. **Wave 1** (2026-07-02) — 2 entries.
**M1.8** (2026-07-02) — 17 entries: 15 Reviewed + 2 Addressed (`design/M1_8_Tasks/G4_findings_M1.8.md`).*
*Prior close-outs: M1.6 Wave 2 (3), M1.5 (2), M1.4 (2+1+3) — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---
[2026-07-03] S4/tests — §8.3.4's "0 / 4 / 6+ defs" matrix shipped as 0-defs fixture + COUNT-AGNOSTIC assertions (no 6-def fixture) · the Wave-4 dispatch brief explicitly requires the test be "count-agnostic or 4-based, NOT hardcoded 6" (S4 runs parallel to S6a/S6b, so the live def count changes mid-wave); every S4 assertion keys off `menu._defs`, and the 6-def case is proven for free the moment S6a/S6b land (plus their own "menu section auto-appears" acceptance) · **Recommend: Reviewed** — the brief supersedes the older fixture sketch; no coverage lost.

[2026-07-03] S4/config_menu — def trap tokens render RAW (`<id>:<param_key>` / `<id>:neutral_card`) in the CFG warn line, not per-trap CSV strings · the legacy traps use hand-authored `CFG_TRAP_<ID>` keys, but a per-def-per-param CSV key-space is unbounded and def-coupled — every new def would need a UI-file edit, quietly breaking "content is data" (the same reasoning as §3.3a's gloss fallback) · **Recommend: Reviewed** — raw tokens are debug-surface strings for the Director; revisit only if the warn line ever ships player-facing.

[2026-07-03] S4/opposition_lint — the Wave-3 close-out "consider a neutral-card trap" flag RESOLVED TO YES: `inert_enabled_defs()` emits `<id>:neutral_card` when an enabled def's effective spawn card is fully neutral (base_count<=0 AND count_per_depth<=0 → the deck lane can never place it) · S2 authored every card neutral, so enable-alone spawns zero — the exact "enabled but silently inert" shape BUG6 exists to catch; without it the pursuer def (no card params at all) reads ENABLED yet never appears · **Recommend: Reviewed** — warn-only, stamps beside the legacy list, all-off stays [].

[2026-07-03] S4/config_menu — the fold toggles use literal "▸"/"▾" glyphs as Button text, not tr() keys · they are pictographic state symbols (like the "⚠" embedded in the trap-warn string), not language strings; a CSV row per glyph adds translation surface for zero localizable content · **Recommend: Reviewed** — swap to tr'd strings only if localization ever wants directional-glyph overrides.

[2026-07-03] S4/respawn — tier-v1 respawn ctx carries `{params, depth, run_t_ms}` only — NOT the legacy per-kind ctx vocabulary (initial_dir / room_bounds / phase_salt) or room_key, which the registry does not record · the spec's §3.7 sketch respawns via `svc.spawn(def, same_cell, ctx)` with merged params; reconstructing the per-piece legacy ctx would need piece lookup the menu deliberately doesn't have (policy stays in the builder). A respawned legacy entity falls back to its ctx defaults (e.g. a pingpong loses its authored room_bounds until the next run) — acceptable for a DEBUG action whose run is already marked dirty · **Recommend: Reviewed** — note for the post-gate live-edit tiers (read-through defs would moot it).
