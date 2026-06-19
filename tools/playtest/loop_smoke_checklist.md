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

## M1.1 cost-axis matrix (RG1 §4) — manual pass on the integrated build

The base loop checklist above is the **all-off (V6) baseline** — the permanent in-build
control. M1.1 adds four toggleable oppositions (R1 hazard · R2 costlier return ·
R3 exposure meter · R4 maze/nav). Set a config in the **Config menu** (the rail beside
START RUN; see `tester_readme.md`), then run the loop. **The objective rows (V1–V18) are
also auto-checked headless** by `godot --headless res://tests/test_rg1_loop_verify.tscn`
(prints `RG1 BUILD VERIFY OK`); this manual pass confirms the *felt / on-screen* half a
human must judge.

Per-opposition isolation (each ON alone, the other three OFF; use the Config menu):
```
[ ] V1 R1 only:  a hazard awakens at the configured depth/linger and VISIBLY chases;
                 catching the player can end the run as "death" (RUN LOST sell screen).
[ ] V2 R2 only:  retreating toward the gate from depth costs measurably more than from
                 shallow (clock drains faster / a return meter climbs) — push feels priced.
[ ] V3 R3 only:  the greybox Exposure readout (HUD) climbs faster the deeper you are,
                 fires penalties at thresholds, and at max forces a "timeout" RUN LOST.
[ ] V4 R4 only:  deep areas branch; vision/fog tightens with depth; the band stays SEALED
                 (you cannot walk off the map — BUG3). Getting lost burns the clock.
```

Stacked + baseline:
```
[ ] V5 All four ON: the loop runs end-to-end with no crash/soft-lock; hazard + return cost
                    + exposure + maze all act in one dive; every end-cause still reachable.
[ ] V6 All OFF:     identical to the M1.0 baseline above (linear spine, full vision, free
                    walk-back, no hazard/meter). This is the control — confirm it matches.
[ ] V7 Reset:       the Config menu "Reset" returns every knob to all-off; a run after reset == V6.
```

End-causes (all four terminal states reachable + sell screen + loop continues):
```
[ ] V8  extract  -> "EXTRACTED";            banked junk -> Money;       Continue loops.
[ ] V9  death    -> "RUN LOST — kept N";    pockets fraction kept;      Continue loops.
[ ] V10 timeout  -> "RUN LOST — kept N" (R3 max OR dive clock expiry);  Continue loops.
[ ] V11 lost     -> manifests as timeout/death (NOT its own end-cause); the run still
                    terminates (no stuck-forever); nav_lost_proxy rows distinguish it in analysis.
```

Telemetry config-snapshot + event-gating (enable telemetry first):
```
[ ] V13 Every run_started JSONL row carries data.run_config (the full flat dict snapshot).
[ ] V14 With an opposition ON its event rows appear (hazard_*/return_cost_incurred/
        exposure_*/nav_*); with it OFF those rows are ABSENT (all-off run = no opposition rows).
[ ] V16 Config carry-forward: Continue re-uses the same config (no menu shown); a new seed differs.
[ ] V17 run_started.data.build = m1-<date>-<sha>; run_config.build_tag = the Director-typed
        sweep label (set it in the Config menu's `build_tag` field before a sweep).
```

Two switch paths from the sell screen (RG1, ratified §8 Q2):
```
[ ] Continue        -> quick re-run, SAME config, new seed (the sweep cadence).
[ ] Back to Config  -> returns to the Config menu so you can switch configs mid-session.
```

## How to enable telemetry for the smoke pass
Telemetry defaults **OFF** (privacy). To verify the telemetry rows, enable it first
(see `tester_readme.md`), then run the loop. The opt-in flag persists in
`user://settings.cfg`.

## Where to look when something fails
- Console / `user://logs/godot.log` — engine errors + stack traces (file logging is ON).
- `user://telemetry/run_log.jsonl` — one JSON object per line; confirms the lifecycle fired.
- The headless integration drives (CI / pre-share sanity) reproduce the loop without a human:
  - `godot --headless res://tests/test_loop_drive.tscn`        -> prints `LOOP OK — ...`
  - `godot --headless res://tests/test_main_game_loop.tscn`    -> prints `MAIN GAME OK — ...`
  - `godot --headless res://tests/test_rg1_loop_verify.tscn`   -> prints `RG1 BUILD VERIFY OK` (the
    M1.1 cost-axis matrix objective half: V1–V18 isolation/stacked/baseline/end-causes/telemetry).
