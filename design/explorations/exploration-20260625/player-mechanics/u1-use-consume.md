# Use / Consume
**Category:** Other item verbs (besides throwing)

## The mechanic
Some junk items carry an **in-place effect** — heal, light, reveal, lure — triggered by a
**use** verb that consumes the item where you stand, instead of (or as an alternative to) throwing it
at a hazard. The throw verb stays central (it's the M1.5 agency verb), but the *highlight decision*
gets richer: with a use-capable item highlighted, the question is no longer "throw this or don't" —
it's **"throw this at the pursuer, OR burn it for light, OR keep it to sell."** A single junk type can
be a weapon, a tool, or salvage value, and you only get to pick one. That triangle (combat / utility /
economy) is the design payoff and it leans directly on the existing extract-vs-greed tension.

## What exists today
Honest read of `data/junk/junk_item.gd`: junk is **purely throwable + sellable salvage** today. The
Resource has identity, slot footprint, `base_sell_value`, greybox shape/color, `tier`/`origin_band` —
**no effect field of any kind.** Throwing (`entities/thrown_item/thrown_item.gd`, L1) already consumes
the item on a hazard hit and re-drops it on a miss, so "an item leaves your inventory and does
something" is a wired, proven path — use/consume is the same shape with the effect resolving *at the
player* instead of *on impact*.

**HP DEPENDENCY (flag for the Director).** A **heal** effect needs a player health pool, and M1 has
none — `entities/player/player.gd` has movement/aim only; the opposition-system doc parks HP at M2, and
hazards are binary-lethal (`r1_catch_kills`, `hpp_kills` → instant `queue_free`/run-end). So **heal is
out until M2.** The non-HP effects do *not* need a health pool and can ship now:
- **Light** — extend/refill the dive clock's light, or widen vision: `DiveClock.modify_light()` already
  exists, and `VisionFog._process` reads a per-frame radius we could add a timed bonus to.
- **Reveal** — flood the `VisionFog._revealed` fog dictionary around the player (counters the
  `4-darkness-pocket` opposition's vision squeeze).
- **Lure** — drop a decoy that pulls the `1-ambusher`/R1 pursuer off the player for a few seconds.

What's missing: an effect field on the data, a use input + UI, and the per-effect handlers.

## How to fit it in
- **Data:** an optional `use_effect` on `JunkItem` — a small enum (`NONE`/`LIGHT`/`REVEAL`/`LURE`,
  `HEAL` reserved for M2) plus one `use_magnitude: float`. `NONE` (the default) = today's pure
  salvage, so every existing `.tres` is unchanged. Throw stays available on use-items too — that's the
  whole point of the dual verb.
- **UI:** the highlight selector (Q/E) shows **both affordances** on a use-capable item — e.g. a
  throw glyph and a use glyph with the effect icon — so the player sees the choice. Plain salvage shows
  throw only (or nothing if `throw_enabled` is off).
- **Effects, sequenced by dependency:** ship **LIGHT/REVEAL/LURE first** (no HP needed), defer
  **HEAL to M2** when the health pool lands. This keeps the dual-verb choice testable now.
- **Opposition interplay:** REVEAL/LIGHT are the player-side counter to the
  `4-darkness-pocket` and the patroller/ambusher's "you can't see it coming"; LURE answers the R1
  pursuer and `1-ambusher`. This makes use-items a deliberate **answer to specific oppositions**, not
  generic buffs.
- **Dive clock:** LIGHT trading a sellable item for `+seconds` directly couples the use verb to the
  ~300s clock (`systems/dive_clock.gd`) — spend salvage to buy time, the core extraction tension.
- **Control mapping:** two clean options (Director call) — a **separate Use button** (throw=Space,
  use=a second key / controller face button), or **context** (tap = use, hold = throw on the same
  button). Separate buttons are more legible and avoid a hold-timing mis-fire mid-chase; context keeps
  the input surface small. Recommend **separate button**.
- **RunConfig + telemetry:** a `use_enabled` master toggle (all-off = today's no-use baseline, mirroring
  `throw_enabled`), plus an `item_used(item_id, effect, depth, run_t_ms)` EventBus signal alongside the
  existing `item_thrown`/`throw_*` rows, so the re-gate can compare **threw it vs used it vs sold it**
  per item type.

## Research (cited)
- **Spelunky** — bombs/ropes are scarce (4 each) and *use-vs-throw is the tactical core*: drop a normal
  bomb vs throw a sticky one; rope up from below vs bomb in from above. Scarcity makes each use a real
  decision — the model for "one item, one choice." [Critical-Gaming](https://critical-gaming.com/blog/2009/2/17/spelunky-a-game-design-gold-mine.html), [Spelunky Wiki: Throwing](https://spelunky.fandom.com/wiki/Throwing)
- **Noita** — a potion can be **drunk** (right-click, permanent consume, reliable timed effect) or
  **thrown** (shatters as a grenade, but the puddle is recoverable). "Drink vs stain is a trade-off,
  neither strictly better" — exactly the throw-or-use duality, with consume = permanent. [Noita Wiki: Potions](https://noita.wiki.gg/wiki/Potions)
- **Zelda: BotW torch** — a held **light/utility** tool (carry fire, reveal, updrafts) distinct from a
  thrown weapon; durability/consume model shows light-as-utility carrying real puzzle weight. [Zelda Dungeon: Torch](https://www.zeldadungeon.net/wiki/Torch_(Breath_of_the_Wild)), [Grizz Studio](https://grizzstudio.com/illuminating-hyrule-the-role-of-the-torch-in-the-legend-of-zelda-breath-of-the-wild/)
- **Resident Evil** — healing items are a separate *consume* verb under inventory pressure; the heal
  pattern is the M2-gated case here (needs HP).

## Graybox sketch
Smallest version that proves the dual verb **without HP**: one new junk `.tres` — a **"Flare"** with
`use_effect = LIGHT`, `use_magnitude = 30` (seconds), still throwable and still worth ~10 Money. With
`use_enabled` on, highlighting the Flare shows both glyphs; **Use** spends it for `DiveClock.modify_light(+30)`
and emits `item_used`, **Throw** flings it as today (kill a pursuer + consume), **neither** keeps it to
sell. That single item makes the player feel the triangle, and the telemetry split (used / threw / sold)
tells the Director whether the choice is live or whether one verb dominates.

## Open questions
- **HP-pool dependency (Director):** HEAL is blocked until the M2 health pool exists. Ship LIGHT/REVEAL/
  LURE now and reserve the `HEAL` enum value, or wait and ship use/consume whole in M2? Recommend ship
  the no-HP effects now — they're the cheaper, opposition-answering half and prove the verb.
- **Input scheme (Director):** separate **Use button** vs **tap/hold context** on the throw button.
  Recommend separate button for legibility under chase pressure; needs a controller-binding check
  against the L6 twin-stick layout.
- **Is the salvage opportunity-cost real?** If junk is abundant, "burn it for light" costs nothing and
  the triangle collapses to "always use." The choice only bites if salvage is scarce relative to the
  quota — a tuning/economy call, measure via the used/threw/sold split.
- **One effect per item, or also a throw-effect?** Could a thrown Flare *also* light where it lands
  (effect on impact)? Richer, but blurs the clean "use here OR throw there" read — defer; start with
  use = in-place only.
- **Stacking/cooldown:** can you chain three Flares for +90s, or is there a per-effect cap? Greybox can
  ignore it; flag for M2 economy tuning.
