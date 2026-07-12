# Save Architecture for Godot 4 — Research Report

*A research companion to the Technical Design Doc §9 (Save / Persistence). Scope: how THE FAR YARD should serialize and persist its split run-state vs. meta-state in Godot 4.6, with a versioned schema and migration strategy.*

---

## 1. The problem in one paragraph

THE FAR YARD has two fundamentally different kinds of state. **Run-state** is disposable: the current expedition's procedural layout, the player's in-run inventory, position, and instability/exposure-so-far. **Meta-state** is persistent and precious: owned tools, the home yard, NPC relationships, the Knowledge tree, and accumulated exposure history. We need multiple save slots, autosave on sleep/extract, and an explicit, versioned schema so that shipping a patch never bricks a player's meta-progress. The choice of serialization format is the foundation that makes the rest tractable (or painful). Below I compare the three native Godot 4 approaches, address the much-discussed "Resources can run code" caveat, then give a concrete recommendation.

---

## 2. The three native approaches

Godot 4 offers three engine-native serialization paths. Critically, the first two share the *same* underlying text serializer.

### 2.1 Resource-based saving (`ResourceSaver` / `ResourceLoader`, `.tres` / `.res`)

You define a `class_name SaveGame extends Resource`, mark fields with `@export`, and persist with one line: `ResourceSaver.save(save, path)`. Loading is `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`. The `CACHE_MODE_IGNORE` flag is important — without it, Godot can hand you a stale cached copy when data gets complex ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)).

- **Pros:** Strong static typing; full editor/inspector integration (you can open and tweak a save in the editor during dev); native support for all Godot types (`Vector2`, `Color`, `NodePath`) with zero conversion code; resources nest naturally — an `Array[ToolResource]` or a nested `YardResource` serializes recursively with no extra work. Godot 4 fixed the two big Godot-3-era pain points: arrays of resources now serialize cleanly, and the cache no longer fights you ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). Performance is excellent — Godot's own scene files (`.tscn`) are resources, so the engine is heavily optimized for this path.
- **Format choice:** `.tres` is human-readable text (great for debugging, diffing, editing); `.res` is binary (smaller, faster, not casually editable). Both load identically, so you can use `.tres` in debug and `.res` in release with a one-line path helper keyed on `OS.is_debug_build()` ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)).
- **Cons:** Saves are coupled to your resource *scripts*. Rename or remove an `@export` var and old saves may fail to load — this is the migration burden (Section 4). And the security caveat below.

### 2.2 JSON serialization

- **Pros:** Universally familiar, trivially inspectable, ideal for interchange with external tools or web services.
- **Cons:** It is the wrong tool for Godot save data, and the Godot community is unusually unanimous on this. JSON has no native Godot types — every `Vector2`/`Color` must be hand-converted to/from arrays or dicts. Worse, JSON numbers are all floats, so ints round-trip lossily unless you guard them. The result is more conversion code, more validation, and more bugs ([Godot 4 Recipes / kidscancode](https://kidscancode.org/godot_recipes/4.x/basics/file_io/index.html); [GDQuest](https://www.gdquest.com/library/save_game_godot4/)). The kidscancode recipe is blunt: *"Don't use JSON for your save files… There's a reason that Godot itself doesn't use JSON for saving scenes and resources."* JSON's one redeeming use here is as a thin, human-readable *metadata header* (slot name, version, timestamp) — see Section 6.

### 2.3 Binary serialization (`FileAccess.store_var` / `get_var`, `store_buffer`)

`store_var()` uses the engine's `var_to_bytes()` and is the safe sibling of the text serializer. You typically collect game data into a `Dictionary`, then `file.store_var(data)`; loading is `data = file.get_var()`.

- **Pros:** **Safe by default** — object serialization is disabled, so no embedded code can execute (the central security advantage). Native support for Godot types (unlike JSON). Compact and fast. No script coupling — the save is just data, so it survives class renames better than a `Resource`.
- **Cons:** You write and maintain the serialize/deserialize glue yourself (game objects → dictionaries → bytes and back). Not human-readable. You *can* opt back into object serialization by passing `true` to `store_var()`, but doing so reintroduces the exact code-execution risk you were avoiding ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)) — so don't.

> Note: `ConfigFile` (`.cfg`) and `var_to_str()` exist too, but they use the *same text serializer as Resources* and carry the *same* code-execution caveat. `ConfigFile` is fine for settings/options, not for the structured save graph we need.

---

## 3. The security caveat: loading Resources can run scripts

This is the single most important thing to internalize before choosing the Resource path for *player-shareable* saves.

Resources, `ConfigFile`, and `str2var()`/`var_to_str()` all share Godot's text serializer, which **can serialize and deserialize objects — and objects can carry and execute code**. A maliciously crafted `.tres` can embed a script that runs at load time. GDQuest states it plainly: *"resources support code execution (Godot scenes and scripts are resources)… If you load a resource from an untrusted source, it could run malicious code"* ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)).

This is not theoretical. The 2024 **GodLoader** malware campaign used Godot's runtime to execute malicious payloads, infecting thousands of machines. Godot's Security Team noted the vector is not engine-specific (it's analogous to shipping a malicious Python script), but it underscores that *running code from untrusted files is a real attack surface* ([Godot Engine, "Statement on GodLoader"](https://godotengine.org/article/statement-on-godloader-malware-loader/); [BleepingComputer](https://www.bleepingcomputer.com/news/security/new-godloader-malware-infects-thousands-of-gamers-using-godot-scripts/)).

**Mitigations the community actually uses:**

1. **Don't serialize objects in the first place.** Use `FileAccess.store_var()` (objects disabled) for anything that may cross machines. This is the cleanest defense.
2. **[Godot Safe Resource Loader](https://github.com/derkork/godot-safe-resource-loader)** — a drop-in `ResourceLoader.load()` replacement that scans a `.tres` for embedded GDScript before loading. Easy to set up; designed precisely for the "let players share savegames safely" use case.
3. **[WCSafeResourceFormat](https://gitlab.com/worstconcept/wcsaferesourceformat)** — a more thorough replacement that whitelists which resource types a data file may instantiate (a permissions model). Better for experienced devs needing full resource fidelity.
4. **Official feature gap:** there is a long-standing proposal, [godot-proposals #4925](https://github.com/godotengine/godot-proposals/issues/4925), to add a first-class "load resources without running scripts" mode. It is not yet a shipped, complete solution, so don't design around it landing.

**For THE FAR YARD:** local single-player saves on the user's own disk are low-risk (an attacker who can write your save file can already run code on the machine). The risk becomes real only if you ever let players *import/share* saves. We default to the safe path anyway (Section 7) so we never have to retrofit security.

---

## 4. Designing a versioned schema and handling migrations

Format choice doesn't exempt you from migrations — *any* serialization format breaks when your data shape changes ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). The job is to make breakage detectable and recoverable.

**Core principle: every save file carries an explicit integer `schema_version`** as its very first field, independent of the game's display version (e.g. "1.4.2"). Bump `schema_version` only when the persisted *shape* changes, not on every release.

A robust migration pipeline:

1. **Read the version first.** Before deserializing the full payload, read `schema_version`. With binary, store it as the first `store_var` so you can read it cheaply; with a JSON/dict header, read the header key. Never trust a save without a version — treat "missing version" as version 0.
2. **Run an ordered migration chain.** Maintain a list of pure migration functions `migrate_v1_to_v2(dict) -> dict`, `migrate_v2_to_v3(dict)`, etc. To load a v1 file in a v4 game, apply 1→2→3→4 in sequence. This "stepwise" approach means each migration only ever has to reason about *one* version delta, which is far easier to get right than N-to-latest jumps. This is the database-migration discipline GDQuest explicitly recommends adapting to saves ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)).
3. **Validate after migration.** Confirm required keys exist and types are sane; fall back to sensible defaults for anything genuinely new (a field that didn't exist in old saves just gets its default).
4. **For the Resource path specifically**, GDQuest's recommended migration recipe is: keep the *old* resource classes around as a frozen schema, load the old file with them, construct fresh instances of the *new* classes, copy/transform the data across, and re-save in the new format ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). This is workable but means carrying dead classes — a real cost over many versions.
5. **Back up before migrating.** Atomically write the migrated file to a temp path, fsync, then rename over the original — and keep a `.bak` of the pre-migration file. The community addon [SaveState](https://github.com/youssof20/savestate) bundles exactly this pattern (atomic writes, rolling `.bak` backups, schema versioning with forward-merge), which validates it as the expected shape of a production save system.

**Why dictionary-based (binary) saves migrate more easily than Resource saves:** a migration that operates on a plain `Dictionary` is just data-munging and never needs the old class to still exist. A Resource migration needs the old `class_name` to remain loadable. For a game expecting many content patches, this tilts the decision toward dict-over-binary for the *payload*, while still letting us use Resources in-memory.

---

## 5. Separating run-state from meta-state

This separation is both a design requirement and a robustness win, so bake it into the file layout:

- **Meta-state** (tools, yard, relationships, Knowledge, exposure history) lives in its own file per slot, written rarely and defensively — this is the data we must never lose. Treat its writes as transactional (temp-write + atomic rename + `.bak`).
- **Run-state** (current expedition layout seed, in-run inventory, position, run-local instability/exposure) lives in a separate file, rewritten freely on autosave. Because it's disposable, a corrupt or unreadable run file should *gracefully discard the run* and drop the player back to the yard with meta-state intact — never block loading the meta save.

Keeping them in separate files (rather than one monolithic blob) means an autosave that crashes mid-write can only ever damage the throwaway run file, and the two can carry **independent `schema_version`s** so a run-format change doesn't force a meta-format migration (and vice-versa). Saving the procedural run by **seed + deltas** rather than every tile keeps run files tiny and fast for frequent autosaves.

---

## 6. Encryption options

`FileAccess.open_encrypted(path, mode, key)` (and `open_encrypted_with_pass`) transparently encrypts on write and decrypts on read with an AES key. A key is typically derived from a passphrase via `"some-string".sha256_buffer()`.

- **What it buys you:** the file is gibberish in a text editor, defeating casual save-editing.
- **What it does *not* buy you:** real security. The key must live in your shipped scripts, so anyone willing to reverse-engineer the build can extract it. It's obfuscation, not cryptography ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). Godot's optional [PCK script-encryption build key](https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_with_script_encryption_key.html) raises the bar but never makes it impossible.
- **Costs:** extra CPU per save/load (negligible for small files, noticeable for large ones).

GDQuest's pragmatic verdict, which I endorse: for most games, **simply saving as binary `.res`/`store_var` is enough to stop casual editing** without the complexity or perf cost of encryption ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)). THE FAR YARD is a single-player roguelite with no competitive leaderboards or purchases riding on save integrity, so encryption is low priority. If we ever want light anti-tamper, prefer a cheap integrity check (store a salted SHA-256 of the payload alongside it) over full encryption — it detects edits without the decrypt overhead.

---

## 7. What the community recommends (synthesis)

There is strong consensus across the major Godot education sources:

- **JSON is discouraged** for save data (GDQuest, kidscancode, Godot 4 Recipes all agree).
- **The two recommended native paths are custom Resources and `FileAccess.store_var()`** ([GDQuest](https://www.gdquest.com/library/save_game_godot4/)).
- **Resources** when you want typing, editor integration, and you already model game data as resources — accepting the migration coupling and the code-execution caveat.
- **`store_var()` binary** when you want safety-by-default and decoupling from scripts — accepting that you hand-write the serialization glue.
- **Production-grade systems add atomic writes, `.bak` backups, slots, and schema versioning** on top of whichever format (SaveState addon being a representative example).

---

## 8. Recommended architecture for THE FAR YARD

**Hybrid: Resources in memory, dictionaries-over-binary on disk.**

Model tools, yard, relationships, Knowledge, etc. as **custom `Resource` classes** in memory — we get typing and editor tooling while building the game. But **serialize to disk as plain `Dictionary` payloads via `FileAccess.store_var()` (object serialization OFF)**. Each save resource exposes a `to_dict()` / `from_dict()` pair. This gives us the best of both: type-safe authoring, plus on-disk saves that are safe-by-default, compact, fast, and — crucially — migratable without keeping dead classes around.

**File layout (per slot):**

```
user://slots/slot_<n>/
    meta.sav      # persistent: tools, yard, relationships, Knowledge, exposure
    run.sav       # disposable: current expedition (seed + deltas, inventory, pos)
    slot.json     # tiny human-readable header: display name, timestamps,
                  # game version, meta_schema_version, run_schema_version
```

A small JSON header per slot is the one justified JSON use — the slot-select menu can read names/timestamps/versions without deserializing (or trusting) the full binary payloads.

**Versioning & migration:**

- First field written to each `.sav` is its integer `schema_version` (separate for meta and run).
- A `SaveMigrations` autoload holds ordered, pure `migrate_vN_to_vN+1(dict)->dict` chains, one chain per file type. On load: read version, run the chain up to current, validate, fill new-field defaults.
- Bump a `schema_version` only when that file's shape changes; the run chain and meta chain evolve independently.

**Write discipline:**

- All writes are atomic: write to `*.sav.tmp`, flush, rename over the target, retain one `*.sav.bak`.
- **Autosave on sleep/extract** writes `run.sav` (cheap, frequent) and, on extract, commits run rewards into `meta.sav` (rare, transactional).
- A corrupt `run.sav` is silently discarded → player returns to the yard. A corrupt `meta.sav` falls back to its `.bak`, and only if that also fails does it surface an error — meta-state is sacred.

**Security:** because the on-disk payload uses `store_var` with objects disabled, no save can ever execute code, so we're safe even if we later add save import/sharing. No encryption for v1; if anti-tamper is ever wanted, add a salted SHA-256 integrity field rather than `open_encrypted`.

**Dev ergonomics:** keep a debug toggle that additionally dumps a `.tres` or pretty-printed mirror of each save (via `OS.is_debug_build()`) so the team can eyeball and hand-edit state during development, while shipping the binary `.sav` only.

This architecture satisfies every §9 requirement — multiple slots, autosave on sleep/extract, explicit versioned schema with stepwise migrations, and a clean run/meta split — while sidestepping the Resource code-execution risk and minimizing future migration pain.

---

## Sources

- [Saving and Loading Games in Godot 4 (with resources) — GDQuest](https://www.gdquest.com/library/save_game_godot4/) — primary reference: format comparison, security caveat, `.tres`/`.res`, encryption, migration recipe.
- [Saving/loading data — Godot 4 Recipes (kidscancode)](https://kidscancode.org/godot_recipes/4.x/basics/file_io/index.html) — `FileAccess`, `store_var`/`get_var`, ResourceSaver/Loader, "don't use JSON."
- [Statement on GodLoader malware loader — Godot Engine](https://godotengine.org/article/statement-on-godloader-malware-loader/) — official security context for code execution from Godot runtime.
- [Hackers abuse Godot engine to infect thousands of PCs (GodLoader) — BleepingComputer](https://www.bleepingcomputer.com/news/security/new-godloader-malware-infects-thousands-of-gamers-using-godot-scripts/) — real-world malware campaign.
- [Provide a way to load resources without running scripts — godot-proposals #4925](https://github.com/godotengine/godot-proposals/issues/4925) — the open engine-level proposal.
- [Godot Safe Resource Loader — derkork (GitHub)](https://github.com/derkork/godot-safe-resource-loader) — drop-in `.tres` script scanner.
- [WCSafeResourceFormat — worstconcept (GitLab)](https://gitlab.com/worstconcept/wcsaferesourceformat) — whitelist-based safe resource format.
- [SaveState — atomic save system for Godot 4 (GitHub)](https://github.com/youssof20/savestate) — atomic writes, `.bak` backups, schema versioning, slots.
- [Compiling with PCK encryption — Godot Engine docs](https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_with_script_encryption_key.html) — build-level script/PCK encryption.
- [FileAccess class reference — Godot Engine docs](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) — `open_encrypted`, `store_var`, `store_buffer`, mode flags.
- [ResourceSaver/Loader or FileAccess for game save — Godot Forum](https://forum.godotengine.org/t/resourcesaver-loader-or-fileaccess-for-game-save/77522) — community discussion of the same tradeoff.
