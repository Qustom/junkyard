# Consumable Loadout
**Category:** Money sink / investment loop

## The mechanic
Before a dive you visit a **prep/buy step** and spend banked Money on **single-use
consumables** that seed your run inventory: a **flare** (light/time — `u1`), a
**decoy** (lure a hazard off you — `u2`), a **one-use shield** (survive one lethal
hit). Each costs Money up front and each takes a carry slot. That turns pre-run prep
into a **wager**: every dollar spent on survival gear is a dollar *not* banked toward
the quota — but a death wipes the unbanked haul (`run_rules.gd` keeps only ~20% via
pockets) or, with K2 on, fails the run outright. The consumable is the **between-run
Money sink** the investment loop is missing: today Money only goes *up* (or to zero on
a wipe). Buying consumables is a recurring, player-chosen drain — "invest in coming
back alive, or hoard and dive bare and hope."

## What exists today
Honest read:
- **Consumables do not exist.** `data/junk/junk_item.gd` items are throwable +
  sellable salvage only — no `use_effect`, no "bought consumable" concept. The flare /
  decoy / shield **verbs themselves are only just-explored, not built**: see
  `u1-use-consume.md` (flare=light), `u2-deploy-place.md` (decoy), and
  `t5-throw-to-place-vs-hit.md`. This whole mechanic **depends on those verbs landing
  first** — a consumable with no effect is dead weight.
- **The inventory can hold them.** `systems/inventory/run_inventory.gd` is a working
  count-based slot bag (`max_slots=12`, `try_add`, `slot_size` footprint, `PLACEABLE`
  gate, `clear_run()` on run end). A bought consumable is just a `JunkItem` pre-loaded
  into this bag at run start — the model already supports it.
- **There is no pre-run loadout / shop screen.** The only pre-run surface is the CFG
  config menu (it writes a `RunConfig`). Money lives in meta-state
  (`game_state.gd`); spending it pre-run and seeding the bag is **the missing wiring**.
- **The wager economics already exist**: pockets-on-death (`run_rules.gd`) and the K2
  quota wipe (`K2_quota_system.md`) are exactly the downside that makes "spend to
  survive" a real bet.

## How to fit it in
1. **Buyables as data.** A consumable is a `JunkItem` whose `use_effect` /
   deploy-effect is set (flare=`LIGHT`, decoy=`LURE`, shield=a new one-hit-save
   effect) plus a `buy_price`. Authored `.tres`, not code (TDD §2).
2. **Pre-run prep step.** Add a **Loadout panel** to the pre-run flow (alongside / in
   CFG): show buyables + prices, current Money, current slot fill. Buying debits
   meta-Money and queues the item; on `GameState.start_run()` the queued items are
   `try_add`-ed into the fresh `run_inventory` **before** the dive begins.
3. **The wager + carry tension.** Consumables **take slots**
   (`slot_size`), so a loaded-for-survival bag has *less room for salvage* — a clean
   double cost (Money now + haul capacity during the run). This couples directly to the
   extract-vs-greed core.
4. **RunConfig knob.** `loadout_enabled` master toggle (all-off = today's no-prep
   baseline, mirroring `throw_enabled`/`quota_enabled`), plus knobs for buy-prices and
   a `loadout_slot_cap` (max consumables a run may carry).
5. **Telemetry.** Emit `consumable_bought(id, price)`, and reuse the existing
   `item_used`/`item_thrown` rows so the re-gate sees **bought vs used vs wasted**
   (carried out unused / lost on death) per type — the signal of whether the wager is
   live or whether players over- or under-buy.

## Research (cited)
- **Darkest Dungeon provisioning** is the closest model: before each expedition you
  buy food/torches/etc. from the Caretaker, **buy too many and they vanish (wasted),
  buy too few and get screwed** — "the entire point is to weigh risk/reward." The
  *wasted-on-purpose* design is the lever this mechanic borrows.
  [Provisions Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2309520917),
  [DD Wiki: Expeditions](https://darkestdungeon.wiki.gg/wiki/Expeditions)
- **Lethal Company** store: consumables run out and must be re-bought; "buying at full
  price quickly eats your money," and items like the **TZP-Inhalant** are explicit
  risk/reward buys. The credit-vs-survival pull is the same wager.
  [LC Store](https://lethal-company.fandom.com/wiki/Store),
  [LC Consumables](https://game8.co/games/Lethal-Company/archives/438969)
- **Tarkov pre-raid kit / Deep Rock loadout / Monster Hunter prep** all gate a run
  behind a spend-or-hoard provisioning choice — well-trodden, readable prior art that
  the quota wipe makes meaningfully tense here.

## Open questions
- **Refund / persist unused consumables?** Three options, escalating "sting":
  (a) **persist** — unused consumables carry to next run (kindest; no waste, weakest
  sink); (b) **refund on extract** — only spent-on-death; (c) **DD-style waste** —
  bought = gone whether used or not (strongest sink + wager, harshest). *Recommend (b)
  for Act 1* (waste only bites when you die — aligns with the pockets penalty); flag
  for the **Director** as a tone/feel call.
- **Loadout slot cap** — is it just the 12-slot bag (consumables compete with salvage
  directly), or a separate small consumable belt? Recommend competing for the same bag
  (cleaner tension); needs the Director's read on whether that's too punishing.
- **Hard dependency:** this mechanic **cannot ship before** the use/deploy verbs
  (`u1`/`u2`) and a shield effect exist. Sequence: build the verbs → then the
  buy/loadout layer. Flag the ordering for the **Director / Producer**.
- **Shield effect needs no HP**, but a "one-use save from a lethal hit" is a new
  effect type (intercept `r1_catch_kills`/`hpp_kills`) — small but real new code;
  confirm scope.
