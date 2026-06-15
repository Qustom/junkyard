# Worklog — <TASK-ID> <title>

- **Date:** <YYYY-MM-DD>
- **Subagent:** <role>
- **Milestone:** M<n>
- **Branch:** <role>/<task-id>
- **Commit:** <full SHA>   ← required; a worklog without a real commit means the task is NOT done

## What changed
<2–5 lines: what was built/changed and why.>

## Files touched
- `path/one.gd` — <why>
- `path/two.tres` — <why>

## Checks run
- [ ] `godot --headless --import` clean (no parse errors)
- [ ] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK
- [ ] task-specific tests (name them) pass
- [ ] definition of done met (quote it)

## Design deviations
<For each departure from the GDD / Technical Design / playbook: what, why, and whether it
needs the human Director's sign-off. Write **"none"** if fully on-spec. Anything here must
also be appended to `design/DESIGN_DEVIATIONS.md`.>

## Handoffs / follow-ups
<New tasks discovered, blockers raised, or judgment calls surfaced to the human.>
