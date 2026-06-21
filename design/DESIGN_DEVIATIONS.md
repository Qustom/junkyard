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

*Last close-out: **M1.4 Wave 3** (2026-06-21) — 1 deviation **W3-F1** (K5b test `queue_free`-on-freed stderr noise) →
Director: **Addressed** (guarded with `is_instance_valid`; test now clean), archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior close-outs: **Wave 2** (0 deviations), **Wave 1** (2 Reviewed + 1 Addressed) — both in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

**[2026-06-21] RG1-F1 — K5 hazard sweep-start magnitudes in `make_default_play_preset()`.**
*What vs. the doc:* the M1.4 breakdown/Phase-3 lock delegated K5 hazard magnitudes to RG1 ("magnitudes are RG1 sweeps") but did not fix values. The three new hazards (hpp/hbomb/hspike) share a single `NEW_HAZARD_BAND_CEILING=48` in starvation order (pingpong → bomb → spike), so an aggressive sweep-start (e.g. base 1 / per_depth 0.5 / cap 2) lets **pingpong alone saturate the 48 ceiling and starve spikes to ZERO** on the deep default band — the Director couldn't evaluate spikes at all. The build agent therefore chose **modest** starts (each: `base_count=0`, `count_per_depth=0.15`, `per_room_cap=2`; type knobs hpp_speed 70 / hbomb proximity 64·pulse 2.0·blast 48 / hspike rot 90·arm 48), giving a balanced **≈9/9/9** so all three spawn (≈27 combined, well under 48).
*Why:* the load-bearing constraint is "every enabled hazard type must actually spawn in the shipped default" (else the re-gate measures a dead type, the M1.2 trap). All other contracts intact — all-off fp unmoved (`e943ac9c8bc1`), 81 knobs, preset trap-free, no leak into the control. Pushing the magnitudes up is a valid RG1/RG2 sweep, just not the shipped default.
*Claude's recommendation:* **Reviewed** (a magnitude call the Director explicitly delegated to RG1; no design-doc change needed — the breakdown already says magnitudes are RG1 sweeps). If the Director wants a documented "shipped sweep-start" of record, that's a one-line note in `G4_findings_M1.4.md`, not a contract change.
