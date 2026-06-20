# SETUP — environment for THE FAR YARD

Everything needed to develop and to run the orchestrator. This repo was bootstrapped on
Ubuntu 20.04 (WSL2) **without root**, so the toolchain is user-local in `~/.local/bin`.
Secrets live in `APIKEYS.md` (gitignored) and in `~/.claude.json` (per-project, not in the repo) —
**never commit either, and never paste real keys into this file.**

## 0. PATH

```bash
export PATH="$HOME/.local/bin:$PATH"   # add to ~/.bashrc so godot/git-lfs/gh/uvx resolve
```

## 1. Toolchain (installed)

| Tool | Version | How it was installed (no sudo) |
|---|---|---|
| Godot | 4.6.3-stable | release zip → extracted with Python → `~/.local/bin/godot` |
| Git LFS | 3.7.1 | release tarball → `~/.local/bin/git-lfs` |
| GitHub CLI (`gh`) | 2.94.0 | release tarball → `~/.local/bin/gh` |
| `uv`/`uvx` | latest | `python3 -m pip install --user uv` (runs the Python MCP servers) |
| pip + Pillow + numpy | 3.8 site | `get-pip.py` (3.8 build) → `pip install --user Pillow numpy` (Tier-A placeholder gen) |

**If you have root** instead, the simpler path is `sudo apt-get install -y git-lfs gh python3-pip unzip`
and download Godot from <https://godotengine.org/download>. `unzip` is absent here — Python's
`zipfile` was used to extract.

Verify:
```bash
godot --version          # 4.6.3.stable.official...
git lfs version          # git-lfs/3.7.1
gh --version             # gh version 2.94.0
python3 -c "import PIL, numpy; print('placeholder gen ready')"
```

### 1a. Export templates + butler (for local exports & itch publishing — DLV1)

A real `--export-release` (Win64 *or* Web) needs the Godot **export templates** for the pinned
version installed where the editor looks. The **one `.tpz` carries every platform** (Windows + web
+ …), so this single install unblocks both the Windows playtest build and the itch HTML5 web build.
CI fetches these per-run (see `.github/workflows/nightly.yml`); install them once locally too:

```bash
# Export templates — one-time, version-EXACT (4.6.3-stable templates only work with 4.6.3-stable).
tpl="https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
curl -sL -o /tmp/templates.tpz "$tpl"
tdir="$HOME/.local/share/godot/export_templates/4.6.3.stable"   # note the version-string normalization
mkdir -p "$tdir"
python3 -c "import zipfile; zipfile.ZipFile('/tmp/templates.tpz').extractall('/tmp/tpl')"
mv /tmp/tpl/templates/* "$tdir/"
ls "$tdir" | grep -E 'web|wasm'    # expect web_release.zip + web_nothreads_release.zip (the fallback)
```

```bash
# butler (itch.io upload CLI) — lands in ~/.local/bin alongside godot (shares the §0 PATH).
# NOTE: butler is distributed ONLY from broth.itch.ovh; if that host is unreachable from your
# network, install butler on a machine that can reach it.
curl -sL -o /tmp/butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
python3 -c "import zipfile; zipfile.ZipFile('/tmp/butler.zip').extractall('$HOME/.local/bin/')"
chmod +x "$HOME/.local/bin/butler"
butler -V          # verify (PATH already has ~/.local/bin)
```

Now a local web export + push works via `bash tools/push_itch.sh` (it stamps the build, exports the
`Web` preset to `build/web/`, resolves the itch key from `BUTLER_API_KEY` or the `# Itch.io` section
of `APIKEYS.md` **without printing it**, and pushes `qusto/the-far-yard:html5`).

**Human-only prerequisites for an actual publish** (butler pushes *builds*, not page settings):

1. **`BUTLER_API_KEY` repo secret** — generate at itch.io → Account → Settings → API Keys; add as a
   GitHub repo secret named `BUTLER_API_KEY` (this gates the nightly publish). Locally, the key is
   read from `APIKEYS.md` (gitignored — **never commit it**).
2. **The itch project `qusto/the-far-yard`** — created on the **personal** account (itch username
   `qusto`, distinct from the GitHub login `Qustom`); set **Visibility = Restricted/Draft + a project
   password** (private playtest); **Kind of project = HTML / playable-in-browser**.
3. **"SharedArrayBuffer support" toggle = ON** on the HTML5 upload — the threaded web build needs
   cross-origin isolation. The threaded build is **CHROMIUM-ONLY** on itch (Firefox lacks the
   `credentialless` COEP scheme itch serves) — play in **Chrome or Edge**. Fallback if the toggle is
   fiddly: a single-threaded export (`variant/thread_support=false` in `export_presets.cfg`, which
   uses the installed `web_nothreads_release.zip` — no SAB/headers, a perf cost, but portable).
4. **Confirm one manual push** — `bash tools/push_itch.sh` (or `butler push build/web
   qusto/the-far-yard:html5`) once, before the nightly cron is relied on.

## 2. Git LFS

Configured via `.gitattributes` (images/audio/fonts/xlsx → LFS; `.gd/.tres/.tscn/.import` stay plain text).
Initialize hooks once per clone:
```bash
git lfs install --local
git lfs track            # list tracked patterns
git lfs status           # confirm new binaries are pointers, not blobs
```
Verified: a test PNG committed as a 3-line LFS pointer (`version/oid/size`), not a binary blob.

## 3. Godot project

```bash
godot --headless --import                                  # compile scripts, build .godot/
godot --headless --script res://tools/ci_smoke_test.gd     # → "SMOKE OK" (exit 0)
godot project.godot                                        # open the editor
```
The smoke test exercises the M0 spike: autoloads, seeded-RNG determinism, save round-trip +
migration, and Resource loading. CI runs the same two commands (`.github/workflows/ci.yml`).

## 4. MCP servers (art/audio tools for the subagents)

Added at **local scope** → stored in `~/.claude.json` under this project, **not** in the repo.
Replace the placeholders with the values from `APIKEYS.md`. After adding/changing servers,
**restart Claude Code** so the running session picks them up.

```bash
# fal.ai — general image gen, concept/mood frames (HTTP)
claude mcp add --transport http fal-ai https://mcp.fal.ai/mcp \
  --header "Authorization: Bearer $FAL_KEY"

# PixelLab — pixel-art sprites/animations/Wang tilesets (HTTP)
claude mcp add pixellab https://api.pixellab.ai/mcp -t http \
  -H "Authorization: Bearer $PIXELLAB_SECRET"

# ElevenLabs — text-to-SFX + scratch TTS VO (stdio via uvx)
claude mcp add elevenlabs -e ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY -- uvx elevenlabs-mcp

claude mcp list   # health check — all three should report ✔ Connected
```

Status (verified `✔ Connected`): **fal-ai, pixellab, elevenlabs**.
Notes:
- These differ from `design/Role_Subagents/README.md`, which predates the official HTTP endpoints —
  see `design/DESIGN_DEVIATIONS.md`.
- **Suno** has no official API; use fal.ai for placeholder music or wire a third-party provider.
- Live generation **spends paid credits** (PixelLab $12/mo tier, fal.ai PAYG, ElevenLabs Creator) —
  get a human OK before a generation run, and quarantine output in `*/\_placeholder/`.

## 5. GitHub Projects (Producer subagent)

`gh` is installed; the `project` subcommand needs auth with the `project` scope. This is an
**interactive** step — run it yourself (in this session you can prefix with `!`):
```bash
gh auth login                      # choose GitHub.com → HTTPS → browser/token
gh auth refresh -s project         # add the 'project' scope
gh auth status                     # confirm
```
Then the Producer can drive the board, e.g.:
```bash
gh project list --owner Qustom
gh project item-list <number> --owner Qustom
gh project item-create <number> --owner Qustom --title "M1-03 slot inventory"
```
Repo remote: `https://github.com/Qustom/junkyard.git`.

## 6. Subagents

8 role agents in `.claude/agents/` (sources in `design/Role_Subagents/`, playbooks in
`design/Role_Playbooks/`). Claude Code loads them at **session start** — restart before
dispatching by name. Each is a normal agent definition; the orchestrator calls them via the
Agent tool (`subagent_type` = the agent's `name`). See `CLAUDE.md` for the roster + the loop.

## 7. Reload checklist after first setup

1. `export PATH="$HOME/.local/bin:$PATH"` (and persist in `~/.bashrc`).
2. Set `FAL_KEY`, `PIXELLAB_SECRET`, `ELEVENLABS_API_KEY` from `APIKEYS.md` (for re-adding MCP if needed).
3. `gh auth login -s project` (interactive).
4. **Restart Claude Code** → subagents + MCP servers become available to the orchestrator.
