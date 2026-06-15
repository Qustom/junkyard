# G3 — Greybox Playtest Build

**Summary:** Produce a runnable nightly build (itch.io via Butler) of the full M1 loop — spawn, dive, pick up junk, decide push vs. extract, bank or lose, sell, repeat — and verify the whole loop runs start to finish without blockers.

- **Parent task:** G3 (M1 breakdown)
- **Dependencies:** all of A–F plus G1 (telemetry must be in the build so G4 can read it)
- **Acceptance criterion:** A fresh build runs the complete loop with no blockers; multiple runs per session are possible.

---

## Assets needed

- **Export presets:** `export_presets.cfg` at project root with at least one preset for the playtest target platform(s) — Windows desktop is the primary M1 target (matches the team's machines); add Linux/HTML5 only if testers need them. Keep one canonical preset name (e.g. `Win64`) referenced by CI.
- **CI workflow:** `.github/workflows/nightly.yml` — scheduled (cron) + manual `workflow_dispatch`. Steps: checkout, fetch pinned Godot 4.6.x headless + export templates, run `--export-release`, then push the artifact to itch.io with Butler.
- **Butler:** the `butler` CLI in CI, authenticated via a repository secret `BUTLER_API_KEY`. Target channel like `studio/the-far-yard:win-nightly`.
- **Build metadata:** stamp the build with a version + git short SHA (a small `version.gd` or `ProjectSettings` value) so telemetry/feedback can be tied to a specific build.
- **Telemetry default in playtest build:** the opt-in toggle still defaults off (privacy), but the playtest build should surface a clear first-run prompt asking testers to enable it (see open questions). The build must include `/systems/telemetry` from G1.
- **Loop-smoke checklist:** `/tools/playtest/loop_smoke_checklist.md` — the manual pass a human runs against each nightly before sharing the link.
- **Tester instructions:** `/tools/playtest/tester_readme.md` — how to run, how to enable telemetry, where the log lives (`user://telemetry/run_log.jsonl`), and how to send it back. (Survey itself belongs to G4.)

---

## Code to generate

This task is mostly pipeline + verification, not gameplay code. Deliverables: the export preset, the nightly workflow, and the smoke checklist.

**Nightly export + Butler workflow (YAML-ish sketch):**

```yaml
# .github/workflows/nightly.yml
name: nightly-playtest
on:
  schedule: [{ cron: "0 6 * * *" }]   # nightly UTC
  workflow_dispatch: {}

jobs:
  export-and-publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }       # need git SHA for version stamp
      - name: Get Godot 4.6.x headless + export templates
        run: |
          # download pinned editor binary AND matching export templates
          # install templates to the version dir Godot expects
      - name: Stamp build version
        run: echo "BUILD_SHA=$(git rev-parse --short HEAD)" >> $GITHUB_ENV
      - name: Export Win64 (release)
        run: |
          mkdir -p build/win
          godot --headless --path . \
            --export-release "Win64" build/win/TheFarYard.exe
      - name: Install Butler
        run: |
          # fetch butler, unzip, chmod +x
      - name: Push to itch.io
        env:
          BUTLER_API_KEY: ${{ secrets.BUTLER_API_KEY }}
        run: |
          ./butler push build/win studio/the-far-yard:win-nightly \
            --userversion "m1-${BUILD_SHA}"
```

Notes that bite in practice: export templates must match the editor version exactly; the export will fail in CI if templates are missing (a common headless gotcha). Confirm the export completes with **zero** errors in the headless log, not just a produced file — a partial export can still emit a binary.

**Manual loop-smoke checklist (`/tools/playtest/loop_smoke_checklist.md`):**

Run on every nightly before sharing the link. Each item is pass/fail; any fail blocks the build.

```
[ ] Build launches to main menu; no error spew in the console.
[ ] Start run -> player spawns in the yard (band depth 0/1).
[ ] Dive: can descend at least one band; band_depth_reached fires (visible/HUD or log).
[ ] Pick up junk: inventory increments; carried value updates on HUD.
[ ] Decision point reachable: clear push (go deeper) vs. extract (cash out) choice.
[ ] Extract path: banks carried haul; bank/currency total increases; back to safe area.
[ ] Death path: dying loses haul per the rule; run ends with cause=death.
[ ] Sell: banked junk converts to currency at the expected rate.
[ ] Repeat: can immediately start a second run in the same session.
[ ] Telemetry (if enabled): user://telemetry/run_log.jsonl exists and has run_started + run_ended lines for each run.
[ ] No soft-locks: every state has an exit (no stuck screens, no required-but-missing input).
```

The last two lines are the acceptance check made concrete: a fresh build runs the full loop, and multiple runs per session work.

---

## Open questions

- **Platforms:** Windows-only for M1, or also HTML5 (lowest-friction for remote testers, but adds export/template/perf risk)? Picking one keeps the pipeline simple.
  - **Recommendation:** Windows-only (`Win64`) for M1. The testers are internal and on the team's machines (Windows), so the HTML5 friction win does not apply, and Web export adds real cost — SharedArrayBuffer/COOP-COEP headers, threading/perf quirks, and a second template to keep version-matched. A native build also gives reliable `user://` JSONL on disk, which the manual telemetry-return flow in G4 depends on. Add HTML5 only if remote/external testers enter the picture later.
- **Butler secret + channel naming:** Who owns the itch.io project and the `BUTLER_API_KEY` secret? Confirm the exact `user/game:channel` slug before the workflow can publish.
  - **Recommendation:** Create the itch.io project under the studio account (not a personal one) so ownership survives team changes, generate the API key from Account > Settings > API Keys, and store it as the GitHub repo secret `BUTLER_API_KEY`. Mark the itch page as restricted/draft so nightly builds are not public. Pin the channel slug to `studio/the-far-yard:win-nightly` (channel name encodes the platform, which Butler also infers from the build) and confirm it once with a manual `butler push` before relying on the cron job. ([source](https://www.vojtechstruhar.com/blog/022-godot-itch-github-action/))
- **Telemetry consent in playtest:** Default-off respects privacy but risks empty G4 data. Do we add a first-run "help us by enabling telemetry" prompt, or just instruct testers in the README to flip the toggle?
  - **Recommendation:** Add an explicit first-run consent prompt (Enable / Not now) that states plainly what is logged, that there is no PII, and that it stays local until they send it back — defaulting to off and only writing after an affirmative choice. A README instruction alone will be skipped by some testers and silently produce empty G4 data, which is the one outcome that wrecks the gate; an in-build opt-in prompt is the standard pattern and keeps consent genuine while maximizing capture for an internal cohort.
- **Build identity:** Is a git short SHA stamp enough to correlate a feedback report + JSONL with a specific build, or do we need a human-readable build number?
  - **Recommendation:** Use a combined human-readable + SHA stamp: `m1-<YYYYMMDD>-<shortsha>` as the Butler `--userversion` and the in-build version string, and emit it into telemetry (e.g. a `build` field on `run_started` or a one-line header event). The date gives humans/testers an at-a-glance "which nightly" while the SHA gives exact reproducibility; SHA alone is correct but unfriendly to reference in survey responses and chat.
- **Nightly vs. on-demand:** Scheduled nightly may publish broken intermediate states. Gate the nightly on the G2 `test` job passing, or keep them independent and rely on the manual smoke checklist?
  - **Recommendation:** Gate the nightly export/publish on the G2 `test` + headless-smoke job passing (use `needs:` on those jobs, or run them as the first steps of the nightly workflow and abort on failure). The manual loop-smoke checklist still runs before a human shares the link, but it should be the second line of defense, not the first — automatically blocking a publish when tests/parse are already red costs nothing and stops broken nightlies from ever reaching itch. Keep `workflow_dispatch` for on-demand builds with the same gate.
- **Crash/error capture in the wild:** Should the build write Godot's log to `user://logs` and ask testers to include it, so we catch blockers the checklist missed?
  - **Recommendation:** Yes — enable Godot's file logging for playtest builds (`ProjectSettings` > Debug > File Logging > Enable, with the default `user://logs/godot.log` rotation) and have the tester README ask testers to send the `logs/` folder alongside their `telemetry/run_log.jsonl`. It is a one-setting change, the log sits right next to the telemetry the "open log folder" button already surfaces, and a stack trace from a real tester crash is far cheaper than reproducing a blocker the manual checklist missed.
