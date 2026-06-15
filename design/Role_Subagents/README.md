# THE FAR YARD — Role Subagents

Eight subagents, one per non-programmer role from Tech Design §6. Each file is a
standard agent definition (YAML frontmatter + system prompt) that draws on the
matching playbook in `../Role_Playbooks/`.

| File | Role | External tools to install |
|---|---|---|
| `game-director-designer.md` | Game Director / Designer | — |
| `environment-artist.md` | 2D Artist — environment/tiles | PixelLab MCP, fal.ai MCP |
| `character-animator.md` | 2D Artist/Animator — characters/FX | PixelLab MCP |
| `ui-ux-designer.md` | UI/UX Designer | fal.ai MCP |
| `audio-designer-composer.md` | Audio Designer / Composer | ElevenLabs MCP, Suno/fal.ai MCP |
| `narrative-writer.md` | Narrative Designer / Writer | — |
| `qa-playtest-coordinator.md` | QA / Playtest Coordinator | — |
| `producer.md` | Producer | Tracker MCP (GitHub/Linear/Trello) |

The subagents assume their listed tools are installed and available — install
them up front (commands below) rather than gating work on them.

## Installing the subagents

**Status: installed.** The 8 agent files are copied into `.claude/agents/` (and
their doc references rewritten to repo-root-relative paths so they resolve when
an agent runs from the repo root). Sources of truth stay here; the matching
playbooks live in `../Role_Playbooks/`. To re-install (e.g. after editing a
source file):

```bash
for f in design/Role_Subagents/*.md; do
  b=$(basename "$f"); case "$b" in README.md|TDD_*.md) continue;; esac
  cp "$f" ".claude/agents/$b"
done
```

Project-level `.claude/agents/` makes them available in this project; put them
in `~/.claude/agents/` to use across all projects. Claude Code loads agents at
**session start** — restart before dispatching by name. The orchestrator
(`CLAUDE.md`) dispatches them via the Agent tool (`subagent_type` = agent name).

## MCP servers / tools (installed & verified)

The art/audio MCP servers below are **installed and `✔ Connected`** (verify with
`claude mcp list`). Keys come from `APIKEYS.md` (gitignored) and are stored at
local scope in `~/.claude.json` — never in the repo. Free placeholder routes
(Tier A code, Kenney CC0) still come first in each workflow; these cover the
generation steps. Full setup + exact commands live in `../../SETUP.md`.

> **Note:** the install methods below changed during M0 — fal.ai and PixelLab now
> use their **official HTTP MCP endpoints** rather than the community/Python
> servers this README originally listed. See `../DESIGN_DEVIATIONS.md`.

### Art
- **fal.ai MCP** — general image gen, concept/mood frames, icons (HTTP).
  `claude mcp add --transport http fal-ai https://mcp.fal.ai/mcp --header "Authorization: Bearer $FAL_KEY"`
- **PixelLab MCP** — pixel-art characters, animations, Wang tilesets; the only
  tool that does *animation* programmatically (HTTP).
  `claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H "Authorization: Bearer $PIXELLAB_SECRET"`

### Audio
- **ElevenLabs MCP (official)** — text-to-SFX (v2: looping, batch) and TTS for
  scratch VO (stdio via `uvx`).
  `claude mcp add elevenlabs -e ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY -- uvx elevenlabs-mcp`
- **Suno** — no official API; use **fal.ai MCP** for placeholder music (cleaner
  licensing) or wire a third-party Suno provider if custom lyrics/style are
  needed (verify licensing before use).

### Production
- **GitHub Projects via the `gh` CLI** (not an MCP) — the Producer drives the
  board with `gh project …`. Needs an interactive `gh auth login -s project`
  (see `../../SETUP.md`). A Tracker MCP (Linear/Trello) is an alternative if the
  team switches trackers.

> Live generation **spends paid credits** — get a human OK before a generation
> run, and quarantine output in the `*/_placeholder/` folders.

## Licensing reminder
All generated art/audio is **placeholder**, quarantined in `/_placeholder`
folders, and scheduled for replacement by a human artist/composer. AI-image
copyright remains unsettled, so don't let generated assets drift toward ship.
