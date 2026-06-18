# Loop-Smoke Checklist (G3)

Run this against **every nightly build before sharing the link**. Each item is
pass/fail; **any fail blocks the build**. The last two items are the G3 acceptance
criterion made concrete: a fresh build runs the full loop, and multiple runs per
session work.

Build under test: `m1-<YYYYMMDD>-<shortsha>` (shown bottom-right of the main menu).

```
[ ] Build launches to the main menu; no error spew in the console / user://logs/godot.log.
[ ] START RUN -> player spawns in the yard at the band entry; a greybox band is visible.
[ ] Dive: can walk through the band; the HUD "Depth N" reads >= 1; the clock bar drains.
[ ] Pick up junk: walk onto a greybox junk shape, press E -> "Holding: N" climbs on the HUD.
[ ] Bag-full feel (optional): keep grabbing until the bag rejects (junk flashes, stays in world).
[ ] Decision point: the draining clock makes "push deeper vs extract now" a real choice.
[ ] Extract path: walk to the green gate near spawn, press E -> EXTRACTED sell screen appears.
[ ] Sell: the per-item payoff lists, the Money total counts up and increases; press Continue.
[ ] Repeat: Continue immediately starts a SECOND run in the same session (new band).
[ ] Death path: in a run, press K (debug-kill) -> "RUN LOST — kept N" sell screen; kept N is a
    subset of the haul (pockets), and Money increases only by that subset.
[ ] Timeout path (optional, ~60s): let the clock hit 0 -> same RUN LOST flow as death.
[ ] Telemetry (if enabled): user://telemetry/run_log.jsonl exists and has a run_started +
    run_ended line for EACH run (and a "build" field on run_started matching the menu stamp).
[ ] No soft-locks: every screen has an exit (menu -> run -> sell -> run); no stuck state, no
    required-but-missing input.
```

## How to enable telemetry for the smoke pass
Telemetry defaults **OFF** (privacy). To verify the telemetry rows, enable it first
(see `tester_readme.md`), then run the loop. The opt-in flag persists in
`user://settings.cfg`.

## Where to look when something fails
- Console / `user://logs/godot.log` — engine errors + stack traces (file logging is ON).
- `user://telemetry/run_log.jsonl` — one JSON object per line; confirms the lifecycle fired.
- The headless integration drives (CI / pre-share sanity) reproduce the loop without a human:
  - `godot --headless res://tests/test_loop_drive.tscn`      -> prints `LOOP OK — ...`
  - `godot --headless res://tests/test_main_game_loop.tscn`  -> prints `MAIN GAME OK — ...`
