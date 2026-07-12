# Top-Down Weapon Systems — THE FAR YARD

*Research spike for the Game Director. Surveys top-down combat prior art, recommends a
combat identity that honors the "engineer, not a soldier" pillar, and sketches how weapons
would integrate against the **as-built** M1 opposition + throw systems. Combat identity is a
vision/tone call — §5 (Open Questions) flags it explicitly for the Director with a recommendation.*

**Companion to:** `Junkyard_GDD.md` §7 (Combat & Tools), §6 (The Dive), `Junkyard_Technical_Design.md`
§3 (Threats / Instability), `06152026/05_difficulty_instability_scaling_model.md`,
`06152026/01_top-down_aesthetic_study.md`, and the M1 as-built opposition system
(`Game/scenes/hazards/`, `Game/entities/thrown_item/`, `Game/entities/player/player.gd`).

---

## 0. Design intent, captured honestly (read this first)

Before surveying weapons, the load-bearing question the task asks: **how much of a combat game
is THE FAR YARD meant to be?** The design is unambiguous, and the honest answer is *not much*:

- **Pillar 2 is "An engineer, not a soldier."** "You solve the depths with tools, wits, and
  jury-rigged gear. Combat is real but improvised and costly. **Cleverness beats firepower.**"
  (GDD §2)
- **GDD §7 makes avoidance a first-class verb.** "Stealth, distraction (toss a noisy part), and
  routing around are first-class options. Many deep things can't be killed cleanly, only evaded
  or warded." Tools are "tools-as-weapons-as-**traversal**" — the weapon list *is* the traversal
  list (magnet-grapple, nail-gun, saw-on-a-pole, breather rig).
- **The core verb is the push/cash-out bet, not the fight.** "This single tension drives the whole
  game" (Pillar 1). Combat is one of several *costs* you weigh against going deeper: "Fighting
  trades resources you could've spent going deeper — that's the point" (§7).
- **Threats are dread, not targets.** "Things that came through" get "more alien, less physical,
  and more dread-inducing by band. Deep things may require Knowledge/specific gear to even
  perceive or repel" (§7). The tone is "cosmic dread with warmth" — horror by wrongness, not gore
  (§13).

**The as-built M1 build already commits to this reading.** There is *no player health bar, no
melee, no gun.* The only offensive verb shipped is **throwing an inventory item** (`main_game.gd`
`_try_throw` → `ThrownItem` projectile), which **consumes the item** on a kill and **re-drops it**
on a miss. Enemies ("hazards") are **one-hit-kill on contact** (they end the run via
`GameState.fail_run(&"death")`) and are themselves **one-hit-killed** by a thrown item — there is
no HP on either side. The whole opposition roster (`ambusher`, `burrower`, `charger`, `lobber`,
`sentry`, `spike`, `splitter`, `pingpong`, the `pursuer`) is built as **telegraphed avoidable
hazards** with a `TelegraphFSM` (dormant→awake tells) rather than as fightable mobs.

> **This is the single most important framing for the whole document:** THE FAR YARD is a
> **survival/extraction game with an avoidance-first threat layer**, in the lineage of **Darkwood
> and Teleglitch**, *not* a twin-stick shooter in the lineage of Enter the Gungeon. Any weapon
> system we add must *reinforce* "fighting is expensive risk-management," not quietly convert the
> game into an action game where killing is the optimal loop. The rest of this doc is written to
> that brief; §5 gives the Director the off-ramp if they want a more combat-forward game.

---

## 1. Prior-art survey — top-down combat patterns

Each pattern below is rated on the axis that matters for us: **which tone it supports**, and
whether it pushes the player toward *fighting* or toward *avoiding*.

### 1.1 Twin-stick aimed ranged (Enter the Gungeon, Nuclear Throne)

**What it is.** One stick moves, the other aims; "the whole game lives in the tension between
dodging and shooting at the same time" ([Choost Games](https://choostgames.com/blog/best-twin-stick-shooter-games/)).
Enter the Gungeon is "a top-down bullet hell shooter with roguelike elements" that "all but
perfected" the form ([Wikipedia](https://en.wikipedia.org/wiki/Enter_the_Gungeon)); Nuclear Throne
is "the fastest, twitchiest game on this list... runs are short, death is instant."

**Strengths.** Extremely high skill ceiling, precise, satisfying, controller-and-mouse legible from
top-down (aim vector is unambiguous overhead). **Our player controller already supports it** —
`player.aim` is a decoupled twin-stick/mouse vector (see §3), so this is the *cheapest to build*.

**Weaknesses / tone.** These games make **killing the core verb and the reward.** Rooms lock; you
clear them; loot is the payoff for combat mastery. That is the **opposite** of "cleverness beats
firepower" and "avoidance is always viable." A bullet-hell skill economy also fights the "cosmic
dread with warmth" tone — bullet-hell is *exciting*, not *dreadful*. **Supports: action-roguelite
tone. Wrong fit for the stated design** unless the Director pivots the pillar.

### 1.2 Directional melee (Hyper Light Drifter, Death's Door, Zelda-likes)

**What it is.** Sword/tool swings in the aim/facing direction; dashes and i-frames as the defensive
core. Death's Door "is inspired greatly by Hyper Light Drifter" and blends "Zelda... with the
combat of Hyper Light Drifter" ([Analog Stick Gaming](https://www.analogstickgaming.com/game-reviews/2021/7/21/deaths-door)).
HLD's **dodge works in the aim direction**, and its designers deliberately made the cursor
"pull double-duty as both attack director and dash direction" — praised by some, contentious for
KB/M players ([Steam](https://steamcommunity.com/app/257850/discussions/0/365163537818567357/)).

**Strengths.** Melee reads *beautifully* from top-down when the swing is a **wide, short-lived arc
with a clear anticipation frame** — the overhead camera shows the whole arc. Risk-reward loops
(HLD/Death's Door refill a resource on melee hits, pulling you *into* danger) are elegant. Cheap
animation (a 3–5-frame arc + a dust puff).

**Weaknesses / tone.** Still fundamentally a **combat-forward** design — you're meant to engage.
For us it's a better fit than twin-stick because melee is *short-range and committal* (swinging
exposes you), which naturally makes fighting costly. Directional-dodge-in-aim-direction is the
proven top-down defensive primitive and maps directly onto our `player.aim`.

### 1.3 Hybrid extraction gunplay (Zero Sievert)

**What it is.** Top-down extraction shooter, "Stalker setting + Tarkov loop"
([GameMaker devlog](https://gamemaker.io/en/blog/zero-seivert-game-development)). Crucially, the
*designer's* framing is **playstyle-agnostic**: "You might approach it like a shooter... You might
choose to play it more like a stealth game... The top-down perspective... encourages careful
positioning and scouting rather than rushing into combat" ([Kotaku](https://kotaku.com/zero-sievert-steam-pc-game-extraction-shooter-tarkov-1849955431)).
Gameplay is "often slow and methodical, sometimes interrupted by sudden bursts of intense
shootouts."

**Strengths.** This is the **closest genre sibling** — an extraction loop where guns exist but
combat is a *risk you choose*, positioning/scouting is primary, and ammo is a scarce resource you
weigh against loot. The "slow and methodical, punctuated by bursts" rhythm is exactly what our
instability clock wants.

**Weaknesses / tone.** Zero Sievert leans harder into gun-collection (50 guns, 150 mods) than our
"engineer not soldier" pillar wants — a full gunsmith economy would drown the improvised-junk
identity. Take its **stance** (combat optional, positioning primary, ammo scarce) but **not** its
gun-catalog depth.

### 1.4 Deliberate "clunky" combat as a horror tool (Darkwood)

**What it is.** Top-down survival horror where combat is "clunky, but **deliberately so** — you'll
need to time your strikes almost perfectly," gated by a **stamina bar** and a **wind-up hold** that
forces you to commit ([Stevivor](https://stevivor.com/reviews/darkwood-review-things-go-bump-night/),
[Push Square](https://www.pushsquare.com/reviews/ps4/darkwood)). "Stealth is often a safer approach,
as many of Darkwood's enemies are incredibly dangerous... Sometimes, the most effective way to
survive is to avoid a fight altogether" ([Horror Chronicles](https://horrorchronicles.com/darkwood/)).

**Strengths.** **This is the tonal bullseye for THE FAR YARD.** Darkwood proves that *making combat
feel bad on purpose* — heavy, committal, stamina-gated, never reliable — is a **horror amplifier**
and a design lever that pushes players toward avoidance without ever forbidding fighting. Every
weapon is a last resort you're nervous to use. That is "combat is real but improvised and costly"
rendered as *feel*.

**Weaknesses / tone.** Clunk must be *legible* clunk (clear wind-up tells), or it reads as unfair
input lag rather than dread. Needs careful telegraph tuning — but our `TelegraphFSM` is already the
scaffolding for it.

### 1.5 Improvised / disposable weapons + durability (Dead Rising, ZombiU)

**What it is.** Weapons are scavenged environment objects that **degrade and break** with use. In
Dead Rising, "combat mechanics center on melee attacks utilizing improvised weapons scavenged from
the environment... which degrade after repeated use," and "the weapon durability system creates
gameplay tension through... resource scarcity and temporal pressure"
([Grokipedia](https://grokipedia.com/page/Dead_Rising_(video_game))). ZombiU's cricket-bat-as-only-
reliable-weapon and one-life stakes make every swing a rationing decision.

**Strengths.** **This is our weapon *identity* handed to us.** Weapons *are* junk; junk is the
economy; a weapon that breaks is a weapon you didn't sell. Durability turns every fight into a
literal **push/cash-out micro-decision** (do I spend this pipe-wrench's remaining swings, or save it
to sell?). It fuses the combat layer into the *economy* layer instead of bolting a separate
combat-power fantasy on top.

**Weaknesses / tone.** Durability is famously fiddly if over-tuned (Breath of the Wild backlash).
Must be *coarse and legible* (a few swings, a clear "about to break" tell), not a decimal HP bar on
every stick. And it must never feel like busywork — the fun is the *rationing decision*, not the
inventory management.

### 1.6 Stealth / avoidance-first with scarce combat (Teleglitch, Darkwood)

**What it is.** Combat exists but ammo/tools are so scarce that the *intended* solution is often to
**not fight**. Teleglitch invokes survival horror "via ammo scarcity," and "players can save a lot
of ammo by **luring monsters into the... anomaly**, which kills everything it touches" — turning
level hazards into weapons and avoidance into strategy ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Teleglitch)).
The tension is "between hoarding, use of items immediately, and use of items to make better items."

**Strengths.** **Directly models GDD §7's "toss a noisy part" distraction and "evade or ward" deep
things.** Environmental kills (lure a hazard into another hazard) are a perfect fit — our roster
already has hazards that kill *anything* (`spike`, `bomb`, the pursuer's lethal contact), so
"lure enemy A into hazard B" is nearly free content. This is the pattern that best expresses
"cleverness beats firepower."

**Weaknesses / tone.** Requires enemy AI that can be *manipulated* (aggro, noise, pathing) — heavier
AI than a dumb chaser. LimboAI (TDD §4) is the intended tool for exactly this.

### 1.7 Traps / deployables (Teleglitch mines, tower-defense-adjacent)

**What it is.** Player-placed area denial: mines, snares, lures, wards. The GDD already seeds this —
**yard defenses in Act 2/3 are "wards, traps, reinforced gates"** with "a tower-defense-adjacent
payoff late" (§8).

**Strengths.** Deployables are the **engineer's** answer to combat — you don't *duel*, you *prepare
the ground*. A pre-placed trap or a ward that repels (not kills) a deep thing is peak "solve it with
gear." They also bridge the dive layer and the yard-defense layer (same trap tech, two contexts).

**Weaknesses / tone.** Placement UI and AI-vs-trap interplay are the most expensive to build well;
defer past the vertical slice.

### 1.8 Defensive options (shields, dodge, block, ward)

The defensive verb matters more than the offensive one for our tone. Options, cheapest→richest:
**(a) dodge/dash in aim direction** (HLD/Death's Door primitive; smallest build, highest utility —
also a *traversal* verb); **(b) a stamina-gated block/parry** (Darkwood's commit-cost feel);
**(c) a deployable/held ward** that *repels rather than kills* deep things (GDD §7's "warded" verb,
and the only viable "defense" against things that "can't be killed cleanly").

### 1.9 Survey summary

| Pattern | Core verb | Tone it supports | Fit for THE FAR YARD |
|---|---|---|---|
| Twin-stick ranged (Gungeon) | **Kill** | Action-roguelite, exciting | ✗ Wrong pillar (but cheapest — controller already supports aim) |
| Directional melee (HLD/Death's Door) | Kill (committal) | Action-adventure | ◐ Good *primitive* (arc + aim-dodge), too combat-forward as the identity |
| Extraction gunplay (Zero Sievert) | **Choose** to fight | Tense survival, playstyle-agnostic | ◑ Closest *loop* sibling; borrow stance not gun-depth |
| Deliberate clunk (Darkwood) | Fight as last resort | **Survival horror / dread** | ✓✓ **Tonal bullseye** |
| Improvised + durability (Dead Rising/ZombiU) | Ration disposable weapons | Scavenger survival | ✓✓ **Weapon identity + economy fusion** |
| Stealth/avoidance (Teleglitch/Darkwood) | **Avoid**, lure, distract | Scarcity survival | ✓✓ **Core-verb fit; nearly-free environmental kills** |
| Traps/deployables | Prepare the ground | Engineer/tower-defense | ✓ Great late; defer past M2 |
| Defensive (dodge/block/ward) | Survive the mistake | All | ✓✓ Dodge is the cheapest, highest-value add |

---

## 2. What fits THE FAR YARD — recommended combat identity

### 2.1 The recommendation: "The Reluctant Engineer" (avoidance-first, improvised, costly)

**A layered kit where every offensive option is deliberately scarce, disposable, or committal, and
the *default* optimal play is to avoid — combining Darkwood's committal feel, Teleglitch's scarcity
and environmental kills, and Dead Rising/ZombiU's disposable-junk weapons.** Concretely:

1. **Defense first (cheapest, highest value): an aim-direction dodge/dash.** A short burst move with
   brief i-frames, aimed by `player.aim`, on a stamina/cooldown budget. It doubles as a *traversal*
   verb (cross a gap, escape a lunge) — honoring "tools-as-weapons-as-traversal." This is the single
   most impactful combat add and the one to build first (§3.5).

2. **The primary offensive verb stays THROWN JUNK** — the already-shipped `ThrownItem` seam. It is
   *self-limiting by construction*: throwing spends an item you could have sold or carried, and a
   miss drops it on the floor to be re-fetched under pressure. This is the purest "cleverness beats
   firepower / fighting trades resources" expression already in the build. **Keep it as the spine.**

3. **A small set of equippable improvised weapons, each with a distinct role and a *durability/ammo/
   fuel* cost**, drawn from the GDD's own examples — the tool *is* the weapon *is* the traversal key.
   Weapons live as **`.tres` data** (§3.1). Suggested launch archetypes (all "junk you found"):

   | Weapon | Archetype | Cost that bites | Traversal / utility twin (GDD §7) | Threat role |
   |---|---|---|---|---|
   | **Pipe wrench** | Melee, wide committal arc | Durability (a few dozen swings; loud) | Pries jammed panels / valves | Reliable but exposes you; the "last resort" |
   | **Rebar spear** | Melee, thrust (long, narrow) | Durability; can snap → becomes thrown | Vaults / pole-vault a gap | Reach without closing distance; anti-lunger |
   | **Nail-gun** | Ranged, short-range, aimed | Ammo (nails, scarce) | Repairs/builds (recipe tie-in), pins panels | The GDD's own example; scarce ammo = choose targets |
   | **Battery taser** | Ranged-touch, *stun not kill* | Charges (rare); recharge at yard | Powers dead terminals / doors | Buys *escape time*, doesn't remove the threat |
   | **Circular-saw-on-a-pole** | Melee, sustained, fuel-hungry | Fuel (burns fast; very loud) | Cuts through blocked paths | Deletes a hazard *and* a wall — but screams your position |
   | **Thrown scrap** (spine) | Thrown, consumes item | The item itself (sell value) | Distraction ("toss a noisy part") | Kill *or* lure — the Teleglitch verb |
   | **Breather rig / ward** (defensive) | Held/deployed | Filter/charge | Survives toxic pockets + **muffles sound (stealth)** | Wards/repels deep things that "can't be killed" |

   Note how each **cost is a different currency of scarcity** (durability / ammo / charge / fuel /
   the item itself), so no single "just stock up" solution trivializes combat — the same
   distinct-drain discipline the economy model uses for Money/Salvage/Lore.

4. **Environmental kills are a first-class, cheap-to-build offensive option.** The roster already has
   hazards that kill anything they touch (`spike`, `bomb`, the pursuer's `LethalContact`). "Lure
   hazard A across hazard B," or "throw a noisy part to pull a pursuer onto a spike," is the
   Teleglitch anomaly-lure verb and the strongest "cleverness beats firepower" beat we can ship.
   It needs *manipulable* AI (noise/aggro), which is the LimboAI investment (§3.4).

5. **Deep things escalate from "killable" to "only evadable/wardable."** By GDD §7, Band-3/4 threats
   should shrug off junk weapons and require a *ward* (repel) or *Knowledge/gear to even perceive*.
   This keeps combat power from scaling into a solved problem and preserves dread at depth — and it's
   consistent with the Instability model (`06152026/05`): the same `I` scalar that makes loot better
   makes threats less physical, so "fight it" stops being on the menu exactly when greed peaks.

### 2.2 Durability / scarcity stance (recommendation)

**Coarse, legible, economy-fused. Not a decimal HP bar on a stick.**

- Express durability as a **small integer "uses/charges/fuel" pool** on the weapon `.tres`
  (e.g. `max_uses`, `current_uses`), with a **single "about to break" tell** (color/sound at ≤20%)
  — Darkwood-style commitment, not Breath-of-the-Wild micromanagement.
- **A broken weapon isn't gone — it's *degraded loot*.** It drops to a lower-tier salvage item you
  can still sell or repair (recipe system, GDD §8). This makes "should I use my last 3 swings or
  save this to sell?" a genuine push/cash-out micro-decision, and keeps durability *inside* the
  economy rather than as a pure punishment.
- **Ammo/fuel/charge are dive consumables** you prep in the morning loadout (GDD §5.1) and can craft
  or buy. Scarcity is the tuning dial that keeps fighting "costly" — set by the economy workbook,
  playtested at the fun gate, not hard-coded.
- **Loudness as a hidden cost.** The saw and gun are *loud*; noise raises hazard aggro / spawns
  (Teleglitch's "gun-toting enemies" tension). This gives the silent options (thrown junk,
  breather-muffled movement) a real strategic edge and rewards avoidance without a stat penalty.

### 2.3 How combat interacts with exposure & extraction pressure

This is where combat must *serve the core loop* rather than compete with it:

- **Combat spends the dive clock indirectly.** Every fight is time you're not moving toward loot or
  a gate while Instability `I` climbs (`06152026/05`). Standing to fight = `I` rises = threats worsen
  and the extract gate gets scarier. Fighting is thus *always* a bet against the clock.
- **Scarce weapon resources are haul you didn't bank.** Ammo/fuel carried and spent, and durability
  burned, are value you chose to convert into safety instead of profit — the Tarkov sunk-cost lens
  from the Instability doc, applied to the *combat* budget.
- **Loud combat can feed Exposure indirectly at depth** (optional, later): a very loud dive (saw,
  gun) could nudge the "things follow you up" incursion pressure that motivates yard defenses in
  Act 2 (GDD §8) — a clean thematic link between *how* you fight below and *what* raids you above.
  Flag as a stretch coupling, not an M2 requirement.
- **The dodge is the pressure-release valve.** Because avoidance is the intended default, the *dodge*
  (not a weapon) is what lets a skilled player run a near-pacifist dive — the highest-tension,
  highest-reward playstyle. That is the fantasy to protect.

### 2.4 Alternatives (for the Director to weigh — see §5)

- **Alt-A "Scavenger Shooter" (more combat-forward):** adopt Zero Sievert's stance harder — a couple
  of real aimed ranged weapons with mods, combat as a *frequent* chosen activity. More content-hungry
  (animation, balance) and softens the "engineer not soldier" pillar, but broadens appeal.
- **Alt-B "Pure avoidance / near-pacifist" (more horror-forward):** cut equippable weapons entirely;
  keep only thrown junk, dodge, distraction, and wards. Maximum dread and cheapest to build; risks
  feeling combat-*starved* for players who want an out when cornered. Darkwood-minus-the-axe.
- **Recommended = the middle path (§2.1):** avoidance-first with a *small* disposable-weapon safety
  net. It's the truest to the written pillars and reuses the most as-built code.

---

## 3. Integration sketch (against the as-built M1 APIs)

The build already contains ~70% of a combat spine. This sketch adds weapons **without breaking the
locked contracts** (fixed-arity EventBus signals, config-snapshot discipline, run/meta boundary).

### 3.1 Weapon as `.tres` data + scene (the Director-owned content seam)

Mirror the existing `JunkItem`/`HazardEntity` split: **data drives a thin scene.** New Resource
`data/weapons/weapon.gd` (`class_name Weapon`), authored per-weapon as `.tres`:

```gdscript
class_name Weapon extends Resource
@export var id: StringName                       # &"pipe_wrench"
@export_enum("melee_arc","melee_thrust","ranged","touch_stun","thrown","ward") var kind: String
@export var damage_tier: int = 1                 # vs a hazard's "armor tier" (see §3.3)
@export var reach_px: float = 28.0               # arc radius / thrust length / hitscan range
@export var arc_degrees: float = 90.0            # melee only; the swept cone the hitbox tests
@export var windup_s: float = 0.12               # Darkwood commit-cost; also the telegraph window
@export var cooldown_s: float = 0.35
# Scarcity — exactly one is the binding drain per weapon (durability | ammo | fuel | charge)
@export_enum("durability","ammo","fuel","charge","item") var cost_kind: String = "durability"
@export var max_uses: int = 40
@export var noise_radius_px: float = 0.0         # 0 = silent; feeds hazard aggro (§3.4)
@export var repels_only: bool = false            # true = ward: pushes/stuns, never frees the body
@export var broken_into_id: StringName = &""     # the degraded JunkItem a broken weapon becomes
```

A **linter** (per the game-director-designer content workflow) checks: `broken_into_id` and any
ammo/fuel item id resolve in the catalogs; `damage_tier`/`max_uses`/reach in sane ranges; `kind`
consistency (e.g. `arc_degrees` only meaningful for `melee_arc`). Never hand over data that fails
its own lint.

Weapons that need a projectile (`ranged`, `thrown`) **reuse `ThrownItem`** (or a `Projectile`
generalization of it); melee/touch/ward weapons are **pure hitbox tests**, no scene needed beyond
an `Area2D` on the player.

### 3.2 The attack: a player `WeaponController` component (compose, don't bloat player.gd)

`player.gd` is deliberately minimal (movement + aim only; §3.5). Follow the **`OppositionComponent`
precedent** — a host-owned child node that the host ticks — but on the player side. New
`entities/player/weapon_controller.gd` reads `player.aim`, owns the equipped `Weapon`, and drives a
child `Area2D` "swing hitbox." Input is a new `attack` action (a *sibling* of the existing `throw`
action; do **not** overload `throw`):

```gdscript
# weapon_controller.gd (child of Player) — sketch, against real APIs
func _unhandled_input(e: InputEvent) -> void:
    if e.is_action_pressed(&"attack") and _ready_to_swing():
        _begin_attack()                  # start windup; play telegraph; lock swing for windup_s

func _resolve_hit() -> void:             # fires at end of windup for melee_arc/thrust
    var aim: Vector2 = (_player as Player).aim
    for body in _swing_area.get_overlapping_bodies():
        if not body.is_in_group(&"hazard"): continue
        if not _within_arc(body.global_position, aim): continue     # cone test for melee_arc
        _apply_hit(body)                 # §3.3
    _spend_cost()                        # durability/fuel decrement + break check (§3.3)
    if weapon.noise_radius_px > 0.0:
        EventBus.combat_noise.emit(_player.global_position, weapon.noise_radius_px, depth, t_ms)
```

**No new physics ticker beyond the one `Area2D`** — the swing area is enabled only during the active
frames, matching the "one physics callback per entity" discipline the opposition components enforce.

### 3.3 Damage / kill resolution — extend the existing throw seam, don't fork it

The build has **no HP** on hazards; a thrown item calls `body.queue_free()` (or the duck-typed
`resolve_throw_death(killer_ctx) -> bool`, which the Splitter uses to split-then-free). **Reuse that
exact seam for melee/ranged** so there is one death path:

- **Simplest (matches M1): one-hit kill by tier gate.** A weapon kills a hazard iff
  `weapon.damage_tier >= body.armor_tier` (new optional `armor_tier` field on the hazard param bag,
  default 0 = "anything kills it," preserving current behavior). Below tier → the hit *repels/stuns*
  (knockback + brief freeze) instead of killing — reusing the pursuer's existing
  `_apply_nonfatal_catch` knockback/stun pattern in reverse. This gives deep things their "can't be
  killed cleanly, only warded" property (GDD §7) **with no HP system**.
- **`_apply_hit(body)`** calls the *same* duck-typed hook the thrown item uses:

```gdscript
func _apply_hit(body: Node) -> void:
    var killer_ctx := {"weapon_id": weapon.id, "kind": weapon.kind,
                       "depth": GameState.current_depth_index, "run_t_ms": _t_ms()}
    EventBus.opposition_event.emit(_hazard_kind(body), &"killed_by_weapon", ctx.depth, ctx.run_t_ms)
    if weapon.repels_only or weapon.damage_tier < _armor_tier(body):
        _repel(body)                                   # knockback + stun; never frees the body
        return
    var handled := body.has_method(&"resolve_throw_death") \
        and body.resolve_throw_death(killer_ctx)       # Splitter etc. handle own death
    if not handled: body.queue_free()
```

This means **Splitter, ward-immunity, and every future hazard death behavior keep working for melee
and ranged for free** — the seam was designed generic. It also keeps telemetry uniform (one
`opposition_event` family; add `&"killed_by_weapon"` alongside the existing `&"killed_by_throw"`).

### 3.4 LimboAI enemy hooks — make hazards *manipulable* (the avoidance payoff)

Today's hazards are scripted state (dormant/awake, chase/patrol). To pay off avoidance/luring
(§2.1.4) they need to *react to the player's noise and to each other*. Two additive hooks, both
config-snapshot-clean:

- **A `combat_noise` EventBus signal** (new, primitives-only, pre-declared before the parallel wave
  per the as-built EventBus discipline): `combat_noise(world_pos, radius, depth, run_t_ms)`. Loud
  weapons and thrown "noisy parts" emit it. Hazards with a `NoiseListener` opposition component wake
  / re-path toward the noise → distraction and luring become real. This is the "toss a noisy part"
  verb (GDD §7) and the mechanism behind Teleglitch-style lures.
- **Hazard-vs-hazard lethality already exists** (a `spike`/`bomb` kills anything on contact). Luring
  hazard A onto hazard B needs only that A's pathing can be *led* — a LimboAI behavior-tree leaf
  "move toward last-heard-noise" or "flee player" gives it for free. LimboAI (TDD §4, pinned
  v1.7.1) is the intended tool; the current bespoke FSMs stay as the fallback for dumb chasers.

Keep the **config-snapshot rule** (`OppositionComponent`): the `NoiseListener` is `bind()`-ed with
resolved primitives, never reads `active_run_config`.

### 3.5 What the player controller already gives us (and what it must NOT lose)

`player.gd` (as-built) is a gift for combat: **`aim` is already decoupled** from movement (twin-stick
right-stick or mouse), unit-testable via the pure `resolve_aim()`. Melee arc direction, thrust
direction, ranged aim, and dodge direction **all read `player.aim` with zero controller changes.**

The dodge (§2.1.1) is a small, testable addition following the existing **pure-function precedent**
(`step_velocity`, `resolve_aim` are side-effect-free and headlessly tested): add a
`step_dodge(velocity, aim, dodge_state, delta)` pure helper + an i-frame window, gated by a `dodge`
action. It must respect the existing `_exposure_speed_mult` seam and the `PlayerVisual` action-lock
so it composes with M1.1's exposure penalties and M1.7's animation lock rather than fighting them.

**Guardrail:** do not add a player health bar casually. The current "one-hit-kill, avoidance is the
health system" model is a strong tonal choice (Darkwood/ZombiU one-life dread). If the Director wants
survivability, prefer **a dodge + wards + a small "downed, drop haul, limp out" state** over a
regenerating HP bar — see §5 Q3.

### 3.6 Smallest testable slice (build order)

The minimum vertical slice that proves the combat *identity* (not a full arsenal), in dependency
order:

1. **Dodge/dash** (aim-direction, i-frames, stamina) — pure `step_dodge` + a `dodge` action + a
   headless test asserting i-frame window and direction from a fixed `aim`. *Highest value, no data.*
2. **One melee weapon (pipe wrench)** as a `Weapon.tres` + `WeaponController` + swing `Area2D`,
   killing a hazard via the reused `resolve_throw_death`/`queue_free` seam. Headless test: swing arc
   overlaps a stub hazard in the aim cone → hazard freed; out-of-cone → untouched.
3. **Durability + break-into-junk:** wrench `max_uses` decrements, at 0 it swaps to `broken_into_id`
   JunkItem (reusing `junk_dropped`/inventory paths). Test: N swings → broken item in inventory.
4. **`combat_noise` + one `NoiseListener` hazard:** a loud swing wakes/pulls a dormant pursuer;
   thrown "noisy part" lures it. Test: emit noise near a dormant hazard → it awakens/re-paths.
5. **Tier-gated repel (one "deep thing"):** a hazard with `armor_tier = 2` shrugs a tier-1 wrench
   (repelled, not killed); a ward `repels_only` weapon pushes it. Test: tier-1 hit → body alive +
   knocked back; ward → pushed, never freed.

Each slice is independently playtestable and maps to a telemetry question (how often do players
fight vs avoid? does durability read as tension or busywork?). That data is what the Director needs
to disposition the §5 identity call at the M2 gate — combat is the M2 "first thing that came through,
with avoid/fight choice" line item (TDD §7).

---

## 4. Readability & feel notes (top-down constraints)

From `06152026/01_top-down_aesthetic_study.md` and the survey, the pixel-art top-down camera imposes
specific rules combat animation must obey:

- **Melee arcs must be wide, brief, and high-contrast.** The overhead view shows the whole swept
  cone — a 3–5-frame arc with a bright leading edge reads instantly; a thrust needs a clear extend/
  retract. Keep the **legibility layer** (band-independent high-contrast for player/threats, per the
  band visual-language study) so a swing never gets lost against busy junk.
- **Telegraph every threat attack** (Instability doc principle 3: "tell before the bite"). The
  `TelegraphFSM` already does dormant→awake; extend it to a **pre-attack wind-up tell** so a hazard's
  lunge is *foreseen*, making avoidance a skill rather than a coin-flip.
- **Deliberate clunk needs a *visible* wind-up** (Darkwood) or it reads as input lag. The `windup_s`
  on the weapon is both the commit-cost *and* the on-screen anticipation frame — surface it (a
  raise/charge pose) so heavy = readable, not laggy.
- **4-directional sprites + short cycles** (aesthetic study's animation-cost mitigation): author
  weapons as a small arc/thrust overlay that rotates to `aim` rather than 8 hand-drawn directions
  per weapon per gear combo — the Moonlighter "4 views × every gear" tax is the thing to avoid.

---

## 5. Open Questions (for the Director — combat identity is a vision/tone call)

> **Q1 is the headline vision call and must not be self-resolved.** The rest cascade from it.

**Q1 — What is THE FAR YARD's combat identity? (VISION/TONE — Director decides.)**
*Trade-off:* the written pillars ("engineer not soldier," "cleverness beats firepower," "avoidance
always viable") and the entire as-built opposition system point at **avoidance-first, combat as
costly last resort** (§2.1, Alt-B-leaning). But that risks feeling combat-*starved* or clunky-in-a-
bad-way for players who want a satisfying out when cornered, and it caps the game's action-market
appeal. The opposite pole (Alt-A "Scavenger Shooter") broadens appeal but softens the pillar and is
far more content-hungry.
**Recommendation:** commit to the **middle path (§2.1) — avoidance-first with a *small* disposable-
weapon safety net + a strong dodge** — and let the M2 telemetry (fight-vs-avoid rates, "did combat
feel fun or annoying?") disposition whether to lean toward Alt-A or Alt-B. Build the §3.6 slice, gate
the decision on data. *Needs Director review.*

**Q2 — Does the player get a health bar, or stay one-hit-kill?**
*Trade-off:* one-hit-kill (current) maximizes dread and is cheapest, but is punishing and can feel
unfair without generous telegraphs; an HP bar softens the game and invites tanking-through-combat
(which fights the pillar). **Recommendation:** stay closer to one-hit-kill but add a **dodge + a
single "downed → drop unbanked haul → limp to a gate" second-chance** rather than a regenerating HP
bar — preserves stakes, removes the worst feel-bad. *Needs Director review* (it changes the fail
model that E3/`fail_run` implements).

**Q3 — Durability: how coarse, and does a broken weapon become sellable junk?**
*Trade-off:* fine-grained durability = rich rationing but risks BotW-style busywork; coarse
"uses/charges" + break-into-junk = legible and economy-fused (§2.2) but less simulationy.
**Recommendation:** coarse + break-into-junk. Numbers set by the economy workbook and swept at the
fun gate. *Resolvable in design; flag the tuning to the economy model.*

**Q4 — Do we add a distinct `attack` input, or keep throw as the only offensive verb for M2?**
*Trade-off:* adding melee/ranged is more fun-surface but more scope; the throw seam alone already
expresses the pillar. **Recommendation:** ship the **dodge + one melee weapon** in the M2 slice
(§3.6 steps 1–3) as the minimum that tests the identity; hold ranged/ward/traps until the identity
is dispositioned. *Resolvable once Q1 lands.*

**Q5 — How manipulable should enemy AI be (noise/luring), and is that an M2 or M3 investment?**
*Trade-off:* luring/distraction is the strongest "cleverness beats firepower" beat and reuses
existing lethal hazards nearly for free — but it needs LimboAI behavior work heavier than the current
bespoke FSMs. **Recommendation:** ship the **`combat_noise` signal + one `NoiseListener` hazard** in
M2 as a proof (§3.4/§3.6 step 4); defer rich multi-hazard luring ecosystems to M3 enemy-variety work.
*Resolvable in design.*

**Q6 — Do deep things (Band 3–4) become truly unkillable (ward-only), and when does that gate in?**
*Trade-off:* ward-only threats preserve dread and stop combat power from solving the deep end
(consistent with the Instability `I` model), but require the ward/repel system and the tier-gate
(§3.3) to exist. **Recommendation:** yes, via the `armor_tier` gate — but it's a Band-3+ concern, so
M3, not M2. *Resolvable in design; note it as an M3 dependency on wards.*

**Q7 — Does loud combat feed Exposure / incursion pressure (the "things follow you up" link)?**
*Trade-off:* a clean thematic bridge (how you fight below → what raids your yard above, GDD §8) but
an extra cross-system coupling that could confuse the exposure model's tuning. **Recommendation:**
prototype as an *optional* stretch coupling after the exposure system is real (M3+), keep it out of
the M2 slice. *Needs Director review as a design-scope call.*

---

## Sources

- [Choost Games — The Best Twin-Stick Shooters That Still Hold Up](https://choostgames.com/blog/best-twin-stick-shooter-games/)
- [Wikipedia — Enter the Gungeon](https://en.wikipedia.org/wiki/Enter_the_Gungeon)
- [Analog Stick Gaming — Death's Door review](https://www.analogstickgaming.com/game-reviews/2021/7/21/deaths-door)
- [Steam — Hyper Light Drifter dodge/aim discussion](https://steamcommunity.com/app/257850/discussions/0/365163537818567357/)
- [Steam — Hyper Light Drifter dashing in aim direction](https://steamcommunity.com/app/257850/discussions/0/365163686046995472/)
- [Kotaku — Zero Sievert extraction shooter](https://kotaku.com/zero-sievert-steam-pc-game-extraction-shooter-tarkov-1849955431)
- [GameMaker devlog — Developing Zero Sievert: A Tense, Top-Down Shooter](https://gamemaker.io/en/blog/zero-seivert-game-development)
- [Stevivor — Darkwood review (deliberate clunky combat)](https://stevivor.com/reviews/darkwood-review-things-go-bump-night/)
- [Push Square — Darkwood review (stamina-gated committal combat)](https://www.pushsquare.com/reviews/ps4/darkwood)
- [Horror Chronicles — Darkwood (avoidance-first)](https://horrorchronicles.com/darkwood/)
- [Grokipedia — Dead Rising (improvised weapons + durability scarcity)](https://grokipedia.com/page/Dead_Rising_(video_game))
- [Dead Rising Wiki — Durability](https://deadrising.fandom.com/wiki/Durability_(Dead_Rising_3))
- [TV Tropes — Teleglitch (ammo scarcity, anomaly lures, avoidance)](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Teleglitch)
- [GamingOnLinux — Teleglitch top-down roguelike shooter](https://www.gamingonlinux.com/2012/12/teleglitch-a-roguelike-topdown-shooter-with-pixel-graphics/)
