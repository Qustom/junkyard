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
