# THE FAR YARD — Playtest Build: Tester README (G3)

Thanks for playing the greybox build! This is a **rough prototype** — flat-colour
shapes, no art or sound yet. We are testing **one thing: is the core loop fun?**

The loop: **start a run → dive into a junk band → grab junk → beat the clock →
decide push deeper or extract → cash out → do it again.**

## How to run

- **Windows:** unzip the build, run `TheFarYard.exe`.
- Controls:
  - **WASD / arrows / left stick** — move
  - **E (or A / south button)** — interact: grab junk, and **extract** at the green gate
  - **Q** — alternate extract action (same as E at the gate)
  - **K** — debug "die" (for testing the death/lose path on purpose)
  - **Esc** — pause
- From the menu, click **START RUN**. The build id is shown bottom-right
  (e.g. `build m1-20260618-852b6e2`) — **please quote it in your feedback.**

## Please enable telemetry (it's how we read the playtest)

Telemetry is **OFF by default** (privacy — nothing is written until you turn it on).
It logs **no personal info**: only run lengths, depths, junk values, and run
outcomes, written **locally** to a file you send back. It is the single most useful
thing you can do for us.

- Enable it in the in-game settings/telemetry toggle (or as instructed in the build).
- Once enabled, it writes to `user://telemetry/run_log.jsonl` as you play.

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
