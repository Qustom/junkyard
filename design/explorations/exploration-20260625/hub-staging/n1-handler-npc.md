# A Handler / NPC
**Category:** The hub as light narrative / texture

## The idea
One recurring character who lives in the hub and *talks to you*: hands over the
quota terms before you depart, reacts when you come back (cleared it, scraped it,
got wiped), and — between those two beats — leaks the world. The job-giving and the
performance-comment are mechanical hooks the player already hits every run (K2's
`quota_advanced` / `quota_evaluated`, the c2 board's accept); the **cheap, huge win**
is that the *same* hooks become a voice. A single barking NPC does the tonal work of
a whole cutscene budget: it tells you what's normal, what's strange, and what the
yard costs you, in two or three lines a run. The handler is the hub's human face —
the warm-surface counterweight to the dread below (GDD §2 pillar 3, "the contrast is
the point").

## What exists today (canon + build)
**The GDD cast is deliberate and a handler must fit it.** Two facts constrain who
this can be:

1. **Cyrus is an *absence*.** GDD §14 / §3 lock him as recordings-only — tapes,
   voicemails, a logbook scattered across the bands — and *"whether he survived
   stays unknown until the very end."* A live, present, banter-every-run handler
   **cannot be Cyrus** without detonating that mystery. (The c2 board's flavor
   string "Cyrus wants 3 copper coils" is a *recorded standing order*, not Cyrus
   speaking live — the handler could be the one who *plays you that tape*.)
2. **The confidants are opt-in and Exposure-costed** (GDD §9): the mechanic friend,
   the diner owner who half-knew Cyrus, the broke grad-student "expert," the
   rideshare buddy. Bringing one *in* is a deliberate relationship beat that *raises
   Exposure* — they are not free hub furniture.

On the build side the *reactive surface already exists, faceless*: K2 fires
`quota_evaluated(run_number, target, achieved, met)`, `quota_advanced(...)`, and
`meta_wiped(prev_run_number)` (`systems/event_bus.gd:128-133`); the exposure system
fires `exposure_threshold_crossed` and the story-crisis hooks. **What's missing is a
mouth.** Dialogue Manager v3.10.4 (CLAUDE.md pinned add-ons) is the tool to give one;
there is no hub scene yet.

## How it could fit in
A greybox hub NPC (`Area2D` + a Dialogue Manager balloon) that listens to those
signals and speaks a handful of **state-based barks**: *first meeting* (sells the
premise), *quota delivered* (reads the c2 board's terms aloud), *good run* (`met` →
warmth + the new bar), *missed quota* (`meta_wiped` → the gut-punch, cross-ref v3
persistence-of-failure), *idle texture* (one-liners that leak lore without ordering a
reveal). It voices the c2 job board (the contract you read is *handed to you*) and
the c1 departure point (a send-off line). Scope: **lowest graybox priority** — the
loop works mute; this is texture layered on a proven seam, real later.

**Canon recommendation (Director's call):** make the handler the **diner owner who
half-knew Cyrus** — a confidant who is *already* in the cast, already Cyrus-adjacent
(so the world-leaking lines are earned), and already warm-surface by design. Crucially,
their *help* (the relationship mechanic, the Exposure cost) can stay gated behind the
GDD opt-in; the **handler role is just them being a person you talk to in town**, not
the confidant unlock. A wholly *new* faceless quota-giver is the safe fallback if the
Director wants zero canon entanglement in greybox.

## Research (cited)
Prior art shows one voice carrying a game's whole tone cheaply:
- **Darkest Dungeon's Narrator/Ancestor** (Wayne June) — a *single* recorded voice
  that *is* the game's dread, commenting on your performance ("Remind yourself that
  overconfidence is a slow and insidious killer"). One actor, one register, total
  atmosphere. The model for "a handler who comments on runs" — except THE FAR YARD
  inverts the register to *warmth*.
- **Deep Rock Galactic's Mission Control** (Robert Friis) — a disembodied
  corporate handler who hands objectives, reacts to swarms, and sells the company's
  blue-collar tone in clipped barks. Proof a *faceless* quota-giver still does
  enormous personality work — the new-NPC fallback's reference.
- **Hades' House cast** (Skelly the training dummy, Dusa, Orpheus) — NPCs that are
  simultaneously a *mechanic* and a *relationship*, accreting reactive lines per run
  so the hub feels alive without cutscenes. The model for a handler whose barks key
  off run state.

The shared lesson: **a small, reactive, well-voiced presence beats a big static one.**
A handful of state-keyed lines that fire on signals you already emit reads as a living
world for a fraction of a cutscene's cost.

## Open questions
- **WHO is this — confidant, new NPC, or Cyrus-adjacent?** *(Canon/vision call, flag
  for Director + narrative lead.)* Recommendation: the diner owner (Cyrus-adjacent,
  in-cast, warm). Risk of a confidant: does *talking to them as a handler* leak the
  Exposure-gated "bring them in" beat? Seam: handler-as-acquaintance ≠ confidant-unlock.
- **Does the handler ever blur into Cyrus?** A handler who *plays you Cyrus's tapes*
  is powerful but risks softening the "is he alive?" absence. Must never let the
  handler *speak for* Cyrus. *(Continuity call.)*
- **VO scope.** Text-only barks for greybox (and likely ship); full VO is a late,
  expensive call — flag the budget question, don't assume it.
- **How reactive for graybox?** Recommend ~5 states (first-meet / quota-given /
  good / wiped / idle), text-only, no branching tree yet. More reactivity = real-later.
- **Reveal ordering.** Idle lore-barks must never leak an out-of-order reveal —
  gate any world-fact line on Knowledge level, same discipline as the lore fragments.

## Sources
- [Narrator (Darkest Dungeon) — Darkest Dungeon Wiki](https://darkestdungeon.fandom.com/wiki/Narrator_(Darkest_Dungeon))
- [Mission Control — Deep Rock Galactic Wiki](https://deeprockgalactic.fandom.com/wiki/Mission_Control)
- [NPCs | Hades Wiki](https://hades.wiki.fextralife.com/NPCs)
