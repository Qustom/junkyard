# Design Deviations Log

Append-only record of every place the build departed from `Junkyard_GDD.md`,
`Junkyard_Technical_Design.md`, the role playbooks, or the documented setup — with rationale
and whether it needs human sign-off. The orchestrator appends here whenever a task is consumed
(`CLAUDE.md` → "Record"). Each subagent's per-task deviations land here too.

Format: `[date] <id/area> — what changed vs. the doc · why · sign-off?`

---

## M0 — Pre-production & Tech Foundations

- **[2026-06-15] Testing — headless smoke test ships before GdUnit4.** TDD §4 standardizes on
  GdUnit4. M0 ships `tools/ci_smoke_test.gd` (a plain `SceneTree` script) as the runnable CI gate
  because the GdUnit4 addon isn't vendored yet. *Why:* gives a green/red gate on day one with zero
  addon dependency. *Sign-off:* not needed; QA vendors GdUnit4 in M1 (task M1-07) and keeps the
  smoke test as the boot check.

- **[2026-06-15] Tooling — fal.ai MCP install differs from the design README.**
  `design/Role_Subagents/README.md` lists fal.ai via a community npm server
  (`npx -y fal-mcp-server`, `FAL_KEY` env). Installed instead the **official fal.ai HTTP MCP**
  (`https://mcp.fal.ai/mcp`, `Authorization: Bearer`). *Why:* first-party, no local process, health
  verified by `claude mcp list`. *Sign-off:* not needed (strict improvement). README should be updated.

- **[2026-06-15] Tooling — PixelLab MCP is an HTTP endpoint, not the GitHub Python server.**
  The README points at `github.com/pixellab-code/pixellab-mcp` (Python SDK + MCP). Installed instead
  the **official HTTP MCP** (`https://api.pixellab.ai/mcp`, Bearer secret). *Why:* first-party, no
  local Python server to maintain; connects cleanly. *Sign-off:* not needed. README should be updated.

- **[2026-06-15] Tooling — `Role_Playbooks/` created.** The 8 subagents and the Role_Subagents
  README reference `Role_Playbooks/NN_*.md`, which did not exist. Authored all 8 at
  `design/Role_Playbooks/` and rewrote the installed agents' doc references to repo-root-relative
  paths so they resolve when an agent runs from the repo root. *Why:* the subagents were otherwise
  pointing at missing files. *Sign-off:* not needed; content is derived from the existing design docs.

- **[2026-06-15] Environment — host tooling installed user-local (no sudo).** Godot/git-lfs/gh/uv
  live in `~/.local/bin` and pip packages in the user site, because passwordless sudo isn't
  available here. *Why:* unblocks M0 without root. *Sign-off:* not needed; documented in `SETUP.md`.

### Confirmations (not deviations)
- Godot **4.6.3-stable** is a real release and matches the TDD §1 version pin — no drift.
