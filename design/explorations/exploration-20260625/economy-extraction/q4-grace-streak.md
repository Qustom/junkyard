# Grace / Streak Mechanics
**Category:** Quota system depth

## The mechanic
A layer that sits *between* meeting the quota and the full roguelite consequence, softening the cliff so the loss is an arc instead of a single fall. Two flavors:

- **Grace (warning state):** a missed quota does not wipe immediately. The first miss puts you in a *warning* — one strike. You play another run; clear the (still-rising) bar and the warning clears, miss again and *now* the consequence fires. Tolerates `grace_count` consecutive misses before the wipe.
- **Streak (buffer):** overperformance banks credit. Clearing the bar with surplus (e.g. ≥150% of target, or ≥2× any single run) earns a stored **"skip"** — a token that auto-absorbs one future miss. You build a cushion by playing well, then spend it when you stumble. A streak buffer rewards the strong runs that the cumulative basis currently lets "leak" past the bar.

Both convert a binary pass/wipe into a graded slide, which is the lever for a *longer* arc than pure permadeath gives.

## What exists today
Honest read of the real build. Today there are **two separate failure surfaces**, and only one is a hard reset:

1. **Within-run loss (E3, `run_rules.gd`):** death/timeout drops the unbanked haul minus a "pockets" fraction (`pockets_fraction = 0.20`, highest-value-first). This is *already soft* — you keep whole items worth ~20% of the haul plus everything banked. No meta touched. This is a per-run cushion, not a quota mechanic.
2. **Quota miss (K2, `game_state.gd` `wipe_meta()`):** when the quota is on (preset `quota_enabled=true`, base 50/step 50, `every_run_end` × `cumulative_money`), a miss = **full roguelite wipe** — `money/salvage/lore/exposure/knowledge/recipes/banked_junk` all reset to defaults, `run_number → 1`, `quota_target → 0`. **There is no warning, no streak, no buffer** — one miss and the whole meta-state is gone (`K2.md` B.4, Director-FINAL).

What's missing: any softening *of the quota cliff itself*. There is also a live **design tension** the Director should see — GDD §88 reads *"No total resets — the run resets, the life persists,"* yet K2's wipe is exactly a total reset. Grace/streak is one way to reconcile that (the wipe becomes the *end* of a tolerated slide, not the first consequence). That reconciliation is itself a Director call (see p4).

## How to fit it in
Both flavors are **pure meta-state additions** that gate `wipe_meta()` — they change *when* the wipe fires, not the wipe itself, so K2's run/meta boundary and idempotency are untouched.

- **Grace:** add meta field `warnings_used: int`. In `_evaluate_quota`, on a miss: if `warnings_used < grace_count`, set a warning, `warnings_used += 1`, **do not** flag `_pending_wipe`. On a met quota, clear `warnings_used` to 0 (a clean run pardons the warning). Only when `warnings_used >= grace_count` does the miss route through `wipe_meta()`. The SellScreen shows "WARNING — clear next quota or you're wiped (1/1)".
- **Streak:** add meta field `skip_tokens: int`. On a met quota whose `achieved` exceeds a `streak_threshold_mult × target`, increment `skip_tokens` (cap it). On a miss, if `skip_tokens > 0`, decrement and absorb (no wipe); else wipe. Skips persist across runs as a banked safety net.

**Interaction with the reset-severity dial (p4):** grace/streak is *one knob on the same harshness axis p4 owns*. p4 picks **how hard** a terminal loss hits; grace/streak picks **how many strikes** precede it. They compose: e.g. p4 = "partial wipe" + grace = 1 warning is a very gentle Act-1 stance; p4 = "full wipe" + grace = 0 is K2-as-shipped. Recommend they be **dialed together** so total harshness is coherent, not stacked-soft by accident.

**Interaction with escalation (q5):** if the bar keeps rising during a warning/streak-protected stretch, grace can mask an *unrecoverable* gap (you're warned, but the bar is now too high to ever clear). Consider **pausing escalation while in a warning state** so grace is a genuine recovery window, not a delayed-doom.

**RunConfig + telemetry:** new knobs `grace_count: int = 0`, `streak_buffer_enabled: bool`, `streak_threshold_mult: float`, `streak_cap: int` — all defaulting **off** so the all-off control still reproduces the K2 baseline byte-for-byte (the standing M1.x contract). Add to `to_flat_dict()` for config-marked telemetry. New rows: `quota_warning_entered`, `quota_recovered_from_warning`, `streak_token_banked`, `streak_token_spent`. The gate metric is **recoveries-from-warning rate** and **wipe-rate-with-vs-without grace** — that's how RG2 tells the Director whether the cliff softened *too* much.

## Research (cited)
**Lethal Company** is the closest cousin and instructive by *omission*: its quota has **no grace period** — miss it and the whole crew is jettisoned (game over). The community is split: a vocal thread asks for "a chance to try again instead of being fired," while others note the harshness is the satirical *point* and the quota "is designed to game-over you eventually" ([Profit Quota wiki](https://lethal-company.fandom.com/wiki/Profit_Quota); [give-players-a-chance thread](https://steamcommunity.com/app/1966720/discussions/0/4034728215964784343/); [quota punishes doing good](https://steamcommunity.com/app/1966720/discussions/0/4038103682228231024/)). The "punishes doing good" complaint is exactly the surplus-leak that a **streak buffer** would convert into a reward.

On the broader cliff-vs-cushion axis: **Hades** reframes death as progress (you carry buffs/resources out), and **Shiren the Wanderer** lets you retain progress on restart — both "make death feel like an opportunity rather than a punishment." The cited caution: permadeath "works best where there are *not* sudden-death situations" — unavoidable losses plus a hard reset breed frustration, which is the case for *some* softening here ([Death in Gaming / Rogue Legacy](https://www.gamedeveloper.com/design/death-in-gaming-roguelikes-and-quot-rogue-legacy-quot-); [On Roguelikes and Progression](https://indiecator.org/2022/03/30/on-roguelikes-and-progression-systems/); [Permadeath - RogueBasin](https://www.roguebasin.com/index.php/Permadeath)). **XCOM** is the canonical knob: Ironman (one save, permadeath) vs. normal (reload) is the same "how many strikes" dial exposed as a difficulty mode — precedent for shipping grace as a *config/difficulty option* rather than a fixed policy.

## Open questions
- **Does grace dilute the tension K2 was built to add?** M1.4 went ITERATE *because* the loop was low-stakes; K2's whole purpose was to make a miss *matter*. Grace risks sanding that back off. **This is a fun/tone call — defer to the Director and to p4's harshness verdict.** Recommendation: ship grace **off by default** (preset `grace_count=0` = K2-as-is) and only turn it on if RG2's wipe-rate reads as *too* punishing in playtest.
- **How many warnings?** 1 (a single strike — recoverable but still scary) is the safe first cut; ≥2 starts to feel consequence-free. Lean 1, swept.
- **Does the game *want* roguelike harshness at all?** GDD §88 ("no total resets") and K2's full wipe genuinely conflict; the GDD also says "keep Act 1 forgiving." This is the same underlying decision p4 (reset-severity) resolves — grace/streak should **not** be decided independently of it. **Flag for the Director:** decide the overall harshness stance once (p4), then grace/streak is just *how many strikes* within that stance.
- **Streak: what counts as "overperformance"?** Under the `cumulative_money` basis, surplus is already implicitly banked (your balance carries forward), so a streak token partly double-rewards. Streak is cleaner under a `this_run_banked` basis — so the streak flavor's value depends on the unresolved q-basis call. Recommend pairing streak design with whichever basis q5/Director settle on.
- **Escalation-during-warning:** pause the bar's rise while warned, or let it keep climbing? Pausing makes grace a true recovery window; not pausing makes it a stay of execution. Lean pause (technical, but surface to Director as a feel call).
