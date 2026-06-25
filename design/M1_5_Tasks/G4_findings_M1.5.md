# M1.5 — Re-gate findings (G4)

**Milestone:** M1.5 (Agency & Legibility). **Build re-gated:** the M1.5 itch/desktop build (`013b4b0`, tuned preset:
`r1_speed_per_depth=5.0`, `r1_catch_radius_per_depth=1.0`, `lvl_room_count=30`). **Gate owner:** the Director (plays + decides);
Claude assembles + recommends.

---

## RG3 — Director playtest verdict (2026-06-25): **ITERATE (controls)**

The Director playtested the M1.5 build and gave **direct qualitative feedback** (the re-gate short-circuited the RG2 telemetry
pass — the call was a clear feel issue, not a metrics question):

> **"The controls are clunky."** Specifically:
> 1. Aim should come from **where the mouse is pointing**, not where the player is looking/moving.
> 2. **Clicking** should throw.
> 3. The **scroll wheel** should cycle the highlighted item.
> 4. The **player should point in the aim direction** too.
> 5. **Add controller support.**

**Verdict: ITERATE — packaged as an M1.5 control-rework wave (Wave 4 = L6), not a sub-version bump.** (Mirrors the M1.4
Wave-5 precedent: re-gate feedback packaged as a focused wave + re-publish + re-test, rather than a full M1.6 four-phase pass.)
The throwing *mechanic* (L1) landed — the feedback is about the *control scheme around it*, plus a net input feature (controller).

### Director-ratified decisions (asked + answered 2026-06-25)
- **Controller = twin-stick:** left stick/dpad move (already bound), **right stick aims & turns** the player, **RT throws**,
  **LB/RB cycle** the highlighted item. (A=grab, B=extract, Start=pause already bound.)
- **Keep Q/E + Space** bound as a keyboard fallback alongside the new mouse scheme (mouse aim + left-click throw + scroll cycle).

### Outcome — L6 (Wave 4)
Built + integrated (`main`@`302d2bd`): aim decoupled from movement via a pure `resolve_aim()` (right-stick > deadzone →
mouse-after-motion → hold-last → movement default); mouse/right-stick aim turns the player (nose + `facing` follow `aim`);
throw fires on LMB/RT in the aim direction; cycle on wheel/bumpers; Q/E + Space retained. **Input-only — all-off fp
`e943ac9c8bc1` unmoved, knob count 89, no save change.** Full headless gate green; the *felt* mouse/controller experience is
**human-deferred to a Director re-test** (headless can't inject real mouse/gamepad hardware).

### Carry-forward for the re-test
- **Keyboard-only-no-mouse aim edge (L6-F1, awaiting Director disposition):** because `aim` initialises to `DOWN` and the
  resolver holds the last aim before falling back to movement, a player using the **pure-keyboard fallback** (Space/Q-E, never
  touching the mouse) aims permanently DOWN. Mouse + controller (the primary schemes) are unaffected. Recommendation: **Reviewed**
  (mouse is the primary KB/M device; the fallback is secondary) — or a small follow-up to let the keyboard fallback track the
  movement direction when no mouse/stick is active.

---

## Next: Director re-test → re-gate verdict
1. **Director re-test** the re-published L6 build on desktop (mouse) + a controller: does the aim/throw/cycle feel right; does
   the player point correctly; is the twin-stick mapping comfortable?
2. **Verdict:** **go → M2** / **iterate → M1.6** / **pivot** — recorded here.
