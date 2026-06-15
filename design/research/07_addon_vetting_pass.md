# Add-on Vetting Pass — THE FAR YARD

*Research companion to the Technical Design Doc §9 (Third-party add-ons & dependencies). Target engine: Godot 4.6 (latest stable, 2026). Vetting date: 2026-06-14.*

---

## 1. Purpose & vetting criteria

Before adopting any third-party Godot add-on, THE FAR YARD evaluates each candidate against four gates:

1. **Compatibility** — confirmed working on Godot 4.6 (our pinned engine), ideally with an explicit 4.6 release tag, not just "4.x".
2. **Maintenance / activity** — recent commits and releases (within ~6 months), an active maintainer, and a healthy issue-response cadence. Stars and fork counts are a proxy for community support and the likelihood that bugs get found and fixed.
3. **License cleanliness** — MIT or similarly permissive (BSD, Apache-2.0, MPL-2.0, CC0). We avoid GPL/AGPL and "source-available" or non-commercial licenses because THE FAR YARD ships commercially. Logo/art assets bundled with a plugin are checked separately (they are often CC-BY and must be excluded or attributed).
4. **Architecture fit** — GDScript add-ons drop in via the Asset Library with zero build steps. C++ *modules* require a custom engine build; C++ *GDExtension* libraries ship as precompiled binaries per-platform (more convenient, and what we prefer if we adopt a C++ add-on at all).

**Where to verify (do this again at adoption time and at each engine bump):**
- **Godot Asset Library** — <https://godotengine.org/asset-library> and the newer Asset Store at <https://store.godotengine.org> — check the listed Godot version, last-update date, and that the listing points at the canonical repo.
- **GitHub repo** — Releases/Tags page (latest version + date), the commit history ("Last commit date"), `LICENSE` file, star/fork/watcher counts, and open-issue volume.
- **README compatibility tables** — Beehave and LimboAI both publish branch/version → Godot-version tables; trust those over the AssetLib blurb.

---

## 2. Category 1 — Dialogue: Dialogue Manager (Nathan Hoad)

**Repo:** <https://github.com/nathanhoad/godot_dialogue_manager> · **Docs:** <https://dialogue.nathanhoad.net/>

- **Latest version:** **v3.10.4 "for Godot 4.6"**, released **2026-04-17** (commit `5487c52`). The maintainer explicitly names the Godot target in each release title — recent 3.10.x releases (3.10.0 through 3.10.4, Feb–Apr 2026) are all tagged "for Godot 4.6." A parallel **v1.19.3** line (2026-04-12) is maintained for the Godot 3.6 LTS branch, which is a good signal of disciplined multi-branch maintenance.
- **Godot 4.6 support:** Confirmed — current release line is built and tagged for 4.6, with prior releases noting backwards-compatibility fixes for 4.4/4.5. The runtime works with both GDScript and C#.
- **License:** **MIT** (permissive, commercial-friendly).
- **Maintenance:** Excellent. ~3.6k stars, 255 forks. Release cadence is roughly monthly, driven primarily by the original author (Nathan Hoad) plus a steady stream of community contributors. Only ~4 open issues at time of review — very low for a project this size, indicating responsive triage.
- **Architecture:** Pure GDScript editor plugin + runtime. Installs via Asset Library or a GitHub copy into `addons/`. Supports gettext and CSV localization, including Godot POT generation — relevant if THE FAR YARD localizes.

**Recommendation: APPROVE.** Best-in-class for Godot dialogue, actively maintained, MIT, explicit 4.6 tags. This is the de-facto standard and a safe core dependency. Pin to **v3.10.4** (or the latest 3.10.x tagged "for Godot 4.6" at adoption time).

---

## 3. Category 2 — AI / behavior: Beehave vs. LimboAI vs. built-ins

### 3a. Beehave (behavior trees)
**Repo:** <https://github.com/bitbrain/beehave> (branch `godot-4.x`) · **Site:** <https://bitbra.in/beehave>

- **Latest version:** **v2.9.2**, released **2025-12-02** (42 releases total). The `godot-4.x` branch shows 268 commits.
- **Godot 4.6 support:** Yes. README compatibility table maps Godot `4.5+` → Beehave branch `4.x`, version `2.10+`; the `godot-4.x` branch tracks current Godot. (Beehave uses a long-lived per-engine branch model rather than per-4.x-minor branches.)
- **License:** **MIT.** (Note: the logo is credited to community artists — code is MIT, branding excluded as usual.)
- **Maintenance:** Healthy. ~3.1k stars, 163 forks, 24 watchers. ~32 open issues. Latest release ~6 months before review — a little slower than Dialogue Manager but still actively maintained, with CI and unit-test coverage (GdUnit) for every feature, plus an in-editor debug view and performance monitor.
- **Architecture:** Pure **GDScript**, node-based — you build the tree directly in the scene tree and attach it to any node. Zero build steps; drop `addons/beehave` in and enable. Lowest-friction option.

### 3b. LimboAI (behavior trees + state machines)
**Repo:** <https://github.com/limbonaut/limboai> · **Docs:** <https://limboai.readthedocs.io>

- **Latest version:** **v1.7.1**, released **2026-06-04** (very fresh; 30 releases, 1,386 commits).
- **Godot 4.6 support:** Yes, and best-in-class here. README explicitly states "Supported Godot Engine: **4.6**" and provides a precise table: `1.7.x` → Godot 4.6+; `1.6.x` → 4.4/4.5/4.6. This is the most current and explicitly-4.6 of the three AI options.
- **License:** **MIT** (logo and demo art are CC-BY-4.0, excluded from the code license — note if we copy demo assets).
- **Maintenance:** Very active. ~2.8k stars, 127 forks, ~55 open issues (higher count partly reflects a feature-rich C++ project). Single primary maintainer (limbonaut) with a fast release cadence — most recent release is days before this review.
- **Architecture:** **C++** plugin. Two consumption modes: (a) a custom **engine module** (requires building Godot + export templates from source), or (b) **GDExtension** as a precompiled shared library (no custom build; project stays compatible with both). LimboAI uniquely bundles **both behavior trees AND hierarchical state machines (HSM)** with a BT editor, visual debugger, blackboard system, and class docs. HSM setup is code-only (no GUI editor for state machines).

### 3c. Godot built-in state-machine patterns
Godot ships no dedicated state-machine *node*, but two built-ins cover most needs:
- **AnimationTree / StateMachine** (`AnimationNodeStateMachine`) — a fully visual state machine intended for animation blending, frequently repurposed for simple character logic. Built-in, zero dependency, MIT (it's part of the engine).
- **Hand-rolled GDScript FSM** — a small `State` base class + a `StateMachine` node is ~100 lines and a well-documented community pattern. For a handful of enemy states this is often the right call: no dependency to vet or pin, and full control.

### Comparison & recommendation

| Option | Type | Latest | Godot 4.6 | License | Maint. | Best for |
|---|---|---|---|---|---|---|
| **Beehave** | GDScript add-on | v2.9.2 (Dec 2025) | Yes (`4.x` branch, 2.10+) | MIT | Healthy | Pure-GDScript BTs, lowest friction |
| **LimboAI** | C++ module / GDExtension | v1.7.1 (Jun 2026) | Yes (explicit 4.6) | MIT | Very active | BT **+** HSM, perf, biggest feature set |
| **Built-in FSM / AnimationTree** | Engine built-in | n/a (4.6) | Yes | MIT (engine) | n/a | Simple enemy/agent states |

**Recommendation:**
- **Default to built-ins** for THE FAR YARD's early enemy AI — a hand-rolled GDScript FSM (or AnimationTree state machine) carries no dependency cost and is enough for simple junkyard mobs.
- **If/when AI complexity grows**, **APPROVE LimboAI (v1.7.1)** as the primary add-on. It is the most current, explicitly targets 4.6, is MIT, very actively maintained, and gives us *both* BTs and HSMs in one vetted dependency — fewer moving parts than mixing built-in FSM + Beehave. Use the **GDExtension** distribution to avoid custom engine builds. The trade-off is a C++ binary dependency (per-platform builds) vs. Beehave's drop-in GDScript.
- **Beehave is APPROVED as the alternative** if we want a pure-GDScript, no-binary option and only need behavior trees. Both are MIT and safe; the choice is architectural (GDScript simplicity vs. LimboAI's broader feature set and fresher 4.6 tagging).

---

## 4. Category 3 — Camera: Phantom Camera

**Repo:** <https://github.com/ramokz/phantom-camera> · **Site:** <https://phantom-camera.dev/> · **Asset Store:** <https://store.godotengine.org/asset/ramokz/phantom-camera/>

- **Latest version:** **v0.11.0.2**, released **2026-03-06** (commit `e468862`), following v0.11.0.1 (Mar 4) and v0.11 (Feb 28, 2026). Note the **0.x** version number — the API is still pre-1.0 and can have breaking changes between minor releases, so version-pinning matters more here than for the others.
- **Godot 4.6 support:** Yes. The Asset Store listing names Godot 4.6 compatibility, and there is active 4.6-specific issue traffic (e.g. issue #629). The plugin historically requires Godot 4.3+ (raised in v0.9.3) and tracks current Godot closely.
- **License:** **MIT** (confirmed via `LICENSE` on `main`).
- **Maintenance:** Active. Maintained primarily by ramokz, with frequent point releases and community bug reports being fixed quickly (e.g. v0.11.0.1 fixed an exported-build viewfinder preload issue within days). Has a dedicated docs site and FAQ.
- **Architecture:** Pure GDScript editor plugin. Inspired by Unity's Cinemachine — declarative `PhantomCamera2D`/`PhantomCamera3D` nodes with tweening, follow modes, and priority-based blending, driven by a `PhantomCameraHost`. Strong fit for a top-down 2D game needing smooth follow, look-ahead, and framing transitions.

**Recommendation: APPROVE.** MIT, actively maintained, 4.6-compatible, and the clear leading camera add-on for Godot. **Caveat:** it is pre-1.0 — **pin to v0.11.0.2** and treat minor-version bumps as breaking until 1.0 ships; review the changelog before upgrading. Vendor it (see §6) so a future API break can't break our build.

---

## 5. Approved add-on list (with pinned versions)

| Category | Add-on | Decision | Pinned version | Godot 4.6 | License | Last release | Repo |
|---|---|---|---|---|---|---|---|
| Dialogue | **Dialogue Manager** (Nathan Hoad) | **Approve** | **v3.10.4** | Yes (explicit 4.6 tag) | MIT | 2026-04-17 | [link](https://github.com/nathanhoad/godot_dialogue_manager) |
| AI — primary (if needed) | **LimboAI** | **Approve** (use GDExtension) | **v1.7.1** | Yes (explicit 4.6) | MIT | 2026-06-04 | [link](https://github.com/limbonaut/limboai) |
| AI — alternative | **Beehave** | **Approve (alt)** | **v2.9.2** | Yes (`4.x` branch) | MIT | 2025-12-02 | [link](https://github.com/bitbrain/beehave) |
| AI — default | **Built-in FSM / AnimationTree** | **Prefer first** | n/a (Godot 4.6) | Yes | MIT (engine) | — | Godot core |
| Camera | **Phantom Camera** | **Approve** (pin; pre-1.0) | **v0.11.0.2** | Yes | MIT | 2026-03-06 | [link](https://github.com/ramokz/phantom-camera) |

All four candidates clear every gate: MIT-licensed, Godot-4.6-compatible, and actively maintained. No GPL/non-commercial entanglements. The only license footnotes are the bundled **logo/demo art** (CC-BY) in Beehave and LimboAI — exclude or attribute those; the code itself is MIT.

---

## 6. General policy — prefer built-ins, vendor critical add-ons, pin versions

These three rules apply to every dependency in THE FAR YARD:

**1. Prefer built-ins.** Every add-on is a maintenance liability: it can lag an engine bump, get abandoned, change its license, or introduce bugs we can't fix as fast as the engine team fixes core. Before adopting, ask whether a Godot 4.6 built-in already covers the need (e.g., AnimationTree state machines, `Camera2D` with smoothing for simple cases, the built-in localization/POT pipeline). Adopt an add-on only when it clearly beats rolling our own *and* clears all four vetting gates.

**2. Vendor critical add-ons.** Commit the add-on's source into our repo under `addons/` (and binaries for GDExtension plugins like LimboAI) rather than relying on the Asset Library to fetch it at build time. This guarantees reproducible builds, insulates us from an upstream repo disappearing or force-pushing, and lets us hot-patch a bug locally without waiting for an upstream release. Record the exact upstream commit/tag we vendored in a short `addons/THIRD_PARTY.md` manifest so re-syncing later is trivial.

**3. Pin versions.** Lock each add-on to a specific tag (the versions in §5), never "latest" or a moving branch. Pre-1.0 add-ons (Phantom Camera) get extra scrutiny on upgrade because they can break API between minors. Upgrades are deliberate: read the changelog, bump in a branch, smoke-test, then re-vendor. Re-run this whole vetting pass at every Godot engine bump, since 4.6 → future-minor can shift compatibility.

**Re-verification checklist (run at adoption and each engine bump):** confirm the GitHub *latest release tag + date*, scan the *commit history* for recent activity, re-read the *LICENSE* file, check the *Asset Library / Asset Store* listing names the engine version, and skim *open issues* for 4.6-specific breakage reports.

---

## Sources

- [Dialogue Manager — GitHub repo](https://github.com/nathanhoad/godot_dialogue_manager)
- [Dialogue Manager — Releases (v3.10.4 for Godot 4.6, 2026-04-17)](https://github.com/nathanhoad/godot_dialogue_manager/releases)
- [Dialogue Manager — docs site](https://dialogue.nathanhoad.net/)
- [Beehave — GitHub repo (godot-4.x, MIT, ~3.1k stars)](https://github.com/bitbrain/beehave)
- [Beehave — LICENSE (MIT)](https://github.com/bitbrain/beehave/blob/godot-4.x/LICENSE)
- [Beehave — README compatibility table](https://github.com/bitbrain/beehave/blob/godot-4.x/README.md)
- [Beehave — v2.9.2 release (2025-12-02)](https://github.com/bitbrain/beehave/releases/tag/v2.9.2)
- [LimboAI — GitHub repo (Supported Godot 4.6, MIT)](https://github.com/limbonaut/limboai)
- [LimboAI — LICENSE (MIT-style)](https://github.com/limbonaut/limboai/blob/master/LICENSE.md)
- [LimboAI — v1.7.1 release (2026-06-04)](https://github.com/limbonaut/limboai/releases)
- [LimboAI — docs / supported-versions](https://limboai.readthedocs.io/)
- [LimboAI — Asset Library listing (Godot 4.4–4.5/4.6)](https://godotengine.org/asset-library/asset/3787)
- [Phantom Camera — GitHub repo](https://github.com/ramokz/phantom-camera)
- [Phantom Camera — Releases (v0.11.0.2, 2026-03-06)](https://github.com/ramokz/phantom-camera/releases)
- [Phantom Camera — LICENSE (MIT)](https://github.com/ramokz/phantom-camera/blob/main/LICENSE)
- [Phantom Camera — Asset Store listing](https://store.godotengine.org/asset/ramokz/phantom-camera/)
- [Phantom Camera — docs site](https://phantom-camera.dev/)
- [Godot Asset Library (verification source)](https://godotengine.org/asset-library)
- [Godot Asset Store (verification source)](https://store.godotengine.org)
