# I5 — Telemetry hygiene (`duration_s = 0` + real build SHA)

**Milestone:** M1.2 — Legibility & Fairness pass · **Workstream:** Wave 1 (Foundations) · **Wave:** 1
**Task id:** I5 · **Design author:** `qa-playtest-coordinator` · **Builder:** `qa-playtest-coordinator`
**dependsOn:** none · **Touch-map:** `systems/version.gd`, `project.godot` (`config/build_sha`), the export/CI SHA-bake step (`.github/workflows/nightly.yml`); a headless test under `tests/`. **Does NOT touch** the `run_ended` arity or `telemetry.gd` row shapes.
**Companion docs:** `design/M1_2_Tasks/M1.2_Breakdown.md` §I5, `design/M1_1_Tasks/G4_findings_M1.1.md` §I5, `design/M1_1_Tasks/BUG1_duration_s.md` (the prior fix), `design/M1_Tasks/M1_As_Built.md` §Telemetry/§G3 (canonical contracts).

> This is a **design / approach** doc (Phase 2). It specifies the two fixes + their checks; it does **not** modify game code. Phase 3 resolves the Open Questions (§5) before a builder is dispatched.

---

## 1. Goal & premise research

The M1.2 re-gate (RG2) reads its verdict off **run-length and build-separated distributions vs. the M1.0/M1.1 baselines**. Two found-in-data defects from the M1.1 playtest make that data untrustworthy. **Crucially, the two are entangled — and the data proves the entanglement is the actual story.**

### Source data
- `design/M1_1_Tasks/G4_findings_M1.1.md` §I5 — the triage row: *"`duration_s = 0` on ~23 current-build runs (correlated with all-off/fast extract); build SHA frozen at `852b6e2`."* Severity **S**.
- `playtest_data/M1.1/run_log_2026-06-19.jsonl` — 1225 rows, 70 `run_started`, 66 `run_ended`. (4 `run_started` have no matching `run_ended` — sessions abandoned mid-run, orthogonal to this task; noted in §5 Q6.)

### Quantified findings (this analysis)

**Defect (a) — `duration_s = 0.0` on a subset.** Of 66 `run_ended` rows, **32 carry `duration_s == 0.0`**. Restricted to the current build `m1-20260619-852b6e2` there are 57 ended runs and **23 of them are zero** — matching the G4 "~23 current-build runs" figure. By end-cause the zeros are 30 `extract` + 2 `death`, never `timeout`.

But the decisive correlation is **not** with config or cause — it is with **session and telemetry-marking**:

| session | build (run_started) | window | zero | nonzero | runs carry `run_config`? |
|---|---|---|---|---|---|
| `s_33c0a1` | `m1-20260618-852b6e2` | 06-18 09:55–10:00 | **9** | 0 | **no** (`nocfg`) |
| `s_34e69b` | `m1-20260619-852b6e2` | 06-19 06:50–06:53 | **10** | 0 | **no** |
| `s_34e929` | `m1-20260619-852b6e2` | 06-19 07:00–07:09 | **13** | 0 | **no** |
| `s_3577d3` | `m1-20260619-852b6e2` | 06-19 17:09–17:12 | 0 | 4 | **yes** |
| `s_357a2d` | `m1-20260619-852b6e2` | 06-19 17:20–17:30 | 0 | 23 | **yes** |
| `s_357d71`/`s_357e2c`/`s_357f72` | `m1-20260619-852b6e2` | 06-19 17:33–17:45 | 0 | 7 | **yes** |

Two facts fall straight out of the table:

1. **Zero-duration is 100% clustered by session** — a session is *all* zero or *all* nonzero, never mixed.
2. **Zero-duration ⇔ the `run_started` row has no `run_config` snapshot** (the TEL config-marking field, added in the *same M1.1 wave 1 as BUG1*). Every zero-duration run is unmarked; **every config-marked run has a real `duration_s`** — among the 34 cfg-marked runs, **zero are zero-duration** (6 all-off + 28 opposition, all nonzero).

3. The zero-duration runs are **not** same-frame fast-extracts. Differencing the envelope `t_ms` of each zero run's `run_started` vs. `run_ended` gives **real spans of 11–53 s** (e.g. `r_7bce28` extract span 53.7 s, `r_914298` death span 13.1 s). A genuine same-frame extract would show a sub-second `t_ms` span. So these are honest 11–53 s runs that *logged* `0.0` — a **missed stamp, not a correct floor**.

### Root-cause hypothesis (a) — RATIFIED-pending: stale-binary, NOT a live BUG1 regression
The data points away from the G4 row's tentative "BUG1 regressed on a run subset / all-off fast extract" framing and toward a sharper cause:

> **The zero-duration runs were produced by a binary that predates the BUG1 fix.** BUG1 (`game_state.gd`: stamp `_run_start_ms` in `start_run`, compute `_elapsed_s()` at each end path) and the TEL `run_config` snapshot landed **in the same M1.1 wave-1 pass**. The three all-zero sessions (`s_33c0a1`, `s_34e69b`, `s_34e929`) ran **before that pass was compiled into the playtester's build** — which is exactly why those rows *also* lack the `run_config` field. Once the fixed binary was in play (every 06-19 17:xx session), **`duration_s` is real on every cause, including all-off and fast extracts**. The "all-off / fast-extract" correlation in the G4 row is an **artifact**: the unmarked pre-fix sessions happened to be early casual all-off runs, so the analyst mis-attributed the zeros to config rather than build.

**Why this still needs a fix even though current marked runs are clean:** the *reason* the analyst could not tell the pre-fix binary from the post-fix one is **defect (b)** — the SHA never moved, so all three pre-fix sessions report the same `852b6e2` as the fixed 17:xx sessions. Without a working build id, the cohort cannot be cleanly partitioned and a future "is BUG1 still fixed?" question is unanswerable from the log alone. **I5 therefore (i) hardens the duration stamp against every end *and re-entry* path so a missed-stamp can never recur, and (ii) makes the build id real so a pre/post-fix mix is detectable.** The audit of the loop-restart re-entry paths below (`start_new_run` → `start_run`) confirms the current code already re-stamps on every loop, but the headless assertion in §3 makes that a standing guarantee rather than an observation.

### Loop re-entry audit (the path the task asks to scrutinise)
Read of `scenes/game/main_game.gd` + `systems/game_state.gd`:
- `MainGame.start_new_run()` is the **single** loop entry. It is wired to **both** `SellScreen.continue_pressed` (the "Continue → next dive" door) and the menu Start; "Back to Config" routes through `_on_back_to_config()` → `_show_menu()` and the next Start re-enters `start_new_run()`. **Every one of these calls `GameState.start_run(BAND_ID, seed)`** (line 209), which stamps `_run_start_ms = Time.get_ticks_msec()` (`game_state.gd:89`) fresh.
- The end paths — `extract_and_end_run()`, `fail_run()` (death + timeout) — each compute `duration_s = _elapsed_s()` *after* the `_run_ended` idempotency guard, so a losing same-frame caller early-returns without recomputing.
- **Conclusion:** there is **no live re-entry path that ends a run without a fresh `start_run` stamp.** The current loop re-stamps correctly on Continue and on Back-to-Config→Start. The zeros are pre-fix binaries, not a surviving code defect. I5's job on (a) is therefore **a regression-lock** (the headless assertion that drives the loop-restart path and asserts a nonzero duration), not a code change to the duration math — unless §5 Q1/Q5 surfaces a path this audit missed.

### Defect (b) — `run_started.data.build` frozen at a stale SHA
Every `run_started` row across the whole log — including 06-19 builds — stamps `"build":"m1-20260619-852b6e2"` (or `m1-20260618-852b6e2`). The **date moves, the SHA never does.** Current `git rev-parse --short HEAD` is `691d9da`; the logged SHA `852b6e2` is an old M1.0 commit.

Root cause, from reading `systems/version.gd` + `project.godot` + the workflows:
- `BuildVersion.short_sha()` reads `ProjectSettings.get_setting("application/config/build_sha")` if the setting exists, else the committed `FALLBACK_SHA = "852b6e2"`.
- **The setting exists and is committed stale.** `project.godot:18` literally contains `config/build_sha="852b6e2"`. So `has_setting(...)` is **always true** and returns the frozen baked value — the `FALLBACK_SHA` is never even reached.
- The SHA *is* supposed to be baked at export by `nightly.yml` (`SHA=$(git rev-parse --short HEAD)`; `sed -i` rewrites `config/build_sha` in `project.godot`, lines 136–141). **But:** (i) that bake only happens inside the **nightly export pipeline**, so any **editor / local-headless / non-nightly playtest binary** carries whatever stale value is committed in `project.godot`; and (ii) the playtest builds were evidently *not* nightly artifacts (they all show `852b6e2`, the committed value, not a fresh per-day SHA). So in practice the SHA is permanently `852b6e2` for every build a playtester actually runs.

So the build id is human-meaningful in its *date* segment only; the SHA — the part that exactly pins a commit for repro — is dead.

---

## 2. Design intent & guardrails

- **(a)** Make `duration_s` **provably real on every end path including every loop re-entry**, and lock it with a headless assertion that drives the Continue / Back-to-Config restart seam — so a missed-stamp regression can never silently ship again.
- **(b)** Make `BuildVersion.short_sha()` report the **actual HEAD SHA** of the binary that is running, in headless, editor, **and exported** builds — so the re-gate can partition the cohort by build and a pre/post-fix mix is visible.
- **Hard guardrails (unchanged from M1.1, restated):**
  - **Do NOT widen `run_ended(reason, duration_s, depth_reached)` arity.** I5 fills the existing `duration_s` slot honestly; it adds no `run_ended` argument and no new telemetry row. (`M1_As_Built.md` §Telemetry; `M1.2_Breakdown.md` §"Out of scope".)
  - **`build` stays an additive `run_started.data` field** — fixing its *value* is not a schema change. `TELEMETRY_SCHEMA_VERSION` stays `1`; `ENVELOPE_KEYS` untouched.
  - **No new autoload.** `BuildVersion` stays the autoload-free static helper it is (G3 pattern).

---

## 3. Design / approach + pseudocode

### 3a. `duration_s` real on every end + re-entry path (regression-lock)

**Code-change scope: none expected** — the audit (§1) shows `game_state.gd` already stamps at `start_run` and computes `_elapsed_s()` at every guarded end path, and every loop re-entry routes through `start_run`. The deliverable is the **standing headless assertion** that *proves* this across the restart seam and fails CI if a future edit breaks it. (If Phase 3 / Q1 / Q5 surfaces a real missed-stamp path, the fix is the BUG1 pattern: ensure that path re-stamps `_run_start_ms` via `start_run`, never ends a run on a stale stamp.)

**The corrected flow it must hold (already true in the build — asserted, not changed):**

```
# start_run (game_state.gd) — stamps fresh EVERY entry, incl. each loop re-entry
func start_run(band_id, seed):
    _run_ended = false
    _run_start_ms = Time.get_ticks_msec()      # fresh stamp on EVERY run, every loop
    ...
    EventBus.run_started.emit(band_id, seed)

# any end path — extract / death / timeout
func <end_path>():
    if _run_ended: return                       # idempotency: losing same-frame caller bails
    _run_ended = true
    var duration_s := _elapsed_s()              # (now - _run_start_ms)/1000, raw float s
    ...
    end_run(cause, duration_s)                  # relays run_ended(cause, duration_s, max_depth)
```

**Headless assertion — drives the LOOP-RESTART path and asserts nonzero duration on the *second* run** (this is the new, I5-specific coverage beyond BUG1's single-run test). Runs as a headless scene host (autoloads don't resolve under bare `--headless --script`; `M1_As_Built.md` testing constraint), `quit()`ing non-zero on failure:

```
# tests/test_duration_loop_reentry.gd  (headless scene host; ports to GdUnit4 once vendored)
func run():
    var GS  := root.get_node("GameState")
    var EB  := root.get_node("EventBus")
    var captured := []                                  # [(reason, duration_s, depth), ...]
    EB.run_ended.connect(func(r, d, depth): captured.append([r, d, depth]))

    # --- Run 1: start, wait a real interval, EXTRACT ---
    GS.start_run(&"test_band", 111)
    await create_timer(0.20).timeout                    # provably-nonzero interval; needs a live tree
    GS.extract_and_end_run()

    # --- Run 2: RE-ENTER the loop (the seam SellScreen.continue_pressed → start_new_run drives) ---
    #     The point of I5: a SECOND start_run must RE-STAMP, so run 2's duration is its OWN elapsed,
    #     not stale from run 1 and not zero.
    GS.start_run(&"test_band", 222)                     # fresh stamp (simulates the Continue restart)
    await create_timer(0.20).timeout
    EB.dive_clock_timeout.emit()                        # end run 2 via the fail path (timeout)

    # --- Run 3: re-enter again, end via DEATH (cover the third cause across re-entry) ---
    GS.start_run(&"test_band", 333)
    await create_timer(0.20).timeout
    EB.player_died.emit(&"death")

    # --- Assert: all three captured ends have a REAL, INDEPENDENT, nonzero duration ---
    assert(captured.size() == 3)
    for i in 3:
        var dur : float = captured[i][1]
        assert(dur > 0.0, "duration_s must be nonzero on loop re-entry run %d (got %f)" % [i, dur])
        # ~0.2s each, tolerance >= one headless frame; band, not exact float
        assert(abs(dur - 0.20) <= (1.0/15.0), "duration_s out of band on run %d: %f" % [i, dur])
    # cross-check causes survived the re-entries in order
    assert(captured[0][0] == &"extract" and captured[1][0] == &"timeout" and captured[2][0] == &"death")
    quit(0)
```

Key properties: it asserts **nonzero on every loop re-entry** (the gap BUG1's single-run test didn't cover), keeps **telemetry OFF** (the duration must be self-contained on the signal, per BUG1 §8 Decision 3), uses a **tolerance band** (real wall time is never bit-exact), and runs all three causes across three sequential `start_run`s in one live tree. Wire it into the CI smoke gate (or the GdUnit4 suite once vendored) so red blocks merge.

### 3b. `BuildVersion.short_sha()` reports the real HEAD SHA

**The problem to solve:** the SHA must be correct in (1) editor/dev runs, (2) local headless runs (what playtesters were using), and (3) exported Windows/standalone builds — where **`git` is not available at runtime** and there is no `.git` directory. So "shell out to `git rev-parse` at runtime" is **not** a complete answer; it works for (1)/(2) but fails for (3). The robust mechanism is **bake-at-build-time into a committed/generated artifact the binary can read at runtime**, with a runtime git read as a dev-time freshness convenience.

**Recommended mechanism — a generated `version.gen.tres` (or a generated `build_info.gd` const), written by a pre-build step, read by `BuildVersion`:**

| Layer | What runs | Result |
|---|---|---|
| **Build/export step** (CI **and** a local `tools/stamp_build.sh`) | `git rev-parse --short HEAD` (+ optional dirty flag) → write `res://version.gen.tres` (a tiny `Resource` with a `short_sha: String`) | The real SHA is frozen into a resource that **ships inside the export** (no git needed at runtime). |
| **Runtime** (`BuildVersion.short_sha()`) | `load("res://version.gen.tres")` if present → its `short_sha`; **else** (editor/dev, file absent) optionally shell `git rev-parse --short HEAD` via `OS.execute` for a live dev value; **else** `FALLBACK_SHA`. | Correct in exported builds (resource), fresh in editor (git), never empty (fallback). |

This **replaces the current `ProjectSettings("application/config/build_sha")` indirection**, whose committed-stale value in `project.godot:18` is the actual bug. (Alternative kept open in §5 Q4: keep the ProjectSettings key but fix the bake to also run locally and strip the stale committed value so `has_setting` falls through correctly.)

**Pseudocode:**

```gdscript
# systems/version.gd  (still autoload-free static)
const FALLBACK_SHA := "0000000"   # neutral "unknown" sentinel, NOT a real old SHA (so a stale build is obvious)
const GEN_PATH := "res://version.gen.tres"

static func short_sha() -> String:
    # 1) Exported / built binary: the baked resource ships inside the pack.
    if ResourceLoader.exists(GEN_PATH):
        var v := load(GEN_PATH)
        if v != null and v.short_sha != "":
            return v.short_sha
    # 2) Editor / dev run with a working tree: read HEAD live (cheap, dev-only).
    if OS.has_feature("editor"):
        var out := []
        if OS.execute("git", ["rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
            var sha := String(out[0]).strip_edges()
            if sha != "":
                return sha
    # 3) Last resort: neutral sentinel so "I don't know my SHA" is visible in the log.
    return FALLBACK_SHA

static func id() -> String:
    return "%s-%s-%s" % [MILESTONE, _date_stamp(), short_sha()]
```

```bash
# tools/stamp_build.sh  (run by CI export AND a local pre-playtest-build step)
SHA=$(git rev-parse --short HEAD)
DIRTY=$([ -n "$(git status --porcelain)" ] && echo "+dirty" || echo "")   # see Q3
cat > version.gen.tres <<EOF
[gd_resource type="Resource" script_class="BuildInfo" load_steps=2 format=3]
[ext_resource type="Script" path="res://systems/build_info.gd" id="1"]
[resource]
script = ExtResource("1")
short_sha = "${SHA}${DIRTY}"
EOF
```

`version.gen.tres` is **git-ignored** (it is a build artifact, regenerated each build) so it never carries a stale committed value the way `project.godot:18` did. The committed default (no `version.gen.tres`, not in editor) yields the neutral `0000000` sentinel — which is *itself* a useful signal: "this binary was built without the stamp step," immediately visible in the log instead of masquerading as a real commit.

**Telemetry contract is untouched:** `telemetry.gd` still stamps `"build": BuildVersion.id()` on the `run_started.data` exactly as today; only the *value* `id()` returns becomes correct. No `run_ended` arity change, no schema bump, no new row.

---

## 4. Files to touch

| File | Change | Owner |
|---|---|---|
| `systems/version.gd` | Replace the `ProjectSettings("application/config/build_sha")` read with the `version.gen.tres` → editor-git → neutral-fallback chain (§3b). Change `FALLBACK_SHA` to a neutral sentinel so a stale build is obvious. | I5 |
| `systems/build_info.gd` (new, tiny) | `class_name BuildInfo extends Resource` with `@export var short_sha: String`. The generated `.tres` binds to it. | I5 |
| `project.godot` | **Remove** the stale `config/build_sha="852b6e2"` line (the indirection is dropped) — or, if Q4 keeps the key, blank it so `has_setting`/empty falls through. | I5 |
| `tools/stamp_build.sh` (new) | Generate `version.gen.tres` from `git rev-parse --short HEAD` (+ optional dirty). Callable locally before a playtest build **and** from CI. | I5 |
| `.github/workflows/nightly.yml` | Swap the `sed`-into-`project.godot` bake (lines ~136–141) for a call to `tools/stamp_build.sh` before export, so the export pack contains `version.gen.tres`. | I5 |
| `.gitignore` | Add `version.gen.tres` (build artifact; never committed stale). | I5 |
| `tests/test_duration_loop_reentry.gd` (+ `.tscn` host) (new) | The §3a headless regression-lock: drives the loop-restart seam over 3 sequential `start_run`s, asserts a real nonzero `duration_s` on each end cause. | I5 |
| `tools/ci_smoke_test.gd` / CI | Wire the new duration test into the gate (or the GdUnit4 suite once vendored); verify smoke stays green after the `version.gd` change. | I5 (verify) |

**Files I5 does NOT touch:** `systems/game_state.gd` (the duration math is already correct — I5 only asserts it, unless Q1/Q5 surfaces a real path), `telemetry.gd` row shapes, `telemetry_schema.gd` (no schema bump), the `run_ended` signature.

---

## 5. Open Questions (Phase 3 / Director calls flagged)

1. **(a) Is `duration_s = 0` ever a *correct* same-frame fast-extract, or always a missed stamp?**
   *Data says always a missed stamp* — every zero run has an 11–53 s `t_ms` span, so none are sub-second. **But** the design should still decide: if a real same-frame extract is ever possible (player spawns on the gate), is `duration_s ≈ 0.000` *correct* (and RG2 floors/rounds at analysis), or do we want a minimum-1-frame floor at the source? **Recommendation:** keep raw float seconds at the source (BUG1 §8 Decision 2), let RG2 bucket — so a genuine instant extract logs ~0 honestly and is distinguishable from a missed stamp *because the build SHA now proves the binary had the fix*. **Confirm: no source-side floor.**

2. **(b) How does an exported Windows build learn its SHA with no git at runtime?**
   **Recommendation (§3b):** bake at build/export time into a shipped `version.gen.tres`; the runtime never calls git in an exported build. Q for the Director/builder: is a generated `.tres` resource preferred, or a generated `const` `.gd` file (`build_info.gd` with `const SHORT_SHA := "..."`)? The `.tres` keeps `version.gd` free of a regenerated source file in the diff; the `const` avoids a `load()` at boot. **Recommend the `.tres`** (artifact stays out of source history cleanly).

3. **Should the build id include dirty/uncommitted state?**
   A playtest build from an uncommitted working tree currently maps to whatever commit it's *near*, which mis-attributes its data. **Recommendation:** append a `+dirty` marker (`691d9da+dirty`) when `git status --porcelain` is non-empty, so a build off uncommitted work is *visibly* non-reproducible in the log rather than silently pinned to the wrong commit. **Director call:** is `+dirty` wanted in the human-facing `id()` string, or only logged as a separate `data.build_dirty` bool? (The latter avoids cluttering the id; the former is impossible to miss.)

4. **Drop the `ProjectSettings("application/config/build_sha")` indirection entirely, or repair it?**
   The committed stale value *is* the bug. **Recommendation:** drop it for the `version.gen.tres` artifact (a git-ignored artifact can't go stale in source). Repairing in place (blank the committed value + make the bake run locally too) is the smaller diff but leaves a footgun (anyone re-committing a non-empty value re-freezes the SHA). **Recommend drop.**

5. **Is there a re-entry path the audit missed?** (The task explicitly asks.)
   The audit found **none** — `start_new_run` is the single loop entry and always calls `start_run`. But two seams are worth a Phase-3 second look: (i) a run that ends via **timeout/death while the SellScreen of a *previous* run is still up** (the `_run_ended` guard + per-`start_run` re-stamp should make this safe, but confirm the guard ordering under a rapid Continue→immediate-fail), and (ii) whether any **demo scene** (`dive_clock_demo.gd`, `sell_screen_demo.gd`, `decision_hud_demo.gd`) calls an end path **without** a preceding `start_run` (those would log `_elapsed_s()` against a stale `_run_start_ms` from a prior run, or `0` if never started). Demos are not the playtest build, so this is **low severity**, but the headless test should optionally cover "end without start" → defensive `0` is acceptable there. **Flag for Phase 3.**

6. **The 4 `run_started` with no `run_ended` — in scope for I5?**
   4 of 70 runs (all in the zero-duration pre-fix sessions) have a `run_started` but no `run_ended` — abandoned mid-run (alt-F4 / session end). This is an **abandonment-funnel** signal for RG2, **not** a telemetry-hygiene defect, and is orthogonal to (a)/(b). **Recommendation: out of scope for I5; note it for RG2's abandonment analysis.** Confirm.

---

## 6. Acceptance criteria

1. **Every completed run logs a real `duration_s`** — the §3a headless test drives **three sequential `start_run` loop re-entries** (extract → timeout → death) and asserts each end emits a **nonzero, independent** `duration_s` within a frame-tolerance band, with telemetry OFF. Red blocks merge.
2. **`run_started.data.build` reflects the actual HEAD SHA** — in editor, local-headless, and exported builds; a build off an unstamped/uncommitted tree is **visibly** marked (neutral sentinel and/or `+dirty`, per Q3/Q4), never silently pinned to a stale commit.
3. **No `run_ended` arity change, no telemetry schema bump, no new row** — only `duration_s`'s value and `build`'s value become correct; `ENVELOPE_KEYS` and `TELEMETRY_SCHEMA_VERSION` unchanged.
4. **All-off control still == M1.0/M1.1 baseline** — I5 is pure hygiene; it changes no gameplay, so the all-off run is byte-identical save for a correct `build` value and a correct `duration_s`.
5. A worklog at `worklogs/<date>-I5-qa-playtest-coordinator.md` names the real commit SHA, lists the touched files, and records the new test passing + the smoke gate green — per the work-product contract.
