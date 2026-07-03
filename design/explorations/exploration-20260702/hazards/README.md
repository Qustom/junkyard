# Explorations — 2026-07-02: Oppositions (refinement)

> ← Part of the [2026-07-02 refinement pass](../README.md). Refines the [2026-06-25 oppositions set](../../exploration-20260625/hazards/README.md).

- [Scalable Opposition System (v2)](0-scalable-opposition-system.md) — supersedes the 20260625 v1. Headline: split the fused `OppositionDirector` into a policy-free **`SpawnService`** (mechanism: instantiate · register · caps · lifecycle · `setup()` handshake · spawn events) and one-or-more **`EncounterBuilder`s** (policy: credit/deck/`I`). Enumerates the API's real clients, and scales the debug tune-and-sweep surface via `OppositionDef.param_schema` + a generalized coverage assertion.
</content>
