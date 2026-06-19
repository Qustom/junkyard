# THE FAR YARD — Playtest Build: Tester README (M1.2)

Thanks for playing the greybox build! This is a **rough prototype** — flat-colour
shapes, no art or sound yet. We are testing **one thing: is the core loop fun?**

The loop: **start a run → dive into a junk band → grab junk → beat the clock →
decide push deeper or extract → cash out → do it again.**

**M1.1 added a "cost axis"** — four *oppositions* you turn on in the **Config menu** (a pursuing
hazard, a costlier return trip, a rising exposure meter, and a maze/fog). **M1.2 makes that cost
axis *legible and fair* and adds a *level scale*.** What changed since last round:

- **The hazard actually catches now** (last round it never did) — and it visibly closes through
  the halls instead of getting stuck on walls.
- **You can make the levels bigger** (a new **Level Scale** section) — bigger rooms and/or more
  rooms, so a dive feels like a *journey* instead of a 17-second sprint.
- **The attrition is visible:** a prominent **exposure bar** with a penalty flash, and a **toll
  pulse / "−N"** when the costlier-return trip bites.
- **The dark actually hides** — beyond your vision radius the geometry is hidden (not just dimmed),
  with a fog memory of where you've been and a clear **"lost"** cue.

The question this round: **now that the gamble is legible and the levels are worth traversing, is
"push deeper vs extract now" a real, tense, fun decision?**

## How to run

- **Windows:** unzip the build, run `TheFarYard.exe`.
- Controls:
  - **WASD / arrows / left stick** — move
  - **E (or A / south button)** — interact: grab junk, and **extract** at the green gate
  - **Q** — alternate extract action (same as E at the gate)
  - **K** — debug "die" (for testing the death/lose path on purpose)
  - **Esc** — pause
- From the menu, click **START RUN**. The build id is shown bottom-right
  (e.g. `build m1-20260619-<sha>`) — **please quote it in your feedback.** (The SHA is now the
  *real* commit; if you ever see `0000000` the build was made without the stamp step — tell us.)

## Setting a config (M1.2) — and how we know which config you ran

The **Config menu** beside START RUN exposes every opposition knob **plus a new Level Scale
section**. To run an experiment:

1. **Toggle** the oppositions you want with their master switches (R1 / R2 / R3 / R4), and
   tune their sliders (each also has a type-exact box). The top line summarises the run
   (`RUN: R1[x] R2[ ] R3[x] R4[ ] · seed auto`).
2. **Level Scale (new in M1.2):** turn on **Level Scale**, then raise **Room Size** (a
   multiplier, 1.0 = old baseline; try 1.5 / 2.0 / 3.0) and/or **Room Count** (−1 = baseline ~12;
   bump it to 16–24). Bigger rooms make a dive a real journey. *(Level scale is separate from the
   oppositions — a "baseline + bigger rooms" run is still a valid control.)*
3. **Type a `build_tag`** in the Meta section. Prefix every M1.2 sweep with **`m12-`** then a short
   handle, e.g. `m12-size-2.0`, `m12-r1-catch`, `m12-all-on`. This is your human-readable label —
   one tag per distinct config — and it's how we separate M1.2 runs from the old M1.0/M1.1 logs.
4. **START RUN.** Press **Continue** on the sell screen to re-run the *same* config (new
   layout) as many times as you like — that's a "sweep." Press **Back to Config** to
   return to the menu and switch to a different config mid-session (no need to quit).
5. **Reset** (in the Config menu) puts every knob back to all-off — the baseline
   control. Run a few baseline runs too, for comparison.

### Suggested sweep order (what we most want data on)

1. **Baseline** (`m12-baseline`) — all off / Reset. A few runs.
2. **Level size** (`m12-size-1.0` … `m12-size-3.0`) — Level Scale on, Room Count at baseline,
   sweep Room Size. *Does a bigger level fix the "too short" feeling?*
3. **Hazard** (`m12-r1-catch`) — R1 on, on a level size that felt good. *Does the chase + catch
   make pushing deeper scary?*
4. **Exposure toll** (`m12-r2r3-toll`) — R2 egress toll set to **exposure** + R3 on. *Watch the
   exposure bar jump when you retreat — the toll now feeds the meter.*
5. **Dark/maze** (`m12-r4-dark`) — R4 on with a vision radius tuned to the room size. *Does the
   dark + getting-lost create tension?*
6. **Everything** (`m12-all-on`) — all four + a level scale.

**You do NOT need to write down the knob values.** Every run stamps its **full config
snapshot** (`run_config`) plus your `build_tag` and the auto build id onto its telemetry —
that is the *ground truth* for which config ran. Just set the `build_tag` and play.

## Please enable telemetry (it's how we read the playtest)

Telemetry is **OFF by default** (privacy — nothing is written until you turn it on).
It logs **no personal info**: only run lengths, depths, junk values, and run
outcomes, written **locally** to a file you send back. It is the single most useful
thing you can do for us.

- Enable it in the in-game settings/telemetry toggle (or as instructed in the build).
- Once enabled, it writes to `user://telemetry/run_log.jsonl` as you play.
- Each `run_started` line carries a `run_config` snapshot (your full config — now including the
  new **Level Scale** knobs + your `build_tag`) and the **real** build id, so a run is a
  self-labelling experiment — that's why you don't hand-transcribe knobs. The opposition events
  (hazard catch/return-cost/exposure/nav) log alongside it so we can see what actually happened
  during the run, and every finished run logs a real `duration_s` (so we can read run lengths).

## Where the files live (so you can send them back)

`user://` resolves to a per-OS app-data folder. For THE FAR YARD:

- **Windows:** `%APPDATA%\Godot\app_userdata\THE FAR YARD\`
  (paste `%APPDATA%\Godot\app_userdata\THE FAR YARD` into Explorer's address bar)
- **Linux:** `~/.local/share/godot/app_userdata/THE FAR YARD/`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/THE FAR YARD/`

Inside that folder:
- `telemetry/run_log.jsonl` — your play telemetry (one JSON line per event).
- `logs/godot.log` — the engine log (a crash trace lands here; file logging is ON).
- `settings.cfg` — your telemetry opt-in (no need to send this).

## How to send your results back

After your session, **zip and send these two folders/files:**
1. `telemetry/run_log.jsonl`
2. `logs/` (the whole folder — helps us catch any crash you hit)

Send them to the team channel along with **the build id** and a sentence or two on
how it felt. (The structured survey is coming separately — this README is just for
getting the build running and the logs back.)

## If it crashes or soft-locks

- Note what you were doing, grab `logs/godot.log`, and send it. A real crash trace
  is gold — far cheaper for us than guessing.
- If you get stuck on a screen with no way out, that's a bug — tell us which screen.
