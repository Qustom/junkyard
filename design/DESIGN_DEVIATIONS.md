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

- **[2026-07-02] S2/TelegraphFSM — presentation-only; FSM timing accumulators stay
  host-side.** The S2 spec §2.2 table assigns the bomb's PULSING→EXPLODED *timing* to
  TelegraphFSM, but the binding Q1 rule keeps every accumulator increment site in the
  host — `_pulse_t` + the State match stay in `bomb_hazard.gd`; TelegraphFSM owns tell
  color/throb/flash presentation only (reads `pulse_seconds` for the throb period).
  Q1 explicitly overrides the body where they conflict, and the golden parity gate is
  the reason. S6a's Charger composes its phase timing host-side and drives these tells.
  · **Recommendation: Reviewed** (Q1 is the spec's own tiebreak).
- **[2026-07-02] S2/components — live `GameState.current_depth_index` reads remain at
  the legacy sites inside components.** Q1's "bind() receives resolved primitives
  (never a GameState read)" is honored for CONFIG; the live within-band depth is
  run-state the legacy entities read live per-frame by contract (BUG2), so transplanted
  blocks keep those reads (documented in `opposition_component.gd`'s contract).
  · **Recommendation: Reviewed** (transplant-verbatim requires it; the config-snapshot
  discipline is intact).
- **[2026-07-02] S2/base contract — one duck-typed cross-host seam,
  `host.call(&"run_clock_ms")`.** Hosts share no script base (CharacterBody2D vs Node2D
  roots), so the component layer's shared run-clock read is a dynamic call — the single
  untyped call in the layer, mirroring the deliberately duck-typed
  `resolve_throw_death`/`get_def_id` seams (Q5). · **Recommendation: Reviewed**.
- **[2026-07-02] S2/golden harness — scope grew beyond the workflow note's letter:**
  (a) a second pursuer trace (room-bound patrol) beyond "one trace per entity";
  (b) the dual-emit twin assertions were added to the harness in the REFACTOR commit
  (they cannot be green pre-refactor; the goldens stay legacy-only so the pre-refactor
  baseline remains the oracle). Both strengthen the gate; no golden or assertion was
  weakened. · **Recommendation: Reviewed**.

---

*Last close-out: **M1.9 Wave 1** (2026-07-02) — 2 entries (S0 SpawnService): **1 Reviewed + 1 Addressed**
(cap accounting live-registry-derived → canonical; untyped sweep locals → restructured typed) — reapplied + archived to
`DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior: **M1.8** (2026-07-02) — 17 entries: 15 Reviewed + 2 Addressed (verdict record `design/M1_8_Tasks/G4_findings_M1.8.md`).*
*Prior close-outs: M1.6 Wave 2 (3 Reviewed), M1.5 (2), M1.4 Wave 5 (3), Wave 3 (1 Addressed), Wave 1 (2+1) — all in
`DESIGN_DEVIATIONS_HISTORY.md`.*

---
- [2026-07-02] **S5 / band flavor stages — attach-at-open-socket, not e4's swap lean** (pre-ratified §10 Q3, recorded per DoD §8.6). `SetPieceInjectStage` appends the set-piece to a depth-gated retained open socket via the untouched grow-loop helpers; the set-piece is a dead-end detour off the spine, never a mid-spine swap. Why: as-built, swap requires re-mating a whole mated neighborhood; attach rides `band.open_sockets` (retained exactly for later passes) with zero new placement code, and keeps the control layout a strict prefix of the flavored one. · **Recommendation: Reviewed** (the spec's §10 Q3 adjudication already ratified attach; revisit swap only if S7's playtest says detour-vaults read as skippable).
- [2026-07-02] **S5 / WearDecay — M1.9 decay is breach-led; blocks only land behind breaches** (the §4.2/§10 Q4 headline — Director visibility mandatory at close-out, non-blocking). On the as-built tree bands every doorway is a bridge, so reject-on-disconnect rejects every block until a prior breach creates a cycle. Pinned by test F5 (with the §10 C2 tree-precondition asserted first, so the assertion can't go silently stale on a future cyclic band). The honest band_two tuning story is breach-heavy (`state = &"flooded"` fits: shortcut energy). · **Recommendation: Reviewed** (accept breach-led decay for M1.9 per D-RAT-1/§10 Q4; do NOT pull `loop_back_count` forward — out of the §0 guardrails).
- [2026-07-02] **S5 / BandPipeline — unknown flavor config type = fail-loud `null`, not spec §2.2's "push_error + skip"**. The pipeline validates every `profile.flavors` entry pre-generation and returns `null` on an unrecognised config type. Why: S1's `test_band_pipeline_parity` P7 pins `flavors = [Resource.new()]` → `null` (control safety), and the S5 DoD requires that test green UNMODIFIED — §2.2's "skip and still generate" semantics are unsatisfiable alongside it. Fail-loud-null is also the stricter control-safety posture (an unknown stage in an authored profile is an authoring error, same as the pre-S5 guard). · **Recommendation: Reviewed** — amend spec §2.2's sentence to match the as-built fail-loud behavior at reapply.
- [2026-07-02] **S5 / stage traits — overridable methods instead of the spec's `const MUTATES_PIECES`/`RESHAPES_FLOOR`**. GDScript cannot shadow a base-class const in a subclass, so `BandFlavorStage` exposes `mutates_pieces()` / `reshapes_floor()` / `journal()` methods (same pipeline-enforced contract, §10 Q7 semantics identical). · **Recommendation: Reviewed** (mechanical language-limitation translation; note it in the as-built doc at reapply).
