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
## M1.9 Wave 4 — S6b (Splitter) — awaiting Director evaluation

- **[2026-07-03] S6b/host-scene — TWO host scenes, not one shared scene.** Spec §2.2 says both defs
  share `splitter.tscn`; as built `splitter_child.tscn` is a 3-line variant of the parent scene
  (same `splitter.gd`, exported `def_id = &"splitter_child"` + smaller/brighter greybox exports).
  · Why: the def-schema host contract (`test_opposition_def_schema` check 4) requires a BARE
  instance of `def.host_scene` to report `get_def_id() == def.id` — a single shared scene cannot
  satisfy both ids without setup-time ctx, which a bare instance never gets. The "child is a
  parametrized splitter" intent holds (one script, scene-authored identity).
  · **Recommendation: Reviewed** (contract-forced; zero behavioral surface).
- **[2026-07-03] S6b/spawn-card — `base_count`/`count_per_depth` added to both defs' params+schema
  (not in the spec §2.1/§2.2 tables).** Parent: 1 / 0.0; child: 0 / 0.0 (neutral — never deck-drawn).
  · Why: S3's deck lane (breakdown amendment 10) reads per-def spawn counts off
  `params["base_count"]`/`["count_per_depth"]`; without them the parent could never spawn from
  band_two's deck. · **Recommendation: Reviewed** (required by the as-built S3 contract; S7's deck
  authoring should assume 1-per-eligible-piece and tune via `param_overrides`).
- **[2026-07-03] S6b/trap-flag — NO `trap_if_neutral` flag on either splitter def.** The S2 norm
  ("exactly one per def, on the mechanism-critical magnitude") is enforced by the committed test only
  for the four legacy ids. · Why: every zero magnitude on the Splitter is a DESIGNED control per the
  spec's own gloss table (`move_speed 0` = stationary tell, `catch_radius 0` = pure obstacle,
  `child_count 0` = clean-kill sweep) — flagging one as a trap would mislabel a legitimate sweep
  variant. · **Recommendation: Reviewed**; if the Director wants a flag anyway, `catch_radius` is
  the least-wrong candidate (a task-sized edit).
- **[2026-07-03] S6b/kills-override — the L5 gate reads the def's typed `kills` field with a
  per-instance `ctx["kills"]` override tier.** New defs have no legacy `*_kills` RunConfig knob, so
  the def field is the gate source (per S0 §5); the ctx override is the harness/sweep tier the
  acceptance criterion 5 (kills=false catch does not end the run) is proven through.
  · **Recommendation: Reviewed** (consistent with the v2 per-instance ctx tier; documented in the host).
- **[2026-07-03] S6b/child-cells — no "nearest free graded-floor cell" snapping (Q9's ideal).**
  Child cells = deterministic ring offsets snapped by `svc.world_to_cell`; the service validates
  (entry-safety + caps) and a refused/invalid cell simply drops that shard (§2.5 no-retry). A ring
  cell inside a wall yields a walled shard (CharacterBody2D vs `world` — it stays put).
  · Why: the service exposes no floor-cell/occupancy query mid-run; adding one is an S0 surface
  change outside S6b's write scope. Greybox-acceptable ("refuge is a feature").
  · **Recommendation: Reviewed**, with a noted follow-up IF SG2 playtests show walled shards
  reading badly: add a floor-cell query to SpawnService (a small S0-owned task).
- **[2026-07-03] S6b/glosses — `CFG_GLOSS_SPLITTER_*` CSV rows NOT added.** The schema rows
  reference 10 gloss keys, but `Game/ui/config/config_strings.csv` is S4's Wave-4 surface (the
  generated-menu net); writing it from the S6b worktree risks clobbering S4's parallel edit.
  · **Recommendation: Reviewed** + integration handoff: add the splitter gloss strings to the CSV
  at S4/S8 merge time (S4's menu falls back to the raw key until then).
