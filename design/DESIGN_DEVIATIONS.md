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

*Last close-out: **M1.5 Wave 2** (2026-06-24) — 1 item: L1-F1 throw telemetry `run_t_ms` uses monotonic clock
(**Reviewed**/no action) — archived to `DESIGN_DEVIATIONS_HISTORY.md`.*
*Prior close-outs: **M1.5 Wave 1** (1 Reviewed), **M1.4 Wave 5** (3 items), **Wave 3** (1 Addressed), **Wave 2** (0),
**Wave 1** (2 Reviewed + 1 Addressed) — all in `DESIGN_DEVIATIONS_HISTORY.md`.*

---

**[2026-06-25] L6-F1 — pure-keyboard-no-mouse aim defaults to DOWN (the kept fallback degrades).**
*What vs. the doc:* L6 §1 says aim falls back to the movement direction when no device has been used. As built, `aim`
initialises to `DOWN` (non-zero) and `resolve_aim()` checks "hold last aim" (prev) *before* "movement direction", so a player
using the **pure-keyboard fallback** (Space throw / Q-E cycle, never moving the mouse) aims permanently DOWN — the movement
branch is unreachable once `prev` is the DOWN default.
*Why:* the chosen priority (stick → mouse-after-motion → hold-last → move → DOWN) keeps controller aim stable on stick release
(twin-stick convention) and never lets a stale cursor hijack aim; the side effect is the keyboard-only fallback never tracks
movement. Mouse + controller (the **primary** schemes) are unaffected; all-off fp unmoved; gate green.
*Claude's recommendation:* **Reviewed** — mouse is the primary KB/M device and the Director kept Q/E+Space as a *fallback*, not
the main scheme. If a usable keyboard-only aim is wanted, file a small follow-up to track movement direction when neither
mouse (`_mouse_active`) nor stick is active. Surfaced for the re-test in `design/M1_5_Tasks/G4_findings_M1.5.md`.
