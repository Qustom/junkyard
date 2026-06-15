# F1 — Single Placeholder Currency: Money Ledger

**Summary:** Add a `Money` ledger to **meta-state** in `GameState` (the full three-currency system — Money / Salvage / Lore — arrives in M3; M1 uses only Money as a placeholder). Banked junk converts to Money at each item's `base_sell_value`. This closes the economic loop: extracted haul becomes a persistent, growing number.

- **Parent task:** F1 (M1 greybox prototype — placeholder economy)
- **Dependencies:** E1 (extract-and-bank: the run-state → meta-state transfer that produces banked junk).
- **Acceptance criterion:** Banked junk increases a persistent `Money` total by the sum of item `base_sell_value`s.

## Assets needed

F1 is **data + autoload logic**; essentially no scenes.

`GameState` meta-state (autoload, `systems/game_state.gd`):
- `var money: int = 0` — the persistent ledger. Integer (no fractional Money in M1; avoids float drift in saves and tests). Lives strictly on the **meta** side — never reset by `_teardown_run_state()`.

Save schema (`SaveManager`):
- `meta.sav` must include `money` in its serialized dictionary, alongside `schema_version`. Since `money` is a brand-new field, bump the meta `schema_version` and add a migration step that defaults `money` to `0` for any pre-F1 save. Serialized via `FileAccess.store_var` with object serialization OFF (plain int — trivially safe).

Data / resources:
- No new `.tres`. F1 consumes the existing `JunkItem.base_sell_value` (D1's item Resource) as the conversion rate. The ~6–10 authored greybox junk items already span a value range; F1 just sums them.

Telemetry:
- Currency-in events: `Telemetry` should log Money credited per source (extract vs. pockets-on-fail). F1 emits a `money_changed` / currency-in signal on `EventBus` so Telemetry's "currency in/out per source" requirement is satisfied without F1 knowing about Telemetry.

## Code to generate

Scripts / signals:
- Additions to `systems/game_state.gd`: `money` field, `credit_money(amount, source)`, and a `sell_banked_junk()` convenience (used by F2).
- `EventBus`: `signal money_changed(new_total: int, delta: int, source: StringName)`.
- `SaveManager`: include `money` in serialize/deserialize + a migration step.

Design notes — **the conversion timing is the key decision** (see Open Questions) and it determines where F1 plugs in:

- **Option A — convert at bank time (E1/E3):** the moment items move into meta, sum their value into `money` and (optionally) drop the item list. Simplest; the running total updates the instant you extract. But F2 then has nothing to itemize unless we keep a record.
- **Option B — convert at sell time (F2):** E1/E3 bank *items* into `banked_junk`; `money` only increases when F2's sell screen calls `sell_banked_junk()`. This lets F2 show an itemized tally animating into Money, which is the more satisfying loop-closing reward.

This doc implements **Option B's machinery** (sell-on-demand) while keeping `credit_money` general enough for Option A. F2 calls `sell_banked_junk()`; if we later prefer auto-sell, E1 calls the same function. Either way Money is **persistent meta-state** and `save_meta()` must follow any credit.

```gdscript
# systems/game_state.gd (partial — Money ledger, meta-state)

# --- meta-state (persistent) ---
var money: int = 0
var banked_junk: Array[JunkItem] = []   # from E1/E3 (pre-sell)

# Core ledger mutation. All Money increases route through here so Telemetry
# and persistence are consistent.
func credit_money(amount: int, source: StringName) -> void:
    if amount == 0:
        return
    money += amount
    EventBus.money_changed.emit(money, amount, source)   # Telemetry listens
    # Caller decides when to save; F2 / E1 call save_meta() after the tally.

# Sell everything currently banked, converting items -> Money at base_sell_value.
# Returns a per-item breakdown so F2 can itemize the payoff.
func sell_banked_junk() -> Array[Dictionary]:
    var breakdown: Array[Dictionary] = []
    var total: int = 0
    for item in banked_junk:
        breakdown.append({"name": item.display_name, "value": item.base_sell_value})
        total += item.base_sell_value
    banked_junk.clear()                       # consumed by the sale
    credit_money(total, &"sell")              # one ledger event for the lot
    SaveManager.save_meta()                   # persist new Money total + empty bank
    return breakdown
```

```gdscript
# systems/save_manager.gd (partial — serialize Money in meta)

const META_SCHEMA_VERSION: int = 2   # bumped for F1's `money` field

func _serialize_meta() -> Dictionary:
    return {
        "schema_version": META_SCHEMA_VERSION,
        "money": GameState.money,
        # banked_junk serialized as plain id/value records (objects-off),
        # not JunkItem instances — store ids + values, re-resolve on load.
        "banked_junk": _banked_to_records(GameState.banked_junk),
    }

func _migrate_meta(data: Dictionary) -> Dictionary:
    var v: int = data.get("schema_version", 1)
    if v < 2:
        data["money"] = 0                # F1: default Money for pre-F1 saves
        data["schema_version"] = 2
    # ... future stepwise migrations chain here ...
    return data
```

Note on serialization: with object serialization OFF, do **not** `store_var` `JunkItem` Resource instances. Persist banked junk as plain records (`{id, value}`) and re-resolve to `JunkItem` defs on load by id. `money` is a plain int — trivially safe and compact.

## Open questions

- **Convert at bank time or at sell time?** (The central decision above.) Sell-at-F2 gives a satisfying itemized payoff; bank-time-convert is simpler and means F2 just displays a number. Recommend sell-at-F2 (Option B) for the loop-closing reward, but confirm with F2's scope.
  - **Recommendation:** Convert at **sell time (Option B)**: E1/E3 bank item identities; `money` only increments when F2 calls `sell_banked_junk()`. The itemized tally animating into a persistent Money total is the single most satisfying reward beat in M1 and the clearest proof that the loop closes — worth the small extra machinery. This matches the E1 "bank items not Money" decision; keep `credit_money()` general so an Option-A auto-sell remains a one-line change if F2's scope ever shrinks.
- **Integer Money only?** Recommend yes for M1 (no fractional currency, no float drift in saves/tests). Confirm no item value or future mechanic needs sub-unit Money.
  - **Recommendation:** Integer Money only. All M1 values derive from integer `base_sell_value`s summed, so there is no source of fractions; using `int` eliminates float drift in saves and makes test assertions exact. `store_var` persists a plain int trivially and safely with object serialization off ([Godot store_var binary serialization](https://www.gdquest.com/library/save_game_godot4/)). If a future mechanic ever needs sub-unit pricing, scale the unit (e.g. cents) rather than introducing floats.
- **One ledger event per sale or per item?** `sell_banked_junk()` emits a single `money_changed` for the whole lot. If Telemetry or F2's animation wants per-item credit events, change to per-item emits. Decide based on what F2's tally animation needs.
  - **Recommendation:** Emit **one `money_changed` per sale** (the whole lot), and let F2 drive its per-item count-up animation purely from the returned breakdown array — the visual tally does not need ledger events per item. One event keeps Telemetry's currency-in log clean (one credit per run-end, tagged by source) and avoids coupling the ledger to UI animation granularity. Revisit only if Telemetry later needs per-item economic data, which M1's feedback gate does not.
- **Pockets-on-fail Money source tagging.** When E3's kept items eventually sell, should they be tagged `source: pockets` vs. `source: sell` for Telemetry's currency-in-by-source analysis? Cheap to do; worth it for the economy feedback gate.
  - **Recommendation:** Yes — tag it. Have `sell_banked_junk()` (or its caller) pass the run-end cause through so credits from a failed run are tagged `source: &"pockets"` and successful extracts `source: &"sell"`/`&"extract"`. This is nearly free and directly feeds the economy feedback gate's key question: how much Money actually comes from pushed-too-far runs vs. clean extracts — which is exactly the push-your-luck balance M1 must validate.
- **Save migration test coverage.** The schema bump (v1→v2 adding `money`) is exactly the kind of thing G-series tests should cover. Confirm a fixture pre-F1 `meta.sav` loads, migrates, and ends with `money == 0` and intact banked junk.
  - **Recommendation:** Yes — add a G-series migration test with a committed v1 fixture `meta.sav` (no `money` field), asserting after load: `schema_version == 2`, `money == 0`, and `banked_junk` intact. Establish this as the template every future schema bump must follow (one stepwise migration + one fixture + one round-trip assert), since silent migration bugs are a top cause of save corruption. Round-trip the migrated data through save/load once to confirm it re-serializes cleanly.
- **Does Money ever decrease in M1?** M1 has no sinks (upgrades are M3). The ledger only credits. Confirm we don't need `debit_money` yet — but keep `credit_money(negative)` working so a debug "reset Money" is trivial.
  - **Recommendation:** No dedicated `debit_money` in M1 — there are no sinks until M3 upgrades, so building spend infrastructure now is premature. Keep `credit_money()` accepting negative amounts (and skipping the no-op zero case) so a debug "reset/refund Money" is a one-liner for testing. The ledger is credit-only in normal play; revisit a proper debit/transaction API when M3's economy and multiple currencies land.
