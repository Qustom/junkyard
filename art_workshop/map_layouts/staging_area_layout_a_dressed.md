# Staging Area — Layout A (Vertical Spine), Dressed

> **Expansion of Layout A** from [`staging_area_layouts.md`](staging_area_layouts.md). That doc
> argued *spatial flow* (where the three exits go); this one dresses the chosen blockout with the
> two things a flow sketch leaves out: **(1) what the ground is made of** and **(2) what objects sit
> on it**. Still exploratory — placeholder-art direction, not locked tile art.
>
> Grounded in the winning concept ([`../concept_art/explorations/20260627_c/nanobanana_pro.png`](../concept_art/explorations/20260627_c/nanobanana_pro.png)
> — golden-hour yard, warm-lit BELLWEATHER SALVAGE shed, packed dirt, walls of rusted cars/appliances,
> a cold-violet glow deep in the scrap) and the **Band 0 / Mundane surface palette** from
> [`../../design/research/02_band_visual_language_study.md`](../../design/research/02_band_visual_language_study.md) §7:
> *analogous rust-browns, oily grays, faded yellows, weathered teal; moderate saturation; everything
> is what it looks like.*

---

## The blockout we're dressing (Layout A — Vertical Spine)

Street at the **bottom** (spawn), shack mid-screen, gated junkyard at the **top**. Walking up = going
deeper. Three zones stack along the spine. The expansion below maps every glyph to a **ground
material** and a **prop**.

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

---

# 1 · The ground (texture)

The floor is read in **three stacked bands**, south→north, that quietly tell the player how far from
safety they are. Each is a tileable base material plus a scatter overlay. All sit inside the Band 0
master palette so the surface reads as one cohesive place; the *gradient-map pipeline* (study §6)
means these are authored once in grayscale and tinted, so re-toning later is cheap.

| Glyph | Zone | Base material | Tint (Band 0) | Surface detail / overlay |
|---|---|---|---|---|
| `=` | **Street edge** (south) | cracked **asphalt / road paving** | cool oily gray, faded yellow lane paint | tar-seam cracks, a worn curb line, gravel spill where asphalt meets dirt |
| `.` | **Open yard** (middle) | packed **dirt / hardpan**, tire-rutted | warm rust-brown, dusty ochre | tyre tracks, oil stains, scattered bolts/pebbles, faint footpath worn shack↔gate |
| `░` | **Yard clutter fringe** (north) | dirt **+ loose ground litter** | rust-brown, slightly grayer | crushed cans, wire offcuts, leaf-litter of shredded metal — *passable, decorative noise* |
| `~` | **Scrap walls** (border) | impassable **junk-pile / scrap wall** | deep rust, oily shadow | the framing heaps — read as wall, not floor; not walkable |
| `▓` | **Shack interior floor** | worn **plywood / board** | warm amber (window-lit) | plank seams, an oil-stained work area under the benches |

**The transition that matters:** the **asphalt→dirt seam** at the street edge and the
**dirt→litter→scrap** gradient as you climb north. The ground gets *grubbier and busier the deeper
you go* — a legibility cue that you're walking toward the dangerous end before any object even tells
you so. Keep the **center walking lane of `.` cleanest** (highest floor-to-prop contrast) so the
path from spawn → shack door → gate always reads (study §6: constant readability hierarchy).

**Lighting:** golden-hour from the concept — long warm shadows cast *south/toward the viewer* off
the north scrap walls and the shack. The dirt picks up the warm key; the violet `P` past the gate is
the one cold note, and nothing else on the surface should compete with it.

---

# 2 · The objects (props on the texture)

Two prop tiers: **functional** (the player interacts — exits, save, sell, stash) and **dressing**
(pure flavor, the `o`/`░` scatter that makes it a *place*). Functional props use the
band-independent legibility layer (higher contrast, a readable silhouette, a subtle interact glint)
so they never get lost in the rust; dressing recedes into the floor band.

### Functional props (interactable)

| Glyph | Object | Where | Reads as | Notes |
|---|---|---|---|---|
| `@` | **Player spawn** | street edge, south-center | — | steps in off the road; faces *up* the spine toward the yard |
| `SS` | **Street exit threshold** | south wall, center | open gap in a low fence/curb, mailbox + a paved apron | "out to the world." Open, inviting — no gate. (Walk-through vs. prompt is an open Q below.) |
| `D` | **Shack door** | shack south face | lit doorway, warm spill on the dirt | → office interior (workbench/sell/stash/**save**). Warmest point on screen = "safe here." |
| `T` | **Workbench / sort table** | inside shack (`▓`) | sturdy bench, tools, a sorting bin | repair/recipes + sort/sell. Two shown — one bench, one sort table. |
| `╬╬` | **Junkyard dive gate** | north wall, center | chain-link double-gate, hazard/keep-out sign, chain & padlock motif | the only "dangerous" exit; **the commitment to descend**. Slightly higher contrast than the fence run so it reads as *the* objective. |
| `P` | **Portal glow** | past the gate, north | faint cold-violet bloom in the distant scrap | flavor/lure only — unreachable from this screen. The single cold color note. |

### Dressing props — the `o` scatter (junkyard reality, "everything is what it looks like")

The `o` glyphs are a **rotating pool of salvage-yard props**, not one repeated sprite. Place them to
(a) frame the open yard so it doesn't read empty, (b) break sightlines without blocking the central
lane, and (c) sell the lived-in business. All are Band-0 mundane — the *recognizable junkyard DNA*
(study §7) that later bands will distort.

- **Stacks & piles:** tire stacks, an oil-drum cluster, a pallet of crushed cans, a coiled
  hose/cable spool.
- **Vehicles & big metal:** a car-on-blocks (hood up), a rusted-out truck cab, a dead chest freezer
  or washer/dryer hull, a bathtub full of scrap.
- **Business dressing:** a hand-painted price/signpost, a wheelbarrow or hand-cart (echoes the
  haul-out fantasy), a folding chair + crate "break spot" by the shack, a propane tank.
- **Soft life-sim touches near the shack** (the Animal-Crossing "pride spot" the Courtyard layout
  wanted): a potted plant, a string of work-lights, a chalkboard with the day's goal, a dog bowl.
  These are the seeds for **base-personalization** as the yard grows.

**Placement rules of thumb**
- Keep the **`.` spine lane (spawn → `D` → `╬╬`) clear** of `o` props — flow first.
- Cluster dressing at the **yard corners and along the shack apron**; let `░` litter thicken toward
  the north scrap walls.
- Bigger silhouettes (car, freezer) go **near the scrap-wall border** so they read as part of the
  framing mass, not obstacles mid-yard.
- Every prop casts the same warm golden-hour shadow direction — consistency over realism.

---

## Quick prop ↔ ground checklist (for the placeholder pass)

1. **3 ground tiles** to author first: `asphalt` (`=`), `packed-dirt` (`.`), `scrap-wall` (`~`) —
   plus a `dirt-litter` (`░`) overlay variant and a `plank-floor` (`▓`) for the interior.
2. **6 functional props:** street threshold, shack door (lit), workbench, sort table, dive gate
   (with sign), portal-glow FX.
3. **~10–12 dressing props** from the `o` pool above, enough to scatter without repeating obviously.
4. Bias contrast so **functional > dressing > ground**, and keep the **central lane cleanest**.

## Open questions (carried from the parent doc, now ground/prop-specific)

- **Shack: interior scene or open-roof room?** If open-roof, the `▓` plank floor + `T` benches must
  be dressed as a *visible* room on this screen (more interior props needed); if a separate scene,
  `D` just needs a convincing lit doorway here.
- **Is the dirt a single tile or does it need rut/path baked variants** so the worn shack↔gate
  footpath reads without a separate decal layer?
- **One dive gate, or hint at multiple portals past it?** Affects whether `P` is a single glow or a
  faint cluster, and how much fence run frames the gate.
- **How much base-personalization** (the soft life-sim props) belongs in the *first* placeholder pass
  vs. deferred until the yard-growth system exists? — a scope call for the Director.
