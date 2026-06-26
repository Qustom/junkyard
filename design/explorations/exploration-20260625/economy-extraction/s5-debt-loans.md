# Debt / Loans
**Category:** Money sink / investment loop

## The mechanic

An **optional loan**: borrow a lump of meta-Money *now* (to buy gear you can't yet
afford), and owe it back *later* — with interest, and against a **steeper future
quota**. It is a deliberate, opt-in **high-risk ramp** for confident players who
want to spike their power early and bet they can out-earn the bill.

Concretely: at the surface, between runs, the player may **take a loan** of `L`
Money. They get `L` immediately. In exchange, the **quota target rises** by
`L * (1 + interest)` spread over the next `N` runs (a per-run *surcharge* added on
top of the normal `quota_step` escalation), or a single balloon payment due in `N`
runs. Miss the surcharged quota → the existing K2 wipe fires. Pay it down → the
surcharge clears and you keep the gear you bought. The fantasy: *leverage* — buy
the breather-rig now, dive deeper sooner, earn enough to cover the note. Confident
players ramp; cautious players never touch it and play the baseline K2 loop.

## What exists today

**The canonical GDD debt is the spine of the whole game** (GDD §1, §3, §10 "The
Debt Clock"): a laid-off engineer drowning in *student loans* inherits the yard and
dives to pay them off; the debt "grows teeth the better you do" across three acts
(student loans → new creditors → predators). That debt is **involuntary and
narrative** — it's the *reason you dive*, not an opt-in.

**K2 quota** (`K2_quota_system.md`, `game_state.gd:47-48`) is the **greybox first
instance of that Debt Clock**: a per-run Money bar (`quota_target`, meta-state) that
rises `+quota_step` each met run; a miss is a **full roguelite wipe** (`wipe_meta()`).
Knobs live in `RunConfig` (`quota_enabled/base/step/check_timing/basis`,
`run_config.gd:248-261`). `RunRules` (`data/economy/run_rules.gd`) governs the
*death* downside (pockets fraction). So today there is a **forced rising quota** and
a **wipe**, but **no player agency to trade future obligation for present power** —
no way to *choose* leverage.

**What's missing:** the *voluntary* layer. Loans are a **new opt-in mechanic that
sits on top of K2's involuntary quota** — they don't reframe the quota, they let a
confident player *raise their own quota early in exchange for cash now*. This makes
the existing Debt Clock fiction interactive: the student loan is the floor; a chosen
loan is you pulling the clock's hands forward yourself.

## How to fit it in

- **Reuse the quota as the repayment vehicle.** A loan adds a **debt surcharge** to
  `quota_target` rather than inventing a second clock. `quota_target` is already
  meta-state that persists, escalates, and resets-on-wipe — a loan just bumps it (and
  records the outstanding principal as a new meta field `loan_outstanding`). The
  per-run met-test (`_evaluate_quota`, `game_state.gd:378`) is unchanged; the bar is
  simply higher while a loan is live. No new wipe path.
- **Powers the gear sink early (s1).** The point of borrowing is to **front-load the
  s1 gear-upgrade buys** — buy a tier-2 tool before you've earned it, so deeper bands
  (better loot tier, the `I` instability ramp) open sooner. The loan converts *future
  quota headroom* into *present gear*, which is exactly the investment loop s1 needs a
  faucet for.
- **The risk ramp interacts with quota escalation (q5).** Because the quota already
  rises per run, a loan **compounds against a curve that's also rising** — borrow late
  and the surcharge stacks on an already-steep bar (q5's escalation shape). This is the
  high-risk part: leverage is cheap early (gentle curve) and dangerous late (steep
  curve), which self-balances *when* a confident player should ramp.
- **Reset-severity interaction (p4).** A wipe must **clear `loan_outstanding`** along
  with the other meta (per K2 Q5 "full reset"): you can't carry debt across a wipe.
  This is the safety valve — the worst case is you lose your gear *and* the debt, back
  to Run 1 / base quota. (Open: should default *short of a wipe* be possible — a soft
  "creditor" beat — or is wipe the only failure? See below.)
- **RunConfig knob + telemetry.** Add a `Loans (S5)` `@export_group` mirroring the K2
  pattern: `loan_enabled` (master, **default off** → byte-identical to baseline),
  `loan_max_principal`, `loan_interest_pct`, `loan_term_runs`. All-off reproduces the
  current K2 loop exactly (no loans offered, no surcharge). Telemetry: emit
  `loan_taken(principal, interest, term)` and fold a `loan_outstanding` stamp into the
  `quota_evaluated` row so the gate can read **loans-taken rate**, **default rate**
  (wipes-while-a-loan-was-live ÷ loans-taken), and **net EV of borrowing** per config.

## Research (cited)

- **Recettear** is the load-bearing precedent: a **fixed-deadline debt** (820,000 pix)
  with **escalating weekly payments**; miss a week → game over, restart keeping level
  and items but **not your pix**. That is structurally K2's wipe (keep meta-progress
  shape, lose the currency) — validating the "rising bar + soft-reset" core. Its
  **Survival Mode** (ever-increasing weekly debt forever) is the *endless* version of
  our quota escalation (q5). [Recettear — Wikipedia](https://en.wikipedia.org/wiki/Recettear:_An_Item_Shop's_Tale)
- **Moonlighter's Banker** is the closest *optional-leverage* prior art: invest gold on
  Sunday, **forget to cash out by next Sunday and lose everything** — a voluntary,
  time-boxed financial bet layered on a shopkeeping loop. The "term with a hard
  deadline and a total-loss downside" is exactly our loan's risk shape; the lesson is to
  keep the term **legible** and the downside **telegraphed**. [Moonlighter Wiki — Banker](https://moonlighter.fandom.com/wiki/Moonlighter)
- **Binding of Isaac Devil Deals / Hades' deal-with-the-devil** items: trade a
  *permanent resource* (heart containers) for *immediate power*, **skill-gated** (better
  play → better deal odds). This is the canonical roguelite "borrow against your future
  survivability for present strength" loop — our loan is the *economy* analogue (borrow
  Money, not health) and should likewise feel like a **confident-player's lever**, not a
  trap. [TBOI Devil Room — Coohom](https://www.coohom.com/article/the-binding-of-isaac-devil-room-items-explained)
- **Debt as a difficulty lever, not a punishment:** GDD §10's explicit design note —
  *"keep Act 1 forgiving… ramp consequence with player power, not real-time."* A loan is
  *player-initiated* power-ramping, so it self-selects difficulty: it should be **net-EV
  positive for skilled play and net-negative for greedy play**, the same tuning target
  as a Devil Deal.

## Open questions

- **Does it duplicate the core quota?** The loan *raises* `quota_target` — so is it just
  "a bigger quota you chose"? Recommendation: that's the point (interactive Debt Clock),
  but the **HUD must distinguish base quota from debt surcharge** or it reads as one
  opaque bar. Needs Director review on whether two visible numbers is worth the UI cost.
- **Default consequences — wipe-only, or a softer creditor beat?** K2 makes every miss a
  full wipe; a loan default could (a) just ride the existing wipe, or (b) trigger a
  *distinct* escalating-creditor beat (GDD Act-2 "new creditors") short of a wipe. (a) is
  the cheap greybox cut; (b) is the richer fiction but a real new system. **Director
  call** (scope/tone).
- **Is it fun, or just stressful?** Optional high-risk ramps can be *ignored* (no value)
  or *mandatory-feeling* (a trap) depending on tuning. Flag for the **playtest gate**:
  measure loans-taken vs. default rate; if nobody borrows it's inert flavour, if everyone
  who borrows wipes it's a trap. Recommend shipping behind a knob, default off, and
  enabling it in **one preset** to A/B against the baseline K2 loop.
- **Relationship to the canonical GDD debt.** Is the *student loan* itself eventually
  modeled as a standing involuntary loan (so K2's quota literally *is* the loan balance),
  with opt-in loans as *additional* creditors? That unifies the fiction but couples this
  mechanic to the Act-1→3 debt arc (M2+/M3 economy_model.xlsx work). **Director call** on
  whether to keep them separate (cleaner now) or unify (richer later).

Sources:
- [Recettear: An Item Shop's Tale — Wikipedia](https://en.wikipedia.org/wiki/Recettear:_An_Item_Shop's_Tale)
- [Moonlighter Wiki — Banker / town investment](https://moonlighter.fandom.com/wiki/Moonlighter)
- [The Binding of Isaac Devil Room Items — Coohom](https://www.coohom.com/article/the-binding-of-isaac-devil-room-items-explained)
