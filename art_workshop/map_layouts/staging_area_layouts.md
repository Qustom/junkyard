# Staging Area — ASCII Map Layouts

> **Exploratory layout sketches, not direction.** These are top-down blockout options for the
> **surface staging area** — the bit of Bellweather Salvage *between the street and the junkyard
> proper*. They exist to argue about spatial flow, not to lock tile art. Grounded in the GDD's
> surface loop ("morning prep — pick gear, set a goal, choose an entry portal") and the
> Bellweather office shed established in
> [`../concept_art/explorations/20260627_c/`](../concept_art/explorations/20260627_c/)
> (winner: `nanobanana_pro.png`).

## What this space is

The staging area is the **safe surface hub**. It's the screen the player stands in to prep a dive
and to decompress after one. It must legibly offer **three ways out**:

1. **→ The Street** — exit to the life-sim / town layer (rideshare, errands, NPC visits, selling).
   Open threshold; this is the "out to the world" door.
2. **→ The Shack / Office** — Bellweather Salvage's office shed. Interior holds the
   workbench (repair/recipes), sorting/sell point, the stash, and the *save*. A door, fence-gated
   front yard optional.
3. **→ The Junkyard (the dive)** — the gate into the scrap that hides the portals. **Fenced and
   gated** — crossing it is the commitment to descend. This is the only "dangerous" exit.

Fences can wall off the junkyard gate and (optionally) the shack's little front plot, so the open
yard reads as the neutral staging ground in the middle.

---

## Legend (shared across all layouts)

```
  #  fence / chain-link run        =  street paving / road edge
  ╬  fence gate (junkyard)         ~  scrap pile / junk wall (impassable clutter)
  +  shack wall                    ░  loose ground clutter (passable, decorative)
  D  shack door (→ interior)       .  open walkable dirt (the staging ground)
  ▓  shack interior floor          @  player spawn / "you start here"
  S  → STREET exit threshold       o  prop (barrel, tire stack, sign, cart)
  J  → JUNKYARD dive gate          T  workbench / sort table (inside shack)
  P  faint violet portal-glow (distant, beyond the gate — flavor only)
```

> Glyphs are blockout shorthand — one glyph ≈ one tile cell, not final art. Violet `P` is the
> uncanny cold-glow teased in the concept art; it sits *past* the junkyard gate as a lure, not
> something you reach in the staging screen.

---

## Layout A — Vertical Spine (street ↓ south, dive ↑ north)

The reading-order classic: arrive from the street at the bottom, the shack anchors mid-screen, the
gated junkyard waits at the top. Walking "up" = going deeper. Cleanest onboarding.

```
   ~~~~~~~~~##########╬╬##########~~~~~~~~~
   ~~~~~~~~#         P  J          #~~~~~~      ← junkyard gate (fenced), violet glow beyond
   ~~~~~~~#  ░░░    ░░░░░     ░░░   #~~~~~
   ~~~~~#     ░░░░░░░░░░░░░░░░░     #~~~
   ~~~~#    o      ░░░░░░░      o    #~~        the OPEN YARD — prep / pace before committing
   .....    ........................   .....
   ....      .....+++++++++.....        ....
   ...        ....+▓▓▓▓▓▓▓+....          ...
   ..    o    ....+▓T▓▓▓T▓+....    o      ..    ← the SHACK (Bellweather office)
   ..         ....+▓▓▓D▓▓▓+....           ..
   ...        .......D...........        ...   D = door out into the yard
   ....     o      ........      o       ....
   =====================SS====================  ← STREET edge
   ===================@====================     @ player spawns stepping in off the street
```

**Flow:** spawn on the street edge → cross the open yard (shack on your right/center for a prep
detour) → reach the fenced gate `╬╬` at the top to dive. The shack literally sits *between* you and
the gate, so prep is on the natural path. Most legible; risks feeling like a corridor.

---

## Layout B — Courtyard Hub (shack to one side, gates opposed)

A square yard you stand in the middle of, with the three exits radiating out. Shack hugs the west
wall so the central dirt stays open for movement and "place" — the Animal-Crossing pride spot.

```
   ##########╬╬████████~~~~~~~~~~~~~~~
   #     J          P  ~~~~~~~~~~~~~~       ← junkyard gate, NW, fenced; glow past it
   #   ░░░░░      ░░░░░░~~~~~~~~~
   #  ░░░░          o      ░░░░░    o
   +++++++++         .............
   +▓▓▓▓▓▓▓+    o    .............        o
   +▓T▓▓▓T▓+         ......@......            ← @ player spawns center-yard
   +▓▓▓▓▓▓D D........ ............            shack door D → out into the courtyard
   +▓▓▓▓▓▓▓+         .............
   +++++++++    o    .............        o
   #  ░░░░          ........              ║
   #   ░░░░░     o        ░░░░░   o       ║
   #      ░░░░░░░░░░░░░░░░░░░░░░         SS  ← STREET exit on the east edge
   ##########################=========
```

**Flow:** spawn dead-center, fully framed — junkyard gate up-left, street out the east, shack door
to your west. No exit is "default"; the player chooses each session. Best "I have a base" feeling;
the open middle wants props (`o`) so it doesn't read empty.

---

## Layout C — L-Bend (street and dive don't face each other)

The street and the dive gate sit on *adjacent* edges, so you turn a corner to go from town to
descent. The shack nestles in the elbow, overlooking both. Adds a sense the junkyard is "around the
back," tucked away from the road — supports the GDD's secrecy/Exposure theme.

```
   ~~~~~~~~~~~~~~~~~##########╬╬######
   ~~~~~~~~~~~~~~~~#      P    J     #        ← dive gate, NE corner, fenced
   ~~~~~~~~~~~~~~~#   ░░░░░░░░░░░░    #
   ░░░░░░░░░░░░░░     ░░░░░░░░░░     #
   ....................     ░░░░    o#
   ...+++++++++.........              .
   ...+▓▓T▓▓▓▓+....o....   the yard wraps   .
   ...+▓▓▓▓▓▓D+.........   the corner        .
   ...+▓▓▓▓▓▓▓+.........              o    ░░
   ...+++DOOR+....@..........             ░░░   ← shack sits in the elbow; @ near its door
   ...........................o........░░░░░
   =====S=====................     ░░░░░░░
   ==========.................░░░░░░░~~~~
   ==========     STREET runs along the south-west
```

**Flow:** come in off the street (SW), the shack is right there for prep, then **turn the corner**
NE to reach the gated dive. The bend hides the junkyard gate from the road on entry — you have to
walk *into* the property to see the dangerous part. Most atmospheric; slightly less legible than A.

---

## Layout D — Wide Frontage (street ← west, dive → east, shack as billboard)

Horizontal read for a wide screen. The shack faces the street as the literal storefront/"shopfront"
the GDD mentions; the gated junkyard is the back lot to the east. Cars-on-blocks and scrap line the
top and bottom as framing walls.

```
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ~o~~~  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ~~~o~~~~~~
   =                                          #
   = S   +++++++++++                          ╬   ← street W (S) ............ dive gate E (J→)
   = .    +▓▓T▓▓▓▓▓▓+    .................     ╬
   = @....D  BELLWEATHER ....................  J
   = .    +▓▓▓▓▓▓T▓▓+    ...........o........  #
   = .    +++++++++++       open back lot       #   P  ← portal glow further east, past the gate
   =                    .....................   #
   ~o~~~  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ~~~~~~~
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

**Flow:** spawn at the street (W) right beside the shack's customer-facing door → cross the long
back lot east → hit the fenced gate `╬` to dive. The shack-as-frontage reinforces the "salvage
business by day" cover story; the danger is out back where customers don't go.

---

## Comparison & recommendation

| Layout | Read | Vibe | Prep-on-path? | Watch out for |
|---|---|---|---|---|
| **A** Vertical Spine | easiest | onboarding-clean | yes (shack mid-spine) | can feel corridor-y |
| **B** Courtyard Hub | medium | strongest "my base" | optional (shack to side) | empty center needs props |
| **C** L-Bend | medium | most secretive/atmospheric | yes (shack in elbow) | gate hidden = findability |
| **D** Wide Frontage | easy | sells the "business" cover | yes (door at spawn) | wide screen / scrolly |

**Recommendation for the first playable:** prototype **A (Vertical Spine)** for clarity, but carry
**B (Courtyard)**'s framing idea into it — i.e. keep the shack *near* the dive path (A) while
leaving enough open dirt around it for the base to grow and feel like a place (B). **C**'s "junkyard
is around the back" bend is the strongest fit for the secrecy theme and is worth a second pass once
the loop is proven. This is a **vision/place call** — surfacing to the Director rather than picking
one.

### Open questions for the Director
- **Is the shack interior a separate scene** (door `D` → load) or an **open-roof room** you walk
  into on the same screen? Layouts assume a door-to-interior; an open room changes the footprint.
- **One dive gate or several?** GDD says you "choose an entry portal/band." The staging screen shows
  a single gate `J` into the junkyard; multiple portals may live *past* the gate (inside the dive)
  rather than as multiple gates here. Confirm before committing fence runs.
- **Does the street exit need to be walk-through** (seamless to a town map) **or a menu/fast-travel**
  prompt? Affects whether `S` is a real threshold or just an interaction point.
