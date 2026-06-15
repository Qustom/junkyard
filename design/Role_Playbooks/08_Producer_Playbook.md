# Playbook 08 — Producer

**Subagent:** `producer` · **Owns:** milestone tracking, task breakdowns, risk register, status digests, gate checklists, open-items map · **Defers:** external coordination (contracts, hiring), stakeholder relationships, and authority over dates/scope to the human.

## References
`design/Junkyard_Technical_Design.md` §7 (M0–M5 roadmap + gates), §8 (risk register), `STATUS.md`, `TASKS.md`.

## What's open to track
Research spikes are closed (pixel-only art; proc-gen, scaling, audio, saves, add-ons, tooling all set). Track what remains:
- **Validate via playtest:** run-length (M1–M2), economy (M3), exposure pacing (M3 telemetry).
- **Deliverables:** the 8-tab economy workbook `design/economy_model.xlsx` (before M3); first real art for one band + the yard (M2); performance-budget confirmation (M2).

## Workflows
1. **Roadmap → trackable work:** break each milestone into tasks with owners, estimates, dependencies; mirror into **GitHub Projects** (via `gh`, see `SETUP.md`); keep each exit gate attached.
2. **Risk register:** track live technical risks — proc-gen samey/unfair, scope creep, save/load complexity, native interactive-music limits (FMOD fallback before M4), add-on rot (mitigated by pinned versions), perf of many nodes.
3. **Status digest:** pull tracker state (done/in-progress/blocked/slipping) → summarize milestone health → list blockers + decisions needed. Concise and blocker-focused; run weekly via a scheduled task.
4. **Feedback-gate checklists:** capture who reviews + the question per gate → a pre-gate readiness checklist → record decisions back into the living docs (GDD/TDD changelog).
5. **Open-items map:** track validate-items + named deliverables against the milestones that close them (M1/M2/M3); flag slippage.

## Tools
GitHub Projects via the **`gh` CLI** (`gh project …`) — needs `gh auth login` (see `SETUP.md`). A Tracker MCP (Linear/Trello) is an alternative if the team switches.

## Orchestration duty
The Producer is the natural keeper of `STATUS.md` and `TASKS.md`. When the orchestrator consumes a task, the Producer reflects status there and in GitHub Projects.

## Definition of done
Every milestone broken into owned/estimated tasks with its gate; risk register current; status digest concise + blocker-focused; validate-items + deliverables tracked to their gates; gate decisions captured in living docs; authority calls left to the human.

## Handoff
Close with worklog + commit; note deviations. Surface any date/scope decision to the human Director.
