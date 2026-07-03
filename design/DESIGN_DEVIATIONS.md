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

*Last close-out: **M1.8** (2026-07-02) — 17 entries (PLAYERTAB + H0/H1 + H2 + H4): **15 Reviewed + 2 Addressed**
(PLAYERTAB per-action locks; H2 front-facade shack) — reapplied + archived to `DESIGN_DEVIATIONS_HISTORY.md`.
Verdict record: `design/M1_8_Tasks/G4_findings_M1.8.md`.*
*Prior close-outs: M1.6 Wave 2 (3 Reviewed), M1.5 (2), M1.4 Wave 5 (3), Wave 3 (1 Addressed), Wave 1 (2+1) — all in
`DESIGN_DEVIATIONS_HISTORY.md`.*

---

- `[2026-07-02] S0/SpawnService — cap-group accounting is live-registry-derived, not the
  monotonic {ceiling, count} counter sketched in S0 spec §6.1's illustrative pseudocode` ·
  Counts are computed from the validity-swept live registry so spawn/despawn/free stay
  coherent with `live_count()` (one source of truth); a node freed mid-run therefore
  re-opens cap headroom for mid-run clients (S6b+). Never observable in Phase A (nothing
  spawns mid-run; the policy `min()` binds first) — all fingerprints/positions verified
  byte-identical. · **Recommendation: Reviewed** (mechanism-internal; "hard caps bound
  live nodes" is arguably the truer reading of the breakdown's cap contract).
- `[2026-07-02] S0/SpawnService — untyped locals in _compact()/clear_all()` · Assigning an
  already-freed instance to a typed `Node` local raises a runtime script error on Godot
  4.6 (caught by test_spawn_service's free-without-despawn case), so the registry sweep
  reads entries into untyped locals guarded by `is_instance_valid`. Departs from the
  "typed GDScript everywhere" convention on two locals, forced by engine semantics. ·
  **Recommendation: Reviewed.**
