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

## M1.9 Wave 4 — active (awaiting Director disposition)

- **[2026-07-03] S7 / band_two deck ships 4 entries, not 6** — spec S7 §6 DoD item 4 says
  `opposition_deck.size() == 6`; in this file-disjoint worktree `charger.tres`/`splitter.tres`
  (S6a/S6b) do not exist, so `band_two.tres` ships the 4 shipped defs (`pursuer`/`pingpong`/`bomb`/
  `spike`) and the two band-2 predators are appended at the S8/SG1 merge integration (the exact
  two-line diff is recorded in the S7 worklog). **Why:** an ExtResource to a nonexistent file fails
  the whole resource load, breaking band_two's own contract test — degrading gracefully to 4 is the
  brief's "author rows that degrade gracefully in YOUR worktree + flag the integration check."
  **Claude's recommendation: Reviewed** — this is the anticipated parallel-merge state, not a design
  change; the deck completes to 6 (with the correct order `[pursuer, pingpong, bomb, spike, charger,
  splitter]` and `min_band=2` gating on the two predators) at S8/SG1. No design edit needed.

- **[2026-07-03] S7 / tint-only visual identity, no retoned tileset** — spec S7 §4 offered a Tier-2
  retoned `greybox_band_two.tres` tileset + a `tileset` BandProfile field; per **D-RAT-4** (art
  budget = tint-only, no PixelLab, `tileset` field deferred), `band_two.tres` ships only
  `palette_tint = Color(0.82, 0.66, 0.42, 1)` (sepia-amber Sump) and no tileset file/field.
  **Claude's recommendation: Reviewed** — this is the Director's ratified call (D-RAT-4), recorded
  here only for the wave-4 audit trail; the design already matches (no reapply needed).

---
- [2026-07-03] **ORCH/Wave-4 integration — D-RAT-2's Charger "deck `param_override → false`" has NO
  data mechanism in the as-built deck.** S7's binding Resolved Decisions made `opposition_deck` a
  plain ordered array of def references ("tunables live ON the defs, not a deck-entry wrapper"), and
  `test_charger` pins the def defaults to D-RAT-2's letter (`throwable_while_charging=true`,
  `wall_crash_recover_mult=1.0`). So the ratified band-two values (dash-invulnerable, crash-stun ≈2.0)
  currently apply NOWHERE. The only as-built override channel is `rc.param_overrides` (ctx-merge,
  S3/S4). · Integration completed the deck 4→6 with plain refs per S7's Resolved Decisions; def
  defaults untouched. · **Recommendation: Addressed via the playtest preset** — have SG1's default
  play preset stage `param_overrides = {"charger": {"throwable_while_charging": false,
  "wall_crash_recover_mult": 2.0}}` (charger is band-2-exclusive, so this is exactly "the band_two
  feel" at the gate; def defaults stay D-RAT-2-letter and menu-sweepable; zero new mechanism).
  Alternative: a deck-entry override wrapper (new mechanism — post-gate scope).


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
[2026-07-03] S6a/D1 — **Host shell beyond the spec's file list.** S6a spec §0 names the new files as
`charger.tres` + `charger.tscn` + `charge_lane.gd` + tests; the build also needed
`charger_hazard.gd` — the per-entity Actor-host shell (family guard, self-timed run clock, fixed
component acquire/tick order, tell constants, S0-vocabulary emit sites, `get_def_id`/
`resolve_throw_death` seams). Why: the S2 component contract is host-ticked with host-owned
presentation/emit sites, and every shipped hazard carries exactly this shell — a `.tscn` root needs
a script to implement the locked `setup(cfg, player, spawn_ctx)` handshake. The "def + ONE new
component" proof holds for *behavior* (ChargeLane is the only new behavior script; LethalContact's
`&"external"` seam pre-existed, so zero shared-file edits) — this is the honest measured cost per
OQ-1's SG3 watch-item. · **Recommendation: Reviewed** — record the shell as part of the Actor-host
pattern's per-entity cost in the M1.9 as-built; no design change.
[2026-07-03] S6a/D2 — **`kills` promoted into `params` + `param_schema`** (13th row, bool, default
`true`) instead of the typed-field-only shape in spec §2.1. Why: the Charger has no RunConfig
`*_kills` knob (deck-driven lane), and the entity reads its knob bag from `spawn_ctx["params"]` —
putting the L5 gate in params makes it sweepable via `rc.param_overrides` and auto-surfaced by S4's
generated menu, exactly like the legacy `*_kills` toggles. The typed `OppositionDef.kills` field is
kept in agreement (`true`). · **Recommendation: Reviewed** — adopt "new-def L5 gates live in params"
as the standing convention for deck-driven defs (S6b's Splitter should match).
[2026-07-03] S6a/D3 — **Spawn-card params `base_count = 1` / `count_per_depth = 0.0` added** to
`charger.tres` (spec §2.1's params sketch omitted them). Why: the S3 deck lane's counts read
`d.params["base_count"]` (breakdown amendment 10) — without a card the Charger could never spawn
from band_two's deck. Authored `1`/`0.0` = one Wrecker per eligible room, bounded by per_room 1 /
per_band 4 / cost 2 against floor(24×1.15)=27 credits → 4 per band at defaults. Unlike the legacy
defs (whose cards mirror the all-off rc defaults = 0), the charger's authored value IS its live
default — the all-off guarantee is unaffected because the def only loads when a deck/lever lists it.
· **Recommendation: Reviewed** — this is the intended deck-lane authoring shape; fold into the S6a
spec's §2.1 at reapply.
[2026-07-03] S6a/D4 — **Menu gloss CSV rows deferred.** The 13 schema rows carry
`CFG_FIELD_CHARGER_*` gloss keys per the house convention, but `ui/config/config_strings.csv` was
NOT edited: S4 (parallel, same wave) owns the `ui/config/` surface and S6b will need its own rows —
editing the shared CSV from three worktrees invites conflicts. Until the rows land, S4's generated
Charger section would render raw keys. · **Recommendation: Addressed at integration** — one-line
task for the Wave-4 merge: append the 13 charger (+ splitter) gloss rows to `config_strings.csv`.

## M1.9 Wave 4 — S4 (generated menu) — awaiting Director evaluation

[2026-07-03] S4/tests — §8.3.4's "0 / 4 / 6+ defs" matrix shipped as 0-defs fixture + COUNT-AGNOSTIC assertions (no 6-def fixture) · the Wave-4 dispatch brief explicitly requires the test be "count-agnostic or 4-based, NOT hardcoded 6" (S4 runs parallel to S6a/S6b, so the live def count changes mid-wave); every S4 assertion keys off `menu._defs`, and the 6-def case is proven for free the moment S6a/S6b land (plus their own "menu section auto-appears" acceptance) · **Recommend: Reviewed** — the brief supersedes the older fixture sketch; no coverage lost.

[2026-07-03] S4/config_menu — def trap tokens render RAW (`<id>:<param_key>` / `<id>:neutral_card`) in the CFG warn line, not per-trap CSV strings · the legacy traps use hand-authored `CFG_TRAP_<ID>` keys, but a per-def-per-param CSV key-space is unbounded and def-coupled — every new def would need a UI-file edit, quietly breaking "content is data" (the same reasoning as §3.3a's gloss fallback) · **Recommend: Reviewed** — raw tokens are debug-surface strings for the Director; revisit only if the warn line ever ships player-facing.

[2026-07-03] S4/opposition_lint — the Wave-3 close-out "consider a neutral-card trap" flag RESOLVED TO YES: `inert_enabled_defs()` emits `<id>:neutral_card` when an enabled def's effective spawn card is fully neutral (base_count<=0 AND count_per_depth<=0 → the deck lane can never place it) · S2 authored every card neutral, so enable-alone spawns zero — the exact "enabled but silently inert" shape BUG6 exists to catch; without it the pursuer def (no card params at all) reads ENABLED yet never appears · **Recommend: Reviewed** — warn-only, stamps beside the legacy list, all-off stays [].

[2026-07-03] S4/config_menu — the fold toggles use literal "▸"/"▾" glyphs as Button text, not tr() keys · they are pictographic state symbols (like the "⚠" embedded in the trap-warn string), not language strings; a CSV row per glyph adds translation surface for zero localizable content · **Recommend: Reviewed** — swap to tr'd strings only if localization ever wants directional-glyph overrides.

[2026-07-03] S4/respawn — tier-v1 respawn ctx carries `{params, depth, run_t_ms}` only — NOT the legacy per-kind ctx vocabulary (initial_dir / room_bounds / phase_salt) or room_key, which the registry does not record · the spec's §3.7 sketch respawns via `svc.spawn(def, same_cell, ctx)` with merged params; reconstructing the per-piece legacy ctx would need piece lookup the menu deliberately doesn't have (policy stays in the builder). A respawned legacy entity falls back to its ctx defaults (e.g. a pingpong loses its authored room_bounds until the next run) — acceptable for a DEBUG action whose run is already marked dirty · **Recommend: Reviewed** — note for the post-gate live-edit tiers (read-through defs would moot it).