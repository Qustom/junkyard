# Critical Path + Side Rooms
**Category:** Room-and-corridor archetypes
**Date:** 2026-06-25

> Procgen-archetype exploration only. Pseudocode is illustrative against the real as-built `BandGenerator` API; no production code, no contract widening, no branch. Goal: a band shape that leans into THE FAR YARD's one core tension (push or cash out) and is the easiest of the room-and-corridor family to tune.

## The archetype

One obvious through-line runs from the entry gate to the exit/deeper gate — the **spine**. Hanging off it are optional **side rooms**: dead-end or short detour branches you can ignore entirely and still finish the band. The spine reads as "the way forward"; the branches read as "you don't *have* to go in there." Spatially it feels like a main hallway with rooms budding off it — the most *authored*-feeling of the procgen family, because the designer controls exactly two levers (how long is forward, how tempting is sideways) instead of an emergent maze.

It is the easiest archetype to tune for extraction because the **risk/reward is explicit and local**: every detour is a discrete, opt-in bet with a legible cost (extra time, deeper exposure, a gauntlet at the mouth) and a legible payoff (the graded loot at the dead end). You can dial fun by moving a single number — the detour-loot premium — without re-architecting the maze. There is no "did the player even find the good stuff?" ambiguity that open layouts suffer.

## How it fits THE FAR YARD bands

The main-line-vs-greedy-detour choice **is** the push/cash-out decision rendered in space. GDD §6: "every zone deeper improves loot quality but costs time, risks your unbanked haul, and raises instability — push or extract?" Here that bet is also: *do I burn the dive clock and exposure budget to clear that side room, or do I stay on the spine toward the next gate and bank?* A player who skips every branch can speed-run gate-to-gate and cash out clean (the cautious M1-baseline behavior); a greedy player detours, fattens the haul, and risks losing it. Both are first-class, which is exactly the tension we want frequent.

This suits **early-to-mid bands** especially, where we want the loop legible and the push/cash-out call teachable. The opposition spread hosts cleanly: branch **mouths** are the natural home for a gatekeeper opposition (a Patroller vision-cone, a Sentry, a Crusher-piston choke) so the detour *costs* before it pays; the spine carries lighter ambient pressure (Lobbers, a sweeping laser) so forward motion is never free either. Core verbs — move, fight, salvage, extract — all read in the choice of which sockets to walk through.

## Generation approach (on the real bandgen system)

The socket assembler already supports this with no rewrite — it's `branch_chance` (`bandgen_config.gd:19`) plus a depth-aware grow-policy, both of which the M1.1 R4 hook (`band_generator.gd:308-329`) already proved.

Algorithm sketch (one `_generate_once` pass, `band_generator.gd:84`):
1. **Grow the spine.** Force `_select_frontier_index` to return the deepest socket (`frontier[-1]`, line 329) until the spine reaches a target length — exactly the current M1.0 linear behavior, which is the all-off baseline.
2. **Bud branches.** With a non-zero, *spine-only* branch chance, occasionally fork from a non-deepest spine socket (the existing `RNG.randi_range(0, frontier.size()-1)` fork, line 328). Cap branch piece-depth to keep detours short (R4 already exposes `r4_max_branch_depth`), and **budget** total branches so the band stays mostly-spine.
3. **Seal & accept.** `socket_sealer` caps leftover sockets; `is_band_connected` (line 477) still guarantees every branch is walkable doorway-connected.

**Loot concentration** is `DepthGrader`'s `dist_to_gate` (`depth_grader.gd:56`), which is computed by *independent reverse BFS* precisely so reward can key off a branch's return distance rather than raw depth — a dead-end side room scores *higher* return-cost than a spine piece at the same depth. `junk_placer` reads that to seat the best-tier junk at branch ends, making "deepest into the detour = best loot, worst walk home" automatic. Fully seeded: every choice flows through `RNG` at the same draw sites, so `(seed + config)` stays byte-reproducible (`tests/test_bandgen_determinism.gd`), and the neutral config reproduces the linear M1.0 fingerprint.

## Flavor knobs

- **Spine length** — pieces gate-to-gate (drives the cautious-path dive time).
- **Branch count / budget** — how many side rooms bud per band.
- **Branch depth cap** — short stub vs. multi-room mini-dungeon (`r4_max_branch_depth`).
- **Detour-loot premium** — the single fun-dial: how much better the dead-end junk tier is vs. spine junk (`depth_grader.dist_to_gate` → `junk_placer` multiplier).
- **Mouth-toll opposition density** — gatekeeper strength at branch entrances.
- **Branch-bias** — fork from shallow vs. deep spine sockets (early vs. late detours).

## Synergies & tensions

- **Gauntlet detours** — pairing a high loot premium with a Sentry/Crusher/laser mouth turns a side room into a self-contained risk/reward set-piece; the archetype's locality makes this trivially tunable per-branch.
- **Dive clock / exposure** — detours spend the same budgets that pressure the cash-out call, so the clock does the balancing for free; a tight clock makes branches a genuine sacrifice.
- **Depth grading** — `dist_to_gate` already does the heavy lifting; no new system needed.
- **Combining archetypes** — drop a *loop* at one branch end (the dormant `loop_back_count`) for a shortcut-home; or make the spine itself a mild gauntlet so even the safe path isn't free. Tension: too many fat branches dilute the spine's "obvious forward" read and it degrades toward a maze.

## Open questions

- **Detour-loot premium magnitude** — *fun/Director call.* How much better must the side-room tier be to make the greedy bet worth it without making spine-only play feel punished? Needs playtest; recommend starting modest (+1 tier) and tuning at the M-gate.
- **Branch visibility** — do we telegraph that a detour holds good loot (a glint, a lit doorway), or is discovery the reward? Affects whether skipping feels informed or blind. *Fun call.*
- **Dead-end vs. loop-back branches** — pure dead-ends maximize the "worst walk home" cost; loops soften it. Per-band mix is a tuning/scope question.
- **Reward keying** — should the premium key off `dist_to_gate` (return cost) or `depth_index` (raw depth)? The system supports both; `dist_to_gate` is recommended as it directly prices the cash-out risk. *Design call, low effort.*
- **Branch-budget determinism** — capping *total* branches needs a running counter inside the grow loop; confirm it stays a same-order integer compare so the all-off fingerprint is untouched (mirrors the R4 contract). *Effort: small.*
