# Vault / Slide over Low Cover
**Category:** Movement verbs
**Date:** 2026-06-25

> Player-mechanic exploration only. Pseudocode is illustrative against the
> as-built `Player`/`BandGenerator` APIs; no production code, no branch.

## The mechanic
A short, committed traversal verb that carries the player **over or through a
low obstacle** they couldn't otherwise pass — vault a wrecked car door, slide
across a hood, dive through a smashed window or a rubble gap. It is *not* a dash:
it's bound to **geometry**, only legal where a vaultable edge exists. Two payoffs:
(1) **geometry becomes escape** — a low wall the pursuer must *go around* but you
go *over* breaks the chase line and buys distance; (2) the **one-way move** — a
window or collapsed breach you can dive *through* but not climb back, turning a
piece of layout into a directional commit-point (the same fiction as the
`e3-verticality-fakes` drop edge, but player-driven and lateral). The verb makes
the player *read cover as a tool*, not just a sight-blocker.

## What exists today
Honest read: there is **no vault, no cover, and no obstacle metadata** in the
build. `player.gd` is a pure `CharacterBody2D` with `Input.get_vector` movement
and `move_and_slide()` — one velocity state, no traversal states, no collision
exceptions. `PlayerMovementStats` is just `max_speed/acceleration/friction`.
Bands are walls + floor cells only: `BandGenerator` mates authored `ZonePiece`
rects on cardinal `ZoneSocket`s, and `is_band_connected` treats every cell as
binary walkable/wall via 4-adjacency flood-fill. There is **no "low cover" tile
class** — a cell is floor or wall.

So this verb has a **hard dependency**: vaultable obstacles must exist *first*.
The two plausible sources are both still proposals — the `b1-open-field-with-cover`
scatter pass (poisson cover obstacles) and `e5-wear-decay-state` rubble. Neither
ships. Vault is downstream of one of them landing, plus a new **per-edge
"vaultable" metadata** the geometry doesn't currently carry.

## How it fit it in
- **Core verbs:** orthogonal to move (commits a burst along the edge normal) and
  to the L6 mouse-aim throw (aim is decoupled, so you can vault and keep pointing
  at a pursuer). No aim cost.
- **Dive clock (`dive_clock.gd`, ~300s):** a vault is a **shortcut vs. detour**
  decision — over the wall saves clock; the no-vault route spends it. One-way
  dives (window/breach) *commit* clock the way a drop edge does.
- **Oppositions:** the headline counter to ground pursuers — vault a low wall the
  chaser must path around, **breaking its line** (the refuge habit, made active).
  The **Leaper** (`1-leaper.md`) explicitly **negates it** — it leaps the same
  wall you vaulted, the one pursuer a vault won't shake, preserving "geometry
  isn't a universal solution." Pairs with `b1` cover (vault between obstacles
  under ranged fire) and `e5` rubble (dive a breach to cut a flank).
- **Geometry hook:** mark a vaultable edge as **socket/cell metadata**, not a new
  entity — mirror `e3`'s dormant `is_drop` socket meta. A cover footprint
  (`b1`) or rubble cell (`e5`) carries a `vaultable` flag + a normal direction; the
  verb is legal only when the player faces such an edge within range. One-way
  windows reuse the directed-edge idea (passable one way, walled the other).
- **Control (L6):** **contextual press** — the existing interact-style edge press
  fires a vault *only when a vaultable edge is in front*; otherwise it's a no-op or
  falls through to interact. Avoids a new dedicated button. (Ambiguity flagged below.)
- **RunConfig knob + telemetry:** `vault_enabled` (off by default → byte-identical
  to today), plus `vault_range_cells`, `vault_duration_s`, `vault_invuln`
  (i-frames mid-vault yes/no). Telemetry: vaults/run, vault-to-escape rate
  (vault followed by losing a pursuer), one-way commits, config-marked per the
  M1.1 comparison contract.

## Research (cited)
Immersive-sim canon treats vaulting as a baseline traversal contract: "if a wall
is short enough to climb or vault, you'd better be able to," and speed players
should be able to "vault over enemies and slide under closing doors before foes
react" — vault/slide as an *escape and tempo* verb, not just animation
([TV Tropes — Immersive Sim](https://tvtropes.org/pmwiki/pmwiki.php/Main/ImmersiveSim),
[Steam guide to immersive sims](https://steamcommunity.com/sharedfiles/filedetails/?id=2961596558)).
Thief's "one player slips in through a basement window, another by a balcony"
captures the **one-way / chosen-traversal** value — geometry offering routes a
pursuer can't mirror ([same TV Tropes ref]; immersive-sim design philosophy,
[rosodude](https://rosodudemods.wordpress.com/2020/12/14/immersive-sim-is-a-design-philosophy-not-a-genre/)).
Top-down precedent for **geometry-bound traversal as escape** is Hyper Light
Drifter's dash, a versatile move-faster/dodge-through verb whose *chaining* is the
skill expression — our vault is the geometry-gated cousin (dash through a *thing*,
not empty space) ([HLD dash discussion](https://steamcommunity.com/app/257850/discussions/0/1694914735998631738/),
[HLD review, Save or Quit](https://saveorquit.com/2021/01/20/review-hyper-light-drifter/)).

## Graybox sketch
Smallest proof of "geometry-based escape is fun": one arena (a baked `b1`-style
piece) with **a single low wall** flagged vaultable, **one ground pursuer**, and
nothing else. Vault = a ~0.25s lerp across the wall (collision off vs. `world`
mid-vault, on vs. `hazard`), triggered by the contextual press when facing the
flagged edge. Win condition for the test: does vaulting the wall *visibly break
the chase* (pursuer must detour, you gain distance) and feel good to chain? Then
add the **Leaper** to confirm the negation reads. Add a one-way window variant
last to test the commit beat.

## Open questions
- **Cover-metadata authoring cost (scope — Director):** vault is dead until cover
  exists *and* carries a vaultable flag + normal. That's two upstream builds
  (`b1`/`e5`) plus an edge-metadata schema on the socket/tile format. Is the verb
  worth gating the whole chain on? *Recommend* prototype against a single
  hand-authored vaultable wall before committing to the scatter/decay pipeline.
- **Contextual-input ambiguity (fun/control — Director):** one button that
  sometimes vaults, sometimes interacts, sometimes no-ops risks mis-fires under
  chase pressure. Dedicated button (clarity, +1 binding) vs. contextual (clean,
  ambiguous)? *Recommend* contextual with a clear pre-vault telegraph (edge
  highlight when in range); revisit if playtest shows misfires.
- **Vault i-frames (balance):** invulnerable mid-vault makes it a panic-button
  dodge (strong, maybe too safe vs. ranged); vulnerable keeps it a *positioning*
  move. *Recommend* vulnerable — keep it geometry, not a dodge-roll; flag.
- **One-way window readability:** same hard problem as `e3` drops — in flat
  top-down, does "dive through, can't come back" read without a tell? Needs a
  distinct breach/window silhouette before it ships.
- **Leaper-only negation, or others too?** Should Chargers/packs also clear low
  cover, or is vault-immunity the Leaper's signature? *Recommend* Leaper-only so
  the negation stays legible; flag to Director.
