# Escalation Shape
**Category:** Quota system depth

## The mechanic
The quota is a Money bar each run must clear (K2); meeting it bumps the run number
and *raises the bar*, missing it wipes meta. **How fast the bar rises — the
escalation shape — is literally the difficulty curve of the whole meta-game.** Three
shapes:

- **Linear** — `quota = base + step·(run-1)`. Today's shape ($50 + $50/run). Constant
  pressure, perfectly predictable, easy to reason about; never spikes, so the wall
  arrives only when player income stops keeping up.
- **Accelerating** — geometric (`base·r^run`) or quadratic (Lethal Company). Each run
  raises the bar *more* than the last, so a calm early game tightens into a vise. The
  run-count "arc" is short and the late-game wall is sharp.
- **Stepped, calm-then-spike** — flat or gentle for N runs, then a jump (a "rent due"
  beat), repeat. Trades a smooth curve for **rhythm**: stretches of breathing room
  punctuated by a dreaded threshold — the meta-game equivalent of `research/05`'s
  in-dive telegraphed crisis tiers, but across runs.

The shape decides *when the player hits the wall*, *how that wall feels* (gradual
squeeze vs sudden cliff vs telegraphed beat), and *how many runs the meta-arc lasts*.

## What exists today
**Pure linear, flat increment, hard-coded as two scalars.** K2 ships
`quota_base=50` + `quota_step=50`; `_evaluate_quota()` does `quota_target += step` on
a met run (K2.md B.2). That's `quota(n) = 50 + 50(n-1)` — a straight line with no
acceleration, no spike, no curve object. `run_rules.gd` is unrelated (it's the
death-pockets dial), so there is **no quota-curve Resource at all** — the shape is
frozen in code, not data.

Meanwhile the *income* side that the quota races against **does** scale with depth:
`DepthCurve.value_curve` (a tunable `Curve`) lifts per-item value ~1.0→1.8 with
depth, `min_tier` steps rarer junk in deeper, and `research/05`'s `I` ties loot value
+ tier to the same instability scalar (+10%/unit, +15%/band). So **loot value rises
geometric-ish with depth/Instability, but quota rises only linear with run number** —
two different mathematical families on the two sides of the bet. That mismatch is the
gap: a linear bar against geometric income means once the player learns to push deeper
the quota stops biting; conversely early runs (shallow, low income) feel the linear
bar hardest. The shape is currently an accident of "+$50," not a designed curve.

## How to fit it in
- **Make the curve a Resource.** A `QuotaCurve.tres` (mirroring `DepthCurve`'s
  data-as-Resource shape) exposing the shape as data: a `mode` enum
  (`LINEAR / GEOMETRIC / QUADRATIC / STEPPED`) + params (`base`, `step`, `growth_rate
  r`, `step_every_n`, `spike_mult`), and a `quota_for(run:int)->int`. `_evaluate_quota`
  calls `quota_for(run_number)` instead of `+= step`. Now the shape is tunable in the
  inspector with no recompile, exactly like the depth value curve.
- **Pace it against player power + loot scaling.** The quota must out-pace *income
  growth*, not raw run count. Because loot value scales with depth/`I` (geometric) and
  s1-gear compounds earning (bigger bag, speed → more $/run), a **linear** quota will
  be out-run once gear lands → the wall recedes and stakes evaporate. A **geometric**
  quota whose rate tracks the gear/loot growth family keeps the bet near break-even
  (`research/05` principle #1: keep the two sides in the same math family).
- **Stepped for rhythm.** The calm-then-spike option gives the meta-game a heartbeat:
  3 calm runs, then a spike you *see coming* (HUD: "rent spikes next run"). This is the
  cross-run mirror of `research/05`'s telegraphed crisis thresholds and best fits the
  GDD's "debt starts soft, gets scary as you succeed."
- **RunConfig knob + telemetry.** Surface the curve params (or a `QuotaCurve` ref) on
  `RunConfig` — *ideal for A/B'ing difficulty feel*: ship linear as the preset, sweep
  geometric/stepped. The all-off/`quota_enabled=false` control already reproduces the
  no-quota baseline. Telemetry: stamp **`run_number` at first quota MISS** on the
  `quota_evaluated` row (K2 already emits it) → the distribution of first-failure run#
  per config **is the empirical difficulty wall**, directly comparable across shapes.

## Research (cited)
- **Lethal Company — quadratic acceleration.** `quota += 100·T·(1+curve(rand))` where
  `T = 1 + fulfilled²/16`: gentle early, then compounds hard — the canonical "calm runs
  then a vise" accelerating shape, with a *randomized offset* per step (echoes
  `research/05`'s randomized crisis flavor). The square term is what makes the late
  meta-game brutal. ([Quota formula — StardewProfit](https://www.stardewprofit.com/guides/lethal-company/quota-formula-explained), [Profit Quota — Lethal Company Wiki](https://lethal-company.fandom.com/wiki/Profit_Quota))
- **Slay the Spire ascension — stepped, and a warning.** Cumulative modifiers per rank
  make difficulty *stepped*; STS2 squished several into single ranks, so 8→9 jumps more
  than 0→8 combined — players call it "a vertical wall." **Lesson:** stepped/accelerating
  spikes must be *telegraphed and spaced*, or a single step reads as an unfair cliff.
  ([Ascension — STS Wiki](https://slay-the-spire.fandom.com/wiki/Ascension), [A9 spike discussion — Steam](https://steamcommunity.com/app/2868840/discussions/0/798967297092923918/))
- **Vampire Survivors — continuous ramp.** Spawn pressure ramps smoothly over a run
  (continuous), the opposite pole from STS's steps — the smooth-vs-stepped contrast that
  frames our choice. ([VS stages — Rogue Ranker](https://rogueranker.com/vampire-survivors-stages/))
- **Idle-game cost curves / RoR2.** Geometric cost inflation (each tier costs `r×` the
  last) keeps a sink from saturating — the same math the quota wants so income growth
  never permanently out-runs the bar (`research/05` RoR2 `coeff`, single-scalar model).

## Open questions
- **[DIRECTOR — core difficulty-curve call] Which shape, and how long is the intended
  arc?** Linear (current, predictable, wall-recedes-with-gear), geometric (short tense
  arc, hard late wall), or stepped (rhythmic, telegraphable). This decides the run-count
  the meta-game is balanced for (a 6-run arc vs a 30-run arc is a different game).
  **Recommendation:** ship **linear** as the shippable control, but make the curve a
  `QuotaCurve` Resource + RunConfig knob so geometric/stepped are A/B-swept at the gate;
  let the *first-MISS run#* telemetry pick the winner. *Fun/scope call — playtest validates.*
- **Coupling to loot/gear scaling.** Should the quota rate be *authored* (a fixed curve)
  or *derived* from the income curve (e.g. quota tracks `expected $/run × runs`)? Derived
  keeps the bet at break-even automatically but is opaque; authored is legible but can
  drift out of sync with depth/gear tuning. Recommend authored-but-validated-against the
  economy model (the M3 `economy_model.xlsx` Debt_Curve tab is exactly this).
- **Where should the wall sit?** What first-MISS run# is "motivating, not crushing"
  (GDD)? Too early = feels rigged; never = no stakes. Needs a target (e.g. "median first
  wall ≈ run 8–12 at the preset") to tune the shape against — a Director number.
- **Spike telegraphing.** If stepped, how many runs of warning before a spike, and does
  the HUD pre-announce it (the cross-run analogue of `research/05`'s telegraph rule)?
