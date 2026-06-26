# Hide
**Category:** Interaction & environment verbs

## The mechanic
**Hide** is a single verb: while standing at a hide spot (a wreck-locker, a gutted car
chassis, a junk pile alcove), press `interact` to **duck inside and break line of sight**.
While hidden, a perceiving enemy cannot acquire you (and an enemy already searching loses
its lead). Press again to step out. It is a discrete, place-bound state change, not a
movement modifier.

This is the crisp line versus sneak/crouch (`m3`): **sneak = move quietly through the open**
(a continuous locomotion mode that lowers your detection footprint while you keep moving);
**hide = enter a designated spot and go unseen, but you are stuck there.** Sneak is about
*traversing* past a threat; hide is about *waiting out* one. They should compose — sneak to a
locker, then hide in it — not overlap.

## What exists today
**No enemy perception exists.** `vision_fog.gd` and `camera_view.gd` are the *player's*
limited-sight cosmetic overlay (a radial-dark occluder hole that hides geometry beyond the
player's vision radius) — they model what *you* can see, not what an *enemy* can see. There
is no enemy, no vision cone, no LoS query, no aggro state machine in the build. Hide is
therefore **hard-blocked on the vision-cone patroller** (`design/explorations/.../1-patroller-vision-cone.md`):
it has nothing to hide *from*.

What does exist and fits cleanly: the **A2 interaction component** — `Interactable` (Area2D,
`interactable_id`, `prompt_text`, `can_interact()`) plus the player's `InteractionDetector`
emitting `EventBus.interaction_requested(id, target)`. A hide spot is just another
`Interactable` with `interactable_id = &"hide_spot"`, prompt "Hide". The **dive clock**
(`dive_clock.gd`, ~300s drain) is the anti-camping lever, already wired to drain in real time
and pause with the tree. Missing: enemy perception, a "player is concealed" flag any perceiver
can read, and a hidden-state visual/control.

## How to fit it in
- **The concealed flag.** Add `EventBus.player_concealment_changed(hidden: bool)` (or a
  read-only `GameState.player_hidden` for run-state). Hide spot owner listens to
  `interaction_requested(&"hide_spot", target)`, toggles the flag, snaps the player into the
  spot, and disables player movement input. Future patrollers query the flag in their LoS
  check: hidden ⇒ never acquired; if mid-search ⇒ drop to last-known and give up.
- **The clock is the cost.** Hiding does **not** pause the dive clock — it keeps draining
  (the clock is `PROCESS_MODE_PAUSABLE` but hiding is not a pause). So every second hidden is a
  second of extraction window spent. This is the structural answer to camping: the seeker you
  fear and the timer you fear are the *same* pressure (cf. Alien Isolation's locker —
  hiding buys safety but never resets the threat, only delays it).
- **Control mapping.** Reuse `interact` (no new action) — enter and exit on the same key,
  matching A2. Optionally a press-and-hold "lean to peek" later, à la Isolation's vent view.
- **RunConfig knob + telemetry.** `hide_enabled: bool` (default `false` ⇒ baseline control,
  no hide spots spawn). Telemetry: `hide_enter`/`hide_exit` with `seconds_hidden`,
  `clock_remaining`, and whether a perceiver was actively searching — to measure if hide is a
  panic button, a routine crutch, or dead weight.

## Research (cited)
Alien Isolation's locker is the touchstone: the prompt is "Hide," not "Open" — a deliberate
cognitive-load reduction under threat — and the *same* press exits noisily, so a panicked
mis-press gets you killed, aligning player and character mental states. Crucially, hiding never
removes the Alien; it only delays, so the locker is tense rather than safe ([Brown, Medium](https://medium.com/@treedemon/hiding-af2cdf40d23d)).
Hello Neighbor attacks degenerate hiding differently — adaptive AI that *learns* your repeated
hiding/escape spots and traps or blocks them, punishing routine ([Hello Neighbor](https://www.helloneighborgame.com/)).
For The Far Yard, the **extraction timer is our anti-camping mechanism** (faucet/drain), which
is structurally cleaner than per-spot timers or learning AI — degenerate waiting is self-punishing
because the clock is the win condition.

## Graybox sketch
Spawn one `Interactable` "locker" (`hide_spot`) + one minimal patroller with a forward LoS
raycast/cone toggling an `acquired` bool. Player walks into cone ⇒ acquired (greybox: tint
red). Player presses Hide at the locker ⇒ `player_hidden = true`, movement locked, sprite
snaps to spot; patroller's LoS check early-returns when `player_hidden`. Press to exit. Verify:
hidden player in the cone is **not** acquired; the dive clock keeps draining the whole time.
Needs exactly one perceiving enemy — so it ships *with or after* the vision-cone patroller.

## Open questions
- **Does hide fully reset aggro, or only break the current acquire?** Full reset (enemy
  forgets entirely) makes it a clean panic button; "break LoS, enemy searches then gives up to
  last-known" is tenser and reads more fairly. Recommend the latter, gated on the patroller's
  search-state design. **Director call.**
- **Is the clock alone enough anti-camping, or do we also cap hide duration / let a Hunter
  yank you out?** The Hunter exploration (`5-the-hunter.md`) wants "wait it out" — but if hiding
  is fully safe, waiting out the Hunter could trivialize it. Tension between "hide beats Hunter"
  and "Hunter ignores/breaches hide." **Director call.**
- **Hard dependency:** enemy perception (vision-cone patroller) must exist first. Do we
  build hide as a no-op stub now, or defer the whole verb until the patroller lands? Recommend
  defer the player-facing verb; land the `player_concealment_changed` signal contract early so
  the patroller can be authored against it.
- **Can you act while hidden** (peek, throw to distract, extract from cover)? Out of scope for
  the smallest version; flag for a later interaction-verb pass.
