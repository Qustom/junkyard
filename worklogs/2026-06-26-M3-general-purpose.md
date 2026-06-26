# Worklog — M3 Hub Shop (sell + buy) + META v3→v4

- **Date:** 2026-06-26
- **Subagent:** general-purpose (programmer)
- **Milestone:** M1.6 (Surface & Staging), Wave 3
- **Branch:** general-purpose/M3
- **Commit:** 7c44f0795439c6d9ed1feed131a56e98a0284c1f (this worklog folded in via the final `--amend`; HEAD of `general-purpose/M3`)

## What changed
Built the Hub Shop — the first meta-spend in THE FAR YARD. A `ShopItem`/`ShopCatalog`
data layer + a 3-item greybox persistent catalog; a Shop interactable mounted at the Hub's
`ShopAnchor` that opens a SELL/BUY `Control`. SELL re-homes the retired SellScreen's cash-out
(`sell_banked_junk(&"shop")`); BUY spends Money via the M0 `purchase()` API, Money-gated +
owned-marked. Purchases persist via a **META v3→v4** save bump (`owned_items` added to the
meta dict + migration step + `meta_v3.sav` fixture + test). Retired `ui/sell/sell_screen.*`
(+ demo + the `--script` test). Added a player-facing **QUOTA MISSED — progress wiped** banner
(W2-F2) on the Hub-return beat + echoed in the Shop. Removed the interim held-haul readout.

## Files touched
- `data/shop/shop_item.gd` — NEW `class_name ShopItem` (id/cost/persistent/effect_kind/greybox_color).
- `data/shop/shop_catalog.gd` — NEW `class_name ShopCatalog` (`Array[ShopItem]`, no spawn_weights).
- `data/shop/shop_catalog.tres` + `data/shop/items/shop_{scrap_magnet,lucky_charm,reinforced_bag}.tres` — 3 persistent greybox upgrades (cost 100/150/250, `effect_kind=&"none"`).
- `ui/shop/shop_ui.gd` + `ui/shop/shop_ui.tscn` — NEW Shop `Control` (SELL tab, BUY tab, Money header, quota-MISS echo, transient flash, close-on-cancel).
- `scenes/hub/shop.gd` + `scenes/hub/shop.tscn` — NEW `HubShop` interactable (departure_portal pattern; owns the ShopUI child).
- `scenes/hub/hub.tscn` — mounted `HubShop` at the ShopAnchor; removed the `HudLayer/HeldHaul` label; added a `HudLayer/QuotaNotice` banner.
- `scenes/hub/hub.gd` — removed `_held_haul_label` + `_refresh_held_haul`; the return beat now raises the W2-F2 banner on a MISS.
- `systems/game_state.gd` — `to_meta_dict`/`from_meta_dict` now persist/rehydrate `owned_items` (objects-OFF id list → typed `Array[StringName]`).
- `systems/save_manager.gd` — `META_SCHEMA_VERSION` 3→4; activated the v3→v4 migration step (default `owned_items=[]`).
- `tests/fixtures/gen_meta_v3_fixture.gd` + `tests/fixtures/meta_v3.sav` — NEW frozen v3 fixture (pre-shop).
- `tests/test_save_migration.gd` — added `_run_v3()` (v3→v4: owned_items default + round-trip) and wired it into `_ready()`; v1/v2 cases now assert against v4.
- `tests/test_shop_economy.gd` + `.tscn` — NEW headless shop-economy test (catalog shape, buy/persist, reject paths, wipe-clears-owned, SELL path).
- DELETED: `ui/sell/sell_screen.gd(.uid)`, `ui/sell/sell_screen.tscn`, `ui/sell/sell_screen_demo.gd(.uid)`, `ui/sell/sell_screen_demo.tscn`, `tests/test_sell_screen.gd(.uid)`.
  Kept `ui/sell/sell_strings.csv(.import)` — still referenced by `project.godot` locale/translations (out of my write scope); the `.en.translation` regenerates from the CSV on import.

## Checks run
- [x] `godot --headless --import` clean (ShopItem/ShopCatalog/HubShop/ShopUI registered; no script/parse errors).
- [x] `godot --headless --script res://tools/ci_smoke_test.gd` → SMOKE OK (exit 0).
- [x] `godot --headless res://tests/test_save_migration.tscn` → **v1→v4, v2→v4, v3→v4 all OK; owned_items round-trips** (exit 0).
- [x] `godot --headless res://tests/test_quota_system.tscn` → QUOTA OK (exit 0).
- [x] `godot --headless res://tests/test_app_router.tscn` → ROUTER OK (menu→hub→dive→hub; shop mounts in hub) (exit 0).
- [x] `godot --headless res://tests/test_config_menu.tscn` → **89/89 knobs** (exit 0).
- [x] `godot --headless res://tests/test_run_config.tscn` → **89 knobs** flat dict (exit 0).
- [x] `godot --headless res://tests/test_corridor_lever.tscn` → **fp e943ac9c8bc1 byte-match** (exit 0).
- [x] `godot --headless res://tests/test_main_game_loop.tscn` → MAIN GAME OK (haul held-banked, not sold) (exit 0).
- [x] `godot --headless res://tests/test_shop_economy.tscn` → SHOP ECONOMY OK (exit 0).
- [x] RG verifies `test_rg1_{loop,m12,m13,m14,m15}_verify`, `test_duration_loop_reentry` → all exit 0 (SellScreen deletion did not break the no-op `_dismiss_sell_screen` stubs). NOTE: `test_rg1_m13_verify` prints internal M5/all-on opposition-row FAIL lines but exits 0 — pre-existing (M2-era), unrelated to M3's save/shop scope.
- [x] Definition of done met: "Shop interactable opens SELL (reuses sell_banked_junk) + BUY (3-item persistent catalog via purchase(), Money-gated, owned-marked); purchases survive save/load (v1→v4 & v3→v4 green + meta_v3.sav fixture; owned_items persisted); ui/sell/* retired with nothing referencing it; quota-MISS shows a player-facing notice; held-haul readout removed; all-off fp byte-identical; 89-knob unchanged; META_SCHEMA_VERSION==4."

## Design deviations
none — built to the M3 spec + Resolved Decisions (Phase 3). Notes within spec:
- Per RD-2, `purchase(item_id, price)` (M0's locked primitive API) was used as-is; the ShopUI does the owned/affordability gate and calls it with primitives — `GameState` stays catalog-agnostic. The M0 body already double-guards owned/affordable/negative (no change needed there).
- The web telemetry-export re-home (R6/RD-11) is M4's (already on the Meta tab per the brief) — NOT re-added here, as instructed.
- `ui/sell/sell_strings.csv` was kept (not deleted) because `project.godot:157` still lists its `.en.translation` in `locale/translations`, and `project.godot` is out of my write scope; deleting the CSV would dangle that reference. The screen/demo/test that *used* the strings are deleted; the strings themselves are inert but referenced.

## Handoffs / follow-ups
- Shop catalog effects are STUB (`effect_kind=&"none"`, RD-3) — a future milestone wires real effects without a schema change. RG2 watch-item (DR-M3-2): whether testers buy at all with no visible effect.
- The *felt* shop UX (layout polish, count-up flourish) is human-deferred — verified structurally + the economy/save round-trip.
- `project.godot` still references `ui/sell/sell_strings.en.translation`; a later cleanup (when project.godot is in scope) could drop the sell locale entry + the orphan CSV if desired.
