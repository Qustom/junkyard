# A Stash / Vault
**Category:** The hub as the money sink made physical

## The idea
A **room you walk through**, not a tab you open — the physical home of every-thing you've secured across runs. Shelves, bins, a money safe, a parked pile of rare junk: the more you've banked, the more *visibly* full the place gets. A number on a menu tells you "$420." A vault *shows* you the $420 — the shelf that filled this run, the gap where the gear you're saving for will sit, the one rare junk you keep choosing not to sell. That's the quiet motivator: between runs you walk past your accumulated wealth, and seeing it climb (or seeing it raided after a bad run) lands in a way a HUD counter never does. The stash is the hub's emotional anchor — the place that says *this is mine, and it grows.*

## What exists today
**The persistence spine is built; the place is not.** Meta money/salvage/lore are already durable (`game_state.gd:33–37`, serialized in `to_meta_dict()` `:547`, only zeroed by a quota-miss `wipe_meta()` `:410`). Banked junk *identities* already cross the run→meta boundary too: `banked_junk: Array[JunkItem]` (`:42`) carries un-sold items between runs, persisted **by id** through the `JunkCatalog` under the objects-OFF save model (`:551`, rehydrated `:584`). So the data the vault would display **already exists and survives**.

What's missing is the **front-end** and the **deliberate keep-store**. There is no hub scene at all (this is a NEW scene). And `banked_junk` is a transient sell-queue, not a vault — `sell_banked_junk()` (`:324`) flushes it to Money at the next sell screen. The new work the p1 exploration names — a real item-vault the player *chooses to keep* across many runs — is a **new meta field** (`vault_junk`/`vault_money`), which costs a `save_manager.gd` `schema_version` bump + stepwise migration (default empty for old saves) + a QA fixture. The stash *room* is the visible skin over that p1 data model.

## How it could fit in
- **A greybox vault room** in the new hub scene, a few steps from the dive portal. Walk in; shelves and a safe render the meta-state. The visual fill is **driven by, not duplicated from, the data** — it reads `vault_money` and the `vault_junk`/`banked_junk` arrays each time you enter, so the place is always honest about what you own.
- **Front-end for p1's stash.** The vault *displays* and is where you *deposit/withdraw*: pull a stashed item back into the next run's bag (run-state) before `start_run`; choose stash-vs-sell at the sell screen instead of auto-flushing.
- **Interacts with banking/rollover (q2) and visible growth (g1).** Under q2 *rollover*, surplus money simply *is* the safe filling up; under q2 *expire/deduct*, the **goods on the shelves** become the only cross-cycle carry — the room dramatizes exactly what's safe. Pairs with g1's "visible growth": the shelf that gains an item per good run is g1 made spatial.
- **Feature gating.** RunConfig `vault_enabled` (off = M1.4 baseline, no new field, no hub room shown) so the prior baseline reproduces exactly; the room only renders when the vault data model is live.

## Research (cited)
**Tarkov** is the archetype: a persistent grid stash that survives raids while the *run* loot is at risk, where **stash space itself is an upgradeable meta-sink** (Hideout levels expand it). **Hades' House** shows the *trophy-room* role — a hub that visibly fills with unlocks gives "a tangible sense of progression" you *marvel at*, appealing to immersion + accomplishment motivations beyond raw stats. The trophy-room literature generalizes it: an *in-game representation* of what you've earned is a stronger pull than a menu entry because the reward is "something you can see while playing," tapping the same collection-completion thrill. **Diablo's shared stash** is the gentle pole (safe, no loss, pure hoarding/organization). THE FAR YARD already sits on the persistent side; a vault room makes the *item* half of that wealth physical and walk-past-able.

Sources:
- [Evolving Achievements with Trophy Room Design — Game Developer](https://www.gamedeveloper.com/design/evolving-achievements-with-trophy-room-design)
- [Escape from Tarkov: Smart Inventory Management Guide — Eye On Annapolis](https://www.eyeonannapolis.net/2025/10/escape-from-tarkov-smart-inventory-management-guide/)
- [House Contractor — Hades Wiki](https://hades.fandom.com/wiki/House_Contractor)
- [How Hades Appeals To Different Players — Cloudfall Studios](https://www.cloudfallstudios.com/blog/2020/11/how-hades-appeals-to-different-players)

## Open questions
- **Abstract display vs. literal item shelves (needs Director review — fun/scope).** A cheap version renders an *abstract* fill (a wealth-meter pile, shelves that get denser with total value) — no per-item placement, low cost. The richer version places **each stashed junk item** on a shelf you can inspect/pick up — far more evocative, far more art + UI + slot-management work. Recommendation: ship the abstract fill first (reads existing totals, no new save field if money-only), prototype literal shelves only if the item-vault (p1) actually lands.
- **Stash-size cap as a sink?** Tarkov makes *space* an upgrade. A capacity-limited vault = "buy more shelves" is a clean Yard/Salvage-track money sink and forces stash-vs-sell tension; unlimited = frictionless hoarding. This is *the* money-sink-made-physical angle — but it adds inventory-management friction. Director call on whether we want that layer.
- **Save-schema cost (defer/batch).** A literal item-vault needs a new meta field → `schema_version` bump + migration + QA fixture (`save_manager.gd` discipline). An abstract money-only display needs *zero* new fields. Batch any vault field with q2/g1/s5 schema additions into one migration if several land together.
- **Vulnerability on loss → defer to p4.** Whether the visibly-stocked vault stays full after a death (safe), gets visibly raided (lose a %), or is wiped on a quota miss (today's `wipe_meta()`) is the p4 reset-severity call — resolve jointly. The *visible* raid (empty shelves after a bad run) is dramatically potent but potentially crushing; flag as tone.
