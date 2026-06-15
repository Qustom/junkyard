# Run-Length Tuning

*Research companion to the Technical Design Doc §9. Topic: what run/session lengths feel right in roguelite and extraction games, and how to validate THE FAR YARD's 15 / 30 / 60-minute dive targets.*

---

## 1. Why run length is a first-class design lever

In a runs-based game, the length of a single run is not a cosmetic number — it sets the unit of commitment the player must agree to every time they press start. It dictates how much a death costs emotionally, how steep the escalation curve can be, how often the meta-progression loop fires, and which audiences will ever finish a run at all. The recurring lesson from shipped roguelites is that there is a "sweet spot" band — too short feels shallow and unresolved, too long curdles into tedium and fatigue — and that the band is genre- and audience-specific rather than universal.

THE FAR YARD's three-tier structure (15 / 30 / 60-minute dives) is unusual and smart: instead of betting on a single ideal length, it offers the player a menu of commitment levels. The job of tuning, then, is not to find one magic number but to make each tier feel *complete and distinct* — a satisfying arc at 15 minutes, a deeper arc at 30, and an epic at 60 — while the overworld day-cycle layer absorbs the meta-progression that justifies repeated dives.

## 2. Reference run lengths across notable roguelites

A survey of community-reported and design-stated run lengths gives a clear picture of where the genre clusters:

| Game | Typical run | Notes |
|---|---|---|
| **Vampire Survivors** | ~15–25 min meaningful; stages hard-cap at 30 | Zero startup friction; predictable, fixed length is a selling point ([Delayed Respawnse](https://delayedrespawnse.com/games/vampire-survivors/), [Steam](https://steamcommunity.com/app/1794680/discussions/0/3734079567829009940/)) |
| **Hades** | ~30–45 min; successful escape 20–50 | Tight, narrative-laced runs; one player averaged ~33 min ([Steam](https://steamcommunity.com/app/1145360/discussions/0/3311769175683554669/)) |
| **Slay the Spire** | ~30 min to 1.5 hr; winning Act 3 run ~50–80 min | Turn-based; length scales heavily with deliberation ([Steam](https://steamcommunity.com/app/646570/discussions/0/3277925755435724330/)) |
| **Dead Cells** | ~20 min rushed to ~1 hr full-clear | Action pacing; player choice of speed vs. completeness ([Steam](https://steamcommunity.com/app/588650/discussions/0/1489992713713196437/)) |
| **Risk of Rain 2** | ~20 min speed, ~35 min average, can loop for hours | Time *is* the difficulty driver; deliberately uncapped ([Steam](https://steamcommunity.com/app/632360/discussions/0/2733047810432246307/)) |
| **FTL** | ~1.5–2 hr full run | Long, tense, turn-ish strategy |
| **Spelunky** | ~3–20 min depending on death/speedrun | Brutal early deaths keep median low |
| **Balatro** | ~30–60 min per run | Escalating ante structure; "one more ante" pull |

Two things stand out. First, the modern action/auto-battler cluster (Vampire Survivors, Hades) lives around **20–45 minutes** — the dominant comfort zone for a focused session. Second, the turn-based and strategy titles (StS, FTL, Balatro) tolerate **60–120 minutes** because deliberation, not reflex, fills the time and a single careless minute doesn't undo it.

The most cited designer rule of thumb sits even tighter. Independent designers repeatedly land on **20–30 minutes as the ideal action-roguelite run**, arguing it gives "a good power and difficulty curve... starting off simple but quickly enter[ing] into fun complications which are given time to grow without becoming too elaborate" ([Todorović](https://medium.com/@todorovicnik2/video-games-roguelite-restart-length-of-a-perfect-run-ef8078c76495)). The Legend of Keepers team independently concluded **1–2 hours was the sweet spot for their slower title**, warning that "making the runs more lengthy puts a risk on making it more boring" ([Tavrox](https://medium.com/game-marketing/essay-the-one-hour-roguelite-404e73d0afa9)).

## 3. Reference raid lengths in extraction games

Extraction games run on a hard timer because the time pressure *is* the tension engine:

- **Escape from Tarkov** raids run **20–40 minutes** by map — Factory day raids are ~20 min (25 at night), Ground Zero/Reserve ~35 min, Interchange ~40 min ([EFT Forum](https://forum.escapefromtarkov.com/topic/127085-length-of-raids/)).
- **Hunt: Showdown** matches auto-end at **45 minutes** (or 5 minutes after all bounties extract), but a mobile player can finish in **~20 minutes**; the long ceiling exists only for unusual slow games ([Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes)).

The pattern: extraction designers pick a **20–45 minute envelope** with a hard cap, then let player aggression determine the real length inside it. The cap exists to prevent indefinite camping and to guarantee a session ends; the extraction decision (push for more loot vs. leave now) is the climax. This maps directly onto THE FAR YARD — each dive tier should have a clean cap, and the extraction choice should sharpen as the timer/danger climbs.

## 4. The psychology of "just one more run"

The "one more run" compulsion is built from a few interlocking mechanisms:

- **Low re-entry cost.** Vampire Survivors is "nearly purpose-built for controlled time windows... no travel time, no lobby wait, no narrative ramp-up. You press start and the session begins immediately" ([Delayed Respawnse](https://delayedrespawnse.com/games/vampire-survivors/)). The faster a player can be back in a run, the lower the activation energy to start another. Re-entry friction is the silent killer of "one more."
- **Predictable length as a contract.** Because the structure is "predictable enough that you can commit to a run knowing roughly how long it will take," players can slot a run into a real-life window. Variable, open-ended length breaks that contract and makes players *not* start when they only have 20 minutes.
- **Death that teaches, not just punishes.** Effective roguelite design makes death "feel educational rather than punishing... players should clearly understand what went wrong so they'll queue up another run" ([Retro Style Games](https://retrostylegames.com/blog/why-are-roguelike-games-so-engaging/)). The post-death emotion you want is "I see my mistake," not "that was unfair."
- **Guaranteed forward progress.** In a roguelite, death "delivers two signals: you made an error, and you still made progress" ([Switchblade](https://www.switchbladegaming.com/strategy-games/roguelike-vs-roguelite-explained/)). Meta-progression converts a loss into a deposit, which is the core reason roguelites pull "one more" harder than pure roguelikes.
- **Flow.** The "one more" trance is a flow state — full immersion at "moderate levels of psychological arousal... unlikely to be overwhelmed, but not understimulated to the point of boredom" ([Wikipedia: Flow](https://en.wikipedia.org/wiki/Flow_(psychology))). Run length must be short enough that the challenge curve stays inside the flow channel the whole way; an over-long run inevitably drops out of flow at the tail.

## 5. How run length interacts with death-cost and the roguelike/roguelite split

Death cost and run length are coupled and must be tuned together. In a pure **roguelike**, death is permanent and erases everything — "you made an error; the game is a system you need to understand better" — which justifies long, careful, high-stakes runs because the run *is* the whole game ([Switchblade](https://www.switchbladegaming.com/strategy-games/roguelike-vs-roguelite-explained/)). In a **roguelite**, persistent meta-progression softens death, which both *permits* shorter runs (you don't need the run to carry the entire experience) and *requires* them (the loop has to fire often enough to feed the meta layer).

The governing relationship: **longer runs demand a softer death cost.** A 60-minute run that wipes all progress on a single unseen shot — the exact failure mode Todorović flags in Risk of Rain 2 — produces disproportionate frustration, because the punishment is scaled to the *time invested*, not the *mistake made*. Conversely, a 15-minute run can afford a harsher, cleaner death because re-entry is cheap. For THE FAR YARD this argues for a **graduated extraction/loss model**: short dives can lose more on death (cheap to retry), while the 60-minute dive should bank partial rewards at checkpoints or extraction beats so a late death still leaves a deposit. The overworld day-cycle layer is the natural home for this — even a failed dive should advance something in the life-sim wrapper, mirroring "narrative advances every single run, whether you win or lose" ([Two Average Gamers](https://www.twoaveragegamers.com/best-roguelikes-short-sessions/)).

## 6. Pacing within a run: escalation and climax

A well-paced run is a tension curve, not a flat line. The consensus shape across action roguelites:

1. **Calm open.** Early encounters "require careful observation and measured responses" — low intensity, build-establishing ([Entalto](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)).
2. **Rising complication.** "Quickly enter into fun complications which are given time to grow" — synergies start firing, difficulty ramps.
3. **Power spike / climax.** "By the time the late game is reached, the player is kitted out with enough powerful abilities to make chewing through the exponentially harder enemies easier" — the cathartic "untouchable ball of chaos" moment ([Todorović](https://medium.com/@todorovicnik2/video-games-roguelite-restart-length-of-a-perfect-run-ef8078c76495)).
4. **Resolution.** A definitive end — boss, extraction, or cap — that "replaces the catharsis of play" with conclusion.

The critical insight for tuning: **the run should end shortly after the power-spike peak.** Todorović's warning is that "being an untouchable ball of chaos can get boring," and Risk of Rain 2's uncapped loops show what happens when difficulty can't keep up with a kitted player — engagement decays into a podcast-background activity. For each FAR YARD tier, place the climax and resolution so the player exits *at* or just past the high, not long after it has gone stale. This means the 15-minute tier needs a compressed-but-complete arc (fast ramp, early spike), while the 60-minute tier needs *multiple* escalation waves or a looping structure so it doesn't flatline at minute 35.

## 7. The twin failure modes: too long vs. too short

**Too long** produces commitment-resistance and fatigue. Players won't *start* a run they can't fit in their window, and runs that overstay "make me feel like I'm stuck... progressing slowly as if walking through mud. The scenery and variety quickly drain" ([Todorović](https://medium.com/@todorovicnik2/video-games-roguelite-restart-length-of-a-perfect-run-ef8078c76495)). Long runs also amplify the pain of a late death and reduce how often the meta-loop fires.

**Too short** produces shallowness — no time for builds to bloom, no escalation arc, no felt conclusion. Todorović notes that "if a game doesn't run long enough there isn't an ample feeling of conclusion." A 15-minute tier must therefore work *harder* on density: faster upgrade cadence, earlier synergy payoffs, a real boss/extraction beat — not simply the first 15 minutes of the 60-minute dive.

The three-tier model is itself the mitigation: it lets players self-select their commitment level, sidestepping the single-length compromise. The tuning risk is that the tiers blur into "the same dive but stopped early." Each tier should feel like its own experience with its own pacing budget.

## 8. How to validate the targets: telemetry and metrics

Stated preferences ("I like 30-minute runs") are unreliable; *behavior* is the ground truth. Instrument the build and read the curves. The lightest-weight stack (e.g., GameAnalytics or a custom event pipeline) needs only a handful of events — session start/end, run start/end, death, extraction, floor/wave transitions ([Gamine AI](https://gamineai.com/blog/the-first-10-telemetry-events-every-indie-game-should-ship-and-why)).

**Core metrics to track per dive tier:**

- **Actual run-length distribution.** Plot a histogram per tier. A healthy game shows "a smooth curve with a long tail," while problems show "spikes at short durations (players quit quickly) or bimodal distributions" ([StraySpark](https://www.strayspark.studio/blog/game-analytics-indie-developers-player-behavior)). For the 30-minute tier you want a peak near 30, not a fat spike at 8 minutes.
- **Completion vs. abandonment rate.** Of runs started, what fraction reach extraction/boss vs. ragequit mid-run? High mid-run abandonment in one tier flags pacing trouble there.
- **Drop-off funnel.** Build a funnel across in-run stages (wave/floor/room transitions) to "pinpoint where most players drop off" ([GameAnalytics Funnels](https://docs.gameanalytics.com/products-and-features/analytics-iq/funnels/)). A cliff at a specific floor reveals a difficulty wall or a boredom point.
- **Tier selection mix.** Which tier do players choose, and does the mix shift with skill/progression? If nobody picks the 60-minute dive, it isn't earning its development cost.
- **"One more run" rate.** Of sessions, what fraction contain ≥2 runs? Measure time-to-next-run (re-entry friction). Rising runs-per-session is the behavioral signature of the "one more" loop working.
- **Retention (D1 / D7 / D30)** as the downstream health check — does the run-length design sustain return play ([GameAnalytics: 22 metrics](https://www.gameanalytics.com/blog/metrics-all-game-developers-should-know)).
- **Time-of-day / session boundaries.** Whether players exit *after a run completes* (good — clean stopping point) or *mid-run* (bad — they hit a wall or ran out of time mid-commitment).

Pair telemetry with qualitative playtests: post-run, ask "did that feel too short, too long, or about right?" and watch for the tail-end disengagement (checking phone, sighing) that signals the run overstayed.

## 9. Concrete guidance for validating THE FAR YARD's 15 / 30 / 60 targets

1. **Treat each tier as its own arc with its own pacing budget.** Don't ship the 60-min dive as the canonical one with two early-exit variants. Give the 15-min tier a faster upgrade cadence and an earlier climax; give the 60-min tier multiple escalation waves so it doesn't flatline after minute ~35.

2. **Measure the *actual* length distribution, not the nominal target.** In early playtests, the number that matters is the histogram peak per tier. If the "30-minute" dive actually peaks at 18 minutes (players dying early) or 50 minutes (no clean ending), the target is mis-tuned regardless of intent. Aim for a unimodal peak near each label with a modest tail.

3. **Set hard caps and clean exits per tier, extraction-game style.** Borrow Tarkov/Hunt's model: a definitive timer/danger ceiling that forces the extraction decision near the climax. This guarantees runs *end* and prevents the Risk-of-Rain-2 flatline. The extraction choice should intensify as the cap approaches.

4. **Graduate the death cost to run length.** Short dives can lose more on death (cheap retry, sharp lesson). The 60-min dive needs partial banking — checkpoint deposits, mid-run extraction beats, or guaranteed overworld progress — so a late death still leaves a deposit and doesn't trigger time-investment rage.

5. **Watch the re-entry funnel.** Instrument time-from-death/extraction-to-next-run-start. If it's long, "one more run" won't fire. Cut lobby/menu/load friction aggressively; predictable, low-friction re-entry is what converts a finished run into the next one.

6. **Validation targets for an early playtest cohort:**
   - Run-length histograms peak within roughly ±20% of each label (≈12–18, ≈24–36, ≈48–72 min).
   - Mid-run abandonment under ~25% per tier; investigate any in-run stage where the drop-off funnel shows a cliff.
   - Runs-per-session > 1.5 on at least one tier (evidence the "one more" loop works).
   - In post-run surveys, the modal answer to "too short / about right / too long" is "about right" for each tier — and the *tail* of the run, not the start, is where you probe for fatigue.
   - All three tiers are actually chosen by some segment; a dead tier is a tuning or value-proposition failure, not just a length problem.

7. **Expect to retune the 60-minute tier hardest.** It carries the highest fatigue and late-death risk. If telemetry shows tail disengagement, the fix is usually more escalation/variety in the back half or earlier banking, not simply shortening it — though shortening toward ~45 (the extraction-genre ceiling) is a defensible fallback if the back half can't be made to sustain flow.

---

## Sources

- [Essay: the "one hour roguelite" — Tavrox (Medium)](https://medium.com/game-marketing/essay-the-one-hour-roguelite-404e73d0afa9)
- [Roguelite Restart: Length of a Perfect Run — Nikola Todorović (Medium)](https://medium.com/@todorovicnik2/video-games-roguelite-restart-length-of-a-perfect-run-ef8078c76495)
- [The Best Roguelikes for 30-Minute Sessions (We Actually Timed These) — Two Average Gamers](https://www.twoaveragegamers.com/best-roguelikes-short-sessions/)
- [5 Essential Tips to Make Your Roguelite Game Work — Entalto Studios](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)
- [Why Are Roguelike Games So Addictive? — Retro Style Games](https://retrostylegames.com/blog/why-are-roguelike-games-so-engaging/)
- [Vampire Survivors for 30-Minute Runs and Build Chaos — Delayed Respawnse](https://delayedrespawnse.com/games/vampire-survivors/)
- [Is 30 minutes the maximum time limit? — Vampire Survivors (Steam)](https://steamcommunity.com/app/1794680/discussions/0/3734079567829009940/)
- [Game length, replay? — Hades (Steam)](https://steamcommunity.com/app/1145360/discussions/0/3311769175683554669/)
- [Run length discussion — Slay the Spire (Steam)](https://steamcommunity.com/app/646570/discussions/0/3277925755435724330/)
- [Run length discussion — Dead Cells (Steam)](https://steamcommunity.com/app/588650/discussions/0/1489992713713196437/)
- [Target duration for average runs — Risk of Rain 2 (Steam)](https://steamcommunity.com/app/632360/discussions/0/2733047810432246307/)
- [Length of raids — Escape from Tarkov Forum](https://forum.escapefromtarkov.com/topic/127085-length-of-raids/)
- [Game Modes (match duration) — Hunt: Showdown Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes)
- [Roguelike vs Roguelite Explained — Switchblade Gaming](https://www.switchbladegaming.com/strategy-games/roguelike-vs-roguelite-explained/)
- [Flow (psychology) — Wikipedia](https://en.wikipedia.org/wiki/Flow_(psychology))
- [Game Analytics for Indie Developers — StraySpark](https://www.strayspark.studio/blog/game-analytics-indie-developers-player-behavior)
- [The First 10 Telemetry Events Every Indie Game Should Ship — Gamine AI](https://gamineai.com/blog/the-first-10-telemetry-events-every-indie-game-should-ship-and-why)
- [Funnels — GameAnalytics Documentation](https://docs.gameanalytics.com/products-and-features/analytics-iq/funnels/)
- [22 Metrics All Game Developers Should Know — GameAnalytics](https://www.gameanalytics.com/blog/metrics-all-game-developers-should-know)
