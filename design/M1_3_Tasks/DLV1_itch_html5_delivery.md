# DLV1 — itch.io HTML5 delivery via butler (F5)

**Milestone:** M1.3 — Legibility & Density · **Workstream:** Wave 1 (Foundation & correctness, infra-disjoint) · **Wave:** 1
**Task id:** DLV1 · **Design author:** `producer` · **Builder(s):** `producer` + `general-purpose`
**dependsOn:** none (infra; its first *useful* push is the RG1 build) · **blockedBy:** none
**Touch-map (planned, for the build phase — NOT touched by this design doc):** `export_presets.cfg` (add a `Web` preset), a new `tools/push_itch.sh` (local push), `.github/workflows/nightly.yml` (update the placeholder slug + add a web export/publish path), `SETUP.md` §1 (butler + web-template install steps). **Does NOT touch** any game code, the `run_ended` arity, telemetry row shapes, or `RunConfig`. `APIKEYS.md` is read-only and never committed.
**Companion docs:** `design/M1_3_Tasks/M1.3_Breakdown.md` §3 (DLV1) / §7 (the DLV1 env-risk), `design/M1_2_Tasks/G4_findings_M1.2.md` §5 (F5: the Director's web-build decision), `export_presets.cfg` (the existing `Win64` preset), `.github/workflows/nightly.yml` (the existing butler→itch scaffolding), `tools/playtest/tester_readme.md` §"Where the files live" (the current desktop telemetry-return flow that web breaks).

> This is a **design / approach** doc (Phase 2). It specifies the install + preset + push plan and surfaces the open questions; it does **NOT** install butler, install templates, run godot, edit any file, or run `butler push`. Phase 3 (fresh eyes) resolves §5; the Director dispositions the flagged item; only then is a builder dispatched.

---

## 1. Goal & premise research

### 1.1 The F5 goal (what the Director asked for)
From `G4_findings_M1.2.md` §5, F5 (Director-ratified, 2026-06-19):

> *"Push each playtest build to **itch.io via butler** as an **HTML5 web build** (Director's choice — the itch page is browser/password-gated). Target `qusto/the-far-yard` (personal account). Needs butler + 4.6.3 web export templates + a web preset (none exist yet) + a push task. Infra, not gameplay."*

The intent: the Director playtests in a **browser** (the itch page is password-gated, so it is private), and **each playtest build auto-publishes** so the re-gate loop (RG1 build → Director plays → RG2 analysis) does not depend on hand-shipping a Windows binary. This is the delivery half of the M1.3 re-gate.

Note the **slug change**: `nightly.yml` was authored for a *studio* account placeholder (`studio/the-far-yard:win-nightly`); the Director's F5 call moves delivery to the **personal** account `qusto/the-far-yard` (note the username is `qusto`, matching the F5 text — distinct from the GitHub login `Qustom`). DLV1 reconciles the scaffolding to that real target.

### 1.2 Current reality — what exists vs. what's missing

**Exists (the Windows / CI-only scaffolding):**
- `.github/workflows/nightly.yml` — a complete two-job pipeline: a `test` gate (import + smoke + save-migration + duration-loop + loop-drive + main-game + GdUnit4) and an `export-and-publish` job that:
  - installs Godot 4.6.3 headless + the **Windows** export templates into `$HOME/.local/share/godot/export_templates/4.6.3.stable/` (lines 118–135),
  - stamps the build via `bash tools/stamp_build.sh` (bakes the git short SHA into the git-ignored `systems/build_info_gen.gd` that `BuildVersion` reads — lines 137–147),
  - exports `--export-release "Win64" build/win/TheFarYard.exe` (lines 152–159),
  - installs butler from `https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default` to `/tmp/butler/butler` (lines 161–167),
  - pushes `butler push build/win "${ITCH_TARGET}" --userversion "${USER_VERSION}"` where `USER_VERSION="m1-$(date -u +%Y%m%d)-$SHA"` (lines 169–175),
  - is **human-gated**: the publish step is skipped unless the `BUTLER_API_KEY` GH secret is set (lines 100–109), and the header (lines 11–18) explicitly states a human must provision the secret + create the itch project + confirm one manual `butler push` before relying on cron.
- `export_presets.cfg` — **one** preset, `preset.0` = `name="Win64"`, `platform="Windows Desktop"`, `export_path="build/win/TheFarYard.exe"`, `script_export_mode=2`, with an `exclude_filter` that drops `design/*, worklogs/*, tools/playtest/*, tests/*, *.md`. Its own header note (lines 6–7) says *"Add a Linux/HTML5 preset later only if remote/external testers enter the picture"* — which F5 now triggers.
- `tools/stamp_build.sh` — the reusable build-id stamp (resolves repo root from `$BASH_SOURCE`, marks an uncommitted tree with `+dirty`). **Web export needs this same stamp**, so DLV1 reuses it verbatim.
- `APIKEYS.md` (gitignored) — confirmed to contain an **`# Itch.io`** section (key present; value NOT read or printed). This feeds butler **locally**; CI uses the `BUTLER_API_KEY` repo secret. The key must never be committed (`.gitignore` already excludes `APIKEYS.md`).
- `.gitignore` — already excludes `/build/`, so the produced `build/web/` artifacts will not be committed.

**Missing (the gaps DLV1 closes):**
1. **butler is NOT installed** locally — `which butler` fails. (Only CI installs it, to `/tmp`.)
2. **No Godot export templates installed** — `~/.local/share/godot/export_templates/` is empty/absent. *Neither* Windows *nor* web templates exist locally; a local `--export-release` of any kind fails fast today. CI fetches templates per-run; a local playtest build needs them installed once.
3. **No web/HTML5 export preset** in `export_presets.cfg` — only `Win64` exists.
4. **No web publish path** — `nightly.yml` exports/pushes Win64 only; nothing exports `build/web` or pushes a `:html5` channel.
5. **No local push script** — there is no `tools/push_itch.sh`; the only butler invocation lives inside CI.
6. **Cross-origin-isolation headers** — a Godot 4 *threaded* web build needs `SharedArrayBuffer`, which needs COOP/COEP headers served by the host (see §1.3). itch.io has a toggle for this; it must be enabled on the page. This is a **page-config** gap, not a repo gap.

### 1.3 Godot 4.6 web export specifics (the load-bearing gotchas)

- **Templates are version-exact.** Web export templates must match the editor version *exactly* (4.6.3-stable templates only work with 4.6.3-stable). The `.tpz` bundle from the Godot release contains *all* platform templates (Windows + web + …), so the **same `Godot_v4.6.3-stable_export_templates.tpz` `nightly.yml` already fetches for Windows also supplies the web template** — no separate download. Install dir: `~/.local/share/godot/export_templates/4.6.3.stable/` (note the version-string normalization `4.6.3-stable` → `4.6.3.stable`, exactly as `nightly.yml` line 132 does).
- **A web export emits a *set* of files**, not one binary: `index.html`, `index.js`, `index.wasm`, `index.pck`, `index.audio.worklet.js`, and (with threads) `index.worker.js` + a `.side.wasm`/service-worker. itch expects the **folder**, with `index.html` as the entry. So the preset's `export_path` is `build/web/index.html` and `butler push` targets the **directory** `build/web` (mirroring how the Win push targets the `build/win` dir).
- **Threads / `SharedArrayBuffer`.** Godot 4 web defaults to a **threaded** build, which requires `SharedArrayBuffer`, which the browser only grants when the page is **cross-origin isolated** (served with `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`). Without those headers the build shows a **white/black screen** and never renders frame one. Two ways to satisfy this on itch:
  1. **itch's "SharedArrayBuffer support" toggle** on the upload (Edit-game → the HTML5 upload has a *"This file will be played in the browser" → "SharedArrayBuffer support"* checkbox). Ticking it makes itch serve the COOP/COEP headers. **This is the Director-facing requirement and must be enabled on `qusto/the-far-yard`.**
  2. Godot's export option **"Ensure Cross Origin Isolation Headers"** (a.k.a. shipping the **COI service-worker** shell) — emits a service worker that re-serves the page cross-origin-isolated even when the host doesn't send the headers. Belt-and-suspenders with (1).
  - **Escape hatch:** Godot 4.3+ added a **"Thread Support" off** web export — a single-threaded build that needs *no* SharedArrayBuffer and *no* special headers, at a perf cost. For a *greybox* playtest build this is a viable fallback if the itch toggle proves fiddly (see §5 Q4).
- **The itch page must be set to "HTML"** (playable in browser), not the default "Downloadable", and the **channel must be tagged HTML5/playable-in-browser** — this tagging happens from the itch Edit-game page on the *first* push (butler sets the platform tag from the channel name on the first upload only).

### 1.4 The telemetry-return reality (the part that may make web the wrong vehicle)

This is the most important research finding and the reason the breakdown flags DLV1's env-risk.

The entire re-gate depends on the Director shipping back `user://telemetry/run_log.jsonl`. Today (desktop) that flow is **simple and proven** (`tools/playtest/tester_readme.md` §"Where the files live"):

- Telemetry writes to `user://telemetry/run_log.jsonl` (const `LOG_PATH` in `systems/telemetry/telemetry_schema.gd:21`).
- On **Windows** `user://` resolves to `%APPDATA%\Godot\app_userdata\THE FAR YARD\`; the tester zips `telemetry/` + `logs/` and sends them. This is how every M1.0–M1.2 re-gate got its data.

**On a web build, `user://` does NOT resolve to a disk folder.** Godot's web platform maps `user://` to the **browser's IndexedDB** (persisted via the Emscripten/IDBFS filesystem). Consequences:

- The `run_log.jsonl` lives **inside the browser's IndexedDB for the itch.io origin** — there is no `%APPDATA%` file to zip and send. The `tester_readme.md` "zip these two folders" instructions **do not apply to a web build**.
- IndexedDB persistence is **per-origin and fragile**: it survives reloads, but is wiped by clearing site data / private-window sessions / some browsers' eviction under storage pressure. A casual "clear browsing data" loses the whole playtest log.
- There is **no built-in way for the Director to hand us the JSONL** from a browser build without an explicit export mechanism. The desktop flow's single biggest virtue — "the file is just on disk" — is gone.

So **a web build can make telemetry retrieval materially HARDER than desktop**, and the re-gate (RG2) is 100% dependent on getting that `.jsonl` back. Options to recover it (none free):
1. **An in-game "Export telemetry" button** (web-only) that reads `user://telemetry/run_log.jsonl` and triggers a **browser download** of it via `JavaScriptBridge` (Godot's `JavaScriptBridge.eval` + a Blob/anchor click). This is the clean fix but is **new game code** outside DLV1's infra scope (would be a sibling task).
2. **Manual IndexedDB extraction** via browser devtools (Application → IndexedDB → the Godot store) — brittle, error-prone, and unreasonable to ask of the Director run-to-run.
3. **Keep desktop for telemetry runs, web for feel** — the Director plays the **web build for the fun-read** (legibility/density: "does push-vs-extract feel tense?") but runs the **Windows build for the data** the re-gate quantifies. This keeps the proven JSONL flow intact and treats web purely as a convenience/feel channel.

This is the **needs-Director-review** call in §5 (Q3): web may be the right *feel* vehicle but the wrong *telemetry* vehicle, and that changes what DLV1 ships (a download button? a web-only-for-feel split?).

---

## 2. Plan / pseudocode (the concrete setup — for the build phase, not executed here)

Five pieces. (1)–(3) are one-time/infra; (4)–(5) wire it into the loop. All file edits are **described**, not made, in this doc.

### (1) Install butler (local)
Mirror the CI install (`nightly.yml` lines 161–167) but persist it on PATH:

```bash
# one-time, documented in SETUP.md §1
curl -sL -o /tmp/butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
unzip -o /tmp/butler.zip -d "$HOME/.local/bin/"      # alongside godot (SETUP §0 PATH)
chmod +x "$HOME/.local/bin/butler"
butler -V                                            # verify; PATH already has ~/.local/bin
butler login                                         # OR rely on BUTLER_API_KEY env (see §4)
```

- Lands in `~/.local/bin/` so it shares the existing `export PATH="$HOME/.local/bin:$PATH"` (SETUP §0) with `godot`.
- Auth: **do not** commit a credential. Locally, export `BUTLER_API_KEY` from `APIKEYS.md` at push time (see §4); `butler login` (which writes `~/.config/itch/butler_creds`) is an alternative but the env-var path matches CI and keeps the secret out of any committed file.

### (2) Install the 4.6.3 web export templates (local)
The **same `.tpz`** the Windows path uses already contains the web template:

```bash
# one-time, documented in SETUP.md §1 — same bundle nightly.yml fetches for Win
tpl="https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
curl -sL -o /tmp/templates.tpz "$tpl"
tdir="$HOME/.local/share/godot/export_templates/4.6.3.stable"   # version-normalized, as nightly.yml line 132
mkdir -p "$tdir"
unzip -o /tmp/templates.tpz -d /tmp/tpl
mv /tmp/tpl/templates/* "$tdir/"
# verify the web template landed:
ls "$tdir" | grep -E 'web|wasm'                                  # expect web_debug.zip / web_release.zip / web_dlink_*
```

- Installing all templates once also unblocks **local Windows** exports (currently impossible — no templates installed), a side benefit.

### (3) The HTML5 export preset (to ADD to `export_presets.cfg` — described, not edited here)
A second preset `preset.1` named **`Web`**, `platform="Web"`, `export_path="build/web/index.html"`. Key fields (the build agent authors these against the real 4.6.3 Web preset; values below are the intent):

```ini
[preset.1]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="design/*, worklogs/*, tools/playtest/*, tests/*, *.md"   # same hygiene as Win64
export_path="build/web/index.html"
script_export_mode=2

[preset.1.options]
custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=true            # threaded build → needs SharedArrayBuffer (see Q4)
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=0
html/progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=true   # ship the COI service worker (belt + braces w/ itch toggle)
```

- **`export_path="build/web/index.html"`** → the export writes the whole file-set into `build/web/`; butler pushes that **directory**.
- **`thread_support=true`** is the default + best-perf choice but couples us to the itch SAB toggle (Q4). The `ensure_cross_origin_isolation_headers` option ships Godot's COI service-worker as a safety net.
- Reuse the `Win64` `exclude_filter` so design/test/worklog files never ship in the web pack.
- **Naming must be stable** (`"Web"`), because the push script + CI reference the preset *by name* (exactly as `--export-release "Win64"` does).

### (4) The local push script `tools/push_itch.sh` (new — described)
Mirror + extend the `nightly.yml` butler step so a local playtest build publishes the same way CI would:

```bash
#!/usr/bin/env bash
# tools/push_itch.sh — export the Web preset and push it to itch via butler.
# Local sibling of nightly.yml's export-and-publish job. Reads the itch key from
# APIKEYS.md (gitignored) if BUTLER_API_KEY is not already in the env. NEVER prints the key.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"; cd "$REPO_ROOT"

ITCH_TARGET="qusto/the-far-yard:html5"        # F5 real slug (personal acct; :html5 channel)

# 1. Stamp the build id the same way CI does (BuildVersion reads systems/build_info_gen.gd).
bash tools/stamp_build.sh
SHA="$(git rev-parse --short HEAD)"
USER_VERSION="m1-$(date -u +%Y%m%d)-${SHA}"

# 2. Export the Web preset (templates must be installed — step 2).
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
test -f build/web/index.html                  # a produced file is the minimum proof; partial exports can still emit

# 3. Resolve the key WITHOUT printing it: prefer env, else read the Itch.io section of APIKEYS.md.
if [ -z "${BUTLER_API_KEY:-}" ]; then
  # parse only the value under the "# Itch.io" header; never echo it
  BUTLER_API_KEY="$(awk '/^# *Itch\.io/{f=1;next} /^#/{f=0} f && NF {print $NF; exit}' APIKEYS.md)"
fi
[ -n "${BUTLER_API_KEY:-}" ] || { echo "no itch key (env or APIKEYS.md)"; exit 1; }

# 4. Push the DIRECTORY to the :html5 channel.
export BUTLER_API_KEY
butler push build/web "${ITCH_TARGET}" --userversion "${USER_VERSION}"
echo "pushed ${ITCH_TARGET} @ ${USER_VERSION}"
```

- The exact APIKEYS.md parse line is illustrative — the build agent matches it to the file's real format. The contract: **resolve the key without echoing it**, prefer an already-set env var (so CI passes its secret straight through).
- `set -euo pipefail` + the `test -f` guard mirror the CI hygiene (a produced file ≠ a clean export, but a *missing* file is a hard fail).

### (5) Wire into the loop
- **RG1 (the M1.3 playtest build):** RG1's build/verify step calls `tools/push_itch.sh` after the loop-smoke checklist passes, so **each playtest build auto-publishes** to `qusto/the-far-yard:html5`. RG1's spec (Wave 3) references this script as its publish step. This is the "auto-push each playtest build" the breakdown asks for.
- **`nightly.yml`:** two edits (described, not made):
  1. **Update the placeholder slug.** `ITCH_TARGET: "studio/the-far-yard:win-nightly"` → the real target. Decide per Q1: if web replaces Windows, set `ITCH_TARGET: "qusto/the-far-yard:html5"` and swap the export step to the `Web` preset (`--export-release "Web" build/web/index.html`) + push `build/web`. If both ship, keep the Win job and **add** a parallel web export/publish step pushing `qusto/the-far-yard:html5` (the `.tpz` already installs both templates, so no extra fetch).
  2. **Stamp + guard unchanged** — reuse `tools/stamp_build.sh` and the `BUTLER_API_KEY`-present guard (lines 100–109) verbatim; the publish stays human-gated until the secret exists.
- **`SETUP.md` §1:** add the butler install (1) + web-template install (2) as documented, CI-reproducible steps so a fresh environment can produce + push a web build (Q5).

### Telemetry note (flag — see §1.4 and §5 Q3)
A web build's `user://` JSONL persists in the **browser's IndexedDB**, not on disk. The proven desktop "zip `%APPDATA%\...\THE FAR YARD\telemetry\`" flow (`tester_readme.md`) **does not work for web**. RG2 cannot read what it cannot retrieve, so DLV1's design must NOT silently assume telemetry will come back the desktop way. The retrieval mechanism is the §5 Q3 **needs-Director-review** decision; until it's resolved, the **safe default is to keep the desktop build as the telemetry vehicle** and treat web as a feel/preview channel.

---

## 3. Definition of done (for the build phase)

DLV1 is **Done** when:
- butler is installed and on PATH locally; `butler -V` succeeds (SETUP.md updated).
- The 4.6.3 web export templates are installed; `godot --headless --export-release "Web" build/web/index.html` produces a non-empty `build/web/index.html` + the wasm/pck/js set.
- `export_presets.cfg` carries a stable-named `Web` preset (the `Win64` preset is untouched).
- `tools/push_itch.sh` exists, reads the key without printing it, and (with a valid key + the itch project + the SAB toggle on) performs a real `butler push build/web qusto/the-far-yard:html5 --userversion <id>` — **confirmed once manually by a human** before RG1 relies on it (the same one-manual-push gate `nightly.yml` already mandates).
- `nightly.yml`'s placeholder slug is reconciled to the real target per the Q1 verdict; the human-gated `BUTLER_API_KEY` guard is preserved.
- The telemetry-retrieval decision (Q3) is Director-dispositioned and reflected in `tester_readme.md` (a web-specific section, or a "use desktop for data" note).
- A worklog at `worklogs/<date>-DLV1-producer.md` names the commit SHA(s); no secret is committed.

---

## 4. Risk register delta (DLV1's live risks)

| risk | sev | mitigation |
|---|---|---|
| **Web telemetry unretrievable** (IndexedDB, no disk file) → RG2 has no data | **HIGH** | Q3 needs-Director-review; safe default = desktop build is the telemetry vehicle, web = feel. |
| White/black screen on itch (SAB headers missing) | med | enable itch's "SharedArrayBuffer support" toggle on the page; ship the COI service worker (`ensure_cross_origin_isolation_headers`); fallback to thread-support-off single-threaded build (Q4). |
| Templates absent locally → export fails fast | low | one-time `.tpz` install (step 2), documented in SETUP.md; CI already fetches per-run. |
| Secret leak (key in a commit / printed in logs) | med | `APIKEYS.md` is gitignored; push script resolves the key without echoing; CI uses the `BUTLER_API_KEY` secret; never commit the key. |
| Wrong/placeholder slug → push to a non-existent project | low | F5 fixes the slug to `qusto/the-far-yard:html5`; one manual confirming push before RG1 relies on it. |
| Channel mis-tagged (not "playable in browser") | low | tag the channel HTML5 from the itch Edit-game page on the first push; set the page to "HTML", not "Downloadable". |

---

## 5. Open Questions

- **Q1 — Web only, or web + Windows?** F5 says publish web. But §1.4 shows web telemetry is hard while the Windows JSONL flow is proven. Do we (a) **replace** Win with web in `nightly.yml`/RG1, (b) **ship both** (web for the Director's browser feel-read, Win for the data — the `.tpz` installs both templates, so the cost is one extra export+push step), or (c) web-only and solve telemetry retrieval (Q3)? *Recommendation: (b) ship both* — lowest risk to the re-gate, small marginal cost, and it keeps the M1.0–M1.2 telemetry flow byte-for-byte intact. *Resolvable on merit; defer the final call to Q3's Director verdict since it's entangled.*

- **Q2 — Channel slug: `:html5` vs `:web`?** Both work; the channel name only sets the platform tag on the *first* push, and itch recognizes either for HTML5. *Recommendation: `:html5`* (matches the breakdown §7's `qusto/the-far-yard:web?` query — pick one and lock it; `:html5` is the more conventional itch web-channel name and is unambiguous about the platform). *Resolvable on merit.*

- **Q3 — How does the Director get the `.jsonl` back from a browser build?** **[needs Director review]** This is the load-bearing question and it may change whether web is the right telemetry vehicle at all. A web build stores `user://telemetry/run_log.jsonl` in **browser IndexedDB**, not on disk; the proven "zip `%APPDATA%\...\telemetry\`" flow does not apply. Options: **(a)** add a web-only in-game **"Export telemetry" download button** (`JavaScriptBridge` reads the file → triggers a browser download) — clean but it's **new game code, a sibling task outside DLV1's infra scope**; **(b)** manual IndexedDB extraction via devtools — brittle, unreasonable per-run; **(c)** **keep the desktop build as the telemetry vehicle and use web only for the fun/feel read** — zero new code, preserves the proven flow, web becomes a convenience channel. *Recommendation: (c) for M1.3 now (desktop = data, web = feel), with (a) as a fast-follow if web-only telemetry becomes desirable later.* **The Director should decide whether web is meant to carry the re-gate's data at all, or just the feel** — that verdict determines DLV1's true scope (infra-only vs infra + a download-button task) and feeds back into Q1.

- **Q4 — SharedArrayBuffer / header config on the itch page.** A threaded Godot 4.6 web build needs cross-origin isolation. Plan: enable itch's **"SharedArrayBuffer support"** toggle on `qusto/the-far-yard` *and* ship the COI service worker (`ensure_cross_origin_isolation_headers=true`). If the toggle proves fiddly for a greybox build, fall back to a **thread-support-off single-threaded** export (no SAB, no headers, some perf cost — acceptable for greybox). *Recommendation: threaded + itch toggle + COI service worker first; single-threaded fallback documented.* *Resolvable on merit, but the toggle is a manual page action only the human can do (see Q7).*

- **Q5 — Do the install steps belong in `SETUP.md`, and are they CI-reproducible?** The butler + web-template installs are one-time env setup; `nightly.yml` already proves the CI install path works (it fetches both from the same URLs). *Recommendation: yes — add both to `SETUP.md` §1 as documented, copy-pasteable steps; keep CI self-contained (it fetches per-run, does not depend on a developer's local install).* *Resolvable on merit.*

- **Q6 — Who provisions the `BUTLER_API_KEY` GH secret + the itch project/channel?** `nightly.yml` (lines 11–18) is explicit that a **human** must: add the `BUTLER_API_KEY` repo secret (from itch Account → Settings → API Keys), create the itch project at the real slug set to draft/restricted, enable the SAB toggle, and confirm one manual `butler push`. Claude did not and must not invent a key or self-create the project. *This is a human-coordination item, not a code task — the producer surfaces the checklist; the human executes it.* *Resolvable on merit (it's an assignment, not a design call) but it is a hard prerequisite for any real publish.*

- **Q7 — Password-page + page-mode config on itch.** The Director wants the page browser/password-gated (private). On itch this is the page **Visibility = Restricted/Draft + a project password**, plus **Kind of project = HTML** (playable in browser). These are manual itch dashboard actions (same human as Q6). *Recommendation: document them in the DLV1 human-checklist; not automatable via butler (butler pushes builds, not page settings).* *Resolvable on merit; human-executed.*

---

## 6. Notes for Phase 3 (fresh eyes) and the Director

- The single highest-value thing a fresh-eyes reviewer can do is **pressure-test Q3** — confirm (or refute) that Godot 4.6 web `user://` is IndexedDB-only and that there is no simpler retrieval than a `JavaScriptBridge` download button or the desktop fallback. If a fresh build agent finds a clean export path, it changes the recommendation.
- Everything in §2 is **described, not done**. No file in the repo was modified by this design doc. The build phase (post-lock) installs butler/templates, adds the `Web` preset, writes `tools/push_itch.sh`, and edits `nightly.yml`/`SETUP.md`.
- The **secret discipline** is non-negotiable: `APIKEYS.md` stays gitignored, the push script never echoes the key, CI uses the repo secret. The itch key value was **not** read or printed in authoring this doc (only the section's existence was confirmed).
