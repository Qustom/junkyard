# BUG1 — `run_ended.duration_s` is always 0

**Milestone:** M1.1 — Greybox Cost Axis · **Workstream:** (a) Foundations · **Wave:** 1
**Task id:** BUG1 · **Assignee role:** `general-purpose` (the programmer)
**Touch-map:** **[GS]** — edits `systems/game_state.gd` only.
**DependsOn:** none (can land wave 1 alongside R0; see §5 for the sequencing constraint vs R0/BUG2).
**Companion docs:** `M1.1_Breakdown.md` §4 (BUG1 entry, §6 wave order), `design/M1_Tasks/M1_As_Built.md` (`GameState`/`EventBus`/Telemetry sections).

> This is a **design / approach** doc. It specifies the fix and its test; it does **not** modify game code. The implementing programmer builds against it on a `general-purpose/BUG1` branch (or the combined `game_state.gd` branch — see §5).

---

## 1. Goal & design intent

`run_ended(reason, duration_s, depth_reached)` is the **locked dive-lifecycle signal** (`M1_As_Built.md` §EventBus) and `duration_s` is the **headline number of the M1.1 re-gate**. The whole milestone exists to answer *"does a depth-scaled cost axis make push-vs-extract a real, fun gamble?"* — and the gate reads that off **run-length distributions** (RG2: "run-length and max-depth distributions … side-by-side vs. the M1.0 baseline"). A short, tense, push-and-die run vs. a long cautious extract is exactly the spread RG2 must measure, and **run length is the primary signal of it**.

Today that number is a **literal `0.0` on every end path**. The only way to recover real run length is the Telemetry `t_ms` envelope field (`M1_As_Built.md` §Telemetry — `t_ms` is process-relative milliseconds stamped on every row), which is:
- **Fragile** — it is wall-time since process start, not run start, so deriving run length means differencing the `run_started` row's `t_ms` from the `run_ended` row's `t_ms` in post-processing. Any dropped/duplicated row, telemetry-off run, or multi-run session makes that arithmetic error-prone.
- **Off by default** — telemetry is opt-in/OFF by default (`M1_As_Built.md` §Telemetry, G6 consent). With telemetry off there is **no** run-length signal at all, even though `run_ended` still fires for in-engine observers.

**Design intent:** make `duration_s` *real and self-contained* — `GameState` captures run-start time at `start_run` and reports true elapsed seconds on the `run_ended` it emits, on **all three** end paths (extract / death / timeout). `t_ms` becomes a **cross-check**, not the source of truth.

This fix widens **no** signal arity (the `run_ended(reason, duration_s, depth_reached)` contract is locked — `M1.1_Breakdown.md` §2). It only fills the already-present `duration_s` slot with a non-zero value.

---

## 2. Root-cause analysis

`GameState` **never records when a run started**, so every end path constructs `duration_s` as a hardcoded `0.0` and passes it straight through to `end_run`.

**(a) No start time is captured.** `start_run` (`systems/game_state.gd:77`) resets all run-state but stamps **no** start time:

```gdscript
func start_run(band_id: StringName, seed: int) -> void:
	run_active = true
	_run_ended = false   # E3: fresh run → run-end guard clear
	run_seed = seed
	current_band = band_id
	current_depth = 0
	unbanked_value = 0
	...
	RNG.seed_from(seed)
	EventBus.run_started.emit(band_id, seed)
```

There is no `_run_start_*` member anywhere in the file (the run-state block, lines 38–61, has no time field).

**(b) Extract path passes 0.** `extract_and_end_run` (`systems/game_state.gd:163`) declares the duration and never assigns it:

```gdscript
	var duration_s: float = 0.0   # line 170 — declared 0, never updated
	...
	end_run(&"extract", duration_s)   # line 192 — emits run_ended(..., 0.0, ...)
```

**(c) Fail path (death + timeout) passes 0.** Both death and timeout converge on `fail_run` (`M1_As_Built.md` §GameState: `_on_player_died` and the `dive_clock_timeout` handler both route through `fail_run`). It has the identical bug (`systems/game_state.gd:284`):

```gdscript
	var duration_s: float = 0.0   # line 289 — declared 0, never updated
	...
	end_run(cause, duration_s)   # line 314 — emits run_ended(cause, 0.0, ...)
```

So **all three** end-causes (`&"extract"`, `&"death"`, `&"timeout"`) emit `duration_s == 0.0`.

**(d) `end_run` is a faithful relay — not the bug site.** `end_run` (`systems/game_state.gd:198`) just forwards whatever it is handed:

```gdscript
func end_run(reason: StringName, duration_s: float) -> void:
	run_active = false
	...
	EventBus.run_ended.emit(reason, duration_s, current_depth)
```

The defect is purely **"start time was never captured, so callers had nothing to compute from."** Fixing it is additive: record the start, compute elapsed at each call site.

**(e) Idempotency interaction.** Run-end is guarded by a single `_run_ended: bool` (`systems/game_state.gd:61`); `extract_and_end_run` and `fail_run` each early-return if it's already set (lines 166, 285), and `start_run` clears it (line 79). The duration must be computed **before/at** the first run-end that wins the guard, and a second (losing) end-path call must **not** recompute or re-emit — which it already won't, because it early-returns above the duration line. (See §3 for why this is naturally safe.)

---

## 3. Design / approach

### 3.1 Which clock — `Time.get_ticks_msec()` (recommended)

**Recommendation: `Time.get_ticks_msec()`** — monotonic milliseconds since engine start.

| Option | Behavior | Verdict |
|---|---|---|
| **`Time.get_ticks_msec()`** | Monotonic, wall-clock-ish, **unaffected by `Engine.time_scale`, frame rate, or physics step**. Same clock family that Telemetry's `t_ms` uses, so cross-checking is apples-to-apples. | **Chosen.** |
| `Time.get_unix_time_from_system()` | Real wall clock, but can jump (NTP/user clock changes) and is float-seconds with lower practical resolution; overkill and less stable for a stopwatch. | Rejected. |
| Accumulating `delta` in `_process`/`_physics_process` | Tracks *engine* time — would pause with the tree and scale with `Engine.time_scale`. That is *game-time*, which the Director **ruled out** for M1.1 (§8 Decision 1 — run length is wall-clock). Also needs a per-frame accumulator GameState doesn't have. | Rejected (Director-ratified). |

**Why monotonic ms specifically:**
- **Matches `t_ms` for cross-check.** `M1_As_Built.md` describes the envelope `t_ms` as process-relative milliseconds; both derive from the same monotonic source, so `duration_s ≈ (t_ms_end − t_ms_start)/1000` to within a frame. That is exactly the cross-check the acceptance criterion demands (§6).
- **Pause-agnostic, and wall-clock is the ratified semantic.** Run length is **wall-clock** (§8 Decision 1): real seconds the player sat in the run, pause-inclusive. The M1 sell screen *pauses the tree* (`M1_As_Built.md` §UI: `SellScreen` pauses the tree, F2), but run-end (`extract_and_end_run`/`fail_run`) fires **before** the sell screen presents, so no pause window is inside the measured interval anyway — wall-clock ms is correct here and simpler than game-time bookkeeping. (A future opposition that pauses *during* an active run is a new task to revisit, not a reopening of this decision — §8 Decision 1.)
- **No per-frame state.** GameState is an autoload with no `_process` loop for timing; a single stamped integer at start + a subtraction at end is the minimal, race-free change.

Store the start as an **int milliseconds** member, convert to **float seconds** only at the end (the `duration_s` param is `float`). Keeping the stored value in int ms avoids float drift across a long run. Per §8 Decision 2 the emitted `duration_s` is **raw float seconds — no rounding at the source**; any reporting-time rounding/bucketing is RG2's, not `GameState`'s.

### 3.2 Capture at `start_run`, compute at every end path

1. **Add one run-state member**: `_run_start_ms: int` (run-state — disposable, never persisted; lives with the other run-state in the lines 38–61 block).
2. **Stamp it in `start_run`** alongside the other run-state resets: `_run_start_ms = Time.get_ticks_msec()`. Place it near the top of `start_run` so it brackets the entire run (before `run_started.emit`).
3. **Add a private helper** `_elapsed_s() -> float` that returns `(Time.get_ticks_msec() - _run_start_ms) / 1000.0`. Single source of the elapsed computation → all three end paths agree by construction.
4. **Replace the two hardcoded `0.0` literals** with `_elapsed_s()`:
   - `extract_and_end_run`: `var duration_s: float = _elapsed_s()` (was line 170).
   - `fail_run`: `var duration_s: float = _elapsed_s()` (was line 289).
   Both already pass their local `duration_s` into `end_run` → so death, timeout, and extract are all correct with no further call-site change. (`fail_run` serves **both** death and timeout; fixing it once covers two of the three causes.)

### 3.3 Idempotency — guaranteed no double-compute

The `_run_ended` guard makes this safe **for free**, no extra logic needed:

- The `if _run_ended: return` check sits at the **top** of both `extract_and_end_run` (line 166) and `fail_run` (line 285) — **above** where `duration_s` is computed. So the **first** end-path to win the guard is the **only** one that ever calls `_elapsed_s()` and the only one that reaches `end_run` → exactly one `run_ended` with one duration. A losing same-frame caller (e.g. a timeout that ties a winning extract) early-returns before touching the clock.
- Therefore `duration_s` reflects the moment of the **winning** end-cause, which is correct (the run ended when that cause resolved). Extract wins a same-frame tie by the existing wiring (E3 #122 — extract handler ordered ahead of timeout), so a gate-reaching player's run length is stamped at the extract instant. No change to that ordering is needed or made.

**Do not** move the duration computation into `end_run`: `end_run` is also reachable directly (it's the shared tail) and computing there would re-derive time at relay, not at the decision point. Keep the compute at the two guarded entry points; `end_run` stays a pure relay.

### 3.4 Edge cases

- **Run never started, `end_run` called directly** (defensive): `_run_start_ms` defaults to `0`, so a stray direct `end_run` would *not* go through `_elapsed_s()` (it isn't changed) and stays a relay — no regression. The two real callers always pass through `start_run` first.
- **Clock not advancing in a single-frame headless test**: `Time.get_ticks_msec()` advances even within one process tick by real wall time, but a synchronous start→end in the same call stack can yield `duration_s` of `0.000…` (sub-millisecond). The acceptance bound is "within a frame," and the test (§6) inserts a real wait so elapsed is provably > 0 and matches `t_ms` — see §6.

---

## 4. Pseudocode

> Illustrative — exact final code is the programmer's. Reflects the real `game_state.gd` surface (`M1_As_Built.md` §GameState).

**(a) New run-state member** (in the run-state block ~lines 38–61):

```gdscript
# BUG1 (M1.1): monotonic ms stamped at start_run; basis for run duration on every
# end path. Run-state (disposable, never persisted). 0 until a run starts.
var _run_start_ms: int = 0
```

**(b) Stamp it in `start_run`** (add near the top, before run_started.emit):

```gdscript
func start_run(band_id: StringName, seed: int) -> void:
	run_active = true
	_run_ended = false
	_run_start_ms = Time.get_ticks_msec()   # BUG1: bracket the whole run
	run_seed = seed
	...
	EventBus.run_started.emit(band_id, seed)
```

**(c) The elapsed helper** (private, near end_run):

```gdscript
## BUG1 (M1.1): real elapsed seconds since start_run, via the monotonic engine
## clock (Time.get_ticks_msec). Single source so extract/death/timeout agree.
## Wall-clock (pause-inclusive) per BUG1 doc §8 Decision 1; run-end fires before the
## sell screen pauses, so no pause window is inside this interval (see §3.1).
func _elapsed_s() -> float:
	return float(Time.get_ticks_msec() - _run_start_ms) / 1000.0
```

**(d) Call-site changes** — replace the two `0.0` literals:

```gdscript
# in extract_and_end_run() — was: var duration_s: float = 0.0
	var duration_s: float = _elapsed_s()
	...
	end_run(&"extract", duration_s)   # → run_ended(&"extract", <real>, depth)
```

```gdscript
# in fail_run(cause) — was: var duration_s: float = 0.0   (covers death AND timeout)
	var duration_s: float = _elapsed_s()
	...
	end_run(cause, duration_s)        # → run_ended(&"death"|&"timeout", <real>, depth)
```

`end_run` is **unchanged** — it already relays `duration_s` faithfully (line 205).

---

## 5. Files to touch

- **`systems/game_state.gd`** — **the only file.** Adds one run-state member, one stamp line in `start_run`, one `_elapsed_s()` helper, and swaps two `0.0` literals. No signal-arity change, no `event_bus.gd` edit, no save-schema change.

**New file:** a GdUnit4-style headless test scene (see §6) under `tests/` — e.g. `tests/test_run_duration.gd` + a `.tscn` host. (Test artifact, not game code.)

### Coordination with BUG2 (same file)

BUG2 ("within-band depth not tracked") also edits `game_state.gd`, and R0 just touched it. Per `M1.1_Breakdown.md` §6 (wave 1):

> *"To avoid two agents editing `game_state.gd` at once, run **BUG1 + BUG2 sequentially after R0** (or as a single combined `game_state.gd` pass)."*

**Decision (§8 Decision 4, Director-ratified 2026-06-19): combine BUG1 + BUG2 into one `game_state.gd` pass on a shared branch `general-purpose/bug1-bug2-game-state`, dispatched after R0 is merged to `main`.** They are small, file-adjacent, and orthogonal in logic:
- BUG1 = start-time capture + `_elapsed_s()` + two call-site swaps (run-state time).
- BUG2 = live within-band depth tracking + `run_ended.depth_reached` (run-state depth + a `depth_changed` signal).

A combined pass means `game_state.gd` is opened **once** post-R0, avoiding a serialize-and-rebase dance between two tiny edits and the two-agents-on-one-file hazard. Per the work-product contract, the combined pass yields **one shared worklog** listing both BUG1 and BUG2 task ids and the single commit SHA. (The rejected alternative — strict one-task-one-branch, i.e. BUG1 first, merge, then BUG2 — is *not* used; the two were never to run in parallel worktrees on this file.) **CFG/TEL/BUG3 fan out only after the `game_state.gd` edits land** (they're file-disjoint and unaffected).

---

## 6. Test design

**Framework:** GdUnit4 is the project test framework, but it is **not yet vendored** (G2 owns vendoring). Until then the runnable check follows the existing M1 headless-scene pattern.

**Headless-autoload constraint (`M1_As_Built.md` §Testing constraints):** autoload globals (`EventBus`, `RNG`, `GameState`) **do not resolve as compile-time globals under `godot --headless --script`**. So this test must run as a **headless scene** (`.tscn` with an attached script that `quit()`s) — or resolve the autoloads via the SceneTree (`Engine.get_main_loop().root.get_node("GameState")` / `"EventBus"`). The duration test inherently needs `GameState`, `EventBus`, and a live tree (to `await` real time passing), so the **scene-host form is required** — a pure `--script` run can't await frames against the autoloads. When G2 lands GdUnit4 (a proper headless harness with autoloads), port this to a native GdUnit4 test.

**Core assertion:** for each of the three end-causes, `run_ended.duration_s` equals the real elapsed run time **within a frame**, and **cross-checks against `t_ms`**.

**Test shape (per end-cause: extract, death, timeout):**

1. Connect to `EventBus.run_ended` (capture `reason`, `duration_s`, `depth_reached`) and, for the cross-check, read Telemetry's `t_ms` at start and end (or stamp `Time.get_ticks_msec()` directly in the test as the reference clock — same monotonic source).
2. Record `t0 = Time.get_ticks_msec()`; call `GameState.start_run(&"test_band", 12345)`.
3. **`await` a known real interval** so elapsed is provably non-zero — e.g. `await get_tree().create_timer(0.2).timeout` (or N `process_frame`s totalling a measurable span). This is the reason the test must run in a live scene tree.
4. Trigger the specific end-cause:
   - **extract:** `GameState.extract_and_end_run()`.
   - **death:** `EventBus.player_died.emit(&"death")` (routes through `_on_player_died → fail_run(&"death")`).
   - **timeout:** `EventBus.dive_clock_timeout.emit()` (routes through `_on_dive_clock_timeout → fail_run(&"timeout")`).
5. Record `t1 = Time.get_ticks_msec()`; compute `expected_s = (t1 - t0)/1000.0`.
6. **Assert:**
   - `reason` matches the triggered cause.
   - `duration_s > 0.0` (the bug was exactly `== 0.0`).
   - `abs(duration_s - expected_s) <= frame_tolerance` where `frame_tolerance ≈ 1.0/30.0` s (one frame at the headless tick; choose a tolerance ≥ one process frame so a single-frame stamp skew passes). The "within a frame" bound from the acceptance criterion.
   - **Cross-check (authoritative): direct `Time.get_ticks_msec()` reference.** Per §8 Decision 3, the standing CI assertion cross-checks `duration_s` against the test's own `(t1 - t0)/1000.0` reference (same monotonic clock, independent of the code path under test) and **does not force telemetry on**: `abs(duration_s - expected_s) <= frame_tolerance`. When telemetry happens to be on, the test *may additionally* assert `abs(duration_s - (t_ms_end - t_ms_start)/1000.0) <= frame_tolerance` against the envelope, but that is an optional extra — the direct-clock check is the one that must hold with telemetry OFF (the default).
7. Reset between cases: a fresh `start_run` clears `_run_ended` and re-stamps `_run_start_ms`, so the three cases can run sequentially in one scene.

**Determinism note:** the test asserts a **tolerance band**, not an exact float (real wall time is never bit-exact). The `0.2s` wait is chosen comfortably above the frame tolerance so `duration_s > 0` is unambiguous and the band check is meaningful.

**Smoke-test gate:** the existing CI smoke test (`tools/ci_smoke_test.gd`) need not change; this is an added focused test. If wired into CI, the scene-host script must `quit()` with a non-zero code on assertion failure (the M1 headless-test convention).

---

## 7. Acceptance criteria

Restated from `M1.1_Breakdown.md` §4 (BUG1) and §7(4):

1. `run_ended.duration_s` equals the **real elapsed run time within a frame** for **extract, death, and timeout** end-causes (no longer a hardcoded `0.0`).
2. The value is **cross-checked against a direct `Time.get_ticks_msec()` reference** (the authoritative assertion, telemetry not forced on — §8 Decision 3) and agrees within a frame; an additional cross-check against the `t_ms` envelope is optional when telemetry is on.
3. A **GdUnit4 assertion covers it** (in the interim, the headless-scene form per §6; ported to native GdUnit4 once G2 vendors it).
4. **No new telemetry row and no signal-arity change** — the fix only makes the existing `run_ended.duration_s` meaningful (`M1.1_Breakdown.md` §4 BUG1: *"makes the existing `run_ended.duration_s` meaningful (no new row)"*; the locked `run_ended(reason, duration_s, depth_reached)` arity is untouched).
5. With the all-off baseline config, M1.0 behavior is otherwise unchanged (this is a pure additive fix to a previously-zero field).

A worklog at `worklogs/<date>-BUG1-general-purpose.md` (or the combined BUG1+BUG2 worklog) names the real commit SHA, lists `systems/game_state.gd` + the test file, and records the test result — per the work-product contract, no worklog → not done.

---

## 8. Resolved Decisions (Director-ratified 2026-06-19 — apply-all-recommendations)

The Director ratified **every** recommendation from this doc's prior open-questions set as a committed decision on 2026-06-19. They are now binding on the implementation; the body of this doc (§3, §6) reflects them as the single chosen approach.

1. **Decision: run length is wall-clock — measure monotonic wall-ish time via `Time.get_ticks_msec()`** (pause-inclusive), not un-paused game-time. *Rationale:* the M1.1 gate asks "how long was the *gamble*?", which is real seconds the player sat in the run; it is also the simpler, race-free, per-frame-state-free change, and in M1.1 no pause falls inside the measured interval anyway (the sell screen pauses *after* run-end). If a future opposition pauses *during* an active run, that is a new task to revisit game-time semantics — not a reopening of this decision.

2. **Decision: keep `duration_s` as raw float seconds on the signal — no rounding at the source.** *Rationale:* the int-ms basis gives ~1 ms precision (ample), and emitting raw float lets RG2 bucket/round at analysis time so no information is lost upstream; any reporting-time rounding lives in the RG2 analysis, not in `GameState`.

3. **Decision: the standing CI cross-check uses a direct `Time.get_ticks_msec()` reference (telemetry not forced on).** *Rationale:* it is the same monotonic clock as the `t_ms` envelope yet stays independent of the code path under test, keeps telemetry OFF as the default, and avoids coupling the `GameState` duration test to telemetry state; when telemetry happens to be on, the test may additionally read `t_ms`, but the direct-clock reference is the authoritative assertion.

4. **Decision: implement BUG1 and BUG2 as one combined `game_state.gd` pass on a shared branch (`general-purpose/bug1-bug2-game-state`), dispatched after R0 is merged to `main`.** *Rationale:* both edits are small, file-adjacent, and logically orthogonal, so opening `game_state.gd` once post-R0 avoids a serialize-and-rebase dance and the two-agents-on-one-file hazard; the combined pass yields one shared worklog listing both task ids and the single commit SHA (see §5).
