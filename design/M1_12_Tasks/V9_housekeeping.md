# V9 / R10 — Housekeeping: dead folders + dead run.sav path

> Phase-2 per-task design doc for M1.12 (Wave 1, file-disjoint). Source: `M1.12_Breakdown.md`
> V9 task card + "What exists today" R10/V9 anchor + DR-6. **This is a design doc — no code
> changes here.** Survey performed in-repo 2026-07-10 against the M1.12 working tree.

---

## (a) Research on the premise

### The four placeholder folders

```
Game/data/items/    → data/items/.gitkeep only (0 real files)
Game/data/enemies/  → data/enemies/.gitkeep only (0 real files)
Game/data/recipes/  → data/recipes/.gitkeep only (0 real files)
Game/data/upgrades/ → data/upgrades/.gitkeep only (0 real files)
```

All four confirmed empty (a lone `.gitkeep` each, no `.gd`/`.tres`/`.import`). Repo-wide grep for
any reference to these paths:

```
grep -rn "res://data/items\|res://data/enemies\|res://data/recipes\|res://data/upgrades" \
  --include="*.gd" --include="*.tres" --include="*.tscn" --include="*.cfg" --include="project.godot" .
```

returns **zero hits**. Nothing in code, `.tres`, `.tscn`, or `project.godot` (autoload paths,
`[dotnet]`/`[importer]` sections, etc.) points at any of the four — deleting any of them cannot
break an import or a `res://` reference. This matches the breakdown's framing:

- `data/items/` — the old generic `Item` class (M0-era) was folded into `JunkItem`
  (`data/junk/junk_item.gd`, the `class_name JunkItem` used throughout `data/junk/` and
  `systems/depth/junk_placer.gd`). The folder is a fossil of a design that no longer exists —
  there is no `Item` class anywhere in `Game/` today (grep for `class_name Item` / `extends Item`
  is empty).
- `data/enemies/` — superseded by `data/oppositions/` (`OppositionDef`-driven hazards, per R3/R4's
  anchor in the breakdown: "the six newer hazards are data-only `OppositionDef` + `DeckEntry`").
  `data/oppositions/` is the live, populated folder; `data/enemies/` never got content.
- `data/recipes/` and `data/upgrades/` — placeholders for **M2** systems (crafting/upgrades per
  the M1.12 breakdown's own framing: "M2 (crafting/upgrades/instability)"). These are the two
  DR-6 asks the Director to keep-or-delete based on whether M2 will actually fill them.

### The `run.sav` path

Full text of `Game/systems/save_manager.gd` (109 lines) read in full. The **only** two mentions
of a resumable-run save anywhere in the file:

- `save_manager.gd:8` — a docstring line: `* Per-slot files: meta.sav (persists) + run.sav
  (resumable in-progress dive), each carrying an integer schema_version.`
- `save_manager.gd:16` — `const RUN_SCHEMA_VERSION := 1`

There is **no `save_run()`, no `load_run()`, no `run.sav` string literal, no run-state
serialization path anywhere** — only the declaring comment and the unused constant. This is
narrower than "a half-built feature to rip out"; it is purely a **docstring claim + one dead
constant**. Confirmed by a tree-wide grep:

```
grep -rn "run\.sav\|run_sav\|RUN_SAV\|RUN_SCHEMA_VERSION" --include="*.gd" --include="*.tscn" --include="*.md" .
→ systems/save_manager.gd:8   (docstring)
   systems/save_manager.gd:16  (the const)
```

`RUN_SCHEMA_VERSION` is not read anywhere (no other file references it), so its removal cannot
affect `_migrate_meta()` (which only steps `META_SCHEMA_VERSION`, meta stays v4) or any test.
A parallel grep for "resumable"/"resume dive"/"in-progress dive" tree-wide turns up only that
same docstring line plus one unrelated comment (`systems/dive_clock.gd:96`, "affects an
in-progress dive" — about clock pause/resume semantics, not save persistence; out of scope).

This confirms the breakdown's framing exactly: **"declared-but-dead"** — declared in a comment
and a version constant, never implemented, never consumed. There is no dangling run-state
serialization code to untangle; this is the cheapest possible "delete" of the three parts.

### The hardcoded slot-0 call sites

Repo-wide grep for `SaveManager.save_meta(0)` / `SaveManager.has_save(...)` / `SaveManager.load_meta(...)`:

**`Game/systems/game_state.gd`** — 7 literal-`0` call sites (no named constant at all, just the
bare integer):

| Line | Call | Context (from `save_meta` grep) |
|---|---|---|
| 181 | `SaveManager.save_meta(0)` | inside a run-lifecycle method (extract/end path) |
| 307 | `SaveManager.save_meta(0)` | economy mutation (purchase/sell path) |
| 387 | `SaveManager.save_meta(0)` | already inline-commented: `# atomic write + .bak, slot 0 (every meta op's path)` |
| 432 | `SaveManager.save_meta(0)` | economy mutation |
| 474 | `SaveManager.save_meta(0)` | quota/run-lifecycle path |
| 556 | `SaveManager.save_meta(0)` | economy mutation |
| 608 | `SaveManager.save_meta(0)` | economy/lifecycle path |

That is **7 sites** (breakdown said "5+" — confirmed at the higher end) all in the single
751-line god-object `game_state.gd` that V4 (Wave 3, same version) is scheduled to split. **None
of these route through a named constant** — each is a bare `0` literal repeated seven times.

By contrast, `Game/scenes/menu/main_menu.gd` already solved this exact problem for its own file:
it declares `const SAVE_SLOT: int = 0` (`main_menu.gd:17`) with a docstring citing the
M1.6-locked decision (`main_menu.gd:15-16`, and `design/M1_6_Tasks/M1_main_menu.md:516` "**OQ 4 —
Single slot 0.** LOCKED... multi-slot is a later milestone"), and every `SaveManager.has_save(...)`
/ `load_meta(...)` call in that file reads `SAVE_SLOT`, not a bare `0`. So the *pattern* to point
at already exists in the codebase — `game_state.gd` just never adopted it. `tests/test_money_ledger.gd`
also has two bare `save_meta(0)`/`load_meta(0)` calls (lines 128, 132) but these are test fixture
code intentionally pinned to slot 0 for a determinism check — not part of the "future multi-slot
UI will touch this" surface the breakdown flags, and out of scope for the marker (test code isn't
what a multi-slot UI feature would edit).

**Scope for part (c):** mark the 7 `game_state.gd` sites (the real "hardcoded, no constant" debt).
`main_menu.gd` already has its own locked, named, documented constant — no marker needed there;
`test_money_ledger.gd` is test fixture code — no marker needed there either.

---

## (b) Concrete plan

### Part (a) — delete superseded folders

- **Delete** `Game/data/items/` (incl. `.gitkeep`) and `Game/data/enemies/` (incl. `.gitkeep`).
  Confirmed 0 references anywhere; deletion is inert w.r.t. import/`res://` resolution.
- **`data/recipes/` and `data/upgrades/`: Director call (DR-6).** Recommendation carried in the
  breakdown is to **keep** both (M2 = crafting/upgrades/instability will fill them) — see Open
  Questions below for the concrete keep-mechanics if the Director ratifies "keep."

```gdscript
# pseudocode — not code to write, just the operation shape:
rm -r Game/data/items/
rm -r Game/data/enemies/
# data/recipes/, data/upgrades/: no-op pending DR-6 (keep as-is with .gitkeep, or delete — see OQ)
```

### Part (b) — resolve the `run.sav` declaration

Two edits, both confined to `save_manager.gd`'s header docstring + one constant line — **delete**
disposition (the breakdown's recommendation, DR-6):

```gdscript
# save_manager.gd:8 — BEFORE:
##   * Per-slot files: meta.sav (persists) + run.sav (resumable in-progress dive),
##     each carrying an integer schema_version.
#
# AFTER (delete the run.sav clause; meta.sav is the only file this system writes today):
##   * Per-slot file: meta.sav (persists), carrying an integer schema_version.
##     (A resumable-dive run.sav was declared here but never implemented; M2 re-adds
##     it if/when resumable dives are actually designed — see M1.12 V9/DR-6.)

# save_manager.gd:16 — DELETE the line entirely:
# const RUN_SCHEMA_VERSION := 1        ← removed, unused, nothing reads it
```

No other line in `save_manager.gd` touches `RUN_SCHEMA_VERSION` or a run.sav path, so this is a
2-line edit (one doc line rewritten, one const line deleted) with zero call-site fallout —
confirmed by the tree-wide grep above finding no other reference. `META_SCHEMA_VERSION` (line 15)
and the entire `_migrate_meta` chain are untouched; meta stays v4 exactly as the breakdown
requires ("No save-schema change anywhere in M1.12").

### Part (c) — mark the slot-0 sites (no behavior change)

Add a single-line tracking comment at each of the 7 `game_state.gd` sites (`:181, :307, :387,
:432, :474, :556, :608`), e.g.:

```gdscript
SaveManager.save_meta(0)  # TODO(multi-slot UI, M1.12 V9): hardcoded slot 0 — see main_menu.gd's
                           # SAVE_SLOT const / OQ 4 (M1_main_menu.md:516); a future multi-slot menu
                           # will need this parameterised (and V4's GameState split, same version,
                           # is a natural seam to introduce a GameState.active_slot).
```

Line 387 already carries an inline comment (`# atomic write + .bak, slot 0 (every meta op's
path)`) — append the tracking note there rather than duplicating a second trailing comment.
Purely textual; no behavior, no test, no fingerprint implication (comments are not layout-fp
inputs).

---

## Open Questions

1. **Delete vs. keep `data/recipes/` + `data/upgrades/` (DR-6, Director).** Breakdown
   recommendation: **keep both** — M2's stated scope is "crafting/upgrades/instability," so
   `recipes/` and `upgrades/` are very likely to be filled within 1 iteration, and keeping an
   empty `.gitkeep`'d folder costs nothing (no CI check globs these paths, no import references
   them). Counter-case: if the Director's actual M2 shape doesn't use a `recipes` *item* Resource
   folder (e.g. recipes get authored as fields on existing Resources, or a CSV per R1's deferred
   catalog work), the folders would sit dead through another milestone before deletion. **This
   doc's recommendation, pending Director sign-off: keep both** (asymmetric cost — keeping an
   empty folder is free; deleting-then-recreating for M2 is not).
2. **Delete vs. keep+mark `run.sav`/`RUN_SCHEMA_VERSION` (DR-6, Director).** Breakdown
   recommendation: **delete** — there is no implementation to preserve (confirmed above: the
   *entire* footprint is one docstring line + one unread constant), so "keep + mark deferred"
   would only be marking a comment that is already effectively a comment. Deleting removes a
   claim the code doesn't back up (arguably worse than no claim: a maintainer skimming the
   docstring today would reasonably infer `run.sav` exists and go looking for it). This doc's
   recommendation: **delete**, with the removed capability's rationale folded into the
   replacement docstring line (see part (b) above) so the *reason* isn't lost, only the false
   claim of existing infra. Low risk either way since nothing depends on it.
3. **Does a `.gitkeep`/`.gdignore` matter for the two possibly-kept-empty folders?** Godot does
   not need a placeholder to track an empty directory (Godot's filesystem dock doesn't require
   one), but **git does** — an empty directory with nothing in it is simply not tracked by git at
   all, so if `recipes/`/`upgrades/` are kept, the existing `.gitkeep` in each must **stay** (that
   is the only reason the empty folder shows up in `git status`/is visible in the repo today).
   No `.gdignore` is needed — Godot only ignores paths matching import excludes, and an empty
   dir doesn't get imported/scanned into anything either way. **Resolution (low-stakes, no
   Director input needed): keep the existing `.gitkeep` in whichever of `recipes/`/`upgrades/`
   the Director elects to keep; delete it (with the folder) for whichever gets deleted.**
4. **Should the slot-0 marker also touch `test_money_ledger.gd`'s two bare `save_meta(0)` /
   `load_meta(0)` calls?** This doc's read: no — those are test-fixture code intentionally
   pinned to slot 0 to check a deterministic round-trip, not part of the "a future multi-slot UI
   will edit this" surface the breakdown is flagging. Marking test code would be noise. Flagged
   here in case the Director/QA reviewer disagrees and wants test call sites annotated too for
   completeness when multi-slot UI eventually lands.

---

## Debt ledger (projected — actual figures land in the V9 worklog after implementation)

Dead surface removed: **2 confirmed-dead folders deleted** (`data/items/`, `data/enemies/` — 0
references each) + **1 dead docstring claim + 1 unread constant deleted** (`run.sav` clause +
`RUN_SCHEMA_VERSION`, `save_manager.gd`) + **7 undocumented magic-number call sites annotated**
(`game_state.gd` slot-0, zero behavior change) — net: two fossil folders gone, one false
"resumable dive" infra claim retracted from the save-architecture docstring, and the
multi-slot-UI debt made discoverable at every site that will need to change, pending Director
disposition of DR-6 on `recipes/`/`upgrades/`.

---

## Resolved Decisions (Phase 3)

> **Fresh-eyes resolution (Phase-3 resolver — NOT this doc's author), 2026-07-10.** Re-verified
> every factual claim in §(a) directly against the working tree (not just re-reading the doc):
> `ls -la` on all four `data/{items,enemies,recipes,upgrades}/` folders confirms each holds
> exactly one `.gitkeep` and nothing else; a tree-wide grep for
> `res://data/items|res://data/enemies|res://data/recipes|res://data/upgrades` across
> `*.gd/*.tres/*.tscn/*.cfg/project.godot` returns **zero hits** (exit code 1 = no match) —
> deletion of any of the four is confirmed import-safe. `save_manager.gd` read in full (109
> lines): the `run.sav` footprint is exactly the two lines the doc cites (`:8` docstring clause,
> `:16` `const RUN_SCHEMA_VERSION := 1`), and `META_SCHEMA_VERSION` / `_migrate_meta` are
> untouched by either line. `game_state.gd` grepped for `SaveManager.(save_meta|load_meta|has_save)`
> — exactly the 7 sites at the cited lines (181, 307, 387, 432, 474, 556, 608), all bare
> `save_meta(0)`, no `load_meta`/`has_save` calls in that file. `main_menu.gd:17`'s
> `const SAVE_SLOT: int = 0` confirmed, with its own docstring (`:15-16`) explicitly citing
> `game_state.gd`'s `save_meta(0)` calls as the thing it matches — i.e. the codebase already
> half-acknowledges the two files should agree on slot semantics, which is the load-bearing fact
> for RD-V9-3 below. `test_money_ledger.gd:128,132` confirmed as the two bare test-fixture calls
> the doc correctly scoped out. `V4_split_gamestate.md` read in full: as of this pass it carries
> **Open Questions only** (no Phase-3 `Resolved Decisions` section yet), and its own Open Q6
> states a recommendation — **defer slot-threading, V4 "preserves the literal `0` at every site
> (now in three files instead of one) and adds the same V9-style comment"** — which this doc's
> resolution is deliberately kept compatible with (RD-V9-3).

**RD-V9-1 — Folder deletions + refless confirmation: VERIFIED, proceed as designed.**
`data/items/` and `data/enemies/` are confirmed 0-reference and safe to delete outright — no
Director call needed here (DR-6 does not gate these two; the breakdown's "likely uncontroversial"
framing holds). This is purely a technical confirmation, folded in so the implementing agent does
not need to re-derive it: delete both folders (incl. `.gitkeep`) with no import/`res://` fallout.

**RD-V9-2 (OQ-3, `.gitkeep`/`.gdignore`) — RATIFIED as the doc's own low-stakes resolution: no
Director input needed.** Git does not track empty directories; whichever of `recipes/`/`upgrades/`
survives DR-6 keeps its existing `.gitkeep` (that is the only reason the empty folder is visible
in `git status`/the repo at all). No `.gdignore` is needed anywhere — Godot's import scanner
ignores by file-extension/exclude-pattern, not by directory emptiness, so an empty dir is already
a no-op for the importer with or without one. Confirmed correct on review; nothing to add.

**RD-V9-3 (technical OQ — `const SAVE_SLOT` vs. comment-only marker) — RESOLVED: comment-only
marker in this pass; do NOT introduce a `const SAVE_SLOT := 0` in `game_state.gd` yet.**
`main_menu.gd`'s `SAVE_SLOT` precedent is real and worth eventually mirroring — but introducing
the constant *now*, in `game_state.gd`, creates a coordination problem this Phase-3 pass can see
and V9's Phase-2 author could not have fully weighed against V4 (the two docs were authored
file-disjointly, in parallel): **V4 (Wave 3, same version) splits `game_state.gd` into three
files** (`game_state.gd` core, new `systems/economy.gd`, new `systems/quota_ladder.gd`), and the
7 `save_meta(0)` sites are distributed **across all three** post-split (start/extract/fail/wipe
stay on core; purchase/sell move to Economy; quota-advance moves to QuotaLadder — see V4 §A.3/§(b)
pseudocode). A `const SAVE_SLOT` declared on `GameState` today would, after V4 lands, either (a)
need Economy/QuotaLadder to reach back across a cross-object reference to read
`GameState.SAVE_SLOT` — the exact kind of coupling V4's design explicitly avoids ("sub-objects
have zero back-references and zero cross-references," V4 §A.4) — or (b) be silently duplicated as
a second/third local constant per new file, which is *more* magic-number surface than today's
single bare `0`, not less. V4's own Open Q6 already anticipated this and recommended deferring:
*"V4 just preserves the literal `0` at every site (now in three files instead of one) and adds
the same V9-style comment"* — i.e. V4's author is already assuming V9 ships a **comment**, not a
constant. Introducing a real constant in V9 now would hand V4 an unplanned decision (thread the
const across the split, or abandon it) that its own design doc explicitly scoped out.
**Resolution: V9 ships the comment-only tracking note (per the doc's existing §(b) Part (c)
pseudocode) at all 7 sites, verbatim as drafted — no `const SAVE_SLOT` introduced in this task.**
The real constant is better introduced **after** V4 lands (or as part of the eventual multi-slot-UI
task), at which point it's obvious which of the three post-split files should own it — most likely
a `SaveManager`-side default-slot constant (since all three future call sites already reach through
`SaveManager`, a single `SaveManager.DEFAULT_SLOT` avoids the cross-object-reference problem
entirely; this is a note for that future task, not a decision this doc needs to make). Coordinating
note for whoever runs V4's Phase-3 pass: no collision — V4's Open Q6 recommendation and this
resolution agree, so V4 should proceed exactly as its own doc describes (defer + add the same
comment style at each site's new location).

**RD-V9-4 (OQ-4, `test_money_ledger.gd`) — RATIFIED as drafted: no marking.** Confirmed at
`test_money_ledger.gd:128,132` — deterministic round-trip fixture code intentionally pinned to
slot 0, not part of the multi-slot-UI-will-edit-this surface. No change from the doc's own
recommendation.

**RD-V9-5 (part (b), `run.sav` docstring rewrite) — technical wording confirmed safe, no
Director input needed for the *mechanics* (the disposition itself is still DR-6(b), escalated
below).** The proposed docstring replacement text (§(b) Part (b)) is a straight rewrite of
`save_manager.gd:8` plus a deletion of `:16`; re-confirmed neither line is referenced anywhere
else in the tree, so the edit is mechanically risk-free regardless of which way DR-6(b) is
dispositioned — the only thing gated on the Director is *whether* to make this edit at all (see
below), not *how*.

---

### Needs Director review (escalated, not self-resolved — DR-6)

Both items below are genuine scope/vision calls (what will M2 actually contain; is retracting a
docstring claim worth losing the "future implementer" breadcrumb) that this fresh-eyes pass will
not decide on the design's behalf, per the standing rule that only the human Director dispositions
DR-* items. Both carry this doc's (and the breakdown's) recommendation, restated with the added
confirmation that **either disposition is mechanically safe** — nothing below blocks on more
research, only on the Director's call.

- **DR-6(a) — `data/recipes/` + `data/upgrades/`: KEEP vs. DELETE.**
  - **Delete `data/items/` + `data/enemies/`: not actually in question** — both are confirmed
    0-reference fossils (superseded by `JunkItem`/`data/oppositions/` respectively); this fresh-eyes
    pass sees no plausible case for keeping either. Treat as settled, proceed to delete.
  - **`recipes/`/`upgrades/` is the real fork.** Recommendation (unchanged from the breakdown and
    the Phase-2 doc): **KEEP both.** M2's stated scope is explicitly "crafting/upgrades/instability"
    (per the M1.12 breakdown's own framing and CLAUDE.md's roadmap), so both folders are very likely
    to be filled within the next 1-2 iterations, and the carrying cost of an empty `.gitkeep`'d
    folder is genuinely zero (no CI glob, no import cost, no code path touches it). The asymmetry
    favors keeping: deleting now and re-creating for M2 costs a trivial `mkdir`, but if the Director
    has information this pass doesn't — e.g. M2's crafting data ends up authored as fields on
    existing Resources rather than a dedicated `recipes/` Resource folder, per the doc's own noted
    counter-case citing R1's deferred CSV-catalog work — deleting now is more correct. **This is a
    genuine "what does M2 actually look like" call that only the Director/game-director-designer
    roadmap owner can make with confidence; recommend KEEP, but flagging that the alternative is
    equally cheap to execute if the Director's M2 mental model says otherwise.**
- **DR-6(b) — `run.sav` / `RUN_SCHEMA_VERSION`: DELETE vs. KEEP+MARK.**
  Recommendation (unchanged): **DELETE.** Re-confirmed the entire footprint really is just the two
  lines (no partial implementation anywhere to preserve), so "keep + mark deferred" would only be
  marking a comment that is already effectively inert — and worse, the current docstring reads as
  an *existing feature claim* ("run.sav (resumable in-progress dive)"), which is actively
  misleading to a maintainer skimming the file today. Deleting the false claim and replacing it
  with the honest "was declared, never implemented, M2 can re-add" note (as already drafted in
  §(b) Part (b)) is strictly more honest than the status quo. **The only reason this is a Director
  item rather than self-resolved:** retracting the docstring also retracts a breadcrumb for
  "someone once intended a resumable-dive save," which is mildly useful historical/roadmap context
  that a future spec author might want preserved somewhere (even if not in this file). If the
  Director wants that breadcrumb kept, the recommendation is still to remove it from
  `save_manager.gd` (the operative file) but fold one sentence into `design/M1_12_Tasks/M1.12_Breakdown.md`'s
  R10 anchor or `design/Junkyard_Technical_Design.md`'s save-architecture section instead — not to
  leave the misleading claim in the code. Either way: **delete from `save_manager.gd`.**

Both DR-6 items are ready for Director disposition; no further research is needed on either — the
facts (reference counts, footprint size, mechanical safety of the edit) are fully verified above.
