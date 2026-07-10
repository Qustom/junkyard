# V8 — Record CI test wall-clock (R9, cheap-now scope; sharding DEFERRED per DR-5)

> Phase-2 per-task design doc for M1.12 (Scaling Debt Paydown). Source: `design/M1_12_Tasks/M1.12_Breakdown.md`
> task card **V8** (Wave 1) and its as-built anchor (R9). Report source: `design/report-09072026.docx`
> §10 R9 — *"Watch test wall-clock; shard when it bites (LOW, effort S now, M later)."*
> **This is a design doc. No code changes are made here.**

## Scope (restated, binding)

- Instrument only. **Do not** restructure the runner, **do not** introduce concurrency (the
  `godot-headless-test-invocation` memory: never run concurrent headless Godot instances against
  one project — import-lock deadlock), **do not** change which tests run or their pass/fail.
- Make the wall-clock **trend visible** in CI output, across commits, cheaply.
- Sharding scene tests (the report's "later" half) is **explicitly out of scope** — filed as a
  follow-up only (see Open Questions / debt ledger below).

---

## (a) Research on the premise

### What the report actually says (verbatim, `design/report-09072026.docx` §10 R9)

> "63 self-quitting scene tests each boot a fresh headless Godot process, serially, and the
> per-milestone RG capstones (15 already) only accrete. Nothing is wrong today, but the trajectory
> is linear boot-cost growth with a known deadlock constraint (no concurrent headless instances
> against one project). Cheap now: record suite wall-clock in CI to see the trend. Later: shard
> scene tests across copies of the import cache, or fold more of them into the single-process
> GdUnit4 sweep."

### What is actually in the repo today (verified 2026-07-10)

**The 63 count is the scene-test population, not what CI currently runs.** `find Game/tests -maxdepth 1 -name "*.tscn" | wc -l` → **63** self-quitting scene tests (each a `Node`-rooted `.tscn`
pairing an `ext_resource` script that runs assertions in `_ready()`/over a few physics frames and
then `get_tree().quit()` — e.g. `Game/tests/test_ambusher.tscn` → `test_ambusher.gd`). None of the
top-level 63 `extends GdUnitTestSuite` (`grep -l "extends GdUnitTestSuite" Game/tests/*.gd` → 0
hits) — they are CLAUDE.md's "verify/knob test... run as a SCENE" idiom (`godot --headless
res://tests/<name>.tscn`), not GdUnit4 suites. The **GdUnit4 logic suites** live in **subfolders**
and are a *separate, small, single-process population*: `Game/tests/economy/test_banking_math.gd`,
`Game/tests/economy/test_death_drop_pockets.gd`, `Game/tests/inventory/test_inventory_capacity.gd`,
`Game/tests/procgen/test_layout_determinism.gd` (4 suites, one boot via
`-a res://tests` in the CI step below).

**What `.github/workflows/ci.yml` actually invokes today, in order** (all steps run
`working-directory: Game`, confirmed 2026-07-10):

| Step (ci.yml line) | Command | Boots |
|---|---|---|
| `Import project` (`ci.yml:43-44`) | `godot --headless --import` | 1 process |
| `Run smoke test (CI gate)` (`ci.yml:46-47`) | `godot --headless --script res://tools/ci_smoke_test.gd` | 1 process |
| `Run save-migration test` (`ci.yml:49-54`) | `godot --headless res://tests/test_save_migration.tscn` | 1 process |
| `Run duration loop-reentry test` (`ci.yml:56-61`) | `godot --headless res://tests/test_duration_loop_reentry.tscn` | 1 process |
| `Run GdUnit4 logic tests` (`ci.yml:63-74`) | `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests` | 1 process (runs all 4 GdUnit4 suites in-process) |

`.github/workflows/nightly.yml`'s `test:` job (`nightly.yml:48-100`) repeats the same import +
smoke + save-migration + GdUnit4 steps and additionally boots two more scene tests individually:
`Loop-drive verification` (`nightly.yml:89-90`, `res://tests/test_loop_drive.tscn`) and
`Main-game integration drive` (`nightly.yml:92-93`, `res://tests/test_main_game_loop.tscn`).

**So today's automated CI boots ~5 Godot processes per run (ci.yml) / ~7 (nightly.yml)** — a small,
*curated* subset of the 63. The other ~59 scene tests (including the 5 RG-family capstones present
in-repo — `test_rg1_loop_verify.tscn`, `test_rg1_m12_verify.tscn`, `test_rg1_m13_verify.tscn`,
`test_rg1_m14_verify.tscn`, `test_rg1_m15_verify.tscn` — the report's "15 already" is a broader
historical count across per-round verify artifacts, not just what's live under `Game/tests/`
today; the discrepancy doesn't change this task's scope) are run **manually, on demand, by
whichever agent/human is verifying a specific task** — per CLAUDE.md's Commands section: `godot
--headless --path Game res://tests/<name>.tscn # run a verify/knob test (as a SCENE, never
--script)`. Each of those manual runs is also a fresh headless boot, and the population that
*could* someday be pulled into an exhaustive CI sweep is the full 63 (growing by ~1 RG capstone
per milestone sub-version — 4 already just across M1.2→M1.5, i.e. `test_rg1_m12/13/14/15_verify.tscn`).

**The actual boot-cost reality this task must make visible:** every `godot --headless <script-or-scene>`
invocation pays a fixed Godot-engine-boot + project-import-resolve cost *before* the test's own
logic runs (this is the "serial, one process per test" model CLAUDE.md's Commands section
codifies and the memory `godot-headless-test-invocation` explicitly forbids parallelizing against
one project — import-lock deadlock). Today's ~5–7-process CI is cheap. The trend the report flags
is: (1) CI's own curated list only grows (one more RG capstone step lands roughly every
sub-version — V8 does not change that; it just measures it), and (2) if a future task ever folds
more of the 63 into CI (the report's "later: fold more into the single-process GdUnit4 sweep"),
the wall-clock is exactly what would justify or refute that move. **Nothing is broken today** —
this task is instrumentation ahead of the bite, per the report's own framing.

### The no-concurrency constraint (binding, from memory + `M1.12_Breakdown.md`)

The project memory `godot-headless-test-invocation` is explicit: **never run concurrent headless
Godot instances against one project — import-lock deadlock.** `ci.yml`'s steps already run
*serially* by construction (sequential `steps:` in one job), so this constraint is automatically
respected by "just add timing to the existing serial steps" — no new parallelism is introduced,
and none should be.

### Existing timing precedent in-repo

`Game/tools/stamp_build.sh` and `Game/tools/push_itch.sh` are the closest existing "small bash
wrapper around a build step" precedent (both plain bash, no test framework, run from
`working-directory: Game`/repo root respectively) — V8's mechanism (a `date`/`time`-based bash
wrapper per CI step) matches that established idiom rather than inventing a new tool. There is no
existing wall-clock instrumentation anywhere in `ci.yml`/`nightly.yml` today, and no
`Game/tests/README.md` exists yet (`find Game -maxdepth 2 -iname "*readme*"` finds none under
`Game/`; the only test-adjacent README is `Game/tools/playtest/tester_readme.md`, which is a
**player/tester-facing** doc for playtest builds, not a developer test-suite doc — the wrong place
for this note). V8 creates a small new `Game/tests/README.md`.

---

## (b) Pseudocode / the concrete change

### Mechanism: per-step epoch timestamps in the existing `ci.yml` steps, no new job/tool

Godot itself doesn't need to change (no touching `ci_smoke_test.gd`, no touching the GdUnit4
runner, no new `.gd` test). Each existing `run:` step already executes as its own shell block —
wrap each with a `date +%s` before/after and echo the delta, then a final step sums them. This
keeps every existing command line **byte-for-byte identical** (so pass/fail behavior is provably
untouched) and only adds bash arithmetic around it.

```yaml
# .github/workflows/ci.yml — illustrative diff, NOT applied by this doc.
# Every existing `run:` step becomes: capture start epoch -> run the SAME command,
# unmodified -> capture end epoch -> echo "<step-name> took Ns" to the step's own log
# AND append a machine-parseable line to a per-job scratch file for the final summary step.

      - name: Run smoke test (CI gate)
        run: |
          _t0=$(date +%s)
          ~/godot-bin/godot --headless --script res://tools/ci_smoke_test.gd
          _rc=$?
          _t1=$(date +%s)
          echo "wallclock smoke_test $((_t1 - _t0))s" | tee -a /tmp/ci_wallclock.log
          exit $_rc   # preserve the original non-zero-on-failure gate behavior exactly

      # ... same wrap for save-migration, duration loop-reentry, GdUnit4 steps ...

      - name: Report suite wall-clock (V8 — instrumentation only, non-gating)
        if: always()   # runs even if an earlier step failed, so a slow-then-red run still reports
        run: |
          echo "== THE FAR YARD headless suite wall-clock =="
          cat /tmp/ci_wallclock.log || echo "(no timing captured — earlier step may have aborted the job)"
          awk '{sum+=$3} END {print "TOTAL headless suite wallclock: " sum "s (commit " ENVIRON["GITHUB_SHA"] ")"}' \
            /tmp/ci_wallclock.log 2>/dev/null || true
```

**Why this shape and not a bash-`time`-wraps-the-whole-job approach:** GitHub Actions already
timestamps every step in its own UI (visible per-run, but not diffable/greppable across runs
without clicking through each run). Emitting an explicit `TOTAL headless suite wallclock: Ns`
line to the **job log** (searchable via `gh run view --log` / the Actions UI's raw log, and
`grep`-able if anyone ever pipes CI logs somewhere) is the cheap, immediately-actionable form the
report asks for ("record suite wall-clock in CI to see the trend") without inventing a new
artifact, dashboard, or dependency. Per-suite lines (one `wallclock <step> Ns` per existing step)
come for free from wrapping each step the same way — cheap, so V8 includes them (the task card's
"and, if cheap, per-suite times").

**Alternative considered and rejected for V8's scope:** a GitHub Actions "job summary"
(`$GITHUB_STEP_SUMMARY`) markdown table. Slightly nicer UI, same cost to add (one more `echo >>`
target) — **left as an Open Question below** since it's a one-line addition either way and
doesn't change the design's shape.

### `nightly.yml` gets the same wrap on its two extra scene-test steps

`nightly.yml:89-93` (`test_loop_drive.tscn`, `test_main_game_loop.tscn`) get the identical
before/after timestamp wrap — same idiom, so the nightly job's wall-clock (currently the larger
of the two CI surfaces, at ~7 processes) is measured too.

### `Game/tests/README.md` (new file — the required short note)

```markdown
# Game/tests/

... (brief orientation: 63 top-level self-quitting scene tests booted individually via
`godot --headless res://tests/<name>.tscn`, run manually per-task per CLAUDE.md's Commands
section; 4 GdUnit4 logic suites under economy/, inventory/, procgen/ booted together via
`tools/run_gdunit.sh`; CI (`.github/workflows/ci.yml`) runs a small curated subset directly as
steps + the full GdUnit4 sweep.)

## Suite wall-clock (M1.12 V8)

CI prints each step's wall-clock and a suite total to the job log on every run (see
`.github/workflows/ci.yml`, the `wallclock ...` / `TOTAL headless suite wallclock` lines). This
exists to make the serial-boot-cost trend VISIBLE as more scene tests + RG capstones accrete —
it does not gate merges and does not change which tests run.

**Deferred follow-up (post-M1.12, not filed as a task yet):** if/when the wall-clock trend (or a
future decision to fold more of the 63 manual scene tests into automated CI) makes serial boot
cost bite, shard scene tests across copies of the import cache, or fold more of them into the
single-process GdUnit4 sweep (per `design/report-09072026.docx` §10 R9's "later" half) — respecting
the no-concurrent-headless-instances-against-one-project constraint (a shard = a separate cached
`.godot`/import directory per lane, not concurrent processes against the SAME project state).
```

---

## Open Questions

1. **Total-only vs per-suite timing.** The task card allows "and, if cheap, per-suite times." Given
   the wrap-every-step mechanism above, per-suite timing is *free* (each existing step already gets
   its own before/after pair) — is there any reason to do total-only instead? *Leaning: include
   per-suite; no added risk or LOC (each step already has its own `run:` block to wrap).*
2. **Where to record it — CI log only vs a committed trend file.** The design above only prints to
   the ephemeral CI job log (grep-able per-run via `gh run view --log`, but not diffable across
   commits without pulling multiple logs). An alternative: append one line per run to a **committed**
   `Game/tests/wallclock_log.csv` (or similar) so the trend is `git log`-able directly. This adds a
   commit-back step to CI (a bot commit, or an artifact + manual append) — meaningfully more
   machinery than "print to the log," and arguably premature for a LOW-priority/effort-S
   instrumentation task. *Recommend: CI-log-only for V8; a committed trend file is itself the kind
   of follow-up that should ride along with whatever "shard or fold into GdUnit4" work eventually
   happens, since that work will want real historical data anyway.*
3. **`$GITHUB_STEP_SUMMARY` job-summary table vs plain `echo`/`tee` to the step log.** Both are a
   ~1-line addition; the job summary renders as a nicer markdown table in the Actions UI. *Resolve
   on merit in Phase 3/implementation — not a design fork, purely a formatting choice.*
4. **The exact sharding follow-up to file for post-M1.12.** DR-5 defers sharding; V8 should leave a
   clean handoff rather than a vague "later." Proposed filing (NOT created by this doc — a
   recommendation for whoever opens the next iteration's backlog): a LOW-priority, effort-M task
   titled *"Shard or GdUnit4-fold the scene-test suite"* scoped as: (a) audit which of the 63
   self-quitting scene tests could be rewritten as GdUnit4 suites (folding them into the existing
   single-process sweep, eliminating their per-test boot cost entirely — likely the highest-value
   half, since several of the 63 are pure-logic checks that don't need a live SceneTree scene, just
   the GdUnit4 harness), vs (b) which genuinely need a booted scene (autoload/physics-dependent
   ones, e.g. `test_ambusher.tscn`'s live `ChargeLane`/physics-frame assertions) and would need real
   sharding (parallel CI **jobs**, each with its OWN checkout + import cache — NOT concurrent
   processes against one shared project directory, which is what the deadlock constraint forbids).
   This should be triggered by the wall-clock data V8 now surfaces (e.g., "flag for the sharding
   task once CI's own curated subset exceeds N minutes" — a number the Director/producer can set
   once a few runs of real data exist under V8).
5. **Does the "if: always()" summary step change failure semantics?** The summary step is
   `if: always()` and itself must not fail the job (a `wallclock` log that's empty because an
   earlier step aborted should not throw a NEW error) — confirmed as a "informational, never
   red" step in the design above (`|| true` on the awk summary, `|| echo "(no timing captured...)"`
   on the cat). *Resolved in the pseudocode already; flagging so implementation preserves it.*

None of these need Director review — they're implementation-detail/process calls that resolve on
technical merit, consistent with the breakdown's framing of V8 as a scope call already
Director-dispositioned via DR-5 (record-only now, sharding deferred).

---

## Debt ledger (one line)

Instrumentation only — no runner restructuring, no concurrency, no behavior change to which tests
run or their pass/fail; net LOC added is small (a `date`/`echo` wrap per existing CI step + one new
summary step + a new `Game/tests/README.md`), net LOC removed is zero (nothing is deleted), and the
payoff is a previously-invisible boot-cost trend becoming visible before it needs the deferred
sharding follow-up (Open Question 4).

---

## Resolved Decisions (Phase 3)

*Fresh-eyes review, 2026-07-10. Verified against the live repo: `find Game/tests -maxdepth 1 -name
"*.tscn" | wc -l` → 63; `grep -rl "extends GdUnitTestSuite" Game/tests --include="*.gd" | wc -l` →
4 (all under `economy/`, `inventory/`, `procgen/`); `find Game -maxdepth 3 -iname "*readme*"` →
only `Game/tools/playtest/tester_readme.md` (no `Game/tests/README.md` today). `.github/workflows/ci.yml`
and `nightly.yml` were read in full and match the design's line-cited step table exactly (import →
smoke → save-migration → duration loop-reentry → GdUnit4 in `ci.yml`; the same four plus
`test_loop_drive.tscn` / `test_main_game_loop.tscn` at `nightly.yml:89-90` / `92-93` in the `test:`
job). `ci_smoke_test.gd` has zero references to `time`/`date`/`wallclock`/`duration` — no prior
instrumentation to collide with. The design's factual premise is sound; no correction needed to
Section (a) or (b).*

1. **Total-only vs per-suite timing → per-suite (confirmed).** The design's mechanism wraps every
   `run:` block with its own before/after epoch pair regardless of whether the emitted output is a
   sum or a list — the marginal cost of also echoing each step's individual delta is one more
   `echo` per step, already-open editing surface, zero added risk. There is no version of "total
   only" that is cheaper to implement than "total + per-step," since the summary step's `awk` sum
   requires the per-step lines to exist as its input in the first place. **Decision: emit both —
   one `wallclock <step> Ns` line per wrapped step (to the step's own log, so it's visible without
   opening the summary step) AND the `TOTAL headless suite wallclock: Ns` line in the dedicated
   summary step.** No Director input needed; this is arithmetic, not a design fork.

2. **CI-log-only vs a committed trend file → CI-log-only (confirmed).** A committed
   `Game/tests/wallclock_log.csv` would need either (a) a bot commit back to `main` from a CI job —
   which fights the repo's stated git discipline (worklog-per-task, human-authored commits, no
   silent bot writes to `main` outside the established stamp/changelog flow) — or (b) a
   human/agent manually transcribing numbers from run logs into a file periodically, which is
   busywork with no consumer yet. Nothing in M1.12's scope reads or gates on historical wall-clock
   data; the only consumer today is a human skimming `gh run view --log` or the Actions UI to eyeball
   the trend. Building persistence machinery for a metric with zero current readers is exactly the
   kind of speculative scope V8's own "cheap-now" framing (and DR-5) argues against. **Decision:
   CI-log-only for V8, as designed.** If/when the deferred sharding task (Open Question 4 / the R9
   "later" half) is actually scheduled, THAT task is the right place to add a committed trend file,
   because by then there will be a concrete consumer (deciding whether to shard) that needs
   multi-run history — collecting data nobody reads yet is waste, not instrumentation.

3. **`$GITHUB_STEP_SUMMARY` job-summary table vs plain `echo`/`tee` → job-summary (upgrade, resolved
   on merit).** Re-examining this past what the design doc flagged as "purely a formatting
   choice": `$GITHUB_STEP_SUMMARY` is a file path GitHub Actions exposes to every step; appending
   markdown to it renders as a rich panel at the top of the run's summary page, visible without
   drilling into any individual step's raw log — meaningfully better ergonomics than `tee`-to-a-log
   line buried inside a step's stdout, for the exact "make the trend visible" goal this task exists
   to serve, at identical cost (one more `>>` target already being written in the awk step). There
   is no reason to prefer log-only now that the two are compared side by side. **Decision: write
   BOTH — keep the plain `echo`/`tee` to the step log (so `gh run view --log` / raw-log grepping
   still works unchanged) AND append the same per-step + total lines as a small markdown table to
   `$GITHUB_STEP_SUMMARY`** (e.g. `echo "| ${_step_name} | ${_dur}s |" >> "$GITHUB_STEP_SUMMARY"`).
   This is additive only — it does not replace or risk the log-based output the rest of this doc's
   design already treats as the source of truth for scripts/greps.

4. **The exact deferred-sharding follow-up to file → confirmed, tightened for actionability.** The
   design's proposed filing (Open Question 4) is directionally right and is RATIFIED as-is, with
   the trigger condition made concrete so it doesn't sit as a vague "later" a second time. **Filed
   wording (to be opened as a real backlog task once M1.12 closes, title and scope fixed now so
   Phase 4/VG3 can act on it without re-deriving it):**

   > **Title:** "Shard or GdUnit4-fold the scene-test suite (post-M1.12 follow-up to V8/R9)"
   > **Priority/effort:** LOW / effort-M (per the report's own R9 framing).
   > **Trigger:** open this task once V8's wall-clock data (collected across the runs following
   > M1.12's merge) shows CI's own curated subset (today ~5 processes on `ci.yml`, ~7 on
   > `nightly.yml`) exceeding **5 minutes total wall-clock** on `ci.yml` specifically (the PR-blocking
   > path, where boot-cost latency is felt on every push/PR — `nightly.yml`'s cost is felt once a day
   > and is a weaker forcing function). 5 minutes is chosen as a concrete, revisable number: it is
   > roughly 3-4x today's likely actual total (a handful of Godot-boot-plus-light-test steps at
   > current scope), so crossing it signals the curated set has grown materially past M1.12's
   > baseline, not just normal jitter. The producer/Director may retune this threshold once a few
   > weeks of real V8 data exist — the number is a starting trigger, not a permanent constant.
   > **Scope (two halves, from the design doc's Section (b)/(a), unchanged):**
   > (a) Audit which of the 63 self-quitting scene tests are pure-logic (no live SceneTree/physics
   > dependency) and could be rewritten as GdUnit4 suites, folding them into the existing
   > single-process sweep and eliminating their per-test boot cost entirely.
   > (b) For the remainder that genuinely need a booted scene (autoload/physics-dependent, e.g.
   > `test_ambusher.tscn`), shard via parallel CI **jobs**, each with its own checkout + import
   > cache — explicitly NOT concurrent processes against one shared project directory (which the
   > `godot-headless-test-invocation` memory's deadlock constraint forbids).
   > **Not in scope:** changing any test's pass/fail behavior; this is boot-cost/CI-topology only.

   This filing is a recommendation for whoever opens the next iteration's backlog (per the design
   doc's own framing) — it is not created as a live task by this doc or by V8's implementation.

5. **`if: always()` summary-step failure semantics → confirmed correct, no change.** The design's
   `|| true` / `|| echo "(no timing captured...)"` guards on the summary step are the right shape:
   an instrumentation step must never be the thing that turns a run red, and must never mask an
   earlier real failure by appearing to "fix" the job (the guarded commands only affect the
   summary step's own exit code, not the exit codes already captured and `exit $_rc`'d by the
   wrapped steps above it). Implementation should preserve this exactly as pseudocoded.

**Director review: none required.** All five items resolve on technical/process merit, consistent
with the breakdown's own framing (Open Questions preamble, and DR-5's "record-only, defer sharding"
disposition, which this resolution operationalizes rather than revisits). Item 3 upgrades the
design's tentative "resolve in Phase 3" placeholder to a concrete "both" answer; item 4 turns a
recommendation into a copy-pasteable task filing; items 1, 2, and 5 confirm the design doc's own
leanings after independent verification against the live repo. This design doc is LOCKED for V8's
Wave 1 implementation.
