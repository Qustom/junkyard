# Worklog — RG2 M1.2 telemetry analysis vs M1.0/M1.1 baselines

- **Date:** 2026-06-19
- **Subagent:** qa-playtest-coordinator
- **Milestone:** M1.2 (Wave 3 re-gate)
- **Branch:** qa/RG2
- **Commit:** ff291e2 (RG2: M1.2 telemetry analysis + G4 findings)

## What changed
Analysis-only task (no game-code change). Segmented the cumulative playtest log
(`playtest_data/M1.2/run_log_2026-06-19.jsonl`, 11,410 rows) into cohorts by build SHA + real
`run_config` knobs, computed per-config end-cause / run-length / depth distributions side-by-side vs the
M1.0 all-off control and the M1.1 cohort, and read each M1.2 fix (I1/I2/I3-R3/BUG5/R2/R4/I5) against the
data. Authored `design/M1_2_Tasks/G4_findings_M1.2.md` with the cohort partition, distributions, per-fix
"did it land" read, and an RG3 recommendation (ITERATE → M1.3). Added a reusable analysis helper.

## Files touched
- `design/M1_2_Tasks/G4_findings_M1.2.md` — the RG2 findings + RG3 recommendation (new)
- `tools/playtest/analyze_m1_2.py` — analysis helper: cohort partition, per-config distributions, per-fix event counts (new)
- `worklogs/2026-06-19-RG2-qa-playtest-coordinator.md` — this worklog (new)

Note: `playtest_data/M1.2/` is an untracked snapshot in the main checkout (not git-tracked). It was
copied into the worktree to run the helper; it is intentionally NOT committed (matches main's untracked state).

## Checks run
- [x] Helper runs clean in the worktree: `python3 tools/playtest/analyze_m1_2.py` → WORKTREE_RUN_OK
- [x] Cohort counts reconcile: M1.2 = 33 started / 32 ended (ba745e1); M1.1 = 70 (852b6e2); M1.0 control = 7 subset
- [x] I5 verification: 0/32 M1.2 runs have duration_s=0 (M1.1 had 32/66); build SHA is real HEAD
- [x] Definition of done met: "G4_findings_M1.2.md exists with cohort partition, per-config distributions
      side-by-side vs M1.0/M1.1, a per-fix 'did it land in the data' read, and a clear go/iterate/pivot
      recommendation backed by the numbers." — all present.
- n/a `godot --headless` checks (no engine/code change in this task)

## Design deviations
None. This is analysis; no GDD/TDD/playbook departure. The recommendation (ITERATE) is surfaced to the
Director as a recommendation only — the verdict is the Director's.

## Handoffs / follow-ups (surfaced to the Director — feed M1.3 if ITERATE)
- **Bug (sev-med):** depth-counter mismatch confirmed in data — `band_depth_reached.depth` maxes at 1 while
  `run_ended.max_depth` reaches 17. HUD likely shows band_depth, not the depth_index config/extraction use.
- **Bug (sev-low):** `hazard_caught` fires per physics frame while overlapping (up to 2,199 events/run) —
  edge-trigger/debounce the signal so one catch = one event.
- **Config trap (invalidated two experiments):** R3 was swept with `r3_threshold_levels=[]` (→ 0 crossings/penalties,
  so I3-R3 + BUG5 are UNVERIFIED this round) and R4 with `r4_lost_proxy_threshold=0.0` + fog off on 27/30 (→ 0
  lost-proxy). Recommend re-testing both with populated knobs + a guard that warns when an opposition is enabled
  with its trigger disabled, so a gate can't silently pass over a dead experiment.
- **Telemetry request for M1.3:** emit corridor entry/exit timestamps so "long hallways are boring" (Director #3a)
  is directly measurable rather than inferred from flat junctions/run vs growing duration.
