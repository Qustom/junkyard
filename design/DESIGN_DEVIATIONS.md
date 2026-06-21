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

*Last close-out: **M1.3 Wave 2** (2026-06-20) — 1 deviation (J2 curve as-built), Reviewed, archived to
`DESIGN_DEVIATIONS_HISTORY.md`.*

---

## M1.4 Wave 1 — awaiting Director disposition (2026-06-21)

- **[2026-06-21] K0 — quota-enum knob count (doc vs as-built).** The K0 design doc's RD-1/RD-6 dropped the two
  quota behaviour enums (`quota_check_timing`, `quota_basis`) → would total **79** knobs. The Breakdown's
  Phase-4 Lock KEPT them (Director wants quota configurable) → as-built is **81**. The build is correct per the
  Lock; only the K0 doc's RD arithmetic is stale. *Claude recommends: **Reviewed** — reapply by correcting the K0
  doc's count to 81; no code change.*
- **[2026-06-21] K3/K6 — render-time behaviour is not headless-verifiable.** Jitter-gone (K6) and the fixed-FOV
  *look* (K3) can't be proven in `--headless`; both are confirmed green at the code/determinism level (fp
  `e943ac9c8bc1`, smoke, unit tests). *Claude recommends: **Reviewed** — fold into the RG1 playtest verify matrix
  as an explicit "confirm on a >60Hz monitor/browser" item; not a design change.*
- **[2026-06-21] K3 — the resolution-independent camera ships OPT-IN.** `make_default_play_preset()` was NOT
  modified, so the fixed-FOV camera is reachable only by setting `cam_enabled` in CFG; the boot preset still uses
  today's window-dependent framing. This matches "make it configurable" literally, but means the **default RG1
  playtest won't exercise the new camera** unless the preset enables it. *Claude recommends: **Addressed** — set
  the preset to enable the fixed FOV (`cam_enabled=true`, `cam_visible_world_width≈576` = today's horizontal FOV)
  so the re-gate actually measures the controlled-visibility change the Director asked for. **Director call** (it's
  a fun/visibility decision).*
